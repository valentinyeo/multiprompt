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
var alt_down = false;
var ctrl_down = false;
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
    const down = if (key == VK_MENU) alt_down else if (key == 0x11) ctrl_down else false;
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
    alt_down = alt;
    ctrl_down = ctrl;
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
        try std.testing.expect(alt_down);
        try std.testing.expectEqual(ctrl, ctrl_down);
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
        try std.testing.expect(!alt_down);
        try std.testing.expectEqual(ctrl, ctrl_down);
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
