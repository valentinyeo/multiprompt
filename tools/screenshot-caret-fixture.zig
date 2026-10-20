const std = @import("std");
const HANDLE = ?usize;
const VK_MENU: u8 = 0x12;
const KEYEVENTF_KEYUP: u32 = 2;
const TIMER_CHAT_FOREGROUND_RETRY = 1;
const TIMER_REFOCUS = 2;
const TIMER_SHOT_FOCUS = 42;
const SW_SHOW = 5;
const GA_ROOT = 2;
const BOOL = u32;
const GUITHREADINFO = struct { cbSize: u32, hwndFocus: HANDLE };
var reparented = false;
var hosted_console = false;
var local_focus_missing = false;
var deny_gui_info = false;
fn GetAncestor(hwnd: HANDLE, _: u32) HANDLE {
    return if (hwnd == 20 or (hwnd == 40 and (reparented or hosted_console))) g_main_hwnd else hwnd;
}
fn IsChild(parent: HANDLE, hwnd: HANDLE) u32 {
    return if ((parent == 10 and (hwnd == 20 or hwnd == 40)) or (parent == 40 and hwnd == 41)) 1 else 0;
}
fn GetGUIThreadInfo(_: u32, info: *GUITHREADINFO) u32 {
    if (deny_gui_info) return 0;
    info.hwndFocus = keyboard_focus;
    return 1;
}
var active_shell: usize = 0;
var shells = [_]struct { shell_id: u32, hwnd: HANDLE }{ .{ .shell_id = 123, .hwnd = 40 }, .{ .shell_id = 456, .hwnd = 50 } };
var g_chat_composer_hwnd: HANDLE = 20;
var g_main_hwnd: HANDLE = 10;
var g_edit_hwnd: HANDLE = null;
var g_focus_paste_target: HANDLE = null;
var g_focus_authorized_hwnd: HANDLE = null;
var g_focus_authorized_until: u64 = 0;
var g_focus_input_tick: u64 = 0;
var g_chat_browser_handoff_until: u64 = 999;
var g_browser_focus_mode = true;
var g_chat_foreground_retries: u32 = 0;
var g_chat_active = true;
var g_shell_focused = false;
var g_search_active = false;
var g_inbox_active = false;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_url_picker_active = false;
var g_all_sessions_active = false;
var g_snippet_create_active = false;
var clock: u64 = 1000;
var foreground: HANDLE = 30;
var keyboard_focus: HANDLE = 30;
var ctrl = false;
var alt = false;
var shift = false;
var deny_foreground = false;
var attached = [_]bool{ false, false, false, false };
var attach_calls: u32 = 0;
var detach_calls: u32 = 0;
var alt_down: u32 = 0;
var alt_up: u32 = 0;
var foreground_calls: u32 = 0;
var focus_calls: u32 = 0;
var pending_cancelled = false;
var caret_pos: usize = 0;
var timer_armed = false;
var console_shown = false;
fn findShellById(id: u32) ?usize {
    for (shells, 0..) |shell, i| if (shell.shell_id == id) return i;
    return null;
}
fn foregroundIsOurs() bool {
    return foreground == 10 or foreground == 20 or foreground == 40;
}
fn focusGuardReadMouse() void {}
fn GetTickCount64() u64 {
    return clock;
}
fn cancelPendingNativeBrowserFocus() void {
    pending_cancelled = true;
}
fn KillTimer(_: HANDLE, id: u32) u32 {
    if (id == TIMER_SHOT_FOCUS) timer_armed = false;
    return 1;
}
fn GetForegroundWindow() HANDLE {
    return foreground;
}
fn GetFocus() HANDLE {
    return if (local_focus_missing) null else keyboard_focus;
}
fn GetWindowThreadProcessId(hwnd: HANDLE, _: ?*u32) u32 {
    return if (hwnd == 30) 2 else if (hwnd == 40) 3 else 1;
}
fn GetCurrentThreadId() u32 {
    return 1;
}
fn AttachThreadInput(_: u32, to: u32, attach: u32) u32 {
    std.debug.assert(g_focus_paste_target != null);
    attached[to] = attach == 1;
    if (attach == 1) attach_calls += 1 else detach_calls += 1;
    return 1;
}
fn fakeAttachThreadInput(_: u32, _: u32, _: u32) u32 {
    return 1;
}
fn isCtrlDown() bool {
    return ctrl;
}
fn GetAsyncKeyState(key: i32) i16 {
    return if ((key == VK_MENU and alt) or (key == 0x10 and shift)) @bitCast(@as(u16, 0x8000)) else 0;
}
fn keybd_event(_: u8, _: u8, flags: u32, _: usize) void {
    if (flags == 0) alt_down += 1 else alt_up += 1;
}
fn SetForegroundWindow(hwnd: HANDLE) u32 {
    std.debug.assert(hwnd == g_focus_paste_target or hwnd == g_main_hwnd);
    foreground_calls += 1;
    if (deny_foreground or (foreground == 30 and (!attached[2] or alt_down == 0))) return 0;
    if (hwnd == 40 and (reparented or !attached[3])) return 0;
    foreground = hwnd;
    return 1;
}
fn SetFocus(hwnd: HANDLE) HANDLE {
    if (foreground != (if (g_chat_active or reparented) g_main_hwnd else hwnd) or (hwnd == 40 and !attached[3])) return null;
    keyboard_focus = hwnd;
    focus_calls += 1;
    return hwnd;
}
fn SendMessageW(hwnd: HANDLE, msg: u32, wp: usize, lp: isize) isize {
    std.debug.assert(hwnd == g_chat_composer_hwnd);
    if (msg == 0x00B1) {
        std.debug.assert(wp == @as(usize, @intCast(lp)));
        caret_pos = wp;
    }
    return 0;
}
fn SetTimer(_: HANDLE, id: u32, _: u32, _: ?usize) usize {
    if (id == TIMER_SHOT_FOCUS) timer_armed = true;
    return 1;
}
fn showShellConsole(_: u32, _: u32, _: []const u8) u32 {
    console_shown = true;
    return 1;
}
fn repositionActive() void {}
fn debugLog(_: []const u8) void {}
fn altqPtr(hwnd: HANDLE) usize {
    return hwnd orelse 0;
}

fn reset() void {
    active_shell = 0;
    reparented = false;
    hosted_console = false;
    local_focus_missing = false;
    deny_gui_info = false;
    g_igsh354_paste_focus = true;
    clock = 1000;
    g_chat_active = true;
    g_edit_hwnd = null;
    g_search_active = false;
    g_chat_composer_hwnd = 20;
    g_focus_paste_target = null;
    g_focus_authorized_hwnd = null;
    g_focus_authorized_until = 0;
    g_focus_input_tick = 0;
    g_chat_browser_handoff_until = 999;
    g_browser_focus_mode = true;
    g_chat_foreground_retries = 0;
    g_shot_focus = .{};
    foreground = 30;
    keyboard_focus = 30;
    ctrl = false;
    alt = false;
    shift = false;
    deny_foreground = false;
    attached = @splat(false);
    attach_calls = 0;
    detach_calls = 0;
    alt_down = 0;
    alt_up = 0;
    foreground_calls = 0;
    focus_calls = 0;
    pending_cancelled = false;
    caret_pos = 0;
    timer_armed = false;
    console_shown = false;
}

test "foreign Chrome context menu delivery lands composer caret and releases narrow authority" {
    reset();
    requestShotFocus(0, 47);
    try std.testing.expectEqual(g_main_hwnd, foreground);
    try std.testing.expectEqual(g_chat_composer_hwnd, keyboard_focus);
    try std.testing.expectEqual(@as(usize, 47), caret_pos);
    try std.testing.expectEqual(@as(u32, 1), attach_calls);
    try std.testing.expectEqual(attach_calls, detach_calls);
    try std.testing.expectEqual(@as(u32, 1), alt_down);
    try std.testing.expectEqual(alt_down, alt_up);
    try std.testing.expect(g_focus_paste_target == null and !timer_armed);
    try std.testing.expect(!g_browser_focus_mode and pending_cancelled);
    try std.testing.expectEqual(@as(u64, 0), g_chat_browser_handoff_until);
}

test "shell screenshot attaches Chrome AND conhost and focuses the exact console" {
    reset();
    g_chat_active = false;
    requestShotFocus(0, null);
    try std.testing.expectEqual(shells[0].hwnd, foreground);
    try std.testing.expectEqual(shells[0].hwnd, keyboard_focus);
    try std.testing.expectEqual(@as(u32, 2), attach_calls);
    try std.testing.expectEqual(attach_calls, detach_calls);
    try std.testing.expect(g_shell_focused and console_shown);
    try std.testing.expect(g_focus_paste_target == null and !timer_armed);
}

test "background tabs, overlays, rename and missing composer never take focus" {
    for (0..4) |case| {
        reset();
        switch (case) {
            1 => g_search_active = true,
            2 => g_edit_hwnd = 99,
            3 => g_chat_composer_hwnd = null,
            else => {},
        }
        requestShotFocus(if (case == 0) 1 else 0, 47);
        try std.testing.expectEqual(@as(u32, 0), foreground_calls);
        try std.testing.expectEqual(@as(u32, 0), attach_calls);
        try std.testing.expect(!timer_armed and !pending_cancelled);
    }
}

test "held Ctrl, Alt or Shift defers, then restores the exact caret after release" {
    for (0..3) |case| {
        reset();
        ctrl = case == 0;
        alt = case == 1;
        shift = case == 2;
        requestShotFocus(0, 47);
        try std.testing.expectEqual(@as(u32, 0), alt_down);
        try std.testing.expect(timer_armed);
        ctrl = false;
        alt = false;
        shift = false;
        shotFocusTick();
        try std.testing.expectEqual(@as(u32, 1), focus_calls);
        try std.testing.expectEqual(@as(usize, 47), caret_pos);
        try std.testing.expect(!timer_armed);
    }
}

test "foreground failure retries without losing caret, then cancels on new input, mode, tab or timeout" {
    reset();
    deny_foreground = true;
    requestShotFocus(0, 47);
    try std.testing.expect(timer_armed);
    try std.testing.expectEqual(attach_calls, detach_calls);
    deny_foreground = false;
    shotFocusTick();
    try std.testing.expect(!timer_armed);
    try std.testing.expectEqual(@as(usize, 47), caret_pos);
    for (0..5) |case| {
        reset();
        ctrl = true;
        requestShotFocus(0, 47);
        ctrl = false;
        switch (case) {
            0 => g_focus_input_tick = clock + 1,
            1 => g_chat_active = false,
            2 => active_shell = 1,
            3 => clock += 1501,
            else => foreground = 99,
        }
        shotFocusTick();
        try std.testing.expectEqual(@as(u32, 0), foreground_calls);
        try std.testing.expect(!timer_armed and g_focus_paste_target == null);
    }
}

test "reparented console uses its frame for activation and its own input queue for typing" {
    reset();
    reparented = true;
    local_focus_missing = true;
    g_chat_active = false;
    requestShotFocus(0, null);
    try std.testing.expectEqual(g_main_hwnd, foreground);
    try std.testing.expectEqual(shells[0].hwnd, keyboard_focus);
    try std.testing.expect(g_shell_focused and !timer_armed);
    try std.testing.expect(!pasteFocusLanded(null));
    deny_gui_info = true;
    try std.testing.expect(!pasteFocusLanded(shells[0].hwnd));
    deny_gui_info = false;
    keyboard_focus = 10;
    try std.testing.expect(!pasteFocusLanded(shells[0].hwnd));
    keyboard_focus = 41;
    try std.testing.expect(pasteFocusLanded(shells[0].hwnd));
    foreground = 30;
    try std.testing.expect(!pasteFocusLanded(shells[0].hwnd));
}

test "disabled paste repair retains the old child activation behavior" {
    reset();
    g_igsh354_paste_focus = false;
    g_chat_active = false;
    requestShotFocus(0, null);
    try std.testing.expectEqual(shells[0].hwnd, foreground);
    try std.testing.expect(g_shell_focused and !timer_armed);
}

test "a hosted console that can be foreground takes the keyboard itself with the paste repair on" {
    reset();
    hosted_console = true;
    g_chat_active = false;
    requestShotFocus(0, null);
    try std.testing.expectEqual(shells[0].hwnd, foreground);
    try std.testing.expectEqual(shells[0].hwnd, keyboard_focus);
    try std.testing.expect(g_shell_focused and !timer_armed);
}

test "a foreground hosted console counts as landed without GUI thread focus" {
    reset();
    hosted_console = true;
    g_chat_active = false;
    requestShotFocus(0, null);
    try std.testing.expectEqual(shells[0].hwnd, foreground);
    deny_gui_info = true;
    try std.testing.expect(pasteFocusLanded(shells[0].hwnd));
    keyboard_focus = null;
    deny_gui_info = false;
    try std.testing.expect(pasteFocusLanded(shells[0].hwnd));
    foreground = 30;
    try std.testing.expect(!pasteFocusLanded(shells[0].hwnd));
}
