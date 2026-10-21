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
const state = read('app_state');
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
    ...['SIDEBAR_W', 'threadTitleHeight', 'consoleEdgePad', 'centeredConsoleColumn', 'contentHeaderLeft', 'browserDockConsoleX', 'paneFocusRingPad', 'paneFocusContentGap', 'paneFocusInset', 'browserUrlBarH', 'calcBrowserLayout'].map(n => fn(browser, n)),
    fn(chat, 'chatViewLayout'), fn(capacity, 'sidebarStickyCardRect'), fn(layout, 'repositionActive'),
  ];
  if (shared) functions.push(...['paneOuterMargin', 'paneGap', 'paneRects', 'activePaneRects'].map(n => fn(layout, n)));
  const production = functions.join('\n').replaceAll('@import("window_layout.zig").', '').replaceAll('@import("browser_pane.zig").', '');
  return `const std = @import("std");
const app_state = @This();
const chat_style = struct { ${fn(read('chat_style'), 'readingColumn')} ${fn(read('chat_style'), 'contentColumn')} };
const chat_history = struct { ${fn(read('chat_history'), 'column')} };
const HANDLE = ?usize;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
${['DEV_TOP_PAD', 'DEV_SHELL_COLS', 'SIDEBAR_W_COLLAPSED', 'SIDEBAR_VPS_CARD_H', 'SIDEBAR_STICKY_CARD_H', 'SIDEBAR_STICKY_CARD_COLLAPSED_H', 'SIDEBAR_STICKY_CARD_GAP', 'THREAD_TITLE_H', 'BROWSER_SPLIT_W', 'BrowserLayout', 'ChatViewLayout'].map(n => n.endsWith('Layout') ? state.slice(state.indexOf('pub const ' + n + ' = struct'), state.indexOf('\n};', state.indexOf('pub const ' + n + ' = struct')) + 3) : declaration(n)).join('\n')}
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
var g_ui_scale: u32 = 100;
var g_sidebar_w_full: i32 = 220;
var g_sidebar_collapsed = false;
var g_hide_sidebar = false;
var g_thread_title = true;
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var shells = [_]struct { hwnd: HANDLE = 2, full_width: bool = false, browser_native: bool = true, font_gen: u32 = 0 }{.{}};
var g_main_hwnd: HANDLE = 1;
var g_chat_active = false;
var g_chat_composer_extra_h: i32 = 0;
var g_webview2_active = false;
var g_webview2_set_visible: ?*const fn (i32) void = null;
var g_all_sessions_active = false;
var g_chat_browser_swap: struct { shell_id: u32 = 0 } = .{};
var g_font_gen: u32 = 0;
var g_nudge_repaint = false;
var reserved = false;
var test_client = RECT{ .right = 1920, .bottom = 1032 };
var shell_rect: RECT = .{};
fn mainWindowDpi() u32 { return 96; }
fn browserSplitPermilleForActiveShell() u16 { return 500; }
fn browserSlotReserved() bool { return reserved; }
fn chatComposerBaseCardH() i32 { return uiScaled(44); }
fn chatReplyBarH() i32 { return 0; }
fn chatWorkingIndicatorH() i32 { return uiScaled(18); }
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
fn positionActiveBrowser() void {}
fn layoutChatControls() void {}
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
                            const burn = sidebarStickyCardRect();
                            const c = chatViewLayout();
                            repositionActive();
                            const primary = if (chat_on) RECT{ .left = c.transcript.left, .top = c.pane.top, .right = c.composer_card.right, .bottom = c.composer_card.bottom } else RECT{ .left = shell_rect.left, .top = shell_rect.top - threadTitleHeight(), .right = shell_rect.right, .bottom = shell_rect.bottom };
                            const margin = if (hidden) uiScaled(8) else burn.left;
                            const sidebar_gap = if (hidden) primary.left else primary.left - burn.right;
                            var right_margin = test_client.right - primary.right;
                            var browser_gap: i32 = margin;
                            var browser_top: i32 = margin;
                            var browser_bottom: i32 = margin;
                            if (browser_on) {
                                const b = calcBrowserLayout().?;
                                right_margin = test_client.right - b.browser_x - b.browser_w;
                                browser_gap = b.browser_x - primary.right;
                                browser_top = b.urlbar_y;
                                browser_bottom = test_client.bottom - b.browser_y - b.browser_h;
                            }
                            std.debug.print("scale={d} chat={} browser={} full={} hidden={} title={} sidebar-gap={d} browser-gap={d} burn-bottom={d} pane-bottom={d} browser-bottom={d} outer={d} right={d} top={d}\\n", .{scale, chat_on, browser_on, full, hidden, title, sidebar_gap, browser_gap, test_client.bottom - burn.bottom, test_client.bottom - primary.bottom, browser_bottom, margin, right_margin, primary.top});
                            const gaps = [_]i32{ sidebar_gap, right_margin, primary.top, test_client.bottom - primary.bottom, browser_gap, browser_top, browser_bottom };
                            for (gaps) |gap| equalGap(margin, gap) catch { failures += 1; };
                            if (!hidden) equalGap(margin, test_client.bottom - burn.bottom) catch { failures += 1; };
                            if (chat_on) {
                                try std.testing.expectEqual(c.transcript.left, c.composer_card.left);
                                try std.testing.expectEqual(c.transcript.right, c.composer_card.right);
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
    fs.writeFileSync(file, harness());
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    console.log(result.stdout + result.stderr);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('pane consumers use the shared production rectangles and spacing tokens', { skip: !layout.includes('pub fn paneRects(') }, () => {
  for (const source of [chat, browser, capacity, layout]) assert.match(source, /activePaneRects\(/);
  assert.match(read('update_card'), /paneGap\(\)/);
  assert.match(read('sidebar'), /activePaneRects\(client_rc\)\.sidebar/);
  assert.match(read('console'), /@import\("window_layout.zig"\)\.repositionActive/);
});
