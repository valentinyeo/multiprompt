const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
function runHarness(control = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh421-capture-'));
  try {
    copyZig(['chat_markdown.zig', 'link_detect.zig', 'voice_filter.zig'], dir);
    let functions = ['chatLineIsToolDetail', 'chatLineIsFence', 'chatFlushBlock', 'chatClassifyBlocks', 'chatIsRuleGlyph', 'chatLineIsTitledRule', 'chatLineLooksLikeTitledRule', 'chatLineLooksLikeComposerRule', 'chatLineIsDivider', 'chatLineHasActivityMarker', 'chatListMarkerLen', 'chatLineStartsStructuredBlock', 'chatJoinedRowsNeedSpace', 'chatReflowTranscript', 'chatWideStartsWithAscii', 'chatWideContainsAscii', 'chatLineHasComposerFooter', 'chatTranscriptWithoutComposer'].map(body).join('\n');
    let chrome = body('captureChatTranscript').match(/\((?:!table_line and )?!tool_header and voice_filter\.isClaudeChrome\(line\)\)/)[0];
    if (control === 'chrome') chrome = chrome.replace('!table_line and ', '');
    if (control === 'reflow') functions = functions.replace('previous_was_divider = is_divider or table_line;', 'previous_was_divider = is_divider;').replace('const table_line = chat_markdown.consoleTableLine(line);', '');
    if (control === true) functions = functions.replace('line.len == 0 or chat_markdown.consoleTableLine(line)', 'line.len == 0');
    fs.writeFileSync(path.join(dir, 'test.zig'), String.raw`
const std = @import("std");
const chat_markdown = @import("chat_markdown.zig");
const ChatBlock = chat_markdown.Block;
const ChatBlockRole = chat_markdown.Role;
const link_detect = @import("link_detect.zig");
const voice_filter = @import("voice_filter.zig");
var g_chat_line_starts: [32]usize = undefined;
var g_chat_line_lens: [32]usize = undefined;
${functions}
test "table surface: chrome filtering keeps structural borders but hides real chrome" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    for ([_]struct { text: []const u16, table: bool, hidden: bool }{
        .{ .text = w("┌─┬─┐"), .table = true, .hidden = false },
        .{ .text = w("├─┼─┤"), .table = true, .hidden = false },
        .{ .text = w("└─┴─┘"), .table = true, .hidden = false },
        .{ .text = w("│A│B│"), .table = true, .hidden = false },
        .{ .text = w("────"), .table = false, .hidden = true },
        .{ .text = w("✔ Update installed · Restart to update"), .table = false, .hidden = true },
        .{ .text = w("ordinary prose"), .table = false, .hidden = false },
    }) |sample| {
        const line = sample.text;
        const table_line = chat_markdown.consoleTableLine(line);
        const tool_header = false;
        try std.testing.expectEqual(sample.table, table_line);
        try std.testing.expectEqual(sample.hidden, ${chrome});
    }
}
test "table surface: narrative rows survive while genuine tool details stay hidden" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    try std.testing.expect(!chatLineIsToolDetail(w("│ Event │ Status │")));
    try std.testing.expect(!chatLineIsToolDetail(w("├────┼────┤")));
    try std.testing.expect(!chatLineIsToolDetail(w("└────┴────┘")));
    try std.testing.expect(chatLineIsToolDetail(w("⎿ tool result")));
    try std.testing.expect(chatLineIsToolDetail(w("├ tool detail")));
    try std.testing.expect(chatLineIsToolDetail(w("└ tool detail")));
    const text = w("● Healthy.\r\n\r\n│ Event │ Status │\r\n│ StZ   │ Active │\r\n\r\nWhat each part means:");
    var blocks: [8]ChatBlock = undefined;
    const n = chatClassifyBlocks(text, &blocks);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(ChatBlockRole.code, blocks[1].role);
}
test "table surface: complete captured box grid is exactly one table block" {
    const a = std.testing.allocator;
    const fixture = @embedFile("testdata/chat-table-fixture.terminal.txt");
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try wire.appendSlice(a, "● Before\r\ncontinued\r\n\r\n");
    for (fixture) |c| {
        if (c == '\n') try wire.append(a, '\r');
        try wire.append(a, c);
    }
    try wire.appendSlice(a, "After");
    const text = try std.unicode.utf8ToUtf16LeAlloc(a, wire.items);
    defer a.free(text);
    var blocks: [8]ChatBlock = undefined;
    var row_count: usize = 0;
    var at: usize = 0;
    while (at < text.len) {
        const end = std.mem.indexOfPos(u16, text, at, &.{ '\r', '\n' }) orelse text.len;
        g_chat_line_starts[row_count] = at;
        g_chat_line_lens[row_count] = end - at;
        row_count += 1;
        at = @min(end + 2, text.len);
    }
    const reflowed = try a.dupe(u16, text);
    defer a.free(reflowed);
    const reflow_len = chatReflowTranscript(reflowed, g_chat_line_starts[0..row_count], g_chat_line_lens[0..row_count], &([_]bool{false} ** 32), &.{});
    const n = chatClassifyBlocks(reflowed[0..reflow_len], &blocks);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(chat_markdown.Kind.table, blocks[1].kind);
    var table = try chat_markdown.parseTable(a, reflowed[blocks[1].start..][0..blocks[1].len]);
    defer table.deinit(a);
    try std.testing.expectEqual(@as(usize, 3), table.rows.items.len);
    try std.testing.expectEqual(@as(usize, 2), table.rows.items[2].cells[0].fragments.items.len);
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    try std.testing.expect(!chatLineLooksLikeComposerRule(w("└───────────┴───────────┘")));
    const prompt = w("│ body │\r\n└───────────┴───────────┘\r\n❯ draft");
    g_chat_line_starts[0] = 0;
    g_chat_line_lens[0] = 8;
    g_chat_line_starts[1] = 10;
    g_chat_line_lens[1] = 25;
    g_chat_line_starts[2] = 37;
    g_chat_line_lens[2] = 7;
    try std.testing.expectEqual(@as(usize, 35), chatTranscriptWithoutComposer(prompt, 3));
}
`);
    const file = path.join(dir, 'test.zig');
    return spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'table surface:'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('production table filtering and capture grouping keep the complete terminal grid', () => {
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('console table oracle rejects the former tool-detail filter', () => {
  const result = runHarness(true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /FAIL \(TestUnexpectedResult\)/);
});
test('table measure, paint, link and character hit testing share rich grid flow', () => {
  for (const name of ['chatMeasureBlockRect', 'chatPaintBlock', 'chatTranscriptLinkAt', 'chatTranscriptCharAt']) assert.match(body(name), /chatFlowBlock/);
  assert.match(body('chatFlowBlock'), /block\.kind == \.table\) return chatFlowTable/);
  assert.match(body('chatFlowTable'), /chatRichText/);
  assert.match(body('captureChatTranscript'), /table_line\) hiding_tool_block = false/);
});

test('terminal table oracle rejects reflow joining the closing border to adjacent prose', () => {
  const result = runHarness('reflow');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /FAIL/);
});

test('IGSH-436 console chrome oracle rejects dropping the real table borders', () => {
  const result = runHarness('chrome');
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected false, found true/);
});
