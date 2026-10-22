const test = require('node:test');
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

function run(code) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'idle-cpu-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, code);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('production placeholder schedules only its actual visible state transition', () => {
  run(`const std = @import("std");
const UINT = u32;
const BrowserPlaceholder = enum { none, opening, not_open, failed };
const BROWSER_PLACEHOLDER_NOT_OPEN_MS = 20_000;
${body('browserPlaceholderDelay')}
test "deadline, pending launch, completed and covered states" {
    try std.testing.expectEqual(@as(?UINT, 20000), browserPlaceholderDelay(.opening, 0, false));
    try std.testing.expectEqual(@as(?UINT, 15234), browserPlaceholderDelay(.opening, 4766, false));
    try std.testing.expectEqual(@as(?UINT, 1), browserPlaceholderDelay(.opening, 20000, false));
    try std.testing.expectEqual(@as(?UINT, 1), browserPlaceholderDelay(.opening, 30000, false));
    try std.testing.expectEqual(@as(?UINT, null), browserPlaceholderDelay(.opening, 0, true));
    try std.testing.expectEqual(@as(?UINT, null), browserPlaceholderDelay(.not_open, 30000, false));
    try std.testing.expectEqual(@as(?UINT, null), browserPlaceholderDelay(.none, 0, false));
    try std.testing.expectEqual(@as(?UINT, null), browserPlaceholderDelay(.failed, 20000, false));
}`);
});

test('production update watcher blocks, rearms before notifying, falls back on failure and stops cleanly', () => {
  run(`const std = @import("std");
const HANDLE = usize;
const WM_APP_UPDATE_CHANGED = 1201;
var waits: []const u32 = &.{};
var at: usize = 0;
var posts: usize = 0;
var fallbacks: usize = 0;
var rearms: usize = 0;
var closes: usize = 0;
var rearm_ok = true;
fn WaitForMultipleObjects(n: u32, handles: [*]const HANDLE, all: i32, timeout: u32) u32 {
    std.debug.assert(n == 2 and handles[0] == 7 and handles[1] == 8);
    std.debug.assert(all == 0 and timeout == 0xFFFFFFFF);
    const value = waits[at]; at += 1; return value;
}
fn FindNextChangeNotification(handle: HANDLE) i32 {
    std.debug.assert(handle == 8); rearms += 1; return @intFromBool(rearm_ok);
}
fn FindCloseChangeNotification(handle: HANDLE) i32 {
    std.debug.assert(handle == 8); closes += 1; return 1;
}
fn PostMessageW(hwnd: HANDLE, msg: u32, wp: usize, lp: isize) i32 {
    std.debug.assert(hwnd == 9 and msg == WM_APP_UPDATE_CHANGED and lp == 0);
    if (wp != 0) { fallbacks += 1; } else { posts += 1; std.debug.assert(rearms >= posts); }
    return 1;
}
${body('updateCardWatchThread')}
test "two changes then shutdown" {
    waits = &.{1, 1, 0};
    updateCardWatchThread(8, 7, 9);
    try std.testing.expectEqual(@as(usize, 2), posts);
    try std.testing.expectEqual(@as(usize, 0), fallbacks);
    try std.testing.expectEqual(@as(usize, 1), closes);
}
test "failed rearm enables timer fallback" {
    at = 0; waits = &.{1}; rearm_ok = false;
    updateCardWatchThread(8, 7, 9);
    try std.testing.expectEqual(@as(usize, 1), fallbacks);
    try std.testing.expectEqual(@as(usize, 2), closes);
}
test "failed wait enables timer fallback" {
    at = 0; waits = &.{0xFFFFFFFF};
    updateCardWatchThread(8, 7, 9);
    try std.testing.expectEqual(@as(usize, 2), fallbacks);
    try std.testing.expectEqual(@as(usize, 3), closes);
}`);
});

test('production mailbox waits through unrelated changes, handles early responses and retains a deadline', () => {
  run(`const std = @import("std");
const HANDLE = ?*anyopaque;
const INVALID_HANDLE_VALUE_PTR: HANDLE = @ptrFromInt(999);
var g_chat_bench_dir: [4]u8 = .{'t', 'e', 's', 't'};
const g_chat_bench_dir_len = 4;
var ready = false;
var consumed = false;
var waits: usize = 0;
var closes: usize = 0;
var rearms: usize = 0;
var timeout = false;
var now: u64 = 100;
fn win32WidePath(out: []u16, _: []const u8) ?[:0]u16 { out[0] = 'x'; out[1] = 0; return out[0..1 :0]; }
fn FindFirstChangeNotificationW(_: [*:0]const u16, _: i32, _: u32) HANDLE { return @ptrFromInt(2); }
fn FindCloseChangeNotification(_: HANDLE) i32 { closes += 1; return 1; }
fn FindNextChangeNotification(_: HANDLE) i32 { rearms += 1; return 1; }
fn writeFileAtomicW(_: []const u8, _: []const u8) bool { return true; }
fn GetTickCount64() u64 { return now; }
fn win32OpenRead(_: []const u8) ?HANDLE { return if (ready) @as(HANDLE, @ptrFromInt(3)) else null; }
fn win32ReadAll(_: HANDLE, out: []u8) usize {
    if (consumed) return 0;
    consumed = true;
    const reply = "@@MP_END@@\\n";
    @memcpy(out[0..reply.len], reply); return reply.len;
}
fn CloseHandle(_: HANDLE) i32 { return 1; }
fn DeleteFileW(_: [*:0]const u16) i32 { return 1; }
fn WaitForSingleObject(_: HANDLE, delay: u32) u32 {
    std.debug.assert(delay > 0 and delay <= 60000);
    waits += 1;
    if (timeout) { now += delay; return 258; }
    if (waits == 2) ready = true;
    return 0;
}
fn Sleep(_: u32) void { @panic("notification path must not poll"); }
${body('chatBenchFetch')}
test "unrelated request notification then matching response" {
    var out: std.ArrayList(u8) = .empty; defer out.deinit(std.heap.page_allocator);
    try std.testing.expect(chatBenchFetch(1, 1, "query", &out));
    try std.testing.expectEqualStrings("@@MP_END@@\\n", out.items);
    try std.testing.expectEqual(@as(usize, 2), waits);
    try std.testing.expectEqual(@as(usize, 2), rearms);
    try std.testing.expectEqual(@as(usize, 1), closes);
}
test "response already exists before first wait" {
    consumed = false; waits = 0;
    var out: std.ArrayList(u8) = .empty; defer out.deinit(std.heap.page_allocator);
    try std.testing.expect(chatBenchFetch(1, 2, "query", &out));
    try std.testing.expectEqual(@as(usize, 0), waits);
    try std.testing.expectEqual(@as(usize, 2), closes);
}
test "missing response times out and closes the subscription" {
    ready = false; timeout = true;
    var out: std.ArrayList(u8) = .empty; defer out.deinit(std.heap.page_allocator);
    try std.testing.expect(!chatBenchFetch(1, 3, "query", &out));
    try std.testing.expectEqual(@as(usize, 1), waits);
    try std.testing.expectEqual(@as(usize, 3), closes);
}`);
});

const popupTypes = source.slice(source.indexOf('const BrowserPopupEvidence = struct {'), source.indexOf('\nfn classifyBrowserPopup('));
test('production foreground polling rejects impossible popups before querying foreign window metadata', () => {
  run(`const std = @import("std");
const HANDLE = ?*anyopaque;
const DWORD = u32;
const LONG_PTR = isize;
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 100, bottom: i32 = 100 };
const GA_ROOT = 2;
const GA_ROOTOWNER = 3;
const GWLP_HWNDPARENT = -8;
const GWL_STYLE = -16;
const GWL_EXSTYLE = -20;
const WS_POPUP: u32 = 0x80000000;
const WS_EX_TOOLWINDOW = 0x80;
var fake_fg_pid: DWORD = 10;
var class_ok = true;
var class_calls: usize = 0;
var metadata_calls: usize = 0;
fn IsWindow(_: HANDLE) i32 { return 1; }
fn GetWindowThreadProcessId(hwnd: HANDLE, pid: *DWORD) DWORD { pid.* = if (@intFromPtr(hwnd) == 1) fake_fg_pid else 10; return 1; }
fn GetClassNameW(_: HANDLE, out: [*]u16, _: i32) i32 { class_calls += 1; out[0] = 'x'; return 1; }
fn u16ContainsU8Insensitive(_: []const u16, _: []const u8) bool { return class_ok; }
fn InternalGetWindowText(_: HANDLE, _: [*]u16, _: i32) i32 { metadata_calls += 1; return 0; }
fn GetWindowRect(_: HANDLE, out: *RECT) i32 { metadata_calls += 1; out.* = .{}; return 1; }
fn GetAncestor(_: HANDLE, _: u32) HANDLE { metadata_calls += 1; return @ptrFromInt(2); }
fn GetWindowLongPtrW(_: HANDLE, _: i32) LONG_PTR { metadata_calls += 1; return 0; }
${popupTypes}
${body('classifyBrowserPopup')}
${body('browserTransientPopupDisposition')}
test "foreign and unavailable PIDs skip all class and metadata reads" {
    for ([_]DWORD{0, 11}) |pid| {
        class_calls = 0; metadata_calls = 0;
        fake_fg_pid = pid;
        try std.testing.expectEqual(BrowserPopupDisposition{}, browserTransientPopupDisposition(@ptrFromInt(1), @ptrFromInt(2)));
        try std.testing.expectEqual(@as(usize, 0), class_calls);
        try std.testing.expectEqual(@as(usize, 0), metadata_calls);
    }
}
test "same-process non-Chromium window skips title, geometry and ownership reads" {
    fake_fg_pid = 10; class_ok = false; class_calls = 0; metadata_calls = 0;
    try std.testing.expectEqual(BrowserPopupDisposition{}, browserTransientPopupDisposition(@ptrFromInt(1), @ptrFromInt(2)));
    try std.testing.expectEqual(@as(usize, 1), class_calls);
    try std.testing.expectEqual(@as(usize, 0), metadata_calls);
}
test "real Chromium owner-linked popup still gets classified" {
    fake_fg_pid = 10; class_ok = true; class_calls = 0; metadata_calls = 0;
    const popup = browserTransientPopupDisposition(@ptrFromInt(1), @ptrFromInt(2));
    try std.testing.expect(popup.owns_pane_foreground and popup.suppress_shell_refocus and popup.suppress_mask_raise);
    try std.testing.expectEqual(@as(usize, 1), class_calls);
    try std.testing.expect(metadata_calls > 0);
}`);
});

test('production theme fallback wakes only for System and follows preference and power changes', () => {
  for (const name of ['saveGlobalTheme', 'loadGlobalTheme', 'applyPowerProfile']) {
    assert.match(body(name), /syncSystemThemeTimer\(/);
  }
  run(`const std = @import("std");
const HANDLE = ?*anyopaque;
const TIMER_SYSTEM_THEME = 25;
const PowerTimerMode = enum { normal, saving, deep_idle };
var g_system_theme = false;
var mode: PowerTimerMode = .normal;
var interval: u32 = 0;
var sets: usize = 0;
var kills: usize = 0;
fn powerModeForTimers() PowerTimerMode { return mode; }
fn KillTimer(hwnd: HANDLE, id: usize) i32 { std.debug.assert(hwnd == @as(HANDLE, @ptrFromInt(7)) and id == 25); interval = 0; kills += 1; return 1; }
fn setCoalescableTimerInterval(hwnd: HANDLE, id: usize, ms: u32) void { std.debug.assert(hwnd == @as(HANDLE, @ptrFromInt(7)) and id == 25); interval = ms; sets += 1; }
${body('syncSystemThemeTimer')}
test "fixed themes have no fallback in any power mode" {
    for ([_]PowerTimerMode{.normal, .saving, .deep_idle}) |m| { mode = m; syncSystemThemeTimer(@ptrFromInt(7)); }
    try std.testing.expectEqual(@as(usize, 0), sets);
    try std.testing.expectEqual(@as(usize, 3), kills);
    try std.testing.expectEqual(@as(u32, 0), interval);
}
test "System retains its original fallback latency and stops on deep idle or fixed theme" {
    g_system_theme = true; mode = .normal; syncSystemThemeTimer(@ptrFromInt(7));
    try std.testing.expectEqual(@as(u32, 1000), interval);
    mode = .saving; syncSystemThemeTimer(@ptrFromInt(7));
    try std.testing.expectEqual(@as(u32, 10000), interval);
    mode = .deep_idle; syncSystemThemeTimer(@ptrFromInt(7));
    try std.testing.expectEqual(@as(u32, 0), interval);
    mode = .normal; syncSystemThemeTimer(@ptrFromInt(7));
    try std.testing.expectEqual(@as(u32, 1000), interval);
    g_system_theme = false; syncSystemThemeTimer(@ptrFromInt(7));
    try std.testing.expectEqual(@as(u32, 0), interval);
}
test "startup before HWND creation does not schedule a thread timer" {
    const old_sets = sets; const old_kills = kills;
    g_system_theme = true; syncSystemThemeTimer(null);
    try std.testing.expectEqual(old_sets, sets);
    try std.testing.expectEqual(old_kills, kills);
}`);
});

test('production orphan cleanup coalesces destroy events, preserves fallback deadlines and releases hooks', () => {
  assert.match(body('browserHealthTick'), /sweepBrowserOrphans\(now\)/);
  assert.match(body('updateBrowserVisibility'), /sweepBrowserOrphans\(GetTickCount64\(\)\)/);
  run(`const std = @import("std");
const WINAPI: std.builtin.CallingConvention = .c;
const HANDLE = ?*anyopaque;
const DWORD = u32;
const LONG = i32;
const UINT = u32;
const EVENT_OBJECT_DESTROY: DWORD = 0x8001;
const EVENT_SYSTEM_FOREGROUND: DWORD = 3;
const OBJID_WINDOW: LONG = 0;
const WINEVENT_OUTOFCONTEXT: UINT = 0;
var g_foreground_hook: HANDLE = null;
var g_browser_orphan_hook: HANDLE = null;
var g_browser_orphan_dirty = true;
var g_browser_orphan_sweep_tick: u64 = 0;
var g_app_closing = false;
var sweeps: usize = 0;
var hooks: usize = 0;
var unhooks: usize = 0;
var fail_orphan_hook = false;
fn SetWinEventHook(first: DWORD, last: DWORD, _: HANDLE, callback: anytype, process: DWORD, thread: DWORD, flags: UINT) HANDLE {
    _ = callback;
    std.debug.assert(first == last and process == 0 and thread == 0 and flags == 0);
    hooks += 1;
    if (first == EVENT_OBJECT_DESTROY) return if (fail_orphan_hook) null else @ptrFromInt(7);
    std.debug.assert(first == EVENT_SYSTEM_FOREGROUND); return @ptrFromInt(8);
}
fn UnhookWinEvent(handle: HANDLE) i32 { std.debug.assert(handle != null); unhooks += 1; return 1; }
fn foregroundWinEventProc(_: HANDLE, _: DWORD, _: HANDLE, _: LONG, _: LONG, _: DWORD, _: DWORD) callconv(WINAPI) void {}
fn enumCloseOrphanPane() void {}
fn EnumWindows(callback: anytype, lp: isize) i32 { _ = callback; std.debug.assert(lp == 0); sweeps += 1; return 1; }
fn debugLog(_: []const u8) void {}
fn browserTrace(_: []const u8) void {}
${body('browserOrphanWinEventProc')}
${body('installForegroundHook')}
${body('uninstallForegroundHook')}
${body('sweepBrowserOrphans')}
test "idle notifications do no repeated scans and window deletes coalesce" {
    installForegroundHook();
    defer uninstallForegroundHook();
    try std.testing.expectEqual(@as(usize, 2), hooks);
    sweepBrowserOrphans(100);
    try std.testing.expectEqual(@as(usize, 1), sweeps);
    sweepBrowserOrphans(10000);
    try std.testing.expectEqual(@as(usize, 1), sweeps);
    browserOrphanWinEventProc(null, 3, null, 0, 0, 0, 0);
    browserOrphanWinEventProc(null, EVENT_OBJECT_DESTROY, null, 1, 0, 0, 0);
    browserOrphanWinEventProc(null, EVENT_OBJECT_DESTROY, null, 0, 1, 0, 0);
    try std.testing.expect(!g_browser_orphan_dirty);
    for (0..3) |_| browserOrphanWinEventProc(null, EVENT_OBJECT_DESTROY, null, 0, 0, 0, 0);
    sweepBrowserOrphans(10001);
    sweepBrowserOrphans(12001);
    try std.testing.expectEqual(@as(usize, 2), sweeps);
    uninstallForegroundHook();
    try std.testing.expectEqual(@as(usize, 2), unhooks);
    try std.testing.expect(g_browser_orphan_hook == null and g_foreground_hook == null and !g_browser_orphan_dirty);
}
test "failed registration retains the original two-second polling fallback" {
    fail_orphan_hook = true; sweeps = 0; g_browser_orphan_sweep_tick = 0;
    installForegroundHook();
    defer uninstallForegroundHook();
    try std.testing.expect(g_browser_orphan_hook == null);
    sweepBrowserOrphans(100);
    sweepBrowserOrphans(2099);
    try std.testing.expectEqual(@as(usize, 1), sweeps);
    sweepBrowserOrphans(2100);
    try std.testing.expectEqual(@as(usize, 2), sweeps);
    g_app_closing = true;
    browserOrphanWinEventProc(null, EVENT_OBJECT_DESTROY, null, 0, 0, 0, 0);
    try std.testing.expect(!g_browser_orphan_dirty);
    uninstallForegroundHook();
}`);
});
