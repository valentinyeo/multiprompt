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
const prelude = `
const std = @import("std");
const chat_markdown = @import("chat_markdown.zig");
const link_detect = @import("link_detect.zig");
const ChatBlock = chat_markdown.Block;
const ChatBlockRole = chat_markdown.Role;
const HANDLE = usize;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
const ChatHit = struct { x: i32, y: i32, char: ?*usize = null };
const DT_SINGLELINE = 1;
const DT_NOPREFIX = 2;
var g_chat_sel_transcript_focus = false;
var code_flow = false;
var g_chat_tables: chat_markdown.TableCache = .{};
fn GetTickCount64() u64 { return 0; }
fn chatPerf(_: []const u8, _: u64, _: usize) void {}
var shown: [1024]u16 = undefined;
var shown_len: usize = 0;
var mapped = false;
fn L(comptime s: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(s); }
fn SelectObject(_: HANDLE, _: HANDLE) HANDLE { return 0; }
fn ensureChatCodeFont() HANDLE { return 1; }
fn ensureChatFont() HANDLE { return 2; }
fn chatTextWidth(_: HANDLE, text: []const u16) i32 { return @intCast(8 * chat_markdown.columnWidth(text)); }
fn uiScaled(n: i32) i32 { return n; }
fn customColorOr(_: []const u8, color: u32) u32 { return color; }
fn themeConsoleFg() u32 { return 0; }
fn SetTextColor(_: HANDLE, _: u32) u32 { return 0; }
fn DrawTextW(_: HANDLE, _: [*]const u16, _: i32, _: *RECT, _: u32) i32 { return 20; }
fn chatRichText(_: HANDLE, _: []const u16, _: RECT, _: u3, _: bool, _: ?ChatHit, _: usize, _: ?*i32) ?link_detect.Range { unreachable; }
fn chatFlowText(_: HANDLE, text: []const u16, _: RECT, code: bool, _: bool, _: ?ChatHit, _: usize, height: ?*i32, map: ?[]const usize) ?link_detect.Range {
    code_flow = code;
    shown_len = text.len;
    @memcpy(shown[0..shown_len], text);
    mapped = map != null and map.?.len == text.len;
    if (height) |h| h.* = @intCast(20 * (1 + std.mem.count(u16, text, &.{'\\n'})));
    return null;
}
`;
const acceptance = `
test "table surface: production filtering keeps narrative rows and hides real tool details" {
    const row = std.unicode.utf8ToUtf16LeStringLiteral("│ Event │ Status │");
    try std.testing.expect(!chatLineIsToolDetail(row));
    try std.testing.expect(chatLineIsToolDetail(std.unicode.utf8ToUtf16LeStringLiteral("⎿ tool result")));
    const text = std.unicode.utf8ToUtf16LeStringLiteral("● Healthy.\\r\\n\\r\\n│ Event │ Status │\\r\\n│ StZ   │ Active │\\r\\n\\r\\nWhat each part means:");
    var blocks: [8]ChatBlock = undefined;
    const n = chatClassifyBlocks(text, &blocks);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(ChatBlockRole.code, blocks[1].role);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("│ Event │ Status │\\r\\n│ StZ   │ Active │"), text[blocks[1].start .. blocks[1].start + blocks[1].len]);
}
test "table surface: production flow uses aligned code text for measure and paint" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| a | b |\\n|---|---|\\n| \`x\` | [site](https://example.test) |");
    var blocks: [4]ChatBlock = undefined;
    try std.testing.expectEqual(@as(usize, 1), chat_markdown.blocks(text, 0, .prose, &blocks));
    try std.testing.expectEqual(ChatBlockRole.code, blocks[0].role);
    var h: i32 = 0;
    for ([_]bool{ false, true }) |paint| {
        _ = chatFlowBlock(0, text, blocks[0], .{ .right = 320 }, paint, null, 0, &h);
        try std.testing.expect(code_flow and mapped);
        try std.testing.expectEqual(@as(i32, 60), h);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("| a  | b    |\\n|----|------|\\n| x  | site |"), shown[0..shown_len]);
    }
}
`;
function runHarness(control = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh309-'));
  try {
    for (const file of ['chat_markdown.zig', 'link_detect.zig']) fs.copyFileSync(`src/${file}`, path.join(dir, file));
    let functions = ['chatLineIsToolDetail', 'chatLineIsFence', 'chatFlushBlock', 'chatClassifyBlocks', 'chatFlowBlock'].map(body).join('\n');
    if (control) functions = functions.replace('line.len == 0 or chat_markdown.consoleTableRow(line)', 'line.len == 0');
    fs.writeFileSync(path.join(dir, 'test.zig'), prelude + functions + acceptance);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', 'table surface:'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('executed production table filtering, block classification and monospace flow retain all table content', () => {
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('console table oracle rejects the former tool-detail filter (positive control)', () => {
  const result = runHarness(true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /FAIL \(TestUnexpectedResult\)/);
});
test('table measurement, paint and hit tests reuse the existing code-block surface and source coordinates', () => {
  for (const name of ['chatMeasureBlockRect', 'chatPaintBlock', 'chatTranscriptLinkAt', 'chatTranscriptCharAt']) assert.match(body(name), /chatFlowBlock/);
  assert.match(body('chatPaintBlock'), /\.code => \{[^]*chatCodePanelColor\(\)[^]*chatPaintCodeHeader/);
  assert.match(body('chatFlowBlock'), /formatTable[^]*chatFlowText[^]*table\.source\.items/);
  assert.match(body('chatFlowText'), /source_map[^]*chatPaintSelectionRun/);
});
