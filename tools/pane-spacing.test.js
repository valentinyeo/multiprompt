const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name + '.zig'), 'utf8');
const layout = read('window_layout');
const browser = read('browser_pane');
const chat = read('chat_composer');
const capacity = read('capacity');
const corners = read('browser_corners');
const state = read('app_state');
const sidebar = read('sidebar');
function statement(source, prefix) {
  const start = source.indexOf(prefix);
  assert.ok(start >= 0, prefix);
  return source.slice(start, source.indexOf(';', start) + 1);
}
function fn(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}
function declaration(name) {
  const match = state.match(new RegExp(`pub const ${name}[^;]+;`));
  assert.ok(match, name);
  return match[0];
}
function harness() {
  const shared = layout.includes('pub fn paneRects(');
  const functions = [
    fn(read('drawing'), 'uiScaled'),
    fn(read('window_frame'), 'frameScaled'),
    fn(read('window_frame'), 'controlsRect').replaceAll('w.RECT', 'RECT'),
    ...['SIDEBAR_W', 'tabRowH', 'threadTitleHeight', 'threadTitleTop', 'consoleEdgePad', 'centeredConsoleColumn', 'contentHeaderLeft', 'browserDockConsoleX', 'paneFocusRingPad', 'paneFocusContentGap', 'paneFocusInset', 'browserUrlBarH', 'browserAppTitlebarH', 'browserDockTarget', 'calcBrowserLayout'].map(n => fn(browser, n)),
    fn(read('drawing'), 'threadTitleBandRightFor'), fn(chat, 'chatReplyBarH'), fn(chat, 'chatDictationMicWidth'), fn(chat, 'chatDictationMicFit'), fn(browser, 'setBrowserSplitFromMouse'), fn(browser, 'positionBrowserEdgeMasks').replace('    refreshBrowserControlMaskColor(layout);\n', ''), fn(chat, 'chatViewLayout'), fn(chat, 'chatSendSlots'), fn(layout, 'repositionActive'), fn(browser, 'paintBrowserSplitter'),
    fn(read('console'), 'positionReconnectedConsole').replace('const pane = @import("browser_pane.zig");', 'const pane = app_state;').replaceAll('@import("drawing.zig").', ''),
  ];
  if (shared) functions.push(...['paneOuterMargin', 'paneGap', 'clampPaneSplitWidth', 'paneRects', 'activePaneRects', 'activePaneContentRect'].map(n => fn(layout, n)));
  const production = functions.join('\n').replaceAll('@import("window_layout.zig").', '').replaceAll('@import("browser_pane.zig").', '').replaceAll('@import("chat_composer.zig").', '').replaceAll('@import("window_frame.zig").', '').replaceAll('@import("console.zig").', '').replaceAll('const style = @import("window_layout.zig");', 'const style = pane_style;');
  return `const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const app_state = @This();
const chat_style = struct { ${fn(read('chat_style'), 'readingColumn')} ${fn(read('chat_style'), 'contentColumn')} };
const chat_history = struct { ${fn(read('chat_history'), 'column')} };
const HANDLE = ?*anyopaque;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
${['GROUP_HEADER_H', 'BROWSER_SPLIT_DEFAULT_PERMILLE', 'CHAT_BUBBLE_RADIUS', 'DEV_TOP_PAD', 'DEV_SHELL_COLS', 'SIDEBAR_W_COLLAPSED', 'SIDEBAR_STICKY_CARD_H', 'SIDEBAR_STICKY_CARD_COLLAPSED_H', 'SIDEBAR_STICKY_CARD_GAP', 'THREAD_TITLE_H', 'BROWSER_SPLIT_W', 'BrowserLayout', 'ChatViewLayout'].map(n => n.endsWith('Layout') ? state.slice(state.indexOf('pub const ' + n + ' = struct'), state.indexOf('\n};', state.indexOf('pub const ' + n + ' = struct')) + 3) : declaration(n)).join('\n')}
const ConsoleColumn = struct { left: i32, width: i32 };
${shared ? layout.slice(layout.indexOf('pub const PaneRects'), layout.indexOf('\n};', layout.indexOf('pub const PaneRects')) + 3) : ''}
const LOOK_UNIFIED = true;
const ISSUE_440_FULL_WIDTH_CHAT = true;
const SHELL_PAD = 8;
const WS_VSCROLL = 1;
const WS_HSCROLL = 2;
const GWL_STYLE = 0;
const SWP_FRAMECHANGED = 1;
const SWP_NOZORDER = 2;
const SW_HIDE = 0;
const SWP_NOREDRAW = 16;
const DWORD = u32;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_inbox_active = false;
var g_url_picker_active = false;
var g_snippet_create_active = false;
var g_search_active = false;
var g_multiprompt_theme = false;
var g_light_theme = false;
var g_amoled_theme = false;
var g_edge_gray_theme = false;
var g_mid_theme = false;
var g_sidebar_scroll: i32 = 0;
var splitter_paint: RECT = .{};
fn reconnectTabVisible(_: u32) bool { return true; }
fn paletteAnchoredBesideBrowser() bool { return false; }
fn RGB(r: u32, g: u32, b: u32) u32 { return r | (g << 8) | (b << 16); }
fn customColorOr(_: []const u8, color: u32) u32 { return color; }
fn CreateSolidBrush(_: u32) HANDLE { return null; }
fn DeleteObject(_: HANDLE) i32 { return 1; }
fn FillRect(_: HANDLE, rc: *const RECT, _: HANDLE) i32 { splitter_paint = rc.*; return 1; }
var g_ui_scale: u32 = 100;
var g_sidebar_w_full: i32 = 220;
var g_sidebar_collapsed = false;
var g_hide_sidebar = false;
var g_thread_title = true;
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var shells = [_]struct { hwnd: HANDLE = @ptrFromInt(2), browser_split_permille: u16 = 500, full_width: bool = false, browser_native: bool = true, font_gen: u32 = 0, disconnected: bool = false }{.{}};
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_active = false;
var g_chat_composer_extra_h: i32 = 0;
var g_chat_reply_len: usize = 0;
var g_webview2_active = false;
var g_webview2_set_visible: ?*const fn (i32) void = null;
var g_all_sessions_active = false;
var g_chat_browser_swap: struct { shell_id: u32 = 0 } = .{};
var g_browser_switch_preparing = false;
var g_font_gen: u32 = 0;
var g_nudge_repaint = false;
var reserved = false;
var test_client = RECT{ .right = 1920, .bottom = 1032 };
var shell_rect: RECT = .{};
fn mainWindowDpi() u32 { return 96; }
${fn(browser, 'browserSplitPermilleForActiveShell')}
fn browserSlotReserved() bool { return reserved; }
fn chatComposerBaseCardH() i32 { return uiScaled(44); }
var test_permission_visible = false;
fn chatPermissionVisible() bool { return test_permission_visible; }
${fn(layout, 'chatWorkingIndicatorH')}
fn chatNewMessagesHeight() i32 { return 0; }
var test_stop_visible = false;
var test_composer_text = false;
var chat_dictation_state: enum { idle, listening, finishing } = .idle;
const DictationState = @TypeOf(chat_dictation_state);
fn chatStopVisible() bool { return test_stop_visible; }
fn chatComposerHasText() bool { return test_composer_text; }
fn consoleCellW() i32 { return uiScaled(10); }
fn GetClientRect(_: HANDLE, rc: *RECT) i32 { rc.* = test_client; return 1; }
fn IsIconic(_: HANDLE) i32 { return 0; }
fn IsWindowVisible(_: HANDLE) i32 { return 0; }
fn ShowWindow(_: HANDLE, _: i32) i32 { return 1; }
fn ShowWindowAsync(_: HANDLE, _: i32) i32 { return 1; }
fn shellConsoleShouldBeVisible(_: u32) bool { return !g_chat_active; }
fn webView2OwnsActiveShell() bool { return false; }
fn hideAllBrowserChrome() void {}
fn positionWebView2() void {}
fn positionActiveBrowser() void {
    const layout = calcBrowserLayout() orelse return;
    const bh: HANDLE = @ptrFromInt(3);
${fn(browser, 'positionActiveBrowser').slice(fn(browser, 'positionActiveBrowser').indexOf('    const native = app_state.shells[app_state.active_shell].browser_native;'), fn(browser, 'positionActiveBrowser').indexOf('\n    } else {'))}
    }
}
const pane_style = struct {
    const paneRects = app_state.paneRects;
    const paneGap = app_state.paneGap;
    const clampPaneSplitWidth = app_state.clampPaneSplitWidth;
    ${fn(layout, 'chatSurfaceBorderW')}
    ${fn(layout, 'chatSurfaceRadius')}
    fn chatSurfaceBorderColor() u32 { return 0; }
};
const POINT = struct { x: i32, y: i32 };
const BrowserEdgeMaskSide = enum { left, top, right, bottom, control_hit, controls, top_left, top_right, bottom_left, bottom_right };
const BROWSER_EDGE_MASKS = true;
const SWP_NOACTIVATE = 4;
const SWP_SHOWWINDOW = 8;
var g_monitor_transition: struct { active: bool = false } = .{};
var g_browser_onscreen: struct { fn mark(_: @This(), _: usize) void {} } = .{};
var placed_browser: RECT = .{};
var placed_masks: [10]RECT = undefined;
const browser_corners = struct {
${corners.slice(corners.indexOf('pub const Corner'), corners.indexOf('pub fn render'))}
};
fn ClientToScreen(_: HANDLE, pt: *POINT) i32 { pt.x += 37; pt.y += 53; return 1; }
fn browserWindowNeedsPosition(_: HANDLE, _: i32, _: i32, _: i32, _: i32) bool { return true; }
fn setBrowserWindowPosAsync(_: HANDLE, _: HANDLE, x: i32, y: i32, w: i32, h: i32, _: i32) void { placed_browser = .{ .left = x, .top = y, .right = x + w, .bottom = y + h }; }
fn browserTraceN(_: []const u8, _: i32) void {}
fn browserTrace(_: []const u8) void {}
fn hideBrowserEdgeMasks() void {}
fn activeBrowserTransientPopupHasForegroundFocus() bool { return false; }
fn suspendBrowserEdgeMaskRaiseForPopup() void {}
fn activeBrowserEdgeMasksAllowed() bool { return true; }
fn browserChromeHiddenForOverlay() bool { return false; }
fn browserChromeForegroundAllowed() bool { return true; }
fn ensureBrowserEdgeMaskWindows() void {}
${fn(browser, 'browserEdgeBottomMaskH')}
fn browserEdgeMaskColor(_: BrowserEdgeMaskSide) u32 { return 0; }
fn browserEdgeMaskFrameColor() u32 { return 0; }
${fn(browser, 'browserMaskCorner')}
fn moveBrowserEdgeMask(side: BrowserEdgeMaskSide, x: i32, y: i32, w: i32, h: i32) void { placed_masks[@intFromEnum(side)] = .{ .left = x, .top = y, .right = x + w, .bottom = y + h }; }


var chat_layouts: usize = 0;
fn layoutChatControls() void { chat_layouts += 1; }
fn fontGenStale(_: u32, _: u32) bool { return false; }
fn fontSyncShell(_: u32) bool { return true; }
fn verboseLoggingEnabled() bool { return false; }
fn debugLog(_: []const u8) void {}
fn ensureDevThemeInitialized() void {}
fn GetWindowLongPtrW(_: HANDLE, _: i32) isize { return 0; }
fn SetWindowLongPtrW(_: HANDLE, _: i32, _: isize) isize { return 0; }
fn SetWindowRgn(_: HANDLE, _: HANDLE, _: i32) i32 { return 1; }
fn SetWindowPos(_: HANDLE, _: HANDLE, x: i32, y: i32, w: i32, h: i32, _: i32) i32 { shell_rect = .{ .left = x, .top = y, .right = x + w, .bottom = y + h }; return 1; }
fn verifyShellWindowSize(_: HANDLE, _: i32, _: i32, _: i32, _: i32) void {}
fn MoveWindow(_: HANDLE, _: i32, _: i32, _: i32, _: i32, _: i32) i32 { return 1; }
fn CreateRoundRectRgn(_: i32, _: i32, _: i32, _: i32, _: i32, _: i32) HANDLE { return null; }
${production}
test "IGSH-1059 chat layout survives a missing remote console" {
    g_chat_active = true;
    shells[0].hwnd = null;
    defer { shells[0].hwnd = @ptrFromInt(2); g_chat_active = false; }
    const before = chat_layouts;
    repositionActive();
    try std.testing.expectEqual(before + 1, chat_layouts);
}
test "split dragging inverts shared pane geometry at both scales" {
    reserved = true;
    for ([_]u32{100, 150}) |scale| {
        g_ui_scale = scale;
        for ([_]bool{false, true}) |hidden| {
            g_hide_sidebar = hidden;
            const whole = paneRects(test_client, SIDEBAR_W(), false, 0, 0).primary;
            const min_x = whole.left + uiScaled(200) + @divTrunc(paneGap(), 2);
            const max_x = whole.right - uiScaled(200) - @divTrunc(paneGap(), 2);
            var x = min_x;
            while (x <= max_x) : (x += 1) {
                setBrowserSplitFromMouse(x);
                const b = calcBrowserLayout().?;
                try equalGap(x, @divTrunc(b.splitter_left + b.splitter_right, 2));
            }
            setBrowserSplitFromMouse(-1000);
            try std.testing.expectEqual(whole.left + uiScaled(200), activePaneRects(test_client).primary.right);
            setBrowserSplitFromMouse(10000);
            try std.testing.expectEqual(whole.right - uiScaled(200), activePaneRects(test_client).browser.left);
        }
    }
    g_hide_sidebar = false;
    shells[0].browser_split_permille = 500;
    reserved = false;
}
${shared ? `test "split widths retain minimum pane sizes on narrow clients" {
    for ([_]u32{100, 150}) |scale| {
        g_ui_scale = scale;
        for ([_]u32{0, 200, 800, 1000}) |ratio| {
            const panes = paneRects(.{ .right = uiScaled(640), .bottom = uiScaled(600) }, uiScaled(220), true, ratio, uiScaled(200));
            try std.testing.expect(panes.primary.right - panes.primary.left >= uiScaled(200));
            try std.testing.expect(panes.browser.right - panes.browser.left >= uiScaled(200));
            try std.testing.expectEqual(uiScaled(8), panes.browser.left - panes.primary.right);
        }
    }
}` : ''}
fn equalGap(expected: i32, actual: i32) !void {
    if (@abs(expected - actual) > 1) {
        std.debug.print("SPACING ASSERTION expected={d} measured={d}\\n", .{expected, actual});
        return error.UnequalPaneSpacing;
    }
}
fn expectInside(rect: RECT, inner: RECT) !void {
    if (rect.left < inner.left or rect.top < inner.top or rect.right > inner.right or rect.bottom > inner.bottom) {
        std.debug.print("scale={d} rect=({d},{d},{d},{d}) inner=({d},{d},{d},{d})\\n", .{ g_ui_scale, rect.left, rect.top, rect.right, rect.bottom, inner.left, inner.top, inner.right, inner.bottom });
        return error.OutsidePaneContent;
    }
}
fn intersects(a: RECT, b: RECT) bool {
    return a.left < b.right and a.right > b.left and a.top < b.bottom and a.bottom > b.top;
}
test "IGSH-549 console HWND and browser layout stay inside the primary content inset" {
    g_chat_active = false;
    g_hide_sidebar = false;
    for ([_]u32{100, 125, 150}) |scale| {
        g_ui_scale = scale;
        for ([_]bool{false, true}) |docked| {
            reserved = docked;
            for ([_]bool{false, true}) |full| {
                shells[0].full_width = full;
                for ([_]bool{false, true}) |title| {
                    g_thread_title = title;
                    const primary = activePaneRects(test_client).primary;
                    const edge = paneFocusInset();
                    const inner = RECT{ .left = primary.left + edge, .top = primary.top + edge, .right = primary.right - edge, .bottom = primary.bottom - edge };
                    repositionActive();
                    try expectInside(shell_rect, inner);
                    const placed = shell_rect;
                    try std.testing.expect(positionReconnectedConsole(0));
                    try expectInside(shell_rect, inner);
                    try std.testing.expectEqual(placed, shell_rect);
                    if (docked) {
                        const b = calcBrowserLayout().?;
                        try expectInside(.{ .left = b.console_x, .top = b.console_y, .right = b.console_x + b.console_w, .bottom = b.console_y + b.console_h }, inner);
                        const content = activePaneContentRect(test_client);
                        try std.testing.expectEqual(content.left, b.console_x);
                        try std.testing.expectEqual(content.right, b.console_x + b.console_w);
                    } else try std.testing.expect(calcBrowserLayout() == null);
                }
            }
        }
    }
    g_thread_title = true;
    shells[0].full_width = false;
    reserved = false;
}
test "IGSH-549 splitter paint is a bounded grip in the gap" {
    reserved = true;
    for ([_]u32{100, 125, 150}) |scale| {
        g_ui_scale = scale;
        paintBrowserSplitter(null);
        const panes = activePaneRects(test_client);
        try expectInside(splitter_paint, panes.splitter);
        try std.testing.expect(splitter_paint.bottom - splitter_paint.top <= uiScaled(32));
    }
    reserved = false;
}
test "IGSH-549 Chat View content stays inside the pane content inset" {
    g_chat_active = true;
    g_hide_sidebar = false;
    g_thread_title = true;
    shells[0].browser_split_permille = 500;
    for ([_]u32{100, 125, 150}) |scale| {
        g_ui_scale = scale;
        for ([_]bool{false, true}) |docked| {
            reserved = docked;
            for ([_]bool{false, true}) |full_width| {
                shells[0].full_width = full_width;
                for (0..12) |variant| {
                    const reply_len = variant % 2;
                    test_permission_visible = variant >= 6;
                    test_stop_visible = variant % 6 >= 2 and !test_permission_visible;
                    test_composer_text = variant % 6 >= 4;
                    g_chat_reply_len = reply_len;
                    g_chat_composer_extra_h = if (reply_len > 0) uiScaled(80) else 0;
                    const primary = activePaneRects(test_client).primary;
                    const edge = paneFocusInset();
                    const inner = RECT{ .left = primary.left + edge, .top = primary.top + edge, .right = primary.right - edge, .bottom = primary.bottom - edge };
                    const c = chatViewLayout();
                    const title = RECT{ .left = c.transcript.left, .top = threadTitleTop(), .right = threadTitleBandRightFor(test_client.right), .bottom = threadTitleTop() + threadTitleHeight() };
                    for ([_]RECT{c.composer_card, c.transcript, title, c.composer, c.send_btn, c.attach_btn, c.mic_btn, c.stop_btn}) |rect| {
                        try std.testing.expect(rect.left >= inner.left);
                        try std.testing.expect(rect.top >= inner.top);
                        try std.testing.expect(rect.right <= inner.right);
                        try std.testing.expect(rect.bottom <= inner.bottom);
                        try std.testing.expect(rect.right >= rect.left and rect.bottom >= rect.top);
                    }
                    try std.testing.expectEqual(uiScaled(14) + (if (test_permission_visible) uiScaled(36) else @as(i32, 0)), c.composer_card.top - c.transcript.bottom);
                    try std.testing.expectEqual(uiScaled(32), c.mic_btn.right - c.mic_btn.left);
                    try std.testing.expectEqual(uiScaled(32), c.mic_btn.bottom - c.mic_btn.top);
                    try std.testing.expect(c.send_btn.left > c.mic_btn.right);
                    try std.testing.expect(c.send_btn.right <= c.composer_card.right);
                    try std.testing.expect(!intersects(c.mic_btn, c.composer));
                    try std.testing.expect(!intersects(c.mic_btn, c.attach_btn));
                    try std.testing.expect(!intersects(c.mic_btn, c.send_btn) or !c.send_shown);
                    try std.testing.expect(!intersects(c.mic_btn, c.stop_btn) or !c.stop_shown);
                    try std.testing.expect(!intersects(c.composer, c.stop_btn) or !c.stop_shown);
                    try std.testing.expect(!intersects(c.composer, c.send_btn) or !c.send_shown);
                    try std.testing.expect(!(c.send_shown and c.stop_shown));
                }
            }
        }
    }
    g_chat_reply_len = 0;
    g_chat_composer_extra_h = 0;
    g_chat_active = false;
    test_stop_visible = false;
    test_permission_visible = false;
    test_composer_text = false;
    reserved = false;
    shells[0].full_width = false;
}
test "IGSH-845 browser covers never enter the app caption at any supported scale" {
    reserved = true;
    defer reserved = false;
    for ([_]u32{100, 125, 150}) |scale| {
        g_ui_scale = scale;
        var b = calcBrowserLayout().?;
        for ([_]i32{0, 1, 2, 4, 10}) |top| {
            b.browser_y = top;
            positionBrowserEdgeMasks(b);
            for ([_]BrowserEdgeMaskSide{.controls, .control_hit}) |side| {
                const mask = placed_masks[@intFromEnum(side)];
                try std.testing.expect(mask.top >= 53);
                try std.testing.expect(mask.top <= b.browser_y + 53);
                try std.testing.expect(mask.bottom > mask.top);
            }
        }
    }
}
test "all production pane consumers share outer margins and gaps" {
    var failures: usize = 0;
    for ([_]u32{100, 150}) |scale| {
        g_ui_scale = scale;
        for ([_]bool{false, true}) |chat_on| {
            g_chat_active = chat_on;
            for ([_]bool{false, true}) |browser_on| {
                reserved = browser_on;
                for ([_]bool{false, true}) |full| {
                    shells[0].full_width = full;
                    for ([_]bool{false, true}) |hidden| {
                        g_hide_sidebar = hidden;
                        for ([_]bool{false, true}) |title| {
                            g_thread_title = title;
                            const burn = activePaneRects(test_client).sidebar;
                            const c = chatViewLayout();
                            repositionActive();
                            const primary = activePaneRects(test_client).primary;
                            const inner = activePaneContentRect(test_client);
                            if (!chat_on) {
                                const expected = centeredConsoleColumn(inner.right, inner.left, 0, consoleCellW());
                                try std.testing.expectEqual(if (full) inner.left else expected.left, shell_rect.left);
                                try std.testing.expectEqual(if (full) inner.right - inner.left else expected.width, shell_rect.right - shell_rect.left);
                                try std.testing.expectEqual(inner.top + threadTitleHeight(), shell_rect.top);
                                try std.testing.expectEqual(inner.bottom, shell_rect.bottom);
                            }
                            const content = chat_style.contentColumn(inner.left, inner.right - inner.left, uiScaled(960));
                            try std.testing.expectEqual(content.left, c.transcript.left);
                            try std.testing.expectEqual(content.width, c.composer_card.right - c.attach_btn.left);
                            const margin = if (hidden) uiScaled(8) else burn.left;
                            const sidebar_gap = if (hidden) primary.left else primary.left - burn.right;
                            var right_margin = test_client.right - primary.right;
                            var browser_gap: i32 = margin;
                            var browser_top: i32 = margin;
                            var browser_bottom: i32 = margin;
                            if (browser_on) {
                                const b = calcBrowserLayout().?;
                                positionActiveBrowser();
                                const expected = RECT{ .left = b.browser_x + 37, .top = b.browser_y + 53, .right = b.browser_x + b.browser_w + 37, .bottom = b.browser_y + b.browser_h + 53 };
                                try std.testing.expectEqual(expected, placed_browser);
                                try equalGap(margin, placed_browser.left - 37 - primary.right);
                                try equalGap(margin, test_client.bottom - (placed_browser.bottom - 53));
                                for ([_]BrowserEdgeMaskSide{ .left, .top, .right, .bottom }) |side| {
                                    const mask = placed_masks[@intFromEnum(side)];
                                    try std.testing.expect(mask.left >= expected.left and mask.top >= expected.top and mask.right <= expected.right and mask.bottom <= expected.bottom);
                                    switch (side) {
                                        .left => try std.testing.expectEqual(expected.left, mask.left),
                                        .right => try std.testing.expectEqual(expected.right, mask.right),
                                        .top => try std.testing.expectEqual(expected.top, mask.top),
                                        .bottom => try std.testing.expectEqual(expected.bottom, mask.bottom),
                                        else => unreachable,
                                    }
                                }
                                for ([_]BrowserEdgeMaskSide{ .top_left, .top_right, .bottom_left, .bottom_right }) |side| {
                                    const is_right = side == .top_right or side == .bottom_right;
                                    const is_bottom = side == .bottom_left or side == .bottom_right;
                                    const w = uiScaled(8) + pane_style.chatSurfaceRadius();
                                    const h = (if (is_bottom) uiScaled(8) else uiScaled(3)) + pane_style.chatSurfaceRadius();
                                    const left = if (is_right) expected.right - w else expected.left;
                                    const top = if (is_bottom) expected.bottom - h else expected.top;
                                    try std.testing.expectEqual(RECT{ .left = left, .top = top, .right = left + w, .bottom = top + h }, placed_masks[@intFromEnum(side)]);
                                }
                                right_margin = test_client.right - b.browser_x - b.browser_w;
                                browser_gap = b.browser_x - primary.right;
                                try equalGap(controlsRect(test_client.right).bottom + margin, b.urlbar_y);
                                browser_top = b.urlbar_y - controlsRect(test_client.right).bottom;
                                browser_bottom = test_client.bottom - b.browser_y - b.browser_h;
                            }
                            std.debug.print("scale={d} chat={} browser={} full={} hidden={} title={} sidebar-gap={d} browser-gap={d} burn-bottom={d} pane-bottom={d} browser-bottom={d} outer={d} right={d} top={d}\\n", .{scale, chat_on, browser_on, full, hidden, title, sidebar_gap, browser_gap, test_client.bottom - burn.bottom, test_client.bottom - primary.bottom, browser_bottom, margin, right_margin, primary.top});
                            const gaps = [_]i32{ sidebar_gap, right_margin, primary.top, test_client.bottom - primary.bottom, browser_gap, browser_top, browser_bottom };
                            for (gaps) |gap| equalGap(margin, gap) catch { failures += 1; };
                            if (!hidden) equalGap(margin, test_client.bottom - burn.bottom) catch { failures += 1; };
                            if (chat_on) {
                                try std.testing.expectEqual(c.transcript.left, c.attach_btn.left);
                                try std.testing.expectEqual(c.transcript.right, c.composer_card.right);
                                try std.testing.expectEqual(uiScaled(8), c.composer_card.left - c.attach_btn.right);
                            }
                        }
                    }
                }
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}
`;
}
test('extracted production pane rectangles have equal spacing at 1920x1032', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pane-spacing-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, (harness()).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    console.log(result.stdout + result.stderr);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    for (const [name, mutate] of [
      ['removed working strip', text => text.replace('return if (chatPermissionVisible()) uiScaled(36) else 0;', 'return if (chatPermissionVisible()) uiScaled(36) else uiScaled(18);')],
      ['microphone overlap', text => text.replace('.right = mic_btn.left - uiScaled(12),', '.right = mic_btn.right,')],
      ['send before microphone', text => text.replace('const send_btn = slots.send;', 'const send_btn = RECT{ .left = composer_card.left, .top = slots.send.top, .right = composer_card.left + send_size, .bottom = slots.send.bottom };')],
      ['native focus inset', text => text.replace('const target_x = target.left;', 'const target_x = target.left + uiScaled(10);')],
      ['caption overlap', text => text.replaceAll('@max(client_origin.y, edge_y -', '@max(client_origin.y - uiScaled(10), edge_y -')],
      ['corner displacement', text => text.replace('moveBrowserEdgeMask(side, rc.left, rc.top,', 'moveBrowserEdgeMask(side, rc.left + 1, rc.top,')],
      ['old splitter origin', text => text.replace('x - pane.left - @divTrunc(style.paneGap(), 2)', 'x - SIDEBAR_W()')],
      ['dead shell full width', text => text.replace('const full_width = app_state.shells[app_state.active_shell].full_width;', 'const full_width = false;')],
    ]) {
      const original = harness();
      const mutated = mutate(original);
      assert.notEqual(mutated, original, name);
      fs.writeFileSync(file, mutated.replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
      const bad = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', file], { encoding: 'utf8', timeout: 120000 });
      assert.notEqual(bad.status, 0, name);
      assert.match(bad.stderr, /FAIL/, name);
      console.log(`${name} rejected by final-placement regression`);
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('pane consumers use the shared production rectangles and spacing tokens', { skip: !layout.includes('pub fn paneRects(') }, () => {
  assert.match(chat, /activePaneContentRect\(/);
  assert.match(fn(layout, 'activePaneContentRect'), /activePaneRects\(client\)\.primary/);
  for (const source of [browser, capacity, layout]) assert.match(source, /activePaneRects\(/);
  assert.match(read('update_card'), /paneGap\(\)/);
  assert.match(read('sidebar'), /activePaneRects\(client_rc\)\.sidebar/);
  assert.match(read('console'), /@import\("window_layout.zig"\)\.repositionActive/);
});

test('overlay backdrop uses the current primary pane rather than old margins', () => {
  const sidebar = read('sidebar');
  const start = sidebar.indexOf('if ((app_state.g_search_active or app_state.g_shortcuts_active or app_state.g_changelog_active) and app_state.g_search_backdrop_bmp');
  const backdrop = sidebar.slice(start, sidebar.indexOf('clampSidebarScroll();', start));
  assert.match(backdrop, /activePaneRects\(client_rc\)\.primary/);
  assert.doesNotMatch(backdrop, /DEV_TOP_PAD/);
  assert.match(sidebar, /const threadTitleHeight = @import\("browser_pane\.zig"\)\.threadTitleHeight;/);
  assert.throws(() => assert.doesNotMatch(backdrop + 'by = DEV_TOP_PAD;', /DEV_TOP_PAD/));
});

test('IGSH-886 selected session background is visible neutral gray in built-in themes', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sidebar-gray-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `const std = @import("std");
const DWORD = u32;
const app_state = @This();
var g_multiprompt_theme = false;
var g_amoled_theme = false;
fn RGB(r: u32, g: u32, b: u32) u32 { return r | (g << 8) | (b << 16); }
fn customColorOr(_: []const u8, fallback: u32) u32 { return fallback; }
${fn(sidebar, 'tintColor')}
fn selectedBackground(sidebar_bg: DWORD) DWORD {
    ${statement(sidebar, 'const hl =')}
    return hl;
}
test "selected session is gray and distinct from its sidebar" {
    for ([_]u32{0, 36, 51, 60, 243}) |base| {
        g_amoled_theme = base == 0;
        const color = selectedBackground(RGB(base, base, base));
        const r = color & 255;
        const g = (color >> 8) & 255;
        const b = (color >> 16) & 255;
        try std.testing.expectEqual(r, g);
        try std.testing.expectEqual(g, b);
        try std.testing.expect(@abs(@as(i32, @intCast(r)) - @as(i32, @intCast(base))) >= 10);
    }
}
`);
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
