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

test('queued URL dismissal only closes its originating editor', () => {
  const root = path.join(__dirname, '..');
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const rename = fs.readFileSync(path.join(root, 'src/rename.zig'), 'utf8');
  const start = main.indexOf('        WM_APP_URLBAR_DISMISS => {');
  const end = main.indexOf('        WM_APP_BROWSER_FOCUS_URL => {', start);
  const postStart = rename.indexOf('    if (msg == WM_KILLFOCUS and app_state.g_edit_is_browser_urlbar');
  const postEnd = rename.indexOf('    if (msg == WM_KEYDOWN)', postStart);
  assert.ok(start >= 0 && end > start && postStart >= 0 && postEnd > postStart);
  const handler = main.slice(start, end);
  const sender = rename.slice(postStart, postEnd);
  const fixture = `
const std = @import("std");
const HANDLE = ?*anyopaque;
const WM_KILLFOCUS: u32 = 8;
const WM_APP_URLBAR_DISMISS: u32 = 1;
const old_edit: HANDLE = @ptrFromInt(1);
const new_edit: HANDLE = @ptrFromInt(2);
const main_window: HANDLE = @ptrFromInt(3);
var posted_wp: usize = 0;
var focused: HANDLE = null;
var discarded: usize = 0;
var visibility_updates: usize = 0;
const app_state = struct {
    var g_main_hwnd: HANDLE = main_window;
    var g_edit_hwnd: HANDLE = old_edit;
    var g_edit_is_browser_urlbar = true;
};
fn PostMessageW(_: HANDLE, _: u32, wp: usize, _: isize) i32 { posted_wp = wp; return 1; }
fn GetFocus() HANDLE { return focused; }
fn discardBrowserUrlBarEdit() void { discarded += 1; app_state.g_edit_hwnd = null; }
fn updateBrowserVisibility() void { visibility_updates += 1; }
fn altqLog(_: []const u8, _: anytype) void {}
fn altqPtr(h: HANDLE) usize { return if (h) |value| @intFromPtr(value) else 0; }
fn GetForegroundWindow() HANDLE { return main_window; }
fn postKill(hwnd: HANDLE, msg: u32) void {
${sender}
}
fn dispatch(wp: usize) isize {
    switch (@as(u32, WM_APP_URLBAR_DISMISS)) {
${handler}
        else => return 1,
    }
}
test "old queued dismissal cannot discard the new unfocused editor" {
    postKill(old_edit, WM_KILLFOCUS);
    try std.testing.expectEqual(@intFromPtr(old_edit), posted_wp);
    app_state.g_edit_hwnd = new_edit;
    _ = dispatch(posted_wp);
    try std.testing.expectEqual(new_edit, app_state.g_edit_hwnd);
    try std.testing.expectEqual(@as(usize, 0), discarded);
    try std.testing.expectEqual(@as(usize, 0), visibility_updates);
    postKill(new_edit, WM_KILLFOCUS);
    focused = new_edit;
    _ = dispatch(posted_wp);
    try std.testing.expectEqual(new_edit, app_state.g_edit_hwnd);
    focused = null;
    _ = dispatch(posted_wp);
    try std.testing.expectEqual(@as(HANDLE, null), app_state.g_edit_hwnd);
    try std.testing.expectEqual(@as(usize, 1), discarded);
    try std.testing.expectEqual(@as(usize, 1), visibility_updates);
}
`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'url-dismiss-'));
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
  const discardStart = browser.indexOf('pub fn discardBrowserUrlBarEdit()');
  const discardEnd = browser.indexOf('\nfn suspendBrowserForShell(', discardStart);
  assert.ok(discardStart >= 0 && discardEnd > discardStart);
  const production = (browser.slice(discardStart, discardEnd) + '\n' + browser.slice(start, end))
    .replaceAll('@import("win32.zig").TIMER_BROWSER_URL_FOCUS', 'timer_id')
    .replaceAll('@import("focus.zig").focusGuardReadMouse()', 'focusGuardReadMouse()')
    .replaceAll('@import("computer_pane.zig").selected()', 'computerSelected()')
    .replaceAll('@import("computer_pane.zig").sync()', 'computerSync()')
    .replaceAll('@import("room_frontend.zig").privateActionsAllowed()', 'privateActionsAllowed()');
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
var computer_selected = false;
var private_allowed = true;
var guard_allowed = true;
var destroyed: HANDLE = null;
var sync_count: usize = 0;
var foreground_attempts: usize = 0;
var switch_count: usize = 0;
var interrupt: u8 = 0;
var killed: usize = 0;
const app_state = struct {
    var g_main_hwnd: HANDLE = main;
    var g_account_locked = false;
    var g_edit_hwnd: HANDLE = edit;
    var g_edit_is_browser_urlbar = true;
    var g_edit_sync_remote_name = false;
    var g_urlbar_hwnd: HANDLE = parent;
    var g_focus_authorized_hwnd: HANDLE = parent;
    var g_focus_authorized_until: u64 = 1000;
    var g_focus_input_tick: u64 = 10;
    var active_shell: usize = 0;
    var shell_count: usize = 1;
    var shells = [_]struct { shell_id: u32 }{.{ .shell_id = 7 }};
};
fn KillTimer(_: HANDLE, _: usize) i32 { killed += 1; return 1; }
fn altqLog(_: []const u8, _: anytype) void {}
fn altqPtr(h: HANDLE) usize { return if (h) |value| @intFromPtr(value) else 0; }
fn DestroyWindow(hwnd: HANDLE) i32 { destroyed = hwnd; return 1; }
fn InvalidateRect(_: HANDLE, _: ?*anyopaque, _: i32) i32 { return 1; }
fn computerSelected() bool { return computer_selected; }
fn computerSync() void { sync_count += 1; }
fn privateActionsAllowed() bool { return private_allowed; }
fn focusGuardReadMouse() void {}
fn IsWindow(h: HANDLE) i32 { return if (h != null) 1 else 0; }
fn GetTickCount64() u64 { return now; }
fn foregroundIsOurs() bool { return owned; }
fn GetAsyncKeyState(key: i32) i16 { return if (key == held) -32768 else 0; }
fn focusGuard(_: HANDLE) bool { return guard_allowed; }
fn GetForegroundWindow() HANDLE { return foreground; }
fn GetFocus() HANDLE { return focused; }
fn SetForegroundWindow(_: HANDLE) i32 {
    foreground_attempts += 1;
    if (interrupt == 1) { foreground = foreign; owned = false; }
    if (interrupt == 2) app_state.g_focus_input_tick = 11;
    if (interrupt == 3) app_state.g_account_locked = true;
    return 0;
}
fn SwitchToThisWindow(h: HANDLE, _: i32) void {
    switch_count += 1;
    foreground = h;
    if (interrupt == 4) app_state.g_account_locked = true;
}
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
    app_state.g_account_locked = false;
    app_state.g_focus_authorized_hwnd = parent;
    app_state.g_focus_authorized_until = 1000;
    app_state.g_focus_input_tick = 10;
    foreground = console;
    focused = null;
    held = 0;
    now = 100;
    owned = true;
    computer_selected = false;
    private_allowed = true;
    guard_allowed = true;
    destroyed = null;
    sync_count = 0;
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
        try std.testing.expectEqual(edit, app_state.g_edit_hwnd);
        try std.testing.expectEqual(@as(HANDLE, null), destroyed);
        try std.testing.expectEqual(@as(usize, 1), killed);
    }
}
test "intervening foreign focus, input or account lock blocks the handoff" {
    for ([_]u8{ 1, 2, 3, 4 }) |cause| {
        reset();
        interrupt = cause;
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 1), foreground_attempts);
        try std.testing.expectEqual(@as(usize, if (cause == 4) 1 else 0), switch_count);
        try std.testing.expectEqual(@as(HANDLE, null), focused);
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 1), killed);
    }
}
test "invalid requests discard only their own pending editor" {
    for (0..11) |case| {
        reset();
        switch (case) {
            0 => owned = false,
            1 => app_state.g_focus_input_tick = 11,
            2 => now = 1000,
            3 => app_state.g_edit_hwnd = null,
            4 => computer_selected = true,
            5 => private_allowed = false,
            6 => guard_allowed = false,
            7 => app_state.g_edit_hwnd = foreign,
            8 => { now = 1001; held = 0x10; },
            9 => app_state.g_account_locked = true,
            10 => { computer_selected = true; app_state.g_edit_hwnd = foreign; },
            else => unreachable,
        }
        browserUrlFocusTick();
        try std.testing.expectEqual(@as(usize, 0), foreground_attempts);
        try std.testing.expectEqual(@as(usize, 0), switch_count);
        try std.testing.expectEqual(@as(usize, 1), killed);
        try std.testing.expectEqual(console, foreground);
        try std.testing.expectEqual(@as(usize, if (case == 4) 1 else 0), sync_count);
        if (case == 3 or case == 7 or case == 10) {
            try std.testing.expectEqual(@as(HANDLE, null), destroyed);
            try std.testing.expectEqual(if (case == 7 or case == 10) foreign else null, app_state.g_edit_hwnd);
        } else {
            try std.testing.expectEqual(edit, destroyed);
            try std.testing.expectEqual(@as(HANDLE, null), app_state.g_edit_hwnd);
            try std.testing.expect(!app_state.g_edit_is_browser_urlbar);
        }
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
const foreign_window: HANDLE = @ptrFromInt(3);
var foreground: HANDLE = main_window;
var focused: HANDLE = main_window;
var simulated_alt_down = false;
var simulated_ctrl_down = false;
var other_held: i32 = 0;
var refuse_foreground = false;
var foreign_on_attempt = false;
var switch_count: usize = 0;
var attachments: usize = 0;
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
    const down = if (key == VK_MENU) simulated_alt_down else if (key == 0x11) simulated_ctrl_down else key == other_held;
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
fn AttachThreadInput(_: u32, _: u32, attach: i32) i32 {
    if (attach != 0) attachments += 1 else attachments -= 1;
    return 1;
}
fn foregroundIsOurs() bool { return foreground != foreign_window; }
fn SetForegroundWindow(hwnd: HANDLE) i32 {
    if (foreign_on_attempt) foreground = foreign_window;
    if (refuse_foreground) return 0;
    foreground = hwnd; focus_changes += 1; return 1;
}
fn SwitchToThisWindow(hwnd: HANDLE, _: i32) void {
    std.debug.assert(attachments == 0);
    switch_count += 1;
    foreground = hwnd;
}
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
    other_held = 0;
    refuse_foreground = false;
    foreign_on_attempt = false;
    switch_count = 0;
    attachments = 0;
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
test "foreground refusal falls back after detach and focuses page" {
    reset(false, false);
    refuse_foreground = true;
    focusActiveBrowserPane();
    try std.testing.expectEqual(pane, foreground);
    try std.testing.expectEqual(@as(usize, 1), switch_count);
    try std.testing.expectEqual(@as(usize, 1), posted);
    try std.testing.expectEqual(@as(WPARAM, 39009), posted_command);
    try std.testing.expectEqual(@as(usize, 0), injections);
}
test "held modifiers block the fallback without fake keys" {
    for ([_]i32{ 0x10, 0x11, 0x12, 0x5B, 0x5C }) |key| {
        reset(key == 0x12, key == 0x11);
        if (key != 0x12 and key != 0x11) other_held = key;
        refuse_foreground = true;
        focusActiveBrowserPane();
        try std.testing.expectEqual(main_window, foreground);
        try std.testing.expectEqual(@as(usize, 0), switch_count);
        try std.testing.expectEqual(@as(usize, 0), posted);
        try std.testing.expectEqual(@as(usize, 0), injections);
        try std.testing.expect(GetAsyncKeyState(key) < 0);
    }
}
test "foreign foreground blocks the fallback" {
    reset(false, false);
    refuse_foreground = true;
    foreign_on_attempt = true;
    focusActiveBrowserPane();
    try std.testing.expectEqual(foreign_window, foreground);
    try std.testing.expectEqual(@as(usize, 0), switch_count);
    try std.testing.expectEqual(@as(usize, 0), posted);
    try std.testing.expectEqual(@as(usize, 0), injections);
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
