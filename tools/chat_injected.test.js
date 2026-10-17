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
const chat_style = @import("chat_style.zig");
const chat_transcript = @import("chat_transcript.zig");
const chat_echo = @import("chat_echo.zig");
const ChatBlock = chat_markdown.Block;
const HANDLE = usize;
const DWORD = u32;
const UINT = u32;
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
const CHAT_BUBBLE_RADIUS = 4;
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
var g_chat_window_full = false;
var g_chat_blocks: [3]ChatBlock = undefined;
var g_chat_block_count: usize = 0;
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
fn DrawTextW(_: HANDLE, text: [*]const u16, len: i32, rc: *RECT, flags: UINT) i32 {
    if ((flags & DT_CALCRECT) != 0) { rc.right = @min(rc.right, len * 8); return 20; }
    metadata_len = @intCast(len);
    @memcpy(metadata[0..metadata_len], text[0..metadata_len]);
    return 20;
}
fn chatBlockDisplayRange(_: []const u16, block: ChatBlock) struct { start: usize, len: usize } { return .{ .start = block.start, .len = block.len }; }
fn chatImgMeasure(_: []const u16, _: i32) ChatImgLayout { return .{}; }
fn chatFlowBlock(_: HANDLE, text: []const u16, _: ChatBlock, area: RECT, paint: bool, _: ?usize, _: usize, height: ?*i32) ?usize {
    if (height) |h| h.* = 20 * @as(i32, @intCast(1 + text.len * 8 / @as(usize, @intCast(@max(1, area.right - area.left)))));
    if (paint) { drawn_len = text.len; @memcpy(drawn[0..drawn_len], text); }
    return null;
}
fn fillRoundRectAA(_: HANDLE, rc: RECT, r: i32, color: DWORD) void { fill = color; filled = rc; radius = r; }
fn fillBubbleAA(_: HANDLE, _: RECT, _: i32, _: DWORD, _: bool, _: bool) void {}
fn chatCodePanelColor() DWORD { return 0; }
fn chatPaintCodeHeader(_: HANDLE, _: RECT, _: ChatBlock) void {}
fn chatPaintAgentHeader(_: HANDLE, _: ChatBlock, _: RECT) void { headers += 1; }
fn chatEchoBlockConfirmed(_: []const u16, _: ChatBlock) bool { return true; }
`;
const acceptance = `
test "injected production paint metadata geometry and user-send matching" {
    var text: [512]u16 = undefined;
    const message = try chat_transcript.messageBlocks("<cross-session-message from='uds:/private.sock' from-mode='bypass' from-name='RUNNER 7'>scope &amp; tests</cross-session-message>", &text, 0, .user, &g_chat_blocks);
    var injected = g_chat_blocks[0];
    const stamp = chat_style.timestamp("2026-10-03T17:32:00Z");
    injected.time = stamp.time;
    injected.zone = stamp.zone;
    var user = injected;
    user.role = .user;
    for ([_]i32{ 100, 320, 800 }) |width| {
        const user_rc = chatMeasureBlockRect(0, text[0..message.len], user, .single, width, 10, null);
        const injected_rc = chatMeasureBlockRect(0, text[0..message.len], injected, .single, width, 10, null);
        try std.testing.expect(std.meta.eql(user_rc, injected_rc));
        try std.testing.expectEqual(width, injected_rc.right);
        try std.testing.expect(injected_rc.right - injected_rc.left <= chat_style.bubbleMaxWidth(width));
        chatPaintBlock(0, text[0..message.len], injected, .single, injected_rc);
        try std.testing.expectEqual(@as(u32, 0xFF1E2F4F), chat_style.argb(fill));
        try std.testing.expectEqual(@as(i32, 4), radius);
        try std.testing.expectEqual(injected_rc.bottom - CHAT_STATUS_H, filled.bottom);
        try std.testing.expectEqual(@as(usize, 0), headers);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("scope & tests"), drawn[0..drawn_len]);
        try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("from RUNNER 7 · 17:32 UTC"), metadata[0..metadata_len]);
    }
    bg = 0xFFFFFF;
    g_light_theme = true;
    chatPaintBlock(0, text[0..message.len], injected, .single, .{ .right = 320, .bottom = 100 });
    try std.testing.expectEqual(@as(u32, 0xFFD6E6F7), chat_style.argb(fill));
    injected.time = @splat(0);
    chatPaintTime(0, injected, .{}, true, true);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("from RUNNER 7"), metadata[0..metadata_len]);
    chatPaintTime(0, user, .{}, true, true);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("17:32 UTC ✓✓ Read"), metadata[0..metadata_len]);

}
`;
function runHarness(oldColor = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh299-'));
  try {
    for (const file of ['chat_markdown.zig', 'chat_style.zig', 'chat_transcript.zig', 'chat_echo.zig']) fs.copyFileSync(`src/${file}`, path.join(dir, file));
    let functions = ['chatUserBubbleColor', 'chatAgentBubbleColor', 'chatInjectedBubbleColor', 'chatMeasureBlockRect', 'chatPaintTime', 'chatPaintBlock', 'chatStatusRowRect'].map(body).join('\n');
    if (oldColor) functions = functions.replace('if (block.role == .injected) chatInjectedBubbleColor() else chatUserBubbleColor()', 'chatUserBubbleColor()');
    fs.writeFileSync(path.join(dir, 'test.zig'), prelude + functions + acceptance);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', 'injected production'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('executed production paint uses blue user geometry, sender metadata and no user-send confirmation', () => {
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('paint oracle rejects the former grey user fill (positive control)', () => {
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
