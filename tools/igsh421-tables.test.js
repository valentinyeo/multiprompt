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
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const chat_hit = @import("chat_hit.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_code = @import("chat_code.zig");
const chat_style = @import("chat_style.zig");
const link_detect = @import("link_detect.zig");
const find_ui = @import("chat_find_ui.zig");
const ChatBlock = chat_markdown.Block;
const HANDLE = ?*anyopaque;
const UINT = u32;
const WPARAM = usize;
const LPARAM = isize;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
const POINT = struct { x: i32, y: i32 };
const SIZE = struct { cx: i32, cy: i32 };
const ChatHit = struct { x: i32, y: i32, char: ?*usize = null, find: ?struct { position: usize, y: *i32 } = null };
const DT_CALCRECT = 1;
const DT_SINGLELINE = 2;
const DT_NOPREFIX = 4;
const WM_MOUSEHWHEEL = 0x020e;
const WM_MOUSEWHEEL = 0x020a;
const CHAT_CODE_PAD = 12;
const CHAT_FIND_TOP_H = 40;
var g_chat_find_open = false;
const CHAT_AGENT_PAD_X = 16;
const CHAT_BUBBLE_PAD = 12;
const CHAT_AGENT_HEADER_H = 22;
var g_chat_tables: chat_markdown.TableCache = .{};
var g_chat_received: chat_markdown.BlockCache = .{};
var chat_received_parses: usize = 0;
var g_chat_last_len: usize = 0;
var g_chat_font_pt: i32 = 13;
var scale: i32 = 100;
var g_chat_sel_active = false;
var g_chat_sel_transcript_focus = false;
var g_chat_hover_link: ?link_detect.Range = null;
var g_light_theme = false;
var g_chat_block_count: usize = 1;
var g_chat_blocks: [3]ChatBlock = undefined;
var g_chat_layout_rects: [3]RECT = undefined;
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
var rounded: usize = 0;
var captures: usize = 0;
var last_invalidate: ?RECT = null;
var last_thumb: RECT = .{};
var last_thumb_color: u32 = 0;
var chat_table_drag: ?struct { offset: usize, hash: u64, pointer_x: i32, scroll: i32 } = null;
fn SetCapture(_: HANDLE) HANDLE { captures += 1; return null; }
fn fillRoundRectAA(_: HANDLE, r: RECT, _: i32, color: u32) void { rounded += 1; last_thumb = r; last_thumb_color = color; }

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
const chatDrawText = DrawTextW;
fn DrawTextW(_: HANDLE, _: [*]const u16, _: i32, rect: *RECT, flags: u32) i32 {
    if ((flags & DT_CALCRECT) == 0) {
        draws += 1; last_x = rect.left;
        if (font == 2) header_draws += 1 else normal_draws += 1;
    }
    return 20;
}
fn uiScaled(n: i32) i32 { return @divTrunc(n * scale, 100); }
fn customColorOr(_: []const u8, color: u32) u32 { return color; }
fn RGB(r: u8, g: u8, b: u8) u32 { return @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16); }
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
fn chatFlowText(_: HANDLE, _: []const u16, _: RECT, _: bool, _: bool, _: ?ChatHit, _: usize, _: ?*i32, _: ?[]const usize, comptime _: bool) ?link_detect.Range { return null; }
fn GET_X(lp: LPARAM) i32 { return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)))))); }
fn GET_Y(lp: LPARAM) i32 { return @as(i16, @bitCast(@as(u16, @truncate(@as(usize, @bitCast(lp)) >> 16)))); }
fn ScreenToClient(_: HANDLE, _: *POINT) i32 { return 1; }
fn chatTranscriptBlockAtPoint(y: i32) ?usize {
    for (g_chat_layout_rects[0..g_chat_block_count], 0..) |r, i| {
        if (y + g_chat_scroll_y >= r.top and y + g_chat_scroll_y < r.bottom) return i;
    }
    return null;
}
fn InvalidateRect(_: HANDLE, r: ?*const RECT, _: i32) i32 { invalidates += 1; last_invalidate = if (r) |rect| rect.* else null; return 1; }
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
    try std.testing.expectEqual(@as(i32, 83), h);
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
    try std.testing.expectEqual(selection_at, find_ui.last);
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
test "ISSUE-458 production scrollbar paints without hover in both themes and reserves no space when narrow" {
    g_chat_tables.clear(std.heap.page_allocator);
    defer { g_chat_tables.deinit(std.heap.page_allocator); g_chat_tables = .{}; }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Wide header | Another header |\n|---|---|\n| body | value |");
    const area = RECT{ .left = 20, .top = 30, .right = 120 };
    var height: i32 = 0;
    rounded = 0;
    g_light_theme = false;
    g_chat_hover_link = null;
    _ = chatFlowTable(null, text, area, true, null, 0, &height);
    const layout = &g_chat_tables.entries.getPtr(0).?.layout;
    var body_h: i32 = 1;
    for (layout.heights) |h| body_h += h;
    try std.testing.expectEqual(@as(usize, 2), rounded);
    try std.testing.expectEqual(body_h + 16, height);
    const dark = last_thumb_color;
    const initial = last_thumb;
    layout.scroll = layout.content_w - layout.view_w;
    _ = chatFlowTable(null, text, area, true, null, 0, null);
    try std.testing.expectEqual(area.right, last_thumb.right);
    try std.testing.expectEqual(initial.right - initial.left, last_thumb.right - last_thumb.left);
    g_light_theme = true;
    _ = chatFlowTable(null, text, area, true, null, 0, null);
    try std.testing.expect(last_thumb_color != dark);
    try std.testing.expectEqual(@as(usize, 6), rounded);
    rounded = 0;
    const wide = RECT{ .right = 2000 };
    _ = chatFlowTable(null, text, wide, true, null, 0, &height);
    try std.testing.expectEqual(@as(usize, 0), rounded);
    try std.testing.expectEqual(body_h, height);
    g_light_theme = false;
}

test "ISSUE-458 production thumb captures outside movement and track clicks page without selecting or redundant redraws" {
    g_chat_tables.clear(std.heap.page_allocator);
    defer { g_chat_tables.deinit(std.heap.page_allocator); g_chat_tables = .{}; chat_table_drag = null; }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Wide header | Another header |\n|---|---|\n| body | value |");
    g_chat_blocks[0] = .{ .start = 0, .len = text.len, .role = .code, .kind = .table, .first = true };
    g_chat_layout_rects[0] = .{ .left = 5, .top = 100, .right = 129, .bottom = 250 };
    g_chat_block_count = 1;
    g_chat_content_left = 30;
    g_chat_scroll_y = 50;
    const layout = chatTableLayout(null, text, 0, 100).?;
    const left = 30 + 5 + CHAT_CODE_PAD;
    try std.testing.expectEqual(@as(i32, 0), chat_style.headerHeight(g_chat_blocks[0], CHAT_AGENT_HEADER_H));
    const top = 100 - 50 + CHAT_CODE_PAD;
    const y = top + layout.bodyHeight() + 8;
    captures = 0;
    invalidates = 0;
    g_chat_sel_active = false;
    g_chat_sel_transcript_focus = false;
    try std.testing.expect(!chatTableMouseDown(null, left + 1, top + 1));
    try std.testing.expect(!chatTableMouseDown(null, left - 1, y));
    try std.testing.expect(chatTableMouseDown(null, left + 1, y));
    try std.testing.expectEqual(@as(usize, 1), captures);
    try std.testing.expect(chat_table_drag != null);
    try std.testing.expect(chatTableMouseMove(null, left + 10000));
    try std.testing.expectEqual(layout.content_w - layout.view_w, layout.scroll);
    try std.testing.expectEqual(@as(usize, 1), invalidates);
    try std.testing.expectEqual(@as(i32, 35), last_invalidate.?.left);
    try std.testing.expectEqual(@as(i32, 50), last_invalidate.?.top);
    try std.testing.expect(chatTableMouseMove(null, left + 20000));
    try std.testing.expectEqual(@as(usize, 1), invalidates);
    try std.testing.expect(chatTableMouseMove(null, left - 10000));
    try std.testing.expectEqual(@as(i32, 0), layout.scroll);
    try std.testing.expect(!g_chat_sel_active and !g_chat_sel_transcript_focus);
    chat_table_drag = null;
    try std.testing.expect(!chatTableMouseMove(null, left + 1));
    try std.testing.expect(chatTableMouseDown(null, left + 99, y));
    try std.testing.expectEqual(@as(i32, 100), layout.scroll);
    try std.testing.expect(chat_table_drag == null);
    try std.testing.expect(chatTableMouseDown(null, left, y));
    try std.testing.expectEqual(@as(i32, 0), layout.scroll);
    g_chat_content_left = 0;
    g_chat_scroll_y = 0;
}

test "ISSUE-458 production wheel targets the pointed table and leaves vertical wheel and narrow tables alone" {
    g_chat_tables.clear(std.heap.page_allocator);
    defer { g_chat_tables.deinit(std.heap.page_allocator); g_chat_tables = .{}; g_chat_block_count = 1; }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("| Wide header | Another header |\n|---|---|\n| body | value |");
    for (0..2) |i| {
        const start = i * 100;
        g_chat_blocks[i] = .{ .start = start, .len = text.len, .role = .code, .kind = .table };
        const top: i32 = @intCast(i * 150);
        g_chat_layout_rects[i] = .{ .top = top, .right = 124, .bottom = top + 130 };
        _ = chatTableLayout(null, text, start, 100);
    }
    g_chat_block_count = 2;
    const first = &g_chat_tables.entries.getPtr(0).?.layout;
    const second = &g_chat_tables.entries.getPtr(100).?.layout;
    const point: LPARAM = 20 | (170 << 16);
    invalidates = 0;
    try std.testing.expect(chatTableWheel(null, WM_MOUSEHWHEEL, 120 << 16, point));
    try std.testing.expectEqual(@as(i32, 0), first.scroll);
    try std.testing.expectEqual(@as(i32, 54), second.scroll);
    try std.testing.expect(!chatTableWheel(null, WM_MOUSEWHEEL, 120 << 16, point));
    try std.testing.expectEqual(@as(i32, 54), second.scroll);
    try std.testing.expect(chatTableWheel(null, WM_MOUSEWHEEL, (120 << 16) | 4, point));
    try std.testing.expectEqual(@as(i32, 0), second.scroll);
    try std.testing.expectEqual(@as(usize, 2), invalidates);
    try std.testing.expect(chatTableWheel(null, WM_MOUSEWHEEL, (120 << 16) | 4, point));
    try std.testing.expectEqual(@as(usize, 2), invalidates);
    try std.testing.expect(!chatTableWheel(null, WM_MOUSEHWHEEL, 120 << 16, 4 | (170 << 16)));
    _ = chatTableLayout(null, text, 100, 2000);
    try std.testing.expect(!chatTableWheel(null, WM_MOUSEHWHEEL, 120 << 16, point));
}
`;
function execute(control) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh421-grid-'));
  try {
    copyZig(['chat_hit.zig', 'chat_markdown.zig', 'chat_table_measure.zig', 'chat_code.zig', 'chat_style.zig', 'link_detect.zig'], dir);
    fs.writeFileSync(path.join(dir, 'chat_find_ui.zig'), 'pub var last: usize = 0;\npub fn paintRun(_: anytype, _: []const u16, at: usize, _: i32, _: i32, _: i32) void { last = at; }\n');
    let functions = ['chatReceivedBlocks', 'chatBlockDisplayRange', 'chatRichSize', 'chatRichText', 'chatTableLayout', 'chatFlowTable', 'chatFlowBlock', 'chatTableAt', 'chatTableSetScroll', 'chatTableMouseDown', 'chatTableMouseMove', 'chatTableWheel', 'chatFindY'].map(name => body(name)).join('\n');
    const render = fs.readFileSync(path.join(__dirname, '../src/chat_render.zig'), 'utf8');
    functions = render.slice(render.indexOf('const TableMeasureBackend ='), render.indexOf('fn chatBlockNaturalWidth(')) + functions;
    if (control) functions = functions.replace('area.left - layout.scroll;', 'area.left;');
    fs.writeFileSync(path.join(dir, 'test.zig'), (prelude + lineHeightPolicy + '\n' + functions + checks).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', 'ISSUE-'], { encoding: 'utf8', timeout: 120000 });
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


test('ISSUE-458 captured scrollbar gestures precede text selection and release on button-up or capture loss', () => {
  const proc = body('chatTranscriptWndProc');
  for (const message of ['WM_LBUTTONDOWN', 'WM_LBUTTONDBLCLK']) {
    const start = proc.indexOf(`${message} => {`);
    const end = proc.indexOf('\n        },', start);
    const handler = proc.slice(start, end);
    assert.ok(handler.indexOf('chatTableMouseDown') >= 0);
    assert.ok(handler.indexOf('chatTableMouseDown') < handler.indexOf('chatTranscriptMouseDown'));
  }
  assert.match(proc, /WM_MOUSEMOVE => \{\s*if \(chatTableMouseMove\(hwnd, GET_X\(lp\)\)\) return 0/);
  assert.match(proc, /WM_LBUTTONUP => \{\s*if \(chat_table_drag != null\) \{[^]*?chat_table_drag = null;[^]*?ReleaseCapture\(\);\s*return 0;/);
  assert.match(proc, /0x0215, 0x001F => \{[^]*?chat_table_drag = null;/);
  assert.match(body('refreshChatBlockCache'), /chatTableRefresh\(/);
  assert.match(body('chatTableRefresh'), /g_chat_tables\.refreshReceived\(/);
});
