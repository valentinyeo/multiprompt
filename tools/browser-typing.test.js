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

test('browser input returns to the shell without key injection or queue attachment', () => {
  const production = productionFunction('focusActiveShellFromBrowserInput')
    .replaceAll('@import("computer_pane.zig").selected()', 'computerSelected()')
    .replaceAll('@import("room_frontend.zig").privateActionsAllowed()', 'privateActionsAllowed()');
  const rename = fs.readFileSync(path.join(__dirname, '../src/rename.zig'), 'utf8');
  const cancelMarker = '            if (was_browser_urlbar) {';
  const cancelStart = rename.indexOf(cancelMarker);
  const cancelEnd = rename.indexOf('\n            } else if (was_inbox)', cancelStart);
  const commitStart = rename.indexOf('    if (app_state.g_edit_is_browser_urlbar) {', rename.indexOf('pub fn commitRename('));
  const commitTail = rename.indexOf('        app_state.g_shell_focused = true;', commitStart);
  const commitEnd = rename.indexOf('\n        return;', commitTail);
  assert.ok(cancelStart >= 0 && cancelEnd > cancelStart && commitStart >= 0 && commitTail > commitStart && commitEnd > commitTail);
  const cancel = rename.slice(cancelStart + cancelMarker.length, cancelEnd);
  const commit = rename.slice(commitTail, commitEnd);
  const fixture = `
const std = @import("std");
const HANDLE = ?*anyopaque;
const frame: HANDLE = @ptrFromInt(1);
const console_window: HANDLE = @ptrFromInt(2);
const composer: HANDLE = @ptrFromInt(3);
const pane: HANDLE = @ptrFromInt(4);
var foreground: HANDLE = pane;
var focused: HANDLE = null;
var owned = true;
var accepted = true;
var guard_allowed = true;
var chat_owns = true;
var alt_held = true;
var ctrl_held = true;
var attachments: usize = 0;
var injections: usize = 0;
var activation_calls: usize = 0;
var focus_calls: usize = 0;
const app_state = struct {
    var g_account_locked = false;
    var g_inbox_active = false;
    var g_all_sessions_active = false;
    var g_chat_active = false;
    var g_main_hwnd: HANDLE = frame;
    var g_urlbar_hwnd: HANDLE = frame;
    var g_shell_focused = false;
    var g_chat_composer_hwnd: HANDLE = composer;
};
fn computerSelected() bool { return false; }
fn privateActionsAllowed() bool { return true; }
fn foregroundIsOurs() bool { return owned; }
fn chatViewOwnsInput() bool { return chat_owns; }
fn activeShellHwndForFocusGuard() HANDLE { return console_window; }
fn IsWindow(h: HANDLE) i32 { return if (h != null) 1 else 0; }
fn focusGuard(_: HANDLE) bool { return guard_allowed; }
fn GetForegroundWindow() HANDLE { return foreground; }
fn SetForegroundWindow(h: HANDLE) i32 {
    activation_calls += 1;
    if (accepted) foreground = h;
    return if (accepted) 1 else 0;
}
fn SetFocus(h: HANDLE) HANDLE { focus_calls += 1; focused = h; return null; }
fn AttachThreadInput(_: u32, _: u32, _: i32) i32 { attachments += 1; return 1; }
fn keybd_event(_: u8, _: u8, _: u32, _: usize) void { injections += 1; }
fn InvalidateRect(_: HANDLE, _: ?*anyopaque, _: i32) i32 { return 1; }
fn focusActiveShell() void { injections += 2; foreground = console_window; focused = console_window; }
fn activeShellHasForegroundFocus() bool { return foreground == console_window; }
fn requestShellRefocus(_: u32, _: u32) void { injections += 2; }
${production}
fn cancelBrowserEdit() void { ${cancel} }
fn commitBrowserEdit() void { ${commit} }
fn reset() void {
    foreground = pane; focused = null; owned = true; accepted = true; guard_allowed = true;
    app_state.g_chat_active = false; app_state.g_account_locked = false; app_state.g_shell_focused = false;
    attachments = 0; injections = 0; activation_calls = 0; focus_calls = 0;
    alt_held = true; ctrl_held = true; chat_owns = true;
}
test "address Escape and Enter return through the non-injecting input path" {
    for ([_]*const fn () void{ &cancelBrowserEdit, &commitBrowserEdit }) |finish| {
        reset(); foreground = frame;
        finish();
        try std.testing.expectEqual(console_window, foreground);
        try std.testing.expectEqual(console_window, focused);
        try std.testing.expect(app_state.g_shell_focused);
        try std.testing.expectEqual(@as(usize, 0), attachments);
        try std.testing.expectEqual(@as(usize, 0), injections);
    }
}
test "held modifiers survive direct console and composer activation" {
    for ([_]bool{ false, true }) |chat| {
        reset(); app_state.g_chat_active = chat;
        focusActiveShellFromBrowserInput();
        try std.testing.expectEqual(if (chat) frame else console_window, foreground);
        try std.testing.expectEqual(if (chat) composer else console_window, focused);
        try std.testing.expectEqual(@as(usize, 0), attachments);
        try std.testing.expectEqual(@as(usize, 0), injections);
        try std.testing.expect(alt_held and ctrl_held);
    }
}
test "foreign foreground, refused activation and guards do not focus" {
    for (0..5) |case| {
        reset();
        switch (case) {
            0 => owned = false,
            1 => accepted = false,
            2 => guard_allowed = false,
            3 => app_state.g_account_locked = true,
            4 => { app_state.g_chat_active = true; chat_owns = false; },
            else => unreachable,
        }
        focusActiveShellFromBrowserInput();
        try std.testing.expectEqual(@as(usize, 0), focus_calls);
        try std.testing.expectEqual(@as(usize, 0), attachments);
        try std.testing.expectEqual(@as(usize, 0), injections);
        try std.testing.expect(alt_held and ctrl_held);
    }
}
`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'hotkey-shell-'));
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
  const postEnd = rename.indexOf('\n    }', postStart) + '\n    }'.length;
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

test('address hotkey registers only for the owned visible custom bar', () => {
  const root = path.join(__dirname, '..');
  const pane = fs.readFileSync(path.join(root, 'src/browser_pane.zig'), 'utf8');
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const shortcuts = fs.readFileSync(path.join(root, 'src/shortcuts.zig'), 'utf8');
  const passthroughStart = shortcuts.indexOf('        if (key_down and !((kb.vkCode == 0x51');
  const passthroughEnd = shortcuts.indexOf('\n        if (kb.vkCode < computer_consumed_keys.len', passthroughStart);
  assert.ok(passthroughStart >= 0 && passthroughEnd > passthroughStart);
  const passthrough = shortcuts.slice(passthroughStart, passthroughEnd)
    .replaceAll('kb.vkCode', 'key')
    .replaceAll('app_state.g_browser_focus_chord_held', 'held')
    .replaceAll('@import("browser_pane.zig")', 'browser')
    .replace('return CallNextHookEx(app_state.g_hook, nCode, wp, lp);', 'return true;');
  const start = pane.indexOf('const Scope = enum { focus_escape');
  const end = pane.indexOf('\npub fn calcBrowserLayout(', start);
  const handlerStart = main.indexOf('        WM_HOTKEY => {');
  const handlerEnd = main.indexOf('        0x0011 => {', handlerStart);
  const helperStart = main.indexOf('fn browserFocusHotkey()');
  const helperEnd = main.indexOf('\n}', helperStart) + '\n}'.length;
  assert.ok(start >= 0 && end > start && handlerStart >= 0 && handlerEnd > handlerStart && helperStart >= 0 && helperEnd > helperStart);
  const focusHelper = main.slice(helperStart, helperEnd)
    .replaceAll('@import("chat_find_ui.zig").close(false)', 'closeFind()')
    .replaceAll('@import("focus.zig").focusActiveShellFromBrowserInput()', 'focusActiveShell()');
  const lifecycle = pane.slice(start, end)
    .replaceAll('@import("win32.zig")', 'win32')
    .replaceAll('@import("focus.zig").heldModifierMask()', 'heldModifierMask()')
    .replaceAll('@import("computer_pane.zig").selected()', 'computerSelected()')
    .replaceAll('@import("room_frontend.zig").privateActionsAllowed()', 'privateActionsAllowed()');
  const handler = main.slice(handlerStart, handlerEnd)
    .replaceAll('@import("win32.zig")', 'win32')
    .replaceAll('@import("browser_pane.zig")', 'browser')
    .replaceAll('@import("room_frontend.zig").privateActionsAllowed()', 'privateActionsAllowed()');
  const fixture = `
const std = @import("std");
const HANDLE = ?*anyopaque;
const WPARAM = usize;
const WM_HOTKEY: u32 = 1;
const HOTKEY_ID_FOCUS: i32 = 1;
const MOD_CONTROL: u32 = 2;
const MOD_SHIFT: u32 = 4;
const frame: HANDLE = @ptrFromInt(1);
const bar: HANDLE = @ptrFromInt(2);
var owned = true;
var visible = true;
var custom = true;
var selected = false;
var private_allowed = true;
var overlay = false;
var refused_id: i32 = 0;
var register_calls: [7]usize = @splat(0);
var unregister_calls: [7]usize = @splat(0);
var simulated_modifiers: u32 = 0;
var launches: usize = 0;
var simulated_pane_foreground = false;
var webview_owned = false;
var webview_focused = false;
var shell_focuses: usize = 0;
var frame_activations: usize = 0;
var posts: usize = 0;
var cancellations: usize = 0;
var find_closes: usize = 0;
var alt_held = true;
var ctrl_held = false;
const WM_APP_BROWSER_FOCUS_TOGGLE: u32 = 81;
const app_state = struct {
    var g_main_hwnd: HANDLE = frame;
    var g_urlbar_hwnd: HANDLE = bar;
    var g_edit_hwnd: HANDLE = null;
    var g_app_closing = false;
    var g_account_locked = false;
    var g_search_active = false;
    var g_chat_find_open = false;
    var g_chat_browser_handoff_until: u64 = 0;
    var g_browser_focus_mode = false;
    var g_shell_focused = false;
    var g_focus_user_action_tick: u64 = 0;
    var active_shell: usize = 0;
    var shell_count: usize = 1;
    var shells = [_]struct { browser_enabled: bool }{.{ .browser_enabled = true }};
};
const win32 = struct {
    const HOTKEY_ID_BROWSER_URL: i32 = 2;
    const HOTKEY_ID_BROWSER_FOCUS: i32 = 3;
    const HOTKEY_ID_BROWSER_FOCUS_ALT_M: i32 = 4;
    const HOTKEY_ID_BROWSER_FOCUS_GRAVE: i32 = 5;
    const HOTKEY_ID_BROWSER_PANE_URL: i32 = 6;
    const MOD_ALT: u32 = 1;
    const MOD_CONTROL: u32 = 2;
    const MOD_SHIFT: u32 = 4;
    const MOD_WIN: u32 = 8;
    const MOD_NOREPEAT: u32 = 0x4000;
    fn RegisterHotKey(_: HANDLE, id: i32, mods: u32, key: u32) i32 {
        const expected_mods = [_]u32{ 0, 0, 6, 1, 1, 2, 2 };
        const expected_keys = [_]u32{ 0, 0, 0x4C, 0x51, 0x4D, 0xC0, 0x4C };
        const i: usize = @intCast(id);
        std.debug.assert(mods == (expected_mods[i] | MOD_NOREPEAT) and key == expected_keys[i]);
        register_calls[i] += 1;
        return if (id == refused_id) 0 else 1;
    }
    fn UnregisterHotKey(_: HANDLE, id: i32) i32 {
        unregister_calls[@intCast(id)] += 1;
        return 1;
    }
};
fn computerSelected() bool { return selected; }
fn privateActionsAllowed() bool { return private_allowed; }
fn browserChromeHiddenForOverlay() bool { return overlay; }
fn activeBrowserShowsUrlBar() bool { return custom; }
fn IsWindow(_: HANDLE) i32 { return 1; }
fn IsWindowVisible(_: HANDLE) i32 { return if (visible) 1 else 0; }
fn foregroundIsOurs() bool { return owned; }
fn isCtrlDown() bool { return ctrl_held; }
fn GetAsyncKeyState(key: i32) i16 {
    const mask: u32 = switch (key) { 0x12 => 1, 0x11 => 2, 0x10 => 4, 0x5B => 8, else => 0 };
    return if (simulated_modifiers & mask != 0) -32768 else 0;
}
fn activeBrowserHwndLive() HANDLE { return if (simulated_pane_foreground) frame else null; }
fn GetTickCount64() u64 { return 123; }
fn startBrowserUrlBarEdit() void { launches += 1; }
fn toggleDictation() void {}
fn webView2OwnsActiveShell() bool { return webview_owned; }
fn webView2HasInputFocus() bool { return webview_focused; }
fn activeBrowserHasForegroundFocus() bool { return simulated_pane_foreground; }
fn closeFind() void { find_closes += 1; app_state.g_chat_find_open = false; }
fn cancelPendingNativeBrowserFocus() void { cancellations += 1; }
fn focusActiveShell() void { shell_focuses += 1; }
fn SetForegroundWindow(h: HANDLE) i32 { std.debug.assert(h == frame); frame_activations += 1; return 1; }
fn PostMessageW(h: HANDLE, msg: u32, _: usize, _: isize) i32 {
    std.debug.assert(h == frame and msg == WM_APP_BROWSER_FOCUS_TOGGLE and app_state.g_focus_user_action_tick == 123);
    posts += 1;
    return 1;
}
${focusHelper}
${productionFunction('heldModifierMask').replaceAll('@import("win32.zig")', 'win32')}
const browser = struct {
${lifecycle}
};
fn nativePass(key: u32, key_down: bool, held: bool) bool {
${passthrough}
    return false;
}
fn dispatch(wp: WPARAM, lp: isize) isize {
    switch (@as(u32, WM_HOTKEY)) {
${handler}
        else => return 1,
    }
}
test "five bindings dispatch and release on foreign foreground" {
    simulated_pane_foreground = true;
    browser.syncBrowserHotkeys();
    for (2..7) |id| try std.testing.expectEqual(@as(usize, 1), register_calls[id]);
    _ = dispatch(2, 0x4C0006);
    _ = dispatch(3, 0x510001);
    _ = dispatch(4, 0x4D0001);
    _ = dispatch(5, 0xC00002);
    _ = dispatch(6, 0x4C0002);
    try std.testing.expectEqual(@as(usize, 2), launches);
    try std.testing.expectEqual(@as(usize, 3), shell_focuses);
    owned = false;
    _ = dispatch(2, 0x4C0006);
    browser.syncBrowserHotkeys();
    for (2..7) |id| try std.testing.expectEqual(@as(usize, 1), unregister_calls[id]);
    try std.testing.expectEqual(@as(usize, 2), launches);
}
test "find and pane scopes" {
    browser.unregisterBrowserHotkeys();
    owned = true; simulated_pane_foreground = true; custom = true;
    app_state.g_chat_find_open = true;
    browser.syncBrowserHotkeys();
    try std.testing.expect(browser.browserHotkeyAction(3, 0x510001) != null);
    try std.testing.expect(browser.browserHotkeyAction(4, 0x4D0001) != null);
    try std.testing.expect(browser.browserHotkeyAction(2, 0x4C0006) == null);
    try std.testing.expect(browser.browserHotkeyAction(5, 0xC00002) == null);
    try std.testing.expect(browser.browserHotkeyAction(6, 0x4C0002) == null);
    app_state.g_chat_find_open = false;
    simulated_pane_foreground = false;
    browser.syncBrowserHotkeys();
    try std.testing.expect(browser.browserHotkeyAction(6, 0x4C0002) == null);
    simulated_pane_foreground = true; custom = false;
    browser.syncBrowserHotkeys();
    try std.testing.expect(browser.browserHotkeyAction(6, 0x4C0002) == null);
    custom = true;
    browser.syncBrowserHotkeys();
    try std.testing.expect(browser.browserHotkeyAction(6, 0x4C0002) != null);
}
test "focus keeps direct return and legacy toggle paths" {
    browser.unregisterBrowserHotkeys();
    owned = true; custom = true; simulated_pane_foreground = true;
    app_state.g_chat_find_open = true; app_state.g_edit_hwnd = bar;
    app_state.g_browser_focus_mode = true; app_state.g_chat_browser_handoff_until = 500;
    browser.syncBrowserHotkeys();
    const prior_focuses = shell_focuses;
    const prior_closes = find_closes;
    _ = dispatch(3, 0x510001);
    try std.testing.expectEqual(prior_focuses + 1, shell_focuses);
    try std.testing.expectEqual(prior_closes + 1, find_closes);
    try std.testing.expect(!app_state.g_browser_focus_mode and app_state.g_shell_focused);
    try std.testing.expectEqual(@as(u64, 0), app_state.g_chat_browser_handoff_until);
    simulated_pane_foreground = false; webview_owned = true; webview_focused = true;
    app_state.shells[0].browser_enabled = false;
    _ = dispatch(4, 0x4D0001);
    try std.testing.expectEqual(prior_focuses + 2, shell_focuses);
    webview_focused = false;
    const prior_posts = posts;
    _ = dispatch(3, 0x510001);
    try std.testing.expectEqual(prior_posts + 1, posts);
    webview_owned = false; app_state.shells[0].browser_enabled = true;
    app_state.g_edit_hwnd = null;
}
test "refusal retries only after leaving scope and modifiers reject extras" {
    browser.unregisterBrowserHotkeys();
    refused_id = 4;
    const before = register_calls[4];
    browser.syncBrowserHotkeys();
    browser.syncBrowserHotkeys();
    try std.testing.expectEqual(before + 1, register_calls[4]);
    try std.testing.expect(browser.browserHotkeyAction(4, 0x4D0001) == null);
    owned = false; browser.syncBrowserHotkeys();
    refused_id = 0; owned = true; browser.syncBrowserHotkeys();
    try std.testing.expectEqual(before + 2, register_calls[4]);
    simulated_modifiers = 3;
    try std.testing.expect(browser.browserHotkeyAction(4, 0x4D0001) == null);
    simulated_modifiers = 9;
    try std.testing.expect(browser.browserHotkeyAction(4, 0x4D0001) == null);
    simulated_modifiers = 1;
    try std.testing.expect(browser.browserHotkeyPasses(0x4D));
    try std.testing.expect(nativePass(0x4D, true, false));
    try std.testing.expect(!nativePass(0x4D, true, true));
    try std.testing.expect(!nativePass(0x4D, false, false));
    try std.testing.expect(!browser.browserHotkeyPasses(0x4C));
    simulated_modifiers = 0;
    try std.testing.expect(browser.browserHotkeyAction(4, 0x4D0001) != null);
    try std.testing.expect(browser.browserHotkeyAction(4, 0x4D0003) == null);
}

`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'url-hotkey-'));
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
  const immediateStart = browser.indexOf('        if (foregroundIsOurs()) {', end);
  const immediateEnd = browser.indexOf('\n    }\n}', immediateStart);
  assert.ok(discardStart >= 0 && discardEnd > discardStart && immediateStart > end && immediateEnd > immediateStart);
  const immediate = browser.slice(immediateStart, immediateEnd)
    .replaceAll('@import("win32.zig").TIMER_BROWSER_URL_FOCUS', 'timer_id')
    .replaceAll('@import("focus.zig").focusGuardReadMouse()', 'focusGuardReadMouse()')
    .replaceAll('@import("computer_pane.zig").selected()', 'computerSelected()')
    .replaceAll('@import("room_frontend.zig").privateActionsAllowed()', 'privateActionsAllowed()');
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
var immediate_allowed = false;
var timers_started: usize = 0;
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
fn SetTimer(_: HANDLE, _: usize, _: u32, _: ?*anyopaque) usize { timers_started += 1; return timer_id; }
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
fn SetForegroundWindow(hwnd: HANDLE) i32 {
    foreground_attempts += 1;
    if (immediate_allowed) { foreground = hwnd; return 1; }
    if (interrupt == 1) { foreground = foreign; owned = false; }
    if (interrupt == 2) app_state.g_focus_input_tick = 11;
    if (interrupt == 3) app_state.g_account_locked = true;
    return 0;
}
fn SwitchToThisWindow(h: HANDLE, activate: i32) void {
    std.debug.assert(activate == 0);
    switch_count += 1;
    foreground = h;
    if (interrupt == 4) app_state.g_account_locked = true;
}
fn SetFocus(h: HANDLE) HANDLE { const previous = focused; focused = h; return previous; }

${production}
fn immediateFocus() void {
    const edit_parent = parent;
${immediate}
}
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
    immediate_allowed = false;
    timers_started = 0;
    destroyed = null;
    sync_count = 0;
    foreground_attempts = 0;
    switch_count = 0;
    interrupt = 0;
    killed = 0;
}
test "immediate foreground activation focuses while Ctrl remains held" {
    reset();
    held = 0x11;
    immediate_allowed = true;
    immediateFocus();
    try std.testing.expectEqual(parent, foreground);
    try std.testing.expectEqual(edit, focused);
    try std.testing.expectEqual(@as(i32, 0x11), held);
    try std.testing.expectEqual(@as(usize, 0), timers_started);
    try std.testing.expectEqual(@as(usize, 1), killed);
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
      'heldModifierMask',
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
const win32 = struct { const WM_COMMAND: u32 = 0x111; const MOD_ALT: u32 = 1; const MOD_CONTROL: u32 = 2; const MOD_SHIFT: u32 = 4; const MOD_WIN: u32 = 8; };
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
var attach_calls: usize = 0;
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
    if (attach != 0) {
        attachments += 1;
        attach_calls += 1;
        simulated_alt_down = false;
        simulated_ctrl_down = false;
        other_held = 0;
    } else attachments -= 1;
    return 1;
}
fn foregroundIsOurs() bool { return foreground != foreign_window; }
fn SetForegroundWindow(hwnd: HANDLE) i32 {
    if (foreign_on_attempt) foreground = foreign_window;
    if (refuse_foreground) return 0;
    foreground = hwnd; focus_changes += 1; return 1;
}
fn SwitchToThisWindow(hwnd: HANDLE, activate: i32) void {
    std.debug.assert(activate == 0);
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
    attach_calls = 0;
    injections = 0;
    focus_changes = 0;
    posted = 0;
    posted_command = 0;
}
test "held modifiers wait for release before attaching and focusing" {
    for ([_]i32{ 0x10, 0x11, 0x12, 0x5B, 0x5C, 0xFF }) |key| {
        reset(key == 0x12 or key == 0xFF, key == 0x11 or key == 0xFF);
        if (key == 0x10 or key == 0x5B or key == 0x5C) other_held = key;
        focusActiveBrowserPane();
        try std.testing.expectEqual(main_window, foreground);
        try std.testing.expectEqual(main_window, focused);
        try std.testing.expectEqual(@as(usize, 0), focus_changes);
        try std.testing.expectEqual(@as(usize, 0), attach_calls);
        try std.testing.expectEqual(@as(usize, 0), posted);
        try std.testing.expectEqual(@as(usize, 0), injections);
        if (key == 0xFF) {
            try std.testing.expect(simulated_alt_down and simulated_ctrl_down);
        } else {
            try std.testing.expect(GetAsyncKeyState(key) < 0);
        }
        simulated_alt_down = false; simulated_ctrl_down = false; other_held = 0;
        focusActiveBrowserPane();
        try std.testing.expectEqual(pane, foreground);
        try std.testing.expectEqual(pane, focused);
        try std.testing.expect(attach_calls > 0);
        try std.testing.expectEqual(@as(usize, 1), posted);
        try std.testing.expectEqual(@as(WPARAM, 39009), posted_command);
        try std.testing.expectEqual(@as(usize, 0), injections);
    }
}
test "plain focus reaches the page without keyboard injection" {
    reset(false, false);
    focusActiveBrowserPane();
    try std.testing.expectEqual(pane, foreground);
    try std.testing.expectEqual(pane, focused);
    try std.testing.expectEqual(@as(usize, 1), posted);
    try std.testing.expectEqual(@as(WPARAM, 39009), posted_command);
    try std.testing.expectEqual(@as(usize, 0), injections);
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
        try std.testing.expectEqual(@as(usize, 0), attach_calls);
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
