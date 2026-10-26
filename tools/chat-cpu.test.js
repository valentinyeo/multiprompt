const { copyZig } = require('./zig-copy');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
const fontSource = fs.readFileSync(path.join(__dirname, '../src/fonts.zig'), 'utf8');
const lineHeightPolicy = fontSource.match(/^pub const CHAT_LINE_HEIGHT_PERMILLE[^;]+;/m)[0] + '\n' + body(fontSource, 'chatLineHeight');
function body(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2)
    .replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary')
    .replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark');
}
function run(code) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cpu707-'));
  try {
    copyZig(['chat_hit.zig', 'chat_echo.zig', 'chat_markdown.zig', 'chat_style.zig', 'chat_code.zig', 'link_detect.zig', 'chat_working.zig'], dir);
    fs.writeFileSync(path.join(dir, 'chat_find_ui.zig'), 'pub fn paintRun(_: anytype, _: []const u16, _: usize, _: i32, _: i32, _: i32) void {}\n');
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, ('const chat_hit = @import("chat_hit.zig");\nvar g_chat_find_open = false;\n' + lineHeightPolicy + '\n' + code).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    return spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
const scheduling = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const HANDLE = ?*anyopaque;
fn L(comptime s: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(s); }
var g_chat_fetch_mutex: HANDLE = null;
var g_chat_fetch_busy = false;
var g_usage_launch_mutex: HANDLE = null;
var selected: usize = 0;
var owner: ?usize = null;
var launch_refs: usize = 0;
var spawned: usize = 0;
var last_error: u32 = 0;
var collector_running = false;
const usage_telemetry_mode = struct { fn isRunning() bool { return collector_running; } };
const Slot = struct { worker: HANDLE = null, busy: bool = false, launch: HANDLE = null, requested: HANDLE = null, served: HANDLE = null, seen: HANDLE = null };
var slots: [6]Slot = @splat(.{});
fn select(i: usize) void {
    slots[selected].worker = g_chat_fetch_mutex; slots[selected].busy = g_chat_fetch_busy; slots[selected].launch = g_usage_launch_mutex;
    selected = i;
    const slot = slots[i];
    g_chat_fetch_mutex = slot.worker; g_main_hwnd = @ptrFromInt(i + 1);
    g_chat_fetch_busy = slot.busy; g_usage_launch_mutex = slot.launch;
}
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var scheduler_tick: u64 = 100;
const WM_TIMER = 0x113;
const TIMER_CHAT_REFRESH = 27;
fn GetTickCount64() u64 { return scheduler_tick; }
fn PostMessageW(_: HANDLE, _: u32, _: usize, _: isize) i32 { return 1; }
const TestWin = struct {
    const LPARAM = isize;
    const BOOL = i32;
    const WINAPI: std.builtin.CallingConvention = .c;
    fn property(hwnd: HANDLE, name: [*:0]const u16) *HANDLE {
        const slot = &slots[@intFromPtr(hwnd) - 1];
        const text = std.mem.span(name);
        if (std.mem.endsWith(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("Pending"))) return &slot.requested;
        if (std.mem.endsWith(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("Served"))) return &slot.served;
        return &slot.seen;
    }
    fn GetPropW(hwnd: HANDLE, name: [*:0]const u16) HANDLE { return property(hwnd, name).*; }
    fn SetPropW(hwnd: HANDLE, name: [*:0]const u16, value: HANDLE) i32 { property(hwnd, name).* = value; return 1; }
    fn EnumWindows(callback: *const fn (HANDLE, LPARAM) callconv(WINAPI) BOOL, param: LPARAM) BOOL {
        for (0..slots.len) |i| if (callback(@ptrFromInt(i + 1), param) == 0) return 0;
        return 1;
    }
};
fn CreateMutexW(_: ?*anyopaque, _: i32, name: [*:0]const u16) HANDLE {
    const text = std.mem.span(name);
    if (std.mem.endsWith(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("Launch"))) {
        last_error = if (launch_refs > 0) 183 else 0;
        launch_refs += 1; return @ptrFromInt(3);
    }
    std.debug.assert(std.mem.eql(u16, text, std.unicode.utf8ToUtf16LeStringLiteral("Local\\\\MultipromptChatTranscriptWorker")));
    return @ptrFromInt(1);
}
fn WaitForSingleObject(_: HANDLE, timeout: u32) u32 {
    std.debug.assert(timeout == 0);
    if (owner) |id| return if (id == selected) 0 else 258;
    owner = selected; return 0;
}
fn ReleaseMutex(_: HANDLE) i32 { std.debug.assert(owner.? == selected); owner = null; return 1; }
fn CloseHandle(h: HANDLE) i32 {
    if (h == @as(HANDLE, @ptrFromInt(3))) launch_refs -= 1;
    return 1;
}
fn GetLastError() u32 { return last_error; }
fn GetModuleFileNameW(_: HANDLE, out: []u16, _: usize) u32 { out[0] = 'm'; out[1] = 0; return 1; }
const SW_HIDE = 0;
fn ShellExecuteW(_: HANDLE, _: [*:0]const u16, _: [*:0]const u16, flag: [*:0]const u16, _: HANDLE, _: i32) HANDLE {
    std.debug.assert(std.mem.eql(u16, std.mem.span(flag), std.unicode.utf8ToUtf16LeStringLiteral("--usage-telemetry")));
    spawned += 1; return @ptrFromInt(64);
}
`;
const scheduleChecks = `
test "one worker across six windows gives pending windows turns before reacquiring even in the same tick" {
    select(0);
    try std.testing.expect(chatFetchAcquire());
    for (1..6) |i| { select(i); try std.testing.expect(!chatFetchAcquire()); }
    select(0); chatFetchRelease();
    try std.testing.expect(!chatFetchAcquire());
    for (0..20) |_| {
        for (1..6) |i| {
            select(i);
            try std.testing.expect(chatFetchAcquire());
            try std.testing.expect(!chatFetchAcquire());
            chatFetchRelease();
            try std.testing.expect(!chatFetchAcquire());
        }
        select(0);
        try std.testing.expect(chatFetchAcquire());
        chatFetchRelease();
        try std.testing.expect(!chatFetchAcquire());
    }
    scheduler_tick += 3002;
    select(5);
    try std.testing.expect(chatFetchAcquire());
    chatFetchRelease();
    try std.testing.expect(owner == null);
}
test "simultaneous window startup launches just one child before its collector mutex exists" {
    for (0..6) |i| { select(i); ensureUsageTelemetryCollector(); }
    try std.testing.expectEqual(@as(usize, 1), spawned);
    for (0..6) |i| { select(i); ensureUsageTelemetryCollector(); }
    try std.testing.expectEqual(@as(usize, 1), spawned);
}
`;

function schedulingFunctions() {
  const turn = source.slice(source.indexOf('const ChatFetchTurn = struct {'), source.indexOf('fn chatFetchOldest('));
  return (turn + ['chatFetchOldest', 'chatFetchAcquire', 'chatFetchRelease'].map(n => body(source, n)).join('\n')).replaceAll('@import("win32.zig")', 'TestWin');
}

test('production cross-window scheduling and telemetry launch reservation execute with nonblocking Win32 ownership', () => {
  const code = scheduling + schedulingFunctions() + body(source, 'ensureUsageTelemetryCollector') + scheduleChecks;
  const result = run(code);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('singleton startup oracle rejects the actual 706 check-then-spawn race', () => {
  const old = ({ status: 0, stdout: fs.readFileSync('tools/fixtures/chat-before-5880899.zig', 'utf8') });
  assert.equal(old.status, 0);
  const code = scheduling + schedulingFunctions() + body(old.stdout, 'ensureUsageTelemetryCollector') + scheduleChecks;
  const result = run(code);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected 1, found 6/);
});

const layout = `
const std = @import("std");
const chat_echo = @import("chat_echo.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_style = @import("chat_style.zig");
const HANDLE = ?*anyopaque;
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
const ChatBlock = chat_markdown.Block;
const ChatImgLayout = struct {};
var blocks: [1001]ChatBlock = undefined;
var g_chat_blocks: []ChatBlock = &blocks;
var g_chat_block_count: usize = 1000;
var g_chat_layout_rects: [1001]RECT = undefined;
var g_chat_bubble_pos: [1001]chat_style.BubblePos = undefined;
var g_chat_capture: [1]u16 = .{'x'};
var g_chat_last_len: usize = 1;
var g_chat_layout_dirty = true;
var g_chat_find_layout_open = false;
const CHAT_FIND_TOP_H: i32 = 52;
var g_chat_layout_width: i32 = 0;
var g_chat_layout_scale: i32 = 0;
var g_chat_layout_font_pt: i32 = 0;
var fake_ui_scale: i32 = 100;
var g_chat_layout_reuse: usize = 0;
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
var g_chat_font_pt: i32 = 13;
var clean_chat: bool = false;
var g_chat_transcript_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_content_h: i32 = 0;
var g_chat_echo_layout_count: usize = 0;
var g_chat_sel_anchor: usize = 0;
var g_chat_sel_caret: usize = 0;
fn chatSelectionClear() void { g_chat_sel_anchor = 0; g_chat_sel_caret = 0; }
var g_chat_content_left: i32 = 0;
var g_chat_img_pass: u64 = 0;
var g_chat_img_first_block: usize = 0;
var g_chat_img_count: [1001]u8 = @splat(0);
var g_chat_img_items: [1001][4]struct { key: u64 = 0 } = undefined;
var g_chat_img_cache: [1]struct { key: u64 = 0, pass: u64 = 0 } = @splat(.{});
var g_chat_img_mutex = struct { fn tryLock(_: *@This()) bool { return true; } fn unlock(_: *@This()) void {} }{};
var g_chat_blocks_from_file = true;
var active_shell: u32 = 0;
var shell_count: u32 = 1;
const CHAT_OUTBOX_KEY_CAP = 8;
var g_chat_outbox = struct { items: []const struct { key: [8]u8, key_len: u8, text: []const u16, id: u64, state: chat_echo.OutboxState } = &.{} }{};
var g_chat_echo_layout: [20]RECT = undefined;
var g_chat_echo_layout_ids: [20]u64 = @splat(0);
var measured: usize = 0;
fn uiScaled(n: i32) i32 { return @divTrunc(n * fake_ui_scale, 100); }
fn GetDC(_: HANDLE) HANDLE { return @ptrFromInt(1); }
fn ReleaseDC(_: HANDLE, _: HANDLE) i32 { return 1; }
fn Sleep(_: u32) void {}
fn chatContentRectInset(w: i32) struct { left: i32, right: i32 } { return .{ .left = 0, .right = w }; }
fn chatImgFirstBlock(_: []const u16) usize { return 0; }
fn chatBlockGapBefore(_: bool, _: chat_markdown.Role, _: bool, _: chat_style.BubblePos) i32 { return 0; }
fn chatMeasureBlockRect(_: HANDLE, _: []const u16, _: ChatBlock, _: chat_style.BubblePos, w: i32, y: i32, _: ?*ChatImgLayout) RECT {
    measured += 1; return .{ .left = 0, .top = y, .right = w, .bottom = y + 20 };
}
fn chatImgStoreLayout(_: usize, _: ChatImgLayout) void {}
fn chatOutboxKeyForShell(_: u32, _: []u8) []const u8 { return ""; }
fn chatMeasureEchoRect(_: HANDLE, _: []const u16, _: i32, _: i32, _: bool) RECT { unreachable; }
fn chatShellRowsLayout(_: HANDLE, _: i32, y: i32) i32 { return y; }
`;
const layoutChecks = `
test "prefix rectangles survive repeated layout and suffix updates; resize and font changes invalidate" {
    for (&blocks) |*b| b.* = .{ .start = 0, .len = 1, .role = .prose };
    chatRelayout(400);
    try std.testing.expectEqual(@as(usize, 1000), measured);
    chatRelayout(400);
    try std.testing.expectEqual(@as(usize, 1000), measured);
    g_chat_layout_reuse = 999; g_chat_block_count = 1001;
    chatRelayout(400);
    try std.testing.expectEqual(@as(usize, 1002), measured);
    try std.testing.expectEqual(@as(i32, 20020), g_chat_content_h);
    chatRelayout(401);
    try std.testing.expectEqual(@as(usize, 2003), measured);
    g_chat_font_pt += 1;
    chatRelayout(401);
    try std.testing.expectEqual(@as(usize, 3004), measured);
    const old_font_pixels = uiScaled(g_chat_font_pt);
    fake_ui_scale = 101;
    try std.testing.expectEqual(old_font_pixels, uiScaled(g_chat_font_pt));
    chatRelayout(401);
    try std.testing.expectEqual(@as(usize, 4005), measured);
}
`;
test('production layout measures only changed suffixes and caches unchanged geometry', () => {
  const result = run(layout + body(source, 'chatRelayout') + layoutChecks);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('ISSUE-268 oldest match has room below the find bar and closing removes that room', () => {
  const check = `
  test "ISSUE-268 first loaded message clears the sticky find bar" {
      for (&blocks) |*b| b.* = .{ .start = 0, .len = 1, .role = .prose };
      g_chat_block_count = 1;
      chatRelayout(400);
      try std.testing.expectEqual(@as(i32, 0), g_chat_layout_rects[0].top);
      g_chat_find_open = true;
      chatRelayout(400);
      try std.testing.expect(g_chat_layout_rects[0].top >= uiScaled(52));
      g_chat_find_open = false;
      chatRelayout(400);
      try std.testing.expectEqual(@as(i32, 0), g_chat_layout_rects[0].top);
  }`;
  const result = run(layout + body(source, 'chatRelayout') + check);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('layout oracle rejects actual 706 full-history remeasurement', () => {
  const old = ({ status: 0, stdout: fs.readFileSync('tools/fixtures/chat-before-5880899.zig', 'utf8') });
  assert.equal(old.status, 0);
  const result = run(layout + body(old.stdout, 'chatRelayout') + layoutChecks);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected 1000, found 2000/);
});
test('UI completion never parses; polling/paint use revisions, cached tables and visible rectangles only', () => {
  assert.doesNotMatch(body(source, 'chatFileOnReady'), /\.apply\(|\.decode\(|\.render\(|Sleep\(/);
  assert.doesNotMatch(body(source, 'refreshChatBlockCache'), /for \(entry\.\?\.history\.blocks/);
  assert.match(body(source, 'refreshChatBlockCache'), /history\.revision/);
  assert.match(body(source, 'chatFileFetchThread'), /history\.suffix\(a\)/);
  assert.match(body(source, 'chatFileFetchThread'), /CACHE_WRITE_MS/);
  assert.match(body(source, 'chatTableLayout'), /g_chat_tables\.layout/);
  assert.match(body(source, 'chatTranscriptWndProc'), /scrollAnchor[^]*for \(first\.\.g_chat_block_count\)/);
  assert.match(body(source, 'chatFileRequestForDelivery'), /GetLastInputInfo[^]*< 5000\) return/);
  assert.match(body(source, 'chatImgFirstBlock'), /g_chat_blocks_from_file[^]*block\.image_count/);
});

const flow = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const chat_code = @import("chat_code.zig");
const link_detect = @import("link_detect.zig");
const HANDLE = usize;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
const SIZE = struct { cx: i32, cy: i32 };
const ChatHit = struct { x: i32, y: i32, char: ?*usize = null, find: ?struct { position: usize, y: *i32 } = null };
const DT_CALCRECT = 1;
const DT_SINGLELINE = 2;
const DT_NOPREFIX = 4;
var g_chat_sel_active = false;
var g_chat_sel_transcript_focus = false;
var g_chat_hover_link: ?link_detect.Range = null;
var g_light_theme = false;
var character_widths: usize = 0;
var selection_runs: usize = 0;
fn L(comptime s: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(s); }
fn ensureChatCodeFont() HANDLE { return 1; }
fn ensureChatFont() HANDLE { return 1; }
fn SelectObject(_: HANDLE, _: HANDLE) HANDLE { return 1; }
const chatDrawText = DrawTextW;
fn DrawTextW(_: HANDLE, _: [*]const u16, _: i32, _: *RECT, _: u32) i32 { return 20; }
fn chatLineIndentPx(_: HANDLE, _: []const u16, _: usize) i32 { return 0; }
fn chatTextWidth(_: HANDLE, text: []const u16) i32 { if (text.len == 1) character_widths += 1; return @intCast(text.len * 8); }
fn GetTextExtentExPointW(_: HANDLE, _: [*]const u16, len: i32, _: i32, fit: *i32, _: ?*anyopaque, size: *SIZE) i32 { fit.* = len; size.* = .{ .cx = len * 8, .cy = 20 }; return 1; }
fn pointInRect(_: RECT, _: i32, _: i32) bool { return false; }
fn chatCharAtX(_: HANDLE, _: []const u16, _: i32) usize { return 0; }
fn SetTextColor(_: HANDLE, _: u32) u32 { return 0; }
fn customColorOr(_: []const u8, value: u32) u32 { return value; }
fn RGB(_: u8, _: u8, _: u8) u32 { return 0; }
fn chatLinkFont(_: bool) HANDLE { return 1; }
fn chatCodeTokenColor(_: chat_code.Kind) u32 { return 0; }
fn chatPaintSelectionRun(_: HANDLE, _: []const u16, _: usize, _: i32, _: i32, _: i32) void { selection_runs += 1; }
`;
const flowChecks = `
test "table paint without selection makes no per-character GDI calls; real selection remains mapped" {
    const text: [1000]u16 = @splat('x');
    var map: [1000]usize = undefined;
    for (&map, 0..) |*value, i| value.* = i;
    _ = chatFlowText(0, &text, .{ .right = 10000 }, true, true, null, 0, null, &map);
    try std.testing.expectEqual(@as(usize, 0), character_widths);
    try std.testing.expectEqual(@as(usize, 0), selection_runs);
    g_chat_sel_active = true;
    for ([_]bool{ true, false }) |focused| {
        g_chat_sel_transcript_focus = focused;
        character_widths = 0; selection_runs = 0;
        _ = chatFlowText(0, &text, .{ .right = 10000 }, true, true, null, 0, null, &map);
        try std.testing.expectEqual(@as(usize, 1000), character_widths);
        try std.testing.expectEqual(@as(usize, 1000), selection_runs);
    }
}
`;
test('production table paint avoids per-character selection measurement when nothing is selected', () => {
  const result = run(flow + body(source, 'chatFlowText') + flowChecks);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('selection measurement oracle rejects the actual 706 unconditional per-character loop', () => {
  const old = ({ status: 0, stdout: fs.readFileSync('tools/fixtures/chat-before-5880899.zig', 'utf8') });
  assert.equal(old.status, 0);
  const result = run(flow + body(old.stdout, 'chatFlowText') + flowChecks);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected 0, found 1000/);
});

const rich = flow
  .replace('const link_detect = @import("link_detect.zig");', `const real_links = @import("link_detect.zig");
var scanned: usize = 0;
const link_detect = struct {
    const Range = real_links.Range;
    fn next(text: []const u16, from: usize) ?Range {
        scanned += text.len - from; // Exact visit count for the URL-free performance fixture.
        return real_links.next(text, from);
    }
};`)
  .replace('fn chatTextWidth(_: HANDLE, text: []const u16) i32 {', 'fn chatTextWidth(_: HANDLE, text: []const u16) i32 { width_calls += 1;')
  .replace('fn pointInRect(_: RECT, _: i32, _: i32) bool { return false; }', 'fn pointInRect(r: RECT, x: i32, y: i32) bool { return x >= r.left and x < r.right and y >= r.top and y < r.bottom; }')
  .replace('fn DrawTextW(_: HANDLE, _: [*]const u16, _: i32, _: *RECT, _: u32) i32 { return 20; }', `fn DrawTextW(_: HANDLE, text: [*]const u16, len: i32, rect: *RECT, _: u32) i32 {
    for ([_]i32{ rect.left, rect.top, rect.right, rect.bottom, len }) |v| draw_hash = draw_hash *% 31 +% @as(u32, @bitCast(v));
    for (text[0..@intCast(len)]) |c| draw_hash = draw_hash *% 31 +% c;
    return 20;
}`)
  .replace('fn GetTextExtentExPointW(_: HANDLE, _: [*]const u16, len: i32, _: i32, fit: *i32, _: ?*anyopaque, size: *SIZE) i32 { fit.* = len;', 'fn GetTextExtentExPointW(_: HANDLE, _: [*]const u16, len: i32, available: i32, fit: *i32, _: ?*anyopaque, size: *SIZE) i32 { fit.* = @min(len, @divTrunc(available, 8));');
const richPrelude = `
const chat_markdown = @import("chat_markdown.zig");
var width_calls: usize = 0;
var draw_hash: u64 = 0;
fn chatRichFont(_: chat_markdown.Style, _: u3) HANDLE { return 1; }
fn CreateSolidBrush(_: u32) HANDLE { return 1; }
fn FillRect(_: HANDLE, _: *RECT, _: HANDLE) i32 { return 1; }
fn DeleteObject(_: HANDLE) i32 { return 1; }
fn chatCodePanelColor() u32 { return 0; }
fn themeConsoleFg() u32 { return 0; }
`;
const caretChecks = String.raw`
var caret_widths: usize = 0;
fn caretTextWidth(hdc: HANDLE, text: []const u16) i32 {
    caret_widths += 1;
    return chatTextWidth(hdc, text);
}
test "ISSUE-438 dragging on line one measures no glyph prefixes on other lines" {
    var data: [128 * 81]u16 = undefined;
    for (0..128) |line| {
        @memset(data[line * 81 ..][0..80], 'x');
        data[line * 81 + 80] = '\n';
    }
    const area = RECT{ .left = 10, .top = 30, .right = 650 };
    for (0..3) |mode| {
        var first_widths: usize = 0;
        for ([_]usize{ 1, 128 }) |lines| {
            const text = data[0 .. lines * 81];
            var at: usize = 0;
            caret_widths = 0;
            const hit = ChatHit{ .x = 331, .y = 35, .char = &at };
            if (mode == 2) _ = chatRichText(0, text, area, 0, false, hit, 17, null, false) else _ = chatFlowText(0, text, area, mode == 0, false, hit, 17, null, null);
            try std.testing.expectEqual(@as(usize, 57), at);
            try std.testing.expect(caret_widths > 1);
            if (lines == 1) first_widths = caret_widths else try std.testing.expectEqual(first_widths, caret_widths);
            if (lines == 128) for ([_]i32{ area.top - 1, area.top + @as(i32, @intCast(lines + 1)) * 20 }) |y| {
                caret_widths = 0;
                const outside = ChatHit{ .x = 331, .y = y, .char = &at };
                if (mode == 2) _ = chatRichText(0, text, area, 0, false, outside, 17, null, false) else _ = chatFlowText(0, text, area, mode == 0, false, outside, 17, null, null);
                try std.testing.expectEqual(@as(usize, 0), caret_widths);
                try std.testing.expectEqual(if (y < area.top) @as(usize, 17) else 17 + text.len, at);
            };
        }
    }
}
`;
function runCaret(control = false) {
  const before = ({ status: 0, stdout: fs.readFileSync('tools/fixtures/chat-before-7953828.zig', 'utf8') });
  assert.equal(before.status, 0);
  const renderer = control ? before.stdout.replace(/\bapp_state\./g, '') : source;
  const prelude = rich.replace('fn chatCharAtX(_: HANDLE, _: []const u16, _: i32) usize { return 0; }',
    body(source, 'chatCharAtX').replaceAll('chatTextWidth(', 'caretTextWidth('));
  return run(prelude + richPrelude + body(renderer, 'chatFlowText') + body(renderer, 'chatRichText') + caretChecks);
}
test('ISSUE-438 production drag hit measures glyph prefixes only on the pointer line', () => {
  const result = runCaret();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('ISSUE-438 caret measurement oracle rejects the original all-lines drag path', () => {
  const result = runCaret(true);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /expected 42, found 5376/);
});

const richChecks = `
test "rich layout: URL-free scans and GDI width calls grow linearly" {
    var data: [5120]u16 = undefined;
    const word = std.unicode.utf8ToUtf16LeStringLiteral("word ");
    for ([_]usize{ 256, 512, 1024 }) |words| {
        for (0..words) |i| @memcpy(data[i * 5 ..][0..5], word);
        scanned = 0; width_calls = 0;
        _ = chatRichText(0, data[0 .. words * 5], .{ .right = 100000 }, 0, false, null, 0, null, false);
        try std.testing.expectEqual(words * 5, scanned);
        try std.testing.expect(width_calls <= words + 1);
    }
}
test "rich layout: cached widths and URLs preserve narrow wrapping, styled runs and hit targets" {
    for ([_][]const u16{
        std.unicode.utf8ToUtf16LeStringLiteral("ordinary words with **bold**, *italic* and code"),
        std.unicode.utf8ToUtf16LeStringLiteral("A (https://example.com/one) and https://example.org/two after a word."),
        std.unicode.utf8ToUtf16LeStringLiteral("[safe link](https://example.com/md) and https://example.org/bare"),
        std.unicode.utf8ToUtf16LeStringLiteral("averylongwordwithoutspaces 世界 and more words"),
    }) |text| {
        for ([_]i32{ 32, 80, 200 }) |width| {
            const area = RECT{ .right = width };
            var old_height: i32 = 0; var height: i32 = 0;
            draw_hash = 0;
            _ = oldRichText(0, text, area, 0, true, null, 17, &old_height);
            const old_hash = draw_hash;
            draw_hash = 0;
            _ = chatRichText(0, text, area, 0, true, null, 17, &height, false);
            try std.testing.expectEqual(old_height, height);
            try std.testing.expectEqual(old_hash, draw_hash);
            var y: i32 = 0;
            while (y < height) : (y += 20) {
                var x: i32 = 0;
                while (x < width) : (x += 8) {
                    const hit = ChatHit{ .x = x, .y = y };
                    try std.testing.expect(std.meta.eql(oldRichText(0, text, area, 0, false, hit, 17, null), chatRichText(0, text, area, 0, false, hit, 17, null, false)));
                }
            }
        }
    }
}
`;
function runRich(control = false) {
  const old = ({ status: 0, stdout: fs.readFileSync('tools/fixtures/chat-before-9a4a7d7.zig', 'utf8') });
  assert.equal(old.status, 0);
  return run(rich + richPrelude + body(source, 'chatFlowText') +
    (control ? body(old.stdout, 'chatRichText').replace('height: ?*i32)', 'height: ?*i32, _: bool)') : body(source, 'chatRichText')) +
    body(old.stdout, 'chatRichText').replace('fn chatRichText(', 'fn oldRichText(') + richChecks);
}
test('correctness rich: production layout scans URLs linearly and preserves wrapping and link targets', () => {
  const result = runRich();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('correctness rich: unchanged pre-fix code fails the oracle', () => {
  const result = runRich(true);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /FAIL \(TestExpectedEqual\)/);
});

test('working bar production working timer is idle-free, row-only and preserves background start times', () => {
  const functions = ['chatWorkingTimesPoll', 'chatWorkingBarVisible', 'chatWorkingBarTick', 'chatWorkingIndicatorInvalidate', 'chatWorkingIndicatorSync']
    .map(n => body(source, n)).join('\n').replaceAll('@import("win32.zig").', '').replaceAll('@import("chat_render.zig").chatWorkingSync', 'chatWorkingSync');
  const prelude = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const HANDLE = ?*anyopaque;
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
const TIMER_CHAT_WORKING: usize = 43;
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_active = true;
var g_chat_screen_working = false;
var g_chat_screen_status_len: usize = 0;
var g_chat_working_text: [128]u16 = @splat(0);
var g_chat_working_applied: [128]u16 = @splat(0);
var g_chat_working_applied_len: usize = 0;
var g_chat_working_timer_running = false;
const shell_count = 2;
var active_shell: usize = 0;
var shells = [_]struct { activity: enum { idle, active } = .idle, console_working: bool = false, working_since_ms: u64 = 0 }{ .{}, .{} };
var fake_tick: u64 = 100;
var starts: usize = 0;
var stops: usize = 0;
var paints: usize = 0;
fn GetTickCount64() u64 { return fake_tick; }
fn SetTimer(_: HANDLE, id: usize, ms: u32, _: ?*anyopaque) usize { std.debug.assert(id == TIMER_CHAT_WORKING and ms == 250); starts += 1; return id; }
fn KillTimer(_: HANDLE, id: usize) i32 { std.debug.assert(id == TIMER_CHAT_WORKING); stops += 1; return 1; }
fn debugLog(_: []const u8) void {}
fn chatViewLayout() struct { transcript: RECT, composer_card: RECT } { return .{ .transcript = .{ .left = 10, .top = 0, .right = 100, .bottom = 50 }, .composer_card = .{ .left = 10, .top = 80, .right = 100, .bottom = 150 } }; }
fn InvalidateRect(_: HANDLE, rc: *const RECT, erase: i32) i32 { std.debug.assert(rc.left == 10 and rc.right == 100 and rc.top == 50 and rc.bottom == 80 and erase == 0); paints += 1; return 1; }
fn chatWorkingSync() void {}
fn chatWorkingIndicatorText() []const u16 { return g_chat_working_text[0..g_chat_screen_status_len]; }
`;
  const checks = `
test "idle, edges, background tab, elapsed update and close" {
    chatWorkingTimesPoll(); chatWorkingIndicatorSync(); chatWorkingBarTick();
    try std.testing.expectEqual(@as(usize, 0), starts + stops + paints);
    shells[0].activity = .active;
    chatWorkingTimesPoll(); chatWorkingIndicatorSync();
    try std.testing.expectEqual(@as(usize, 1), starts);
    try std.testing.expectEqual(@as(usize, 1), paints);
    fake_tick = 1100; chatWorkingBarTick();
    try std.testing.expectEqual(@as(usize, 2), paints);
    chatWorkingIndicatorSync();
    try std.testing.expectEqual(@as(usize, 2), paints);
    chatWorkingBarTick();
    try std.testing.expectEqual(@as(usize, 3), paints);
    shells[1].activity = .active; fake_tick = 2100; chatWorkingTimesPoll();
    active_shell = 1; chatWorkingIndicatorSync();
    try std.testing.expectEqual(@as(u64, 2100), shells[1].working_since_ms);
    fake_tick = 12100; active_shell = 0; chatWorkingTimesPoll(); chatWorkingIndicatorSync();
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("Working… · 12s"), g_chat_working_applied[0..g_chat_working_applied_len]);
    shells[0].activity = .idle; chatWorkingTimesPoll(); chatWorkingIndicatorSync();
    try std.testing.expectEqual(@as(u64, 0), shells[0].working_since_ms);
    try std.testing.expectEqual(@as(usize, 1), stops);
    const before = paints; chatWorkingIndicatorSync(); chatWorkingBarTick();
    try std.testing.expectEqual(before, paints);
    active_shell = 1; chatWorkingIndicatorSync();
    try std.testing.expectEqual(@as(usize, 2), starts);
    g_chat_active = false; chatWorkingIndicatorSync();
    try std.testing.expectEqual(@as(usize, 2), stops);
    shells[1].activity = .idle; g_chat_screen_working = true;
    chatWorkingTimesPoll();
    try std.testing.expectEqual(@as(u64, 0), shells[1].working_since_ms);
    g_chat_active = true; g_chat_screen_working = false;
    g_chat_screen_status_len = 1; g_chat_working_text[0] = 'x';
    fake_tick = 20000; chatWorkingTimesPoll(); chatWorkingIndicatorSync();
    try std.testing.expectEqual(@as(u64, 20000), shells[1].working_since_ms);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("x · 0s"), g_chat_working_applied[0..g_chat_working_applied_len]);
    g_chat_screen_status_len = 0; shells[0].console_working = true;
    chatWorkingTimesPoll();
    try std.testing.expectEqual(@as(u64, 20000), shells[0].working_since_ms);
    fake_tick = 25000; chatWorkingTimesPoll();
    try std.testing.expectEqual(@as(u64, 20000), shells[0].working_since_ms);
}
`;
  const result = run('const ISSUE_265_WORKING_BAR = true;\n' + prelude + functions + checks);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const disabled = run('const ISSUE_265_WORKING_BAR = false;\n' + prelude + functions + `
test "disabled switch keeps old text and no new timer or per-session tracking" {
    shells[0].activity = .active;
    g_chat_working_text[0] = 'x'; g_chat_screen_status_len = 1;
    chatWorkingTimesPoll(); chatWorkingIndicatorSync(); chatWorkingBarTick();
    try std.testing.expectEqual(@as(u64, 0), shells[0].working_since_ms);
    try std.testing.expectEqual(@as(usize, 0), starts + stops);
    try std.testing.expectEqualSlices(u16, &.{'x'}, g_chat_working_applied[0..g_chat_working_applied_len]);
}
`);
  assert.equal(disabled.status, 0, disabled.stdout + disabled.stderr);
  const broken = run('const ISSUE_265_WORKING_BAR = true;\n' + prelude + functions.replace('const running = visible and g_main_hwnd != null;', 'const running = g_main_hwnd != null;') + checks);
  assert.equal(broken.status, 1, broken.stdout + broken.stderr);
  assert.match(broken.stderr, /FAIL \(TestExpectedEqual\)/);
  const compileControl = run('const ISSUE_265_WORKING_BAR = true;\n' + prelude + functions.replace('const running = visible and g_main_hwnd != null;', '@compileError("working bar compile control");\n        const running = visible and g_main_hwnd != null;') + checks);
  assert.notEqual(compileControl.status, 0);
  assert.match(compileControl.stderr, /working bar compile control/);
});
