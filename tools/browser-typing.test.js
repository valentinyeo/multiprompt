const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../src/focus.zig'), 'utf8');

function productionFunction(name) {
  const start = source.indexOf(`pub fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, `${name} must have a body`);
  return source.slice(start, end + 2);
}

test('shell handoff while Alt is held preserves the real modifier', () => {
  const start = source.indexOf('        if (phys_alt) {', source.indexOf('fn focusActiveShellInner('));
  const end = source.indexOf('        if (isCtrlDown())', start);
  assert.ok(start >= 0 && end > start);
  const branch = source.slice(start, end);
  const fixture = `
const std = @import("std");
const VK_MENU: u8 = 0x12;
var alt_down = true;
var ctrl_down = false;
var injections: usize = 0;
var requested = false;
const app_state = struct {
    var g_main_hwnd: usize = 1;
    var g_ws_switch_focus_grace: u64 = 0;
    var g_refocus_waiting_for_alt_release = false;
};
fn keybd_event(_: u8, _: u8, _: u32, _: usize) void { injections += 1; }
fn SetForegroundWindow(_: usize) i32 { return 1; }
fn SetFocus(_: usize) usize { return 1; }
fn GetTickCount64() u64 { return 100; }
fn requestShellRefocus(delay: u32, retries: u32) void { requested = delay == 80 and retries == 40; }
fn handoff(phys_alt: bool) void {
${branch}
}
test "held Alt and AltGr are not injected or released" {
    for ([_]bool{ false, true }) |ctrl| {
        alt_down = true;
        ctrl_down = ctrl;
        injections = 0;
        requested = false;
        handoff(alt_down);
        try std.testing.expectEqual(@as(usize, 0), injections);
        try std.testing.expect(alt_down);
        try std.testing.expectEqual(ctrl, ctrl_down);
        try std.testing.expect(requested);
        try std.testing.expect(app_state.g_refocus_waiting_for_alt_release);
    }
}
`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'shell-modifiers-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout || ''}\n${result.stderr || ''}`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('URL focus waits for modifiers and cancels stale handoffs', () => {
  const browser = fs.readFileSync(path.join(__dirname, '../src/browser_pane.zig'), 'utf8');
  const start = browser.indexOf('var url_focus_edit:');
  const end = browser.indexOf('\npub fn startBrowserUrlBarEdit()', start);
  assert.ok(start >= 0 && end > start);
  const production = browser.slice(start, end)
    .replaceAll('@import("win32.zig").TIMER_BROWSER_URL_FOCUS', 'timer_id')
    .replaceAll('@import("focus.zig").focusGuardReadMouse()', 'focusGuardReadMouse()');
  const fixture = `
const std = @import("std");
const HANDLE = ?*anyopaque;
const timer_id: usize = 45;
const main: HANDLE = @ptrFromInt(1);
const console: HANDLE = @ptrFromInt(2);
const parent: HANDLE = @ptrFromInt(3);
const edit: HANDLE = @ptrFromInt(4);
const foreign: HANDLE = @ptrFromInt(5);
var foreground: HANDLE = console;
var focused: HANDLE = null;
var held: i32 = 0;
var now: u64 = 100;
var owned = true;
var foreground_attempts: usize = 0;
var switch_count: usize = 0;
var interrupt: u8 = 0;
var killed: usize = 0;
const app_state = struct {
    var g_main_hwnd: HANDLE = main;
    var g_edit_hwnd: HANDLE = edit;
    var g_edit_is_browser_urlbar = true;
    var g_focus_authorized_hwnd: HANDLE = parent;
    var g_focus_authorized_until: u64 = 1000;
    var g_focus_input_tick: u64 = 10;
    var active_shell: usize = 0;
    var shell_count: usize = 1;
    var shells = [_]struct { shell_id: u32 }{.{ .shell_id = 7 }};
};
fn KillTimer(_: HANDLE, _: usize) i32 { killed += 1; return 1; }
fn focusGuardReadMouse() void {}
fn IsWindow(h: HANDLE) i32 { return if (h != null) 1 else 0; }
fn GetTickCount64() u64 { return now; }
fn foregroundIsOurs() bool { return owned; }
fn GetAsyncKeyState(key: i32) i16 { return if (key == held) -32768 else 0; }
fn focusGuard(_: HANDLE) bool { return true; }
fn GetForegroundWindow() HANDLE { return foreground; }
fn GetFocus() HANDLE { return focused; }
fn SetForegroundWindow(_: HANDLE) i32 {
    foreground_attempts += 1;
    if (interrupt == 1) { foreground = foreign; owned = false; }
    if (interrupt == 2) app_state.g_focus_input_tick = 11;
    return 0;
}
fn SwitchToThisWindow(h: HANDLE, _: i32) void { switch_count += 1; foreground = h; }
fn SetFocus(h: HANDLE) HANDLE { const previous = focused; focused = h; return previous; }

${production}
fn reset() void {
    url_focus_edit = edit;
    url_focus_parent = parent;
    url_focus_deadline = 1000;
    url_focus_input_tick = 10;
    url_focus_shell_id = 7;
    app_state.g_edit_hwnd = edit;
    app_state.g_edit_is_browser_urlbar = true;
    app_state.g_focus_authorized_hwnd = parent;
    app_state.g_focus_authorized_until = 1000;
    app_state.g_focus_input_tick = 10;
    foreground = console;
    focused = null;
    held = 0;
    now = 100;
    owned = true;
    foreground_attempts = 0;
    switch_count = 0;
    interrupt = 0;
    killed = 0;
}
test "held modifiers defer; release focuses after foreground refusal" {
    for ([_]i32{ 0x10, 0x11, 0x12, 0x5B, 0x5C }) |key| {
        reset(); held = key;
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 0), foreground_attempts);
        try std.testing.expectEqual(@as(usize, 0), switch_count);
        try std.testing.expectEqual(console, foreground);
        held = 0;
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 1), foreground_attempts);
        try std.testing.expectEqual(@as(usize, 1), switch_count);
        try std.testing.expectEqual(parent, foreground);
        try std.testing.expectEqual(edit, focused);
        try std.testing.expectEqual(@as(usize, 1), killed);
    }
}
test "intervening foreign focus or input blocks the fallback" {
    for ([_]u8{ 1, 2 }) |cause| {
        reset();
        interrupt = cause;
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 1), foreground_attempts);
        try std.testing.expectEqual(@as(usize, 0), switch_count);
        try std.testing.expectEqual(@as(HANDLE, null), focused);
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 1), killed);
    }
}
test "foreign foreground, newer input, expired request and destroyed edit cancel" {
    for (0..4) |case| {
        reset();
        switch (case) {
            0 => owned = false,
            1 => app_state.g_focus_input_tick = 11,
            2 => now = 1000,
            3 => app_state.g_edit_hwnd = null,
            else => unreachable,
        }
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 0), foreground_attempts);
        try std.testing.expectEqual(@as(usize, 0), switch_count);
        try std.testing.expectEqual(@as(usize, 1), killed);
        try std.testing.expectEqual(console, foreground);
    }
}
`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'url-focus-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout || ''}\n${result.stderr || ''}`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('browser focus preserves physical modifiers and never injects keyboard input', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-typing-'));
  try {
    const production = [
      'browserPageFocusCommand',
      'unlockBrowserForeground',
      'focusActiveBrowserPane',
      'focusActiveBrowserPaneUnlocked',
    ].map(productionFunction).join('\n').replaceAll('@import("win32.zig")', 'win32');
    const fixture = `
const std = @import("std");
const HANDLE = ?*anyopaque;
const WPARAM = usize;
const VK_MENU: u8 = 0x12;
const KEYEVENTF_KEYUP: u32 = 2;
const win32 = struct { const WM_COMMAND: u32 = 0x111; };
const pane: HANDLE = @ptrFromInt(1);
const main_window: HANDLE = @ptrFromInt(2);
var foreground: HANDLE = main_window;
var focused: HANDLE = main_window;
var simulated_alt_down = false;
var simulated_ctrl_down = false;
var injections: usize = 0;
var focus_changes: usize = 0;
var posted: usize = 0;
var posted_command: WPARAM = 0;
const app_state = struct {
    var g_native_browser_alt_unlocked_at: u64 = 0;
    var g_main_hwnd: HANDLE = main_window;
    var g_chat_active = false;
    var g_browser_focus_mode = false;
    var g_shell_focused = true;
    var g_chat_browser_handoff_until: u64 = 0;
};
fn GetAsyncKeyState(key: i32) i16 {
    const down = if (key == VK_MENU) simulated_alt_down else if (key == 0x11) simulated_ctrl_down else false;
    return if (down) @bitCast(@as(u16, 0x8000)) else 0;
}
fn keybd_event(_: u8, _: u8, _: u32, _: usize) void { injections += 1; }
fn GetTickCount64() u64 { return 100; }
fn activeBrowserHasForegroundFocus() bool { return foreground == pane; }
fn activeBrowserHwndLive() HANDLE { return pane; }
fn focusGuard(_: HANDLE) bool { return true; }
fn altqLog(_: []const u8, _: anytype) void {}
fn altqPtr(hwnd: HANDLE) usize { return if (hwnd) |h| @intFromPtr(h) else 0; }
fn cancelShellRefocus(_: HANDLE) void {}
fn GetForegroundWindow() HANDLE { return foreground; }
fn GetWindowThreadProcessId(hwnd: HANDLE, _: ?*u32) u32 { return if (hwnd == pane) 2 else 3; }
fn GetCurrentThreadId() u32 { return 1; }
fn AttachThreadInput(_: u32, _: u32, _: i32) i32 { return 1; }
fn SetForegroundWindow(hwnd: HANDLE) i32 { foreground = hwnd; focus_changes += 1; return 1; }
fn SetFocus(hwnd: HANDLE) HANDLE { const old = focused; focused = hwnd; focus_changes += 1; return old; }
fn PostMessageW(hwnd: HANDLE, msg: u32, command: WPARAM, _: isize) i32 {
    if (hwnd == pane and msg == win32.WM_COMMAND) { posted += 1; posted_command = command; }
    return 1;
}
fn armBrowserEdgeMaskRaise() void {}
fn InvalidateRect(_: HANDLE, _: ?*anyopaque, _: i32) i32 { return 1; }
${production}
fn reset(alt: bool, ctrl: bool) void {
    foreground = main_window;
    focused = main_window;
    simulated_alt_down = alt;
    simulated_ctrl_down = ctrl;
    injections = 0;
    focus_changes = 0;
    posted = 0;
    posted_command = 0;
}
test "held Alt and AltGr keep focus and keys unchanged" {
    for ([_]bool{ false, true }) |ctrl| {
        reset(true, ctrl);
        focusActiveBrowserPane();
        try std.testing.expectEqual(main_window, foreground);
        try std.testing.expectEqual(main_window, focused);
        try std.testing.expectEqual(@as(usize, 0), focus_changes);
        try std.testing.expectEqual(@as(usize, 0), posted);
        try std.testing.expectEqual(@as(usize, 0), injections);
        try std.testing.expect(simulated_alt_down);
        try std.testing.expectEqual(ctrl, simulated_ctrl_down);
    }
}
test "plain and held Ctrl focus the browser without keyboard injection" {
    for ([_]bool{ false, true }) |ctrl| {
        reset(false, ctrl);
        focusActiveBrowserPane();
        try std.testing.expectEqual(pane, foreground);
        try std.testing.expectEqual(pane, focused);
        try std.testing.expectEqual(@as(usize, 1), posted);
        try std.testing.expectEqual(@as(WPARAM, 39009), posted_command);
        try std.testing.expectEqual(@as(usize, 0), injections);
        try std.testing.expect(!simulated_alt_down);
        try std.testing.expectEqual(ctrl, simulated_ctrl_down);
    }
}
`;
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout || ''}\n${result.stderr || ''}`);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
