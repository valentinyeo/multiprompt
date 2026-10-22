const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const main = read('src/main.zig');
const browser = read('src/browser_pane.zig');
const palette = read('src/command_palette.zig');
const state = read('src/app_state.zig');
const offset = 'SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET';

function fn(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `Missing production function ${name}`);
  const end = text.indexOf('\n}', start);
  assert.ok(end > start, `Missing end of ${name}`);
  return text.slice(start, end + 2);
}

function block(text, marker, indent) {
  const start = text.indexOf(marker);
  assert.ok(start >= 0, 'Missing Close All Browser Panes command');
  const end = text.indexOf(`\n${indent}}`, start);
  assert.ok(end > start, 'Missing end of Close All Browser Panes command');
  return text.slice(start, end + indent.length + 2);
}

function harness() {
  const command = block(main, `if (target == ${offset}) {`, '                ');
  const row = block(palette, 'if (app_state.g_search_result_count < app_state.g_search_results.len and labelsMatchQuery(&.{ "Close All Browser Panes"', '    ');
  const declaration = state.match(new RegExp(`pub const ${offset}: usize = \\d+;`));
  assert.ok(declaration, 'Missing Close All Browser Panes command offset');
  const production = ['cancelledBrowserLaunchSlot', 'resetBrowserConnection', 'closeBrowserForShell', 'closeWebView2', 'webView2OwnsShell', 'webView2OwnsActiveShell']
    .map(name => fn(browser, name)).join('\n\n');
  const matching = ['u16ToLower', 'asciiContainsQueryInsensitive', 'labelsMatchQuery'].map(name => fn(palette, name)).join('\n\n');
  return `const std = @import("std");
const app_state = @This();
const HANDLE = ?usize;
const WM_CLOSE = 16;
const TIMER_BROWSER_PLACEHOLDER = 4;
const TIMER_BROWSER_URL_POLL = 1;
const BROWSER_PLACEHOLDER_NOT_OPEN_MS = 20_000;
const CancelledBrowserLaunch = struct {
    nonce: [40]u8 = @splat(0),
    nonce_len: usize = 0,
    deadline: u64 = 0,
};
var g_cancelled_browser_launches = [_]CancelledBrowserLaunch{.{}} ** 7;
var g_browser_resolve_inflight = [_]struct { shell_id: u32 = 0 }{.{}} ** 7;
var g_browser_pending_activate_sid: u32 = 0;
var g_slot_placeholder_since: u64 = 0;
const TIMER_WEBVIEW2_FOCUS = 2;
const TIMER_REFOCUS = 3;
${declaration[0]}
const Shell = struct {
    shell_id: u32 = 0,
    workspace: u8 = 0,
    hidden_idle_streak: u8 = 0,
    keep_awake: bool = false,
    browser_enabled: bool = false,
    browser_hwnd: HANDLE = null,
    browser_url: [512]u8 = @splat(0),
    browser_url_len: u32 = 0,
    browser_docking: bool = false,
    browser_launch_tick: u64 = 0,
    browser_first_launch_tick: u64 = 0,
    browser_connection_id: u64 = 0,
    browser_open_failed: bool = false,
    browser_bind_nonce: [40]u8 = @splat(0),
    browser_bind_nonce_len: usize = 0,
    browser_pending_url_len: u32 = 0,
    browser_suspended: bool = false,
    browser_health_misses: u8 = 0,
    browser_relaunch_after_tick: u64 = 0,
    browser_window_id: i64 = 0,
};
var shells: [7]Shell = undefined;
var shell_count: u32 = 6;
var active_shell: u32 = 0;
var g_active_workspace: u8 = 0;
var g_main_hwnd: HANDLE = 99;
var g_search_active = true;
var g_browser_focus_mode = true;
var g_shell_focused = false;
var g_browser_shortcut_open_guard_until: u64 = 1234;
var g_webview2_active = false;
var g_webview2_owner_shell_id: u32 = 0;
var g_webview2_focus_retries: u8 = 4;
var g_webview2_set_visible: ?*const fn (i32) void = &setWebViewVisible;
var g_webview2_close: ?*const fn () void = &releaseWebView;
var g_search_results: [2]usize = @splat(0);
var g_search_result_count: usize = 0;
var g_search_buf: [128]u16 = @splat(0);
var g_search_len: usize = 0;
var cancelled: [7]u32 = @splat(0);
var window_closes: [8]u32 = @splat(0);
var hidden: [8]bool = @splat(false);
var id_deleted: [7]u32 = @splat(0);
var files_removed: [7]u32 = @splat(0);
var webview_releases: u32 = 0;
var webview_files_removed: u32 = 0;
var webview_hidden = false;
var edits_discarded: u32 = 0;
var layouts: u32 = 0;
var mouse_syncs: u32 = 0;
var sidebar_invalidations: u32 = 0;
var saves: u32 = 0;
var refocuses: u32 = 0;
fn cancelBrowserAdoptionForShell(idx: u32) void { cancelled[idx] += 1; }
fn hideBrowserEdgeMasks() void {}
fn GetTickCount64() u64 { return 1000; }
fn cancelBrowserVisibilitySettle() void {}
fn publishInboxState() void {}
fn IsWindow(hwnd: HANDLE) i32 { return @intFromBool(hwnd != null); }
fn hideBrowserWindowHard(hwnd: HANDLE) void { hidden[hwnd.?] = true; }
fn PostMessageW(hwnd: HANDLE, msg: u32, _: usize, _: isize) i32 {
    std.debug.assert(msg == WM_CLOSE and hidden[hwnd.?]);
    window_closes[hwnd.?] += 1;
    return 1;
}
fn deleteBrowserWindowIdFile(sid: u32) void { id_deleted[sid - 1] += 1; }
fn removePaneSessionFilesForShell(idx: u32) void { files_removed[idx] += 1; }
fn KillTimer(_: HANDLE, _: usize) i32 { return 1; }
fn setWebViewVisible(value: i32) void { std.debug.assert(value == 0); webview_hidden = true; }
fn releaseWebView() void { std.debug.assert(webview_hidden); webview_releases += 1; }
fn removeWebView2SessionFilesForOwner() void {
    std.debug.assert(g_webview2_owner_shell_id != 0);
    webview_files_removed += 1;
}
fn clearSearchBackdrop() void { std.debug.assert(!g_search_active); }
fn discardBrowserUrlBarEdit() void { edits_discarded += 1; }
fn assertClosed() void {
    for (shells[0..shell_count]) |shell| {
        std.debug.assert(!shell.browser_enabled and shell.browser_hwnd == null and shell.browser_launch_tick == 0);
    }
    std.debug.assert(!g_webview2_active);
}
fn showActiveShellAfterOverlay() void { assertClosed(); }
fn updateBrowserVisibility() void { assertClosed(); }
fn repositionActive() void { layouts += 1; }
fn syncMouseHookForUrlClicks() void { mouse_syncs += 1; }
fn invalidateSidebar() void { sidebar_invalidations += 1; }
fn saveSession() void { assertClosed(); saves += 1; }
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) i32 { return 1; }
fn SetTimer(_: HANDLE, timer: usize, _: u32, _: ?usize) usize {
    std.debug.assert(timer == TIMER_REFOCUS);
    refocuses += 1;
    return 1;
}
${production}
${matching}
fn confirm(target: usize, hwnd: HANDLE) i32 {
    ${command}
    return -1;
}
fn listRow() void {
    ${row}
}
fn prepare(webview_owner: u32) void {
    shell_count = 6;
    active_shell = 0;
    g_active_workspace = 0;
    for (&shells, 0..) |*shell, i| {
        shell.* = .{
            .shell_id = @intCast(i + 1),
            .workspace = @intCast(i % 2),
            .hidden_idle_streak = if (i == 2) 8 else 0,
            .keep_awake = i == 1,
            .browser_enabled = i != 5,
            .browser_hwnd = if (i == 3 or i == 4) null else i + 1,
            .browser_suspended = i == 3,
            .browser_docking = i == 4,
            .browser_launch_tick = if (i == 4) 123 else 0,
            .browser_first_launch_tick = if (i == 4) 123 else 0,
            .browser_health_misses = 2,
            .browser_relaunch_after_tick = 456,
            .browser_window_id = if (i == 3 or i == 4) 0 else @intCast(i + 10),
        };
        const url = tryUrl(&shell.browser_url, i);
        shell.browser_url_len = @intCast(url.len);
    }
    g_webview2_active = webview_owner != 0;
    g_webview2_owner_shell_id = webview_owner;
    g_webview2_focus_retries = 4;
    g_search_active = true;
    g_browser_focus_mode = true;
    g_shell_focused = false;
    g_browser_shortcut_open_guard_until = 1234;
    cancelled = @splat(0);
    window_closes = @splat(0);
    hidden = @splat(false);
    id_deleted = @splat(0);
    files_removed = @splat(0);
    webview_releases = 0;
    webview_files_removed = 0;
    webview_hidden = false;
    edits_discarded = 0;
    layouts = 0;
    mouse_syncs = 0;
    sidebar_invalidations = 0;
    saves = 0;
    refocuses = 0;
}
fn tryUrl(buf: []u8, i: usize) []const u8 {
    return std.fmt.bufPrint(buf, "https://example.com/session/{d}", .{i}) catch unreachable;
}
test "production palette handler closes every session through native teardown and retains URLs" {
    for ([_]u32{ 0, 1, 4 }) |owner| {
        prepare(owner);
        const before = shells;
        try std.testing.expectEqual(@as(i32, 0), confirm(SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET, g_main_hwnd));
        for (shells[0..shell_count], 0..) |shell, i| {
            try std.testing.expectEqual(@as(u32, 1), cancelled[i]);
            try std.testing.expect(!shell.browser_enabled);
            try std.testing.expectEqual(@as(HANDLE, null), shell.browser_hwnd);
            try std.testing.expect(!shell.browser_docking and !shell.browser_suspended);
            try std.testing.expectEqual(@as(u64, 0), shell.browser_launch_tick);
            try std.testing.expectEqual(@as(u64, 0), shell.browser_first_launch_tick);
            try std.testing.expectEqual(@as(u8, 0), shell.browser_health_misses);
            try std.testing.expectEqual(@as(u64, 0), shell.browser_relaunch_after_tick);
            try std.testing.expectEqual(@as(i64, 0), shell.browser_window_id);
            try std.testing.expectEqualSlices(u8, &before[i].browser_url, &shell.browser_url);
            try std.testing.expectEqual(before[i].browser_url_len, shell.browser_url_len);
            try std.testing.expectEqual(before[i].workspace, shell.workspace);
            try std.testing.expectEqual(before[i].hidden_idle_streak, shell.hidden_idle_streak);
            try std.testing.expectEqual(before[i].keep_awake, shell.keep_awake);
            if (before[i].browser_hwnd) |hwnd| try std.testing.expectEqual(@as(u32, 1), window_closes[hwnd]);
            const expected: u32 = 1;
            try std.testing.expectEqual(expected, id_deleted[i]);
            try std.testing.expectEqual(expected, files_removed[i]);
        }
        try std.testing.expectEqualDeep(before[6], shells[6]);
        try std.testing.expectEqual(@as(u32, 0), cancelled[6]);
        try std.testing.expectEqual(@as(u32, 0), window_closes[7]);
        try std.testing.expectEqual(@as(u32, @intFromBool(owner != 0)), webview_releases);
        try std.testing.expectEqual(webview_releases, webview_files_removed);
        try std.testing.expect(!g_webview2_active and g_webview2_owner_shell_id == 0);
        if (owner != 0) try std.testing.expectEqual(@as(u8, 0), g_webview2_focus_retries);
        try std.testing.expect(!g_search_active and !g_browser_focus_mode and g_shell_focused);
        try std.testing.expectEqual(@as(u64, 0), g_browser_shortcut_open_guard_until);
        for ([_]u32{ edits_discarded, layouts, mouse_syncs, sidebar_invalidations, saves, refocuses }) |count| {
            try std.testing.expectEqual(@as(u32, 1), count);
        }
        _ = confirm(SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET, g_main_hwnd);
        for (window_closes) |count| try std.testing.expect(count <= 1);
        try std.testing.expectEqual(@as(u32, @intFromBool(owner != 0)), webview_releases);
    }
}
test "production handler also releases WebView2 without any sessions" {
    prepare(4);
    shell_count = 0;
    try std.testing.expectEqual(@as(i32, 0), confirm(SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET, g_main_hwnd));
    try std.testing.expectEqual(@as(u32, 1), webview_releases);
    for (cancelled) |count| try std.testing.expectEqual(@as(u32, 0), count);
}
test "production palette lists command for its label and respects row capacity" {
    for ([_][]const u8{ "", "Close All Browser Panes", "CLOSE ALL BROWSERS", "close browser windows", "free browser memory", "unrelated" }) |query| {
        for (query, 0..) |c, i| g_search_buf[i] = c;
        g_search_len = query.len;
        g_search_result_count = 0;
        listRow();
        const matches = !std.mem.eql(u8, query, "unrelated");
        try std.testing.expectEqual(@as(usize, @intFromBool(matches)), g_search_result_count);
        if (matches) try std.testing.expectEqual(SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET, g_search_results[0]);
    }
    g_search_len = 0;
    g_search_result_count = g_search_results.len;
    listRow();
    try std.testing.expectEqual(g_search_results.len, g_search_result_count);
}
`;
}

test('Close All Browser Panes is listed, painted, documented and registered in the test step', () => {
  assert.ok(main.includes(`if (target == ${offset}) {`), 'Missing Close All Browser Panes command');
  assert.match(palette, new RegExp(`${offset} => "close all browser panes"`));
  assert.ok(palette.includes(`g_search_results[app_state.g_search_result_count] = ${offset};`));
  const sidebar = read('src/sidebar.zig');
  assert.ok(sidebar.includes(`result_idx == ${offset}`));
  assert.ok(sidebar.includes('L("Close All Browser Panes")'));
  assert.match(sidebar, /else if \(is_hibernate_now or is_close_all_browser_panes\)/);
  for (const classifier of ['is_newwin', 'is_new_shell', 'is_tmux_inactive']) {
    const chain = sidebar.match(new RegExp(`const ${classifier} = ([^;]+);`));
    assert.ok(chain, classifier);
    assert.ok(chain[1].includes('!is_close_all_browser_panes'), `${classifier} must exclude the close-all command`);
  }
  assert.match(read('src/shortcuts.zig'), /\.a = "Ctrl\+K \\u\{2192\} Close All Browser Panes"/);
  assert.ok(read('openwiki/operations/keyboard-shortcuts.md').includes('Ctrl+K → Close All Browser Panes'));
  assert.match(read('build.zig'), /const (\w+) = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/close-all-browser-panes\.test\.js" \}\);\s*test_step\.dependOn\(&\1\.step\);/);
});

test('extracted production close-all handler releases native panes and WebView2 across workspaces', () => {
  const production = harness();
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'close-all-browser-panes-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, production);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    console.log(result.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
