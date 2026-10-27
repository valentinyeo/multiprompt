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
const prelude = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const chat_markdown = @import("chat_markdown.zig");
const chat_style = @import("chat_style.zig");
const chat_transcript = @import("chat_transcript.zig");
const chat_echo = @import("chat_echo.zig");
const chat_reply = @import("chat_reply.zig");
const chat_diff = @import("chat_diff.zig");
const ChatBlock = chat_markdown.Block;
const HANDLE = usize;
var clean_chat: bool = false;
var active_shell: usize = 0;
var shell_count: usize = 1;
const shells = [_]struct { name: []const u16, name_len: usize }{.{ .name = std.unicode.utf8ToUtf16LeStringLiteral("REVIEWER"), .name_len = 8 }};
const DWORD = u32;
const UINT = u32;
fn L(comptime text: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(text); }
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
const DT_CALCRECT: u32 = 1;
const DT_WORDBREAK: u32 = 2;
const DT_NOPREFIX: u32 = 4;
const DT_SINGLELINE: u32 = 8;
const DT_VCENTER: u32 = 16;
const DT_END_ELLIPSIS: u32 = 32;
const DT_RIGHT: u32 = 64;
const TRANSPARENT = 1;
const CHAT_BUBBLE_PAD = 12;
const CHAT_BUBBLE_RADIUS = 20;
const CHAT_STATUS_H = 18;
const CHAT_AGENT_HEADER_H = 22;
const CHAT_AGENT_PAD_X = 12;
const CHAT_AGENT_PAD_Y = 10;
const CHAT_PARA_GAP = 8;
const CHAT_CODE_PAD = 12;
const CHAT_CODE_HEADER = 28;
const CHAT_IMG_GAP = 8;
const CHAT_ECHO_RECENT_USER_BLOCKS = 4;
const ChatImgLayout = struct { count: usize = 0, max_w: i32 = 0, total_h: i32 = 0, origin_x: i32 = 0, origin_y: i32 = 0 };
var g_light_theme = false;
var bg: u32 = 0;
var fill: u32 = 0;
var radius: i32 = 0;
var filled: RECT = .{};
var metadata: [96]u16 = @splat(0);
var metadata_len: usize = 0;
var drawn: [512]u16 = undefined;
var drawn_len: usize = 0;
var headers: usize = 0;
var diff_fills: [64]struct { color: u32, rc: RECT } = undefined;
var diff_fill_count: usize = 0;
fn CreateSolidBrush(color: u32) HANDLE { return color; }
fn FillRect(_: HANDLE, rc: *const RECT, brush: HANDLE) i32 {
    diff_fills[diff_fill_count] = .{ .color = @intCast(brush), .rc = rc.* };
    diff_fill_count += 1;
    return 1;
}
fn DeleteObject(_: HANDLE) i32 { return 1; }
var g_chat_window_full = false;
var g_chat_blocks: [3]ChatBlock = undefined;
var g_chat_block_count: usize = 0;
var g_chat_scroll_y: i32 = 0;
var g_chat_content_left: i32 = 0;
var g_chat_layout_rects: [3]RECT = undefined;
var relayouts: usize = 0;
fn chatImageReady() void { relayouts += 1; }
fn uiScaled(n: i32) i32 { return n; }
fn customColorOr(_: []const u8, color: u32) u32 { return color; }
fn themeConsoleBg() u32 { return bg; }
fn themeConsoleFg() u32 { return if (g_light_theme) 0 else 0xFFFFFF; }
fn RGB(r: u32, g: u32, b: u32) u32 { return r | (g << 8) | (b << 16); }
fn SelectObject(_: HANDLE, _: HANDLE) HANDLE { return 0; }
fn ensureChatFont() HANDLE { return 0; }
fn ensureChatCodeFont() HANDLE { return 0; }
fn chatMetadataFont() HANDLE { return 0; }
fn SetTextColor(_: HANDLE, _: DWORD) DWORD { return 0; }
fn SetBkMode(_: HANDLE, _: i32) i32 { return 0; }
const chatDrawText = DrawTextW;
fn DrawTextW(_: HANDLE, text: [*]const u16, len: i32, rc: *RECT, flags: UINT) i32 {
    if ((flags & DT_CALCRECT) != 0) { rc.right = @min(rc.right, len * 8); return 20; }
    metadata_len = if (len < 0) std.mem.len(@as([*:0]const u16, @ptrCast(text))) else @intCast(len);
    @memcpy(metadata[0..metadata_len], text[0..metadata_len]);
    return 20;
}
fn chatBlockDisplayRange(_: []const u16, block: ChatBlock) struct { start: usize, len: usize } { return .{ .start = block.start, .len = block.len }; }
fn chatImgMeasure(_: []const u16, _: i32) ChatImgLayout { return .{}; }
fn chatBlockNaturalWidth(_: HANDLE, text: []const u16, _: ChatBlock, _: usize, max_width: i32) i32 { return @min(max_width, @as(i32, @intCast(text.len)) * 8); }
fn chatFlowBlock(_: HANDLE, text: []const u16, _: ChatBlock, area: RECT, paint: bool, _: ?usize, _: usize, height: ?*i32) ?usize {
    if (height) |h| h.* = 20 * @as(i32, @intCast(1 + text.len * 8 / @as(usize, @intCast(@max(1, area.right - area.left)))));
    if (paint) { drawn_len = text.len; @memcpy(drawn[0..drawn_len], text); }
    return null;
}
fn chatFlowText(dc: HANDLE, text: []const u16, area: RECT, _: bool, paint: bool, _: ?usize, offset: usize, height: ?*i32, _: ?[]const usize, comptime _: bool) ?usize {
    return chatFlowBlock(dc, text, .{ .start = offset, .len = text.len, .role = .code }, area, paint, null, offset, height);
}
fn fillRoundRectAA(_: HANDLE, rc: RECT, r: i32, color: DWORD) void { fill = color; filled = rc; radius = r; }
fn fillBubbleAA(_: HANDLE, _: RECT, _: i32, _: DWORD, _: bool, _: bool) void {}
fn fillBubbleStyled(_: HANDLE, rc: RECT, r: i32, color: DWORD, _: bool, _: bool) void { fill = color; filled = rc; radius = r; }
fn chatCodePanelColor() DWORD { return 0; }
fn chatPaintCodeHeader(_: HANDLE, _: RECT, _: ChatBlock) void {}
fn chatPaintAgentHeader(_: HANDLE, _: ChatBlock, _: RECT) void { headers += 1; }
fn chatEchoBlockConfirmed(_: []const u16, _: ChatBlock) bool { return true; }
`;
const acceptance = `
test "production compact reference paints only the reply body above its bubble" {
    const w = std.unicode.utf8ToUtf16LeStringLiteral;
    const text = w("> Original message\\n> Second source line\\n> Third source line\\n\\nMy answer");
    const block = ChatBlock{ .start = 0, .len = text.len, .role = .user };
    const rect = chatMeasureBlockRect(0, text, block, .single, 400, 10, null);
    chatPaintBlock(0, text, block, .single, rect);
    try std.testing.expectEqualSlices(u16, w("My answer"), drawn[0..drawn_len]);
    try std.testing.expectEqualSlices(u16, w("↩ Original message"), metadata[0..metadata_len]);
    try std.testing.expectEqual(rect.top + 24, filled.top);
    try std.testing.expectEqual(rect.bottom, filled.bottom);
    try std.testing.expect(rect.bottom - rect.top < 100);
}
test "injected production folded rows and open body preserve ordinary user bubbles" {
    var text: [512]u16 = undefined;
    const message = try chat_transcript.messageBlocks("<cross-session-message from='uds:/private.sock' from-mode='bypass' from-name='RUNNER 7'>scope &amp; tests</cross-session-message>", &text, 0, .user, &g_chat_blocks);
    var injected = g_chat_blocks[0];
    const stamp = chat_style.timestamp("2026-10-03T17:32:00Z");
    injected.time = stamp.time;
    injected.zone = stamp.zone;
    var user = injected;
    user.role = .user;
    for ([_]bool{ false, true }) |light| {
        g_light_theme = light;
        bg = if (light) 0xFFFFFF else 0;
        for ([_]i32{ 100, 320, 800 }) |width| {
            const user_rc = chatMeasureBlockRect(0, text[0..message.len], user, .single, width, 10, null);
            try std.testing.expectEqual(width, user_rc.right);
            try std.testing.expect(user_rc.right - user_rc.left <= chat_style.bubbleMaxWidth(width, uiScaled(720)));
            chatPaintBlock(0, text[0..message.len], user, .single, user_rc);
            try std.testing.expectEqual(if (light) @as(u32, 0xFFE5E5E5) else @as(u32, 0xFF353535), chat_style.argb(fill));
            try std.testing.expectEqual(@as(i32, 20), radius);
            try std.testing.expectEqual(user_rc.bottom, filled.bottom);
            try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("scope & tests"), drawn[0..drawn_len]);
            for ([_]bool{ false, true }) |open| {
                injected.note_open = open;
                const rc = chatMeasureBlockRect(0, text[0..message.len], injected, .single, width, 10, null);
                try std.testing.expectEqual(@as(i32, 0), rc.left);
                if (open) try std.testing.expect(rc.bottom - rc.top > 28) else try std.testing.expectEqual(@as(i32, 28), rc.bottom - rc.top);
                fill = 0x123456;
                drawn_len = 0;
                chatPaintBlock(0, text[0..message.len], injected, .single, rc);
                try std.testing.expectEqual(@as(u32, 0x123456), fill);
                try std.testing.expectEqual(@as(usize, 0), headers);
                try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("RUNNER 7 to REVIEWER"), metadata[0..metadata_len]);
                if (open) try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("scope & tests"), drawn[0..drawn_len]) else try std.testing.expectEqual(@as(usize, 0), drawn_len);
            }
        }
    }
    injected.time = @splat(0);
    chatPaintTime(0, injected, .{}, true);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("from RUNNER 7"), metadata[0..metadata_len]);
    metadata_len = 0;
    chatPaintTime(0, user, .{}, true);
    try std.testing.expectEqual(@as(usize, 0), metadata_len);
    g_light_theme = false;
    bg = 0;
}
test "ISSUE-270 production folded and open diff rows fill the card without wrapping" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("Edited foo +4 -2-a\\n+b\\n c\\n+d\\n-e\\n+f\\n g");
    const summary = std.unicode.utf8ToUtf16LeStringLiteral("Edited foo +4 -2").len;
    var tool = ChatBlock{ .start = 0, .len = summary, .role = .tool, .diff_start = summary, .diff_len = text.len - summary };
    for ([_]bool{ false, true }) |light| {
        g_light_theme = light;
        for ([_]bool{ false, true }) |open| {
            tool.tool_open = open;
            const rect = chatMeasureBlockRect(0, text, tool, .single, 160, 40, null);
            const rows: usize = if (open) 7 else 6;
            try std.testing.expectEqual(40 + 28 + @as(i32, @intCast(rows)) * chat_diff.row_height, rect.bottom);
            diff_fill_count = 0;
            chatPaintBlock(0, text, tool, .single, rect);
            try std.testing.expectEqual(rows, diff_fill_count);
            try std.testing.expectEqual(if (light) chat_diff.removed_light else chat_diff.removed_dark, diff_fills[0].color);
            try std.testing.expectEqual(if (light) chat_diff.added_light else chat_diff.added_dark, diff_fills[1].color);
            try std.testing.expectEqual(chatCodePanelColor(), diff_fills[2].color);
            for (diff_fills[0..rows], 0..) |row, i| {
                try std.testing.expectEqual(rect.left, row.rc.left);
                try std.testing.expectEqual(rect.right, row.rc.right);
                try std.testing.expectEqual(rect.top + 28 + @as(i32, @intCast(i)) * chat_diff.row_height, row.rc.top);
                try std.testing.expectEqual(chat_diff.row_height, row.rc.bottom - row.rc.top);
            }
            try std.testing.expectEqual(rect.bottom, diff_fills[rows - 1].rc.bottom);
        }
    }
    g_light_theme = false;
}
test "ISSUE-263 production tool geometry painting folding hit testing and open-all" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("Ran testsinput\\n\\noutput");
    const summary_len = std.unicode.utf8ToUtf16LeStringLiteral("Ran tests").len;
    var tool = ChatBlock{ .start = 0, .len = summary_len, .role = .tool, .first = true, .detail_start = summary_len, .detail_len = text.len - summary_len };
    const folded = chatMeasureBlockRect(0, text, tool, .single, 160, 40, null);
    try std.testing.expectEqual(@as(i32, 28), folded.bottom - folded.top);
    headers = 0;
    drawn_len = 0;
    for ([_]chat_markdown.ToolStatus{ .running, .ok, .@"error" }) |status| {
        tool.tool_status = status;
        chatPaintBlock(0, text, tool, .single, folded);
        try std.testing.expectEqual(@as(usize, 0), headers);
        try std.testing.expectEqual(@as(usize, 0), drawn_len);
        try std.testing.expectEqualSlices(u16, text[0..summary_len], metadata[0..metadata_len]);
    }
    tool.tool_open = true;
    const expanded = chatMeasureBlockRect(0, text, tool, .single, 160, 40, null);
    try std.testing.expect(expanded.bottom > folded.bottom);
    chatPaintBlock(0, text, tool, .single, expanded);
    try std.testing.expectEqualSlices(u16, text[summary_len..], drawn[0..drawn_len]);
    g_chat_blocks[0] = tool;
    g_chat_block_count = 1;
    g_chat_layout_rects[0] = expanded;
    g_chat_scroll_y = 20;
    g_chat_content_left = 30;
    try std.testing.expectEqual(@as(?usize, 0), chatToolAt(40, 25));
    try std.testing.expectEqual(@as(?usize, null), chatToolAt(29, 25));
    try std.testing.expectEqual(@as(?usize, null), chatToolAt(40, 50));
    g_chat_blocks[1] = .{ .start = 0, .len = 1, .role = .prose };
    g_chat_block_count = 2;
    chatToggleAllTools();
    try std.testing.expect(!g_chat_blocks[0].tool_open);
    chatToggleAllTools();
    try std.testing.expect(g_chat_blocks[0].tool_open);
    try std.testing.expect(!g_chat_blocks[1].tool_open);
    try std.testing.expectEqual(@as(usize, 2), relayouts);
}

`;
function runHarness(oldColor = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh299-'));
  try {
    copyZig(['chat_markdown.zig', 'chat_style.zig', 'chat_transcript.zig', 'chat_echo.zig', 'chat_diff.zig', 'chat_reply.zig'], dir);
    let functions = [...['chatReplyLineHeight', 'chatPaintReplyLine'].filter(name => source.includes(`fn ${name}(`)), 'chatUserBubbleColor', 'chatAgentBubbleColor', 'chatInjectedBubbleColor', 'chatMeasureBlockRect', 'chatPaintTime', 'chatNoteBodyRect', 'chatPaintBlock', 'chatStatusRowRect', 'chatToolAt', 'chatTranscriptBlockAtPoint', 'chatToggleAllTools'].map(body).join('\n');
    if (oldColor) functions = functions.replace('chat_style.bubbleColors(themeConsoleBg()).user', 'chat_style.bubbleColors(themeConsoleBg()).agent');
    fs.writeFileSync(path.join(dir, 'test.zig'), (prelude + functions + acceptance).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', 'production'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('executed production paint folds runner rows and preserves ordinary user bubbles', () => {
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('paint oracle rejects assistant fill on user bubbles (positive control)', () => {
  const result = runHarness(true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected \d+, found \d+/);
});
test('inbox preview and unread are not transcript-user driven; hit tests and voice exclude injected replies', () => {
  assert.match(body('chatEchoAssignForKey'), /b\.role != \.user/);
  assert.match(body('captureShellPreview'), /ReadConsoleOutputCharacterW/);
  assert.doesNotMatch(body('captureShellPreview'), /g_chat_blocks|chat_transcript|\.role/);
  assert.match(body('publishInboxStateNow'), /shells\[i\]\.needs_attention/);
  assert.doesNotMatch(body('publishInboxStateNow'), /g_chat_blocks|chat_transcript|\.role/);
  for (const name of ['chatTranscriptCharAt', 'chatTranscriptLinkAt', 'chatFlowBlock', 'voiceReadReply', 'chatLatestAgentReply']) assert.match(body(name), /\.injected/);
});
