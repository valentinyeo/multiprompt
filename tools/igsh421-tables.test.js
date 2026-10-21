const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const source = require('./app-source').readAppSource();
const fontSource = fs.readFileSync(path.join(__dirname, '../src/fonts.zig'), 'utf8');
const lineHeightPolicy = fontSource.match(/^pub const CHAT_LINE_HEIGHT_PERMILLE[^;]+;/m)[0] + '\n' + body('chatLineHeight', fontSource);
function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
const prelude = String.raw`
const std = @import("std");
const chat_hit = @import("chat_hit.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_code = @import("chat_code.zig");
const chat_style = @import("chat_style.zig");
const link_detect = @import("link_detect.zig");
const find = @import("chat_find_ui.zig");
const ChatBlock = chat_markdown.Block;
const HANDLE = ?*anyopaque;
const UINT = u32;
const WPARAM = usize;
const LPARAM = isize;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
const POINT = struct { x: i32, y: i32 };
const SIZE = struct { cx: i32, cy: i32 };
const ChatHit = struct { x: i32, y: i32, char: ?*usize = null };
const DT_CALCRECT = 1;
const DT_SINGLELINE = 2;
const DT_NOPREFIX = 4;
const WM_MOUSEHWHEEL = 0x020e;
const WM_MOUSEWHEEL = 0x020a;
const CHAT_CODE_PAD = 12;
const CHAT_AGENT_PAD_X = 16;
const CHAT_BUBBLE_PAD = 12;
const CHAT_AGENT_HEADER_H = 24;
var g_chat_tables: chat_markdown.TableCache = .{};
var g_chat_font_pt: i32 = 13;
var scale: i32 = 100;
var g_chat_sel_active = false;
var g_chat_sel_transcript_focus = false;
var g_chat_hover_link: ?link_detect.Range = null;
var g_light_theme = false;
var g_chat_blocks: [1]ChatBlock = undefined;
var g_chat_layout_rects: [1]RECT = undefined;
var g_chat_capture: []const u16 = &.{};
var g_chat_transcript_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_content_left: i32 = 0;
var g_chat_scroll_y: i32 = 0;
var font: usize = 1;
var logs: [16][192]u8 = undefined;
var log_lens: [16]usize = undefined;
var log_count: usize = 0;
var clips: usize = 0;
var grids: usize = 0;
var draws: usize = 0;
var invalidates: usize = 0;
var header_draws: usize = 0;
var normal_draws: usize = 0;
var selection_at: usize = 0;
var last_x: i32 = 0;
fn L(comptime s: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(s); }
fn SelectObject(_: HANDLE, handle: HANDLE) HANDLE { const old: HANDLE = @ptrFromInt(font); font = @intFromPtr(handle); return old; }
fn chatRichFont(style: chat_markdown.Style, _: u3) HANDLE { return @ptrFromInt(if (style.bold) @as(usize, 2) else if (style.code) @as(usize, 3) else 1); }
fn ensureChatFont() HANDLE { return @ptrFromInt(1); }
fn chatTextWidth(_: HANDLE, text: []const u16) i32 { return @as(i32, @intCast(text.len)) * (if (font == 2) @as(i32, 9) else 8); }
fn GetTextExtentExPointW(dc: HANDLE, text: [*]const u16, len: i32, available: i32, fit: *i32, _: ?*anyopaque, size: *SIZE) i32 {
    const width = chatTextWidth(dc, text[0..@intCast(len)]);
    fit.* = @min(len, @divTrunc(available, if (font == 2) @as(i32, 9) else 8));
    size.* = .{ .cx = width, .cy = 20 };
    return 1;
}
fn DrawTextW(_: HANDLE, _: [*]const u16, _: i32, rect: *RECT, flags: u32) i32 {
    if ((flags & DT_CALCRECT) == 0) {
        draws += 1; last_x = rect.left;
        if (font == 2) header_draws += 1 else normal_draws += 1;
    }
    return 20;
}
fn uiScaled(n: i32) i32 { return @divTrunc(n * scale, 100); }
fn customColorOr(_: []const u8, color: u32) u32 { return color; }
fn RGB(_: u8, _: u8, _: u8) u32 { return 0; }
fn themeConsoleFg() u32 { return 0; }
fn SetTextColor(_: HANDLE, _: u32) u32 { return 0; }
fn CreateSolidBrush(_: u32) HANDLE { return @ptrFromInt(1); }
fn FillRect(_: HANDLE, _: *const RECT, _: HANDLE) i32 { grids += 1; return 1; }
fn DeleteObject(_: HANDLE) i32 { return 1; }
fn SaveDC(_: HANDLE) i32 { return 1; }
fn RestoreDC(_: HANDLE, _: i32) i32 { return 1; }
fn IntersectClipRect(_: HANDLE, _: i32, _: i32, _: i32, _: i32) i32 { clips += 1; return 1; }
fn GetTickCount64() u64 { return 1; }
fn chatPerf(_: []const u8, _: u64, _: usize) void {}
fn debugLog(line: []const u8) void { @memcpy(logs[log_count][0..line.len], line); log_lens[log_count] = line.len; log_count += 1; }
fn chatCodePanelColor() u32 { return 0; }
fn chatPaintSelectionRun(_: HANDLE, _: []const u16, at: usize, _: i32, _: i32, _: i32) void { selection_at = at; }
fn pointInRect(r: RECT, x: i32, y: i32) bool { return x >= r.left and x < r.right and y >= r.top and y < r.bottom; }
fn chatCharAtX(_: HANDLE, _: []const u16, x: i32) usize { return @intCast(@max(0, @divTrunc(x, 8))); }
fn chatFlowText(_: HANDLE, _: []const u16, _: RECT, _: bool, _: bool, _: ?ChatHit, _: usize, _: ?*i32, _: ?[]const usize) ?link_detect.Range { return null; }
fn GET_X(lp: LPARAM) i32 { return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)))))); }
fn GET_Y(lp: LPARAM) i32 { return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16)))); }
fn ScreenToClient(_: HANDLE, _: *POINT) i32 { return 1; }
fn chatTranscriptBlockAtPoint(y: i32) ?usize { return if (y >= g_chat_layout_rects[0].top and y < g_chat_layout_rects[0].bottom) 0 else null; }
fn InvalidateRect(_: HANDLE, _: ?*const RECT, _: i32) i32 { invalidates += 1; return 1; }
fn GetDC(_: HANDLE) HANDLE { return @ptrFromInt(1); }
fn ReleaseDC(_: HANDLE, _: HANDLE) i32 { return 1; }
`;
const checks = String.raw`
test "ISSUE-421 production rich table caches layout clips draws and preserves hit source offsets while scrolled" {
    defer { g_chat_tables.deinit(std.heap.page_allocator); g_chat_tables = .{}; }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Header | Flag |\n|---|---|\n| **body** | [site](https://example.test) |");
    var blocks: [4]ChatBlock = undefined;
    _ = chat_markdown.blocks(text, 41, .prose, &blocks);
    var h: i32 = 0;
    const area = RECT{ .left = 20, .top = 30, .right = 120 };
    for (0..4) |_| _ = chatFlowBlock(null, text, blocks[0], area, true, null, 41, &h);
    try std.testing.expectEqual(@as(usize, 1), g_chat_tables.builds);
    try std.testing.expectEqual(@as(usize, 1), log_count);
    try std.testing.expect(std.mem.startsWith(u8, logs[0][0..log_lens[0]], "CHAT_TABLE rows=1 columns=2 header_bold=1 content_w="));
    try std.testing.expect(std.mem.endsWith(u8, logs[0][0..log_lens[0]], "view_w=100 source=pipe"));
    try std.testing.expectEqual(@as(i32, 74), h);
    try std.testing.expect(header_draws > 0 and normal_draws > 0 and grids > 0);
    try std.testing.expectEqual(@as(usize, 4), clips);
    const layout = &g_chat_tables.entries.getPtr(41).?.layout;
    layout.scroll = layout.content_w - layout.view_w;
    const cell_x = area.left - layout.scroll + layout.widths[0] + uiScaled(10);
    const cell_y = area.top + layout.heights[0] + uiScaled(6);
    var char: usize = 0;
    const link = chatFlowBlock(null, text, blocks[0], area, false, .{ .x = cell_x + 2, .y = cell_y + 1, .char = &char }, 41, null).?;
    const target = std.unicode.utf8ToUtf16LeStringLiteral("https://example.test");
    const label = std.unicode.utf8ToUtf16LeStringLiteral("site");
    try std.testing.expectEqualSlices(u16, target, text[link.start - 41 .. link.end - 41]);
    try std.testing.expectEqual(41 + std.mem.indexOf(u16, text, label).?, char);
    _ = chatFlowBlock(null, text, blocks[0], area, true, null, 41, null);
    try std.testing.expectEqual(41 + std.mem.indexOf(u16, text, label).?, selection_at);
    try std.testing.expectEqual(selection_at, find.last);
    try std.testing.expect(chatFlowBlock(null, text, blocks[0], area, false, .{ .x = area.left - 1, .y = cell_y }, 41, null) == null);
    _ = chatFlowBlock(null, text, blocks[0], .{ .right = 200 }, false, null, 41, null);
    g_chat_font_pt += 1;
    _ = chatFlowBlock(null, text, blocks[0], .{ .right = 200 }, false, null, 41, null);
    scale = 125;
    _ = chatFlowBlock(null, text, blocks[0], .{ .right = 200 }, false, null, 41, null);
    try std.testing.expectEqual(@as(usize, 4), g_chat_tables.builds);
    try std.testing.expectEqual(@as(usize, 4), log_count);
    scale = 100;
}
test "ISSUE-421 production box fragments stack find locates the containing row and both wheel routes clamp" {
    g_chat_tables.clear(std.heap.page_allocator);
    const a = std.testing.allocator;
    const text = try std.unicode.utf8ToUtf16LeAlloc(a, @embedFile("testdata/chat-table-fixture.terminal.txt"));
    defer a.free(text);
    var out: [4]ChatBlock = undefined;
    _ = chat_markdown.blocks(text, 0, .prose, &out);
    g_chat_blocks[0] = out[0];
    g_chat_blocks[0].first = false;
    g_chat_layout_rects[0] = .{ .right = 124, .bottom = 200 };
    g_chat_capture = text;
    _ = chatFlowBlock(null, text, out[0], .{ .right = 100 }, false, null, 0, null);
    const layout = &g_chat_tables.entries.getPtr(0).?.layout;
    try std.testing.expectEqual(@as(i32, 53), layout.heights[2]);
    try std.testing.expectEqual(@as(i32, CHAT_CODE_PAD), chatFindY(0, 0));
    const cpu = std.mem.indexOf(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("CPU")).?;
    try std.testing.expectEqual(@as(i32, CHAT_CODE_PAD + 66), chatFindY(0, cpu));
    try std.testing.expect(std.mem.endsWith(u8, logs[log_count - 1][0..log_lens[log_count - 1]], "source=box"));
    const pt: LPARAM = 20 | (20 << 16);
    try std.testing.expect(chatTableWheel(null, WM_MOUSEHWHEEL, 120 << 16, pt));
    try std.testing.expectEqual(@as(i32, 54), layout.scroll);
    try std.testing.expect(chatTableWheel(null, WM_MOUSEWHEEL, (120 << 16) | 4, pt));
    try std.testing.expectEqual(@as(i32, 0), layout.scroll);
    try std.testing.expect(!chatTableWheel(null, WM_MOUSEWHEEL, 120 << 16, pt));
    try std.testing.expect(!chatTableWheel(null, WM_MOUSEHWHEEL, 120 << 16, 4 | (20 << 16)));
    try std.testing.expectEqual(@as(usize, 2), invalidates);
}
test "ISSUE-421 nested marker and body share the depth indent and trace only their first layout" {
    const text = std.unicode.utf8ToUtf16LeStringLiteral("- child");
    const block = ChatBlock{ .start = 500, .len = text.len, .role = .prose, .kind = .list, .markdown = true, .prefix = 2, .level = 2 };
    const before = log_count;
    _ = chatFlowBlock(null, text, block, .{ .right = 400 }, true, null, 500, null);
    try std.testing.expectEqual(@as(i32, 74), last_x);
    _ = chatFlowBlock(null, text, block, .{ .right = 400 }, true, null, 500, null);
    try std.testing.expectEqual(before + 1, log_count);
    try std.testing.expectEqualStrings("CHAT_LIST depth=2", logs[before][0..log_lens[before]]);
}
`;
function execute(control) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh421-grid-'));
  try {
    copyZig(['chat_hit.zig', 'chat_markdown.zig', 'chat_code.zig', 'chat_style.zig', 'link_detect.zig'], dir);
    fs.writeFileSync(path.join(dir, 'chat_find_ui.zig'), 'pub var last: usize = 0;\npub fn paintRun(_: anytype, _: []const u16, at: usize, _: i32, _: i32, _: i32) void { last = at; }\n');
    let functions = ['chatRichText', 'chatTableCellSize', 'chatTableLayout', 'chatFlowTable', 'chatFlowBlock', 'chatTableWheel', 'chatFindY'].map(name => body(name)).join('\n');
    if (control) functions = functions.replace('area.left - layout.scroll;', 'area.left;');
    fs.writeFileSync(path.join(dir, 'test.zig'), prelude + lineHeightPolicy + '\n' + functions + checks);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', 'ISSUE-421'], { encoding: 'utf8', timeout: 120000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('ISSUE-421 executed production grid layout, rich cells, clipping, traces, find and horizontal input', () => {
  const result = execute(false);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('ISSUE-421 production hit-test oracle rejects missing horizontal source translation', () => {
  const result = execute(true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /FAIL|panic: attempt to use null value/);
});

test('ISSUE-421 wheel routing works while the composer owns keyboard focus', () => {
  const main = fs.readFileSync('src/main.zig', 'utf8');
  assert.match(main, /WM_MOUSEWHEEL, WM_MOUSEHWHEEL => \{[^]*?pointInRect\(layout\.transcript, pt\.x, pt\.y\)[^]*?chatTableWheel\(app_state\.g_chat_transcript_hwnd, msg, wp, lp\)/);
});
