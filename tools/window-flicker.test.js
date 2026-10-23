const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();

function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
function optional(name) {
  return source.includes(`fn ${name}(`) ? body(name) : '';
}
function windowPosBranch() {
  const start = source.indexOf('WM_WINDOWPOSCHANGED => {');
  assert.ok(start >= 0, 'WM_WINDOWPOSCHANGED');
  const end = source.indexOf('\n        },', start);
  return source.slice(start, end + '\n        },'.length);
}
function zig(code, filter) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'issue521-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), code);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', filter], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

const prelude = `
const std = @import("std");
const HANDLE = ?*anyopaque;
const DWORD = u32;
const LONG = i32;
const UINT = u32;
const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;
const WINAPI: std.builtin.CallingConvention = .c;
const WM_WINDOWPOSCHANGED: UINT = 0x0047;
const EVENT_SYSTEM_FOREGROUND: DWORD = 3;
const OBJID_WINDOW: LONG = 0;
const SWP_NOSIZE: u32 = 0x0001;
const SWP_NOMOVE: u32 = 0x0002;
const SWP_NOZORDER: u32 = 0x0004;
const SWP_NOACTIVATE: u32 = 0x0010;
const SWP_FRAMECHANGED: u32 = 0x0020;
const SWP_SHOWWINDOW: u32 = 0x0040;
const SWP_HIDEWINDOW: u32 = 0x0080;
const TIMER_CONSOLE_GEOMETRY_SETTLE: usize = 9;
const WINDOWPOS = extern struct { hwnd: HANDLE, hwndInsertAfter: HANDLE, x: i32, y: i32, cx: i32, cy: i32, flags: UINT };
const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
const main_hwnd: HANDLE = @ptrFromInt(0x100);
const pane_hwnd: HANDLE = @ptrFromInt(0x200);
var g_main_hwnd: HANDLE = main_hwnd;
var g_monitor_transition = struct { active: bool = false }{};
var g_console_geometry_settle_ticks: i32 = 0;
var g_pane_ring_state: u8 = 0;
var fg: HANDLE = main_hwnd;
var settle_armed = false;
var full_repaints: usize = 0;
var console_relayouts: usize = 0;
var visibility_updates: usize = 0;
fn GetForegroundWindow() HANDLE { return fg; }
fn foregroundHwndIsOurs(h: HANDLE) bool { return h == main_hwnd or h == pane_hwnd; }
fn foregroundIsOurs() bool { return foregroundHwndIsOurs(fg); }
fn activeBrowserHasForegroundFocus() bool { return fg == pane_hwnd; }
fn activePaneBorderOn() bool { return true; }
fn IsIconic(_: HANDLE) i32 { return 0; }
fn SetTimer(_: HANDLE, id: usize, _: u32, _: ?*anyopaque) usize { if (id == TIMER_CONSOLE_GEOMETRY_SETTLE) settle_armed = true; return 1; }
fn KillTimer(_: HANDLE, id: usize) i32 { if (id == TIMER_CONSOLE_GEOMETRY_SETTLE) settle_armed = false; return 1; }
fn InvalidateRect(h: HANDLE, rc: ?*const RECT, _: i32) i32 { if (h == main_hwnd and rc == null) full_repaints += 1; return 1; }
fn DefWindowProcW(_: HANDLE, _: UINT, _: WPARAM, _: LPARAM) LRESULT { return 0; }
fn noteMainWindowMonitor(_: HANDLE) void {}
fn armMonitorTransitionTimer(_: HANDLE) void {}
fn updateBrowserVisibility() void { visibility_updates += 1; }
fn repositionActive() void { console_relayouts += 1; }
fn syncMainWindowDpi(_: HANDLE, _: u32) bool { return false; }
fn fontSyncMarkAllStale(_: HANDLE, _: []const u8) void {}
fn fontSyncActiveNow() void {}
fn sessionFrontChanged() void {}
fn focusGuardReturnFromPane(_: HANDLE) bool { return false; }
fn syncPaneFocusModeFromForeground(_: HANDLE, _: bool) void {}
fn leftMouseButtonDown() bool { return false; }
fn clearSelectedTabDotOnReturn() void {}
fn activeBrowserTransientPopupHasForegroundFocus() bool { return false; }
fn suspendBrowserEdgeMaskRaiseForPopup() void {}
fn browserTrace(_: []const u8) void {}
fn armBrowserEdgeMaskRaise() void {}
fn hideBrowserEdgeMasks() void {}
fn invalidateBrowserBottomMask() void {}
const active_shell: u32 = 0;
const shell_count: u32 = 1;
const shells = [_]struct { browser_enabled: bool = true }{.{}};
fn windowPosChanged(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) LRESULT {
    switch (msg) {
        ${windowPosBranch()}
        else => return 0,
    }
}
fn sendWindowPos(flags: UINT) void {
    var pos = WINDOWPOS{ .hwnd = main_hwnd, .hwndInsertAfter = null, .x = 0, .y = 0, .cx = 1600, .cy = 900, .flags = flags };
    _ = windowPosChanged(main_hwnd, WM_WINDOWPOSCHANGED, 0, @bitCast(@intFromPtr(&pos)));
}
fn settleTimerFires() void {
    if (!settle_armed) return;
    settleConsoleGeometry(main_hwnd);
    g_console_geometry_settle_ticks -= 1;
    if (g_console_geometry_settle_ticks <= 0) {
        g_console_geometry_settle_ticks = 0;
        settle_armed = false;
    }
}
fn foregroundMovesTo(h: HANDLE) void {
    fg = h;
    foregroundWinEventProc(null, EVENT_SYSTEM_FOREGROUND, h, OBJID_WINDOW, 0, 0, 0);
}
${body('armConsoleGeometrySettle')}
${body('settleConsoleGeometry')}
${body('foregroundWinEventProc').replaceAll('@import("main.zig").', '')}
${optional('windowPosChangeMovesGeometry')}
${optional('paneRingState')}
${optional('paneRingRepaintNeeded')}
`;

test('ISSUE-521 a burst of agent browser windows does not repaint or re-lay out the main window per window', () => {
  zig(prelude + `
test "ISSUE-521 agent window burst" {
    foregroundMovesTo(main_hwnd);
    full_repaints = 0;
    var i: usize = 0;
    while (i < 30) : (i += 1) {
        foregroundMovesTo(@ptrFromInt(0x1000 + i));
        sendWindowPos(SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        settleTimerFires();
    }
    try std.testing.expectEqual(@as(usize, 1), full_repaints);
    try std.testing.expectEqual(@as(usize, 0), console_relayouts);
    foregroundMovesTo(main_hwnd);
    try std.testing.expectEqual(@as(usize, 2), full_repaints);
}
`, 'ISSUE-521 agent window burst');
});

test('ISSUE-521 focus bouncing between an agent window and multiprompt repaints only the focus ring change', () => {
  zig(prelude + `
test "ISSUE-521 focus bounce" {
    foregroundMovesTo(main_hwnd);
    full_repaints = 0;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        foregroundMovesTo(@ptrFromInt(0x1000 + i));
        foregroundMovesTo(main_hwnd);
        sendWindowPos(SWP_NOMOVE | SWP_NOSIZE);
        settleTimerFires();
    }
    try std.testing.expectEqual(@as(usize, 40), full_repaints);
    try std.testing.expectEqual(@as(usize, 0), console_relayouts);
    try std.testing.expectEqual(@as(usize, 20), visibility_updates);
}
`, 'ISSUE-521 focus bounce');
});

test('ISSUE-521 real moves, resizes and show changes still settle the console geometry', () => {
  zig(prelude + `
test "ISSUE-521 geometry still settles" {
    sendWindowPos(SWP_NOSIZE | SWP_NOZORDER);
    settleTimerFires();
    sendWindowPos(SWP_NOMOVE | SWP_NOZORDER);
    settleTimerFires();
    sendWindowPos(SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    settleTimerFires();
    sendWindowPos(SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);
    settleTimerFires();
    try std.testing.expectEqual(@as(usize, 4), console_relayouts);
    try std.testing.expectEqual(@as(usize, 4), full_repaints);
}
`, 'ISSUE-521 geometry still settles');
});
