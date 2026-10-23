const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const source = require('./app-source').readAppSource();
function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = text.indexOf('\nfn ', start + 1);
  return text.slice(start, end < 0 ? text.length : end);
}
function paintFirst(text) {
  const switching = body('switchToShell', text);
  const chat = switching.slice(switching.indexOf('} else if (g_chat_active) {'), switching.indexOf('} else if (shells[idx].hwnd'));
  assert.match(chat, /chatDeferTranscriptLoad\(\);[\s\S]*layoutChatControls\(\);/);
  assert.doesNotMatch(chat, /positionActiveBrowser|parkInactiveBrowserPanes|updateBrowserVisibility|refreshChatTranscript/);
  for (const fn of ['positionActiveBrowser', 'updateBrowserVisibility', 'adoptBrowserTick', 'browserHealthTick', 'refreshChatTranscript', 'chatFileOnReady']) {
    assert.match(body(fn, text), /if \(g_chat_browser_swap\.shell_id != 0\) return;/);
  }
  const paint = body('chatTranscriptWndProc', text);
  assert.match(paint, /EndPaint\(hwnd, &ps\);\s*if \(painted\) chatSwitchDidPaint\(\);/);
  assert.match(paint, /painted = BitBlt\([^]*\) != 0;/);
  assert.match(body('chatSwitchDidPaint', text), /\.didPaint\(shells\[active_shell\]\.shell_id\)[\s\S]*PostMessageW\(g_main_hwnd, WM_TIMER, TIMER_CHAT_BROWSER_SWAP, 0\)/);
  assert.match(body('chatSwitchBrowserTick', text), /\.take\(shells\[active_shell\]\.shell_id\)[\s\S]*updateBrowserVisibility\(\)/);
}

test('chat paints before the coalesced browser exchange, including stale refresh/adoption callbacks', () => {
  paintFirst(source);
  const baseline = `fn switchToShell(idx: u32) void {
    if (want_chat != g_chat_active) {
        if (want_chat) openChatView() else closeChatView();
    } else if (g_chat_active) {
        if (browserSlotReserved()) {
            parkInactiveBrowserPanes();
            if (webView2OwnsActiveShell()) positionWebView2() else positionActiveBrowser();
        } else {
            hideAllBrowserChrome();
        }
        updateBrowserVisibility();
        if (browserPaneActive()) armBrowserVisibilitySettle(12);
        chatDraftBindToActive();
        layoutChatControls();
        chatDeferTranscriptLoad();
    } else if (shells[idx].hwnd != null) {}
}`;
  assert.throws(() => paintFirst(baseline), assert.AssertionError);
});

test('switch restores the unified parsed cache and defers disk/remote IO', () => {
  const restore = body('chatDeferTranscriptLoad');
  assert.match(restore, /chatHistoryEntry\(chatCacheIdentity\(\)\)/);
  assert.match(restore, /history.text.items/);
  assert.doesNotMatch(source, /g_chat_tab_cache|g_chat_file_token/);
  assert.doesNotMatch(restore, /chat_transcript\.parse|captureChatTranscript|readFile|fetchAcPersistent/);
  assert.match(body('chatFileFetchThread'), /history.apply/);
  assert.match(body('chatFileFetchThread'), /chatHistoryRead[\s\S]*History.decode/);
  assert.doesNotMatch(body('chatHistoryEntry'), /chatHistoryRead|History.decode/);
  assert.doesNotMatch(body('chatFileOnReady'), /chat_transcript\.parse|fetchAcPersistent|Sleep\(/);
  assert.match(body('refreshChatBlockCache'), /chatStoreTabCache\(from_file\)/);
});

test('foreign HWND mutations and bridge/OS launches never wait on the UI thread', () => {
  assert.match(body('setBrowserWindowPosAsync'), /SWP_ASYNCWINDOWPOS \| SWP_NOACTIVATE/);
  assert.match(body('positionActiveBrowser'), /SWP_NOZORDER \| SWP_NOACTIVATE \| SWP_SHOWWINDOW/);
  assert.match(body('layoutChatControls'), /BeginDeferWindowPos\(2\)[\s\S]*EndDeferWindowPos/);
  assert.match(body('dockBrowserWindow'), /std\.Thread\.spawn\([^]*browserDockWorker/);
  assert.doesNotMatch(body('dockBrowserWindow'), /SetWindowLongPtrW|SetParent|DwmSetWindowAttribute/);
  assert.match(body('browserDockWorker'), /SetWindowLongPtrW[\s\S]*WM_APP_BROWSER_DOCKED/);
  assert.match(body('finishBrowserDock'), /findShellById\(job.shell_id\)/);
  assert.match(body('spawnBrowserCliHidden'), /std\.Thread\.spawn\([^]*spawnBrowserCliWorker/);
  assert.match(body('shellExecuteEdgeUrl'), /std\.Thread\.spawn\([^]*browserLaunchWorker/);
  assert.doesNotMatch(body('shellExecuteEdgeUrl'), /ShellExecuteW\(/);
  assert.doesNotMatch(body('chatSwitchBrowserTick'), /Sleep\(|WaitFor|SendMessage|SetFocus|SetForegroundWindow/);
});

test('pane follows without requesting browser focus and debug timings sample actual placement', () => {
  assert.match(body('switchToShell'), /cancelPendingNativeBrowserFocus\(\)/);
  assert.match(body('switchToShell'), /if \(idx < shell_count and shells\[idx\]\.hwnd == null/);
  assert.match(body('switchToShell'), /armSshReconnectTimerIfNeeded\(\)/);
  assert.doesNotMatch(body('switchToShell'), /respawnShellInPlace\(/);
  assert.doesNotMatch(body('openChatView'), /shells\[active_shell\]\.hwnd == null/);
  assert.match(body('updateBrowserVisibility'), /if \(g_chat_active\) launchBrowserForShellFromRequest/);
  assert.doesNotMatch(body('chatSwitchBrowserTick'), /requestNativeBrowserFocus|focusActiveBrowserPane/);
  const log = body('chatSwitchLogBrowserShown');
  assert.match(log, /verboseLoggingEnabled\(\)/);
  assert.match(log, /GetWindowRect[\s\S]*std\.meta\.eql\(actual, expected\)/);
  assert.match(log, /\[switch\] chat painted in \{d\} ms, browser shown in \{d\} ms/);
});

test('palette tab confirmation restores both hidden chat controls after switching', () => {
  const main = fs.readFileSync('src/main.zig', 'utf8');
  const start = main.lastIndexOf('switchToShellByUser(@intCast(target));');
  assert(start > 0);
  const confirm = main.slice(start, main.indexOf('if (spawned_new)', start));
  assert.match(confirm, /if \(app_state.g_chat_active\)[^]*ShowWindow\(app_state.g_chat_transcript_hwnd, SW_SHOWNOACTIVATE\)[^]*ShowWindow\(app_state.g_chat_composer_hwnd, SW_SHOWNOACTIVATE\)[^]*InvalidateRect\(app_state.g_chat_transcript_hwnd/);
  assert.match(body('switchToShell'), /\.request\(shells\[idx\].shell_id, switch_started\)[^]*SetTimer\(g_main_hwnd, TIMER_CHAT_BROWSER_SWAP, @import\("chat_switch.zig"\).paint_deadline_ms, null\)/);
  assert.match(body('openChatView'), /\.request\(shells\[active_shell\].shell_id, g_chat_switch_started\)[^]*SetTimer\(g_main_hwnd, @import\("win32.zig"\).TIMER_CHAT_BROWSER_SWAP, @import\("chat_switch.zig"\).paint_deadline_ms, null\)/);
});

test('production switch timer releases missing paints, defers all overlays and ignores stale deadlines', () => {
  const os = require('node:os'), path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-switch-deadline-'));
  const prelude = `
const std = @import("std");
const chat_switch = @import("chat_switch.zig");
var g_chat_browser_swap: chat_switch.Pending = .{};
var g_chat_active = true;
var active_shell: u32 = 0;
var shell_count: u32 = 1;
var shells = [_]struct { shell_id: u32 = 7, browser_frozen: bool = false, browser_window_id: u32 = 0 }{.{}};
var g_main_hwnd: ?usize = 1;
var g_chat_transcript_hwnd: ?usize = 2;
var g_chat_composer_hwnd: ?usize = 3;
var g_chat_switch_preparing = false;
var g_edit_hwnd: ?usize = null;
var g_popup_menu_active = false;
var g_search_active = false;
var g_inbox_active = false;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_url_picker_active = false;
var g_all_sessions_active = false;
var g_snippet_create_active = false;
var g_chat_switch_started: u64 = 1000;
var g_chat_switch_painted_ms: u64 = 0;
var g_chat_switch_browser_sid: u32 = 0;
var g_restoring = false;
const TIMER_CHAT_BROWSER_SWAP = 9;
const SW_SHOWNOACTIVATE = 4;
var test_now: u64 = 1000;
var timer_ms: u32 = 0;
var reveals: usize = 0;
var exchanges: usize = 0;
var ready: usize = 0;
var refreshes: usize = 0;
var fallbacks: usize = 0;
fn GetTickCount64() u64 { return test_now; }
fn SetTimer(_: ?usize, _: usize, ms: u32, _: ?*anyopaque) usize { timer_ms = ms; return 1; }
fn KillTimer(_: ?usize, _: usize) bool { timer_ms = 0; return true; }
fn layoutChatControls() void {}
fn ShowWindow(_: ?usize, mode: i32) bool { std.debug.assert(mode == SW_SHOWNOACTIVATE); reveals += 1; return true; }
fn InvalidateRect(_: ?usize, _: ?*anyopaque, _: i32) bool { return true; }
fn debugLog(line: []const u8) void { if (std.mem.startsWith(u8, line, "[switch] paint fallback after")) fallbacks += 1; }
fn parkInactiveBrowserPanes() void {}
fn ecoqosReevaluateAll() void {}
fn wakeBrowserPaneFromFreeze(_: u32) void {}
fn updateBrowserVisibility() void { exchanges += 1; }
fn browserPaneActive() bool { return false; }
fn armBrowserVisibilitySettle(_: u32) void {}
fn saveSession() void {}
fn writePaneSessionFileForShell(_: u32) void {}
fn chatSwitchLogBrowserShown() void {}
fn chatFileOnReady() void { std.debug.assert(g_chat_browser_swap.shell_id == 0); ready += 1; }
fn refreshChatTranscript(_: bool) void { std.debug.assert(g_chat_browser_swap.shell_id == 0); refreshes += 1; }
`;
  const cases = `
test "missing paint releases through the production timer exactly once" {
    g_chat_browser_swap.request(7, 1000);
    test_now = 1299;
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(u32, 1), timer_ms);
    try std.testing.expectEqual(@as(usize, 0), exchanges);
    test_now = 1300;
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(u32, 0), g_chat_browser_swap.shell_id);
    try std.testing.expectEqual(@as(usize, 2), reveals);
    try std.testing.expectEqual(@as(usize, 1), exchanges);
    try std.testing.expectEqual(@as(usize, 1), fallbacks);
    try std.testing.expectEqual(@as(usize, 1), ready);
    try std.testing.expectEqual(@as(usize, 1), refreshes);
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(usize, 1), exchanges);
}
test "every overlay defers even an already painted exchange" {
    const flags = [_]*bool{ &g_search_active, &g_inbox_active, &g_shortcuts_active, &g_changelog_active, &g_url_picker_active, &g_all_sessions_active, &g_snippet_create_active, &g_chat_switch_preparing, &g_popup_menu_active };
    test_now = 2300;
    for (flags) |flag| {
        for ([_]bool{false, true}) |painted| {
            g_chat_browser_swap.request(7, 2000);
            if (painted) _ = g_chat_browser_swap.didPaint(7);
            reveals = 0; exchanges = 0;
            flag.* = true;
            chatSwitchBrowserTick();
            try std.testing.expectEqual(@as(usize, 0), reveals);
            try std.testing.expectEqual(@as(usize, 0), exchanges);
            try std.testing.expectEqual(@as(u32, 7), g_chat_browser_swap.shell_id);
            try std.testing.expectEqual(@as(u32, 300), timer_ms);
            flag.* = false;
            chatSwitchBrowserTick();
            try std.testing.expectEqual(@as(usize, 1), exchanges);
        }
    }
    g_chat_browser_swap.request(7, 2000);
    g_edit_hwnd = 4; reveals = 0; exchanges = 0;
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(usize, 0), reveals);
    try std.testing.expectEqual(@as(usize, 0), exchanges);
    try std.testing.expectEqual(@as(u32, 300), timer_ms);
    g_edit_hwnd = null;
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(usize, 1), exchanges);
}
test "stale timer cannot release a newer target early or a different active shell" {
    reveals = 0; exchanges = 0;
    g_chat_browser_swap.request(7, 3000);
    test_now = 3100;
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(u32, 200), timer_ms);
    try std.testing.expectEqual(@as(usize, 0), exchanges);
    test_now = 3300;
    shells[0].shell_id = 8;
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(usize, 0), reveals);
    try std.testing.expectEqual(@as(usize, 0), exchanges);
    shells[0].shell_id = 7;
    g_chat_active = false;
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(usize, 0), exchanges);
    g_chat_active = true;
    _ = g_chat_browser_swap.didPaint(7);
    chatSwitchBrowserTick();
    try std.testing.expectEqual(@as(usize, 0), reveals);
    try std.testing.expectEqual(@as(usize, 1), exchanges);
}
`;
  try {
    copyZig(['chat_switch.zig'], dir);
    const check = timer => {
      fs.writeFileSync(path.join(dir, 'timer.zig'), prelude + body('chatViewOwnsInput') + '\n' + timer + cases);
      return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'timer.zig')], { encoding: 'utf8', timeout: 120_000 });
    };
    const current = check(body('chatSwitchBrowserTick'));
    assert.equal(current.status, 0, current.stdout + current.stderr);
    const old = `fn chatSwitchBrowserTick() void {
    _ = KillTimer(g_main_hwnd, TIMER_CHAT_BROWSER_SWAP);
    if (!g_chat_active or active_shell >= shell_count or
        !g_chat_browser_swap.take(shells[active_shell].shell_id)) return;
    parkInactiveBrowserPanes();
    ecoqosReevaluateAll();
    if (shells[active_shell].browser_frozen) wakeBrowserPaneFromFreeze(active_shell);
    updateBrowserVisibility();
    if (browserPaneActive()) armBrowserVisibilitySettle(12);
    if (!g_restoring) saveSession();
    if (shells[active_shell].browser_window_id != 0) writePaneSessionFileForShell(active_shell);
    g_chat_switch_browser_sid = shells[active_shell].shell_id;
    chatSwitchLogBrowserShown();
    chatFileOnReady();
    refreshChatTranscript(false);
}`;
    const baseline = check(body('chatSwitchBrowserTick', old));
    assert.notEqual(baseline.status, 0);
    assert.match(baseline.stderr, /missing paint releases through the production timer exactly once[^]*FAIL/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
