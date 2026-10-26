const std = @import("std");
const HANDLE = ?*anyopaque;
const DWORD = u32;
const UINT = u32;
const BOOL = i32;
const WPARAM = usize;
const LPARAM = isize;
const GA_ROOT = 2;
const GA_ROOTOWNER = 3;
const WM_KEYDOWN = 0x100;
const WM_SYSKEYDOWN = 0x104;
const WM_LBUTTONDOWN = 0x201;
const WM_LBUTTONUP = 0x202;
const WM_LBUTTONDBLCLK = 0x203;
const WM_RBUTTONDOWN = 0x204;
const WM_MOUSEWHEEL = 0x20a;
const WM_APP_OPEN_URL_AT = 0x801b;
const SW_SHOW = 5;
const SW_RESTORE = 9;
const SW_MAXIMIZE = 3;
const SW_SHOWNOACTIVATE = 4;
const SWP_NOACTIVATE = 0x10;
fn win(id: usize) HANDLE {
    return @ptrFromInt(id);
}
var g_main_hwnd: HANDLE = @ptrFromInt(1);
var g_chat_active = false;
var g_search_active = false;
var g_inbox_active = false;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_url_picker_active = false;
var g_all_sessions_active = false;
var g_snippet_create_active = false;
var g_chat_find_open = false;
var g_edit_hwnd: HANDLE = null;
var g_native_browser_focus_pending_shell_id: u32 = 0;
var g_chat_browser_handoff_until: u64 = 0;
fn captureWorkspaceFocus() void {}
fn altqLog(_: []const u8, _: anytype) void {}
fn altqPtr(hwnd: HANDLE) usize {
    return @intFromPtr(hwnd);
}
var g_chat_composer_hwnd: HANDLE = @ptrFromInt(3);
var shell_count: usize = 2;
var active_shell: usize = 0;
var shells = [_]struct { hwnd: HANDLE, browser_hwnd: HANDLE, shell_id: u32 }{
    .{ .hwnd = @ptrFromInt(2), .browser_hwnd = @ptrFromInt(4), .shell_id = 10 },
    .{ .hwnd = @ptrFromInt(5), .browser_hwnd = @ptrFromInt(6), .shell_id = 20 },
};
var g_browser_focus_mode = false;
var g_shell_focused = true;
var clock: u64 = 10000;
var foreground: HANDLE = @ptrFromInt(2);
var keyboard_focus: HANDLE = @ptrFromInt(2);
var activation_calls: usize = 0;
var attachment_calls: usize = 0;
var show_cmd: i32 = 0;
var position_flags: u32 = 0;
var blocked_logs: usize = 0;
var returned_logs: usize = 0;
fn GetTickCount64() u64 {
    return clock;
}
fn GetForegroundWindow() HANDLE {
    return foreground;
}
fn GetFocus() HANDLE {
    return keyboard_focus;
}
fn GetCurrentThreadId() DWORD {
    return 11;
}
fn GetWindowThreadProcessId(hwnd: HANDLE, _: ?*DWORD) DWORD {
    return @intCast(@intFromPtr(hwnd) + 10);
}
fn IsWindow(hwnd: HANDLE) BOOL {
    return if (hwnd != null) 1 else 0;
}
fn IsChild(parent: HANDLE, child: HANDLE) BOOL {
    return if (parent == win(1) and (child == win(2) or child == win(3) or child == win(5))) 1 else 0;
}
fn GetAncestor(hwnd: HANDLE, _: UINT) HANDLE {
    return if (IsChild(win(1), hwnd) != 0) win(1) else hwnd;
}
fn browserPaneOwnsForegroundHwnd(fg: HANDLE, _: HANDLE) bool {
    return fg == win(4) or fg == win(6);
}
fn foregroundIsOurs() bool {
    return foreground != null and foreground != win(9);
}
fn focusTrace(event: enum { allowed, activation_refocus, blocked }, _: HANDLE, _: usize) void {
    if (event == .blocked) blocked_logs += 1;
}
fn debugLog(text: []const u8) void {
    if (std.mem.startsWith(u8, text, "focus guard: blocked")) blocked_logs += 1;
    if (std.mem.startsWith(u8, text, "focus guard: returned focus")) returned_logs += 1;
}
const FocusNative = struct {
    fn SetForegroundWindow(hwnd: HANDLE) BOOL {
        foreground = hwnd;
        activation_calls += 1;
        return 1;
    }
    fn SetFocus(hwnd: HANDLE) HANDLE {
        keyboard_focus = hwnd;
        activation_calls += 1;
        return hwnd;
    }
    fn AttachThreadInput(_: DWORD, _: DWORD, _: BOOL) BOOL {
        attachment_calls += 1;
        return 1;
    }
    fn SwitchToThisWindow(hwnd: HANDLE, _: BOOL) void {
        foreground = hwnd;
        activation_calls += 1;
    }
    fn AllowSetForegroundWindow(_: DWORD) BOOL {
        activation_calls += 1;
        return 1;
    }
    fn ShowWindow(_: HANDLE, cmd: i32) BOOL {
        show_cmd = cmd;
        return 1;
    }
    fn ShowWindowAsync(_: HANDLE, cmd: i32) BOOL {
        show_cmd = cmd;
        return 1;
    }
    fn SetWindowPos(_: HANDLE, _: HANDLE, _: i32, _: i32, _: i32, _: i32, flags: UINT) BOOL {
        position_flags = flags;
        return 1;
    }
    fn PostMessageW(_: HANDLE, _: UINT, _: WPARAM, _: LPARAM) BOOL {
        return 1;
    }
};
fn reset() void {
    g_chat_active = false;
    g_search_active = false;
    g_inbox_active = false;
    g_shortcuts_active = false;
    g_changelog_active = false;
    g_url_picker_active = false;
    g_all_sessions_active = false;
    g_snippet_create_active = false;
    g_chat_find_open = false;
    g_edit_hwnd = null;
    g_native_browser_focus_pending_shell_id = 0;
    g_chat_browser_handoff_until = 0;
    g_chat_composer_hwnd = win(3);
    clock = 10000;
    foreground = win(2);
    keyboard_focus = win(2);
    active_shell = 0;
    activation_calls = 0;
    attachment_calls = 0;
    blocked_logs = 0;
    returned_logs = 0;
    g_focus_user_action_tick = 0;
    g_focus_input_tick = 0;
    g_focus_return_hwnd = null;
    g_focus_typing_tick = 0;
    g_focus_paste_target = null;
    g_focus_authorized_hwnd = null;
    g_focus_authorized_until = 0;
    g_focus_browser_shell_id = 0;
    g_focus_restoring = false;
    g_focus_activation_until = 0;
    g_focus_mouse_seen = 0;
    g_focus_mouse_tick.store(0, .release);
    g_focus_mouse_hwnd.store(0, .release);
    g_focus_foreign_input_tick.store(0, .release);
    g_focus_user_messages = @splat(.{});
    g_focus_user_message_next = 0;
}
test "recent typing never grants agent foreground, focus, queue attachment or foreground unlock" {
    reset();
    focusGuardNoteInput(win(2), clock, true);
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(4)));
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(4)));
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(1)));
    reset();
    try std.testing.expectEqual(@as(BOOL, 0), AttachThreadInput(11, 14, 1));
    try std.testing.expectEqual(@as(BOOL, 0), AllowSetForegroundWindow(999));
    try std.testing.expectEqual(@as(usize, 0), activation_calls);
    try std.testing.expect(blocked_logs >= 2);
    try std.testing.expectEqual(@as(BOOL, 1), AttachThreadInput(11, 14, 0));
}
test "user Alt Q into pane survives timers and can return to Chat View" {
    reset();
    foreground = win(1);
    keyboard_focus = win(3);
    focusGuardNoteInput(win(3), clock, true);
    g_focus_user_action_tick = clock;
    g_focus_browser_shell_id = 10;
    g_focus_authorized_until = clock + 1500;
    g_focus_user_action_tick = 0;
    try std.testing.expectEqual(@as(BOOL, 1), SetForegroundWindow(win(4)));
    try std.testing.expect(!focusGuardReturnFromPane(win(4)));
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(3)));
    clock += 100;
    focusGuardNoteInput(win(4), clock, true);
    g_focus_user_action_tick = clock;
    try std.testing.expectEqual(@as(BOOL, 1), SetForegroundWindow(win(1)));
    try std.testing.expectEqual(win(3), SetFocus(win(3)));
}
test "unauthorized Chrome activation returns to exact console or composer and logs" {
    for ([_]HANDLE{ win(2), win(3) }) |target| {
        reset();
        focusGuardNoteInput(target, clock, true);
        clock += 200;
        foreground = win(4);
        try std.testing.expect(focusGuardReturnFromPane(win(4)));
        try std.testing.expectEqual(target, keyboard_focus);
        try std.testing.expectEqual(if (target == win(3)) win(1) else target, foreground);
        try std.testing.expectEqual(@as(usize, 1), returned_logs);
    }
}
test "physical pane click owns focus and stale refocus cannot undo it" {
    reset();
    focusGuardNoteInput(win(2), clock, true);
    clock += 100;
    g_focus_mouse_hwnd.store(4, .release);
    g_focus_mouse_tick.store(clock, .release);
    foreground = win(4);
    try std.testing.expect(!focusGuardReturnFromPane(win(4)));
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(2)));
    try std.testing.expectEqual(win(4), g_focus_return_hwnd);
}
test "new typing or foreign input supersedes delayed user focus requests" {
    reset();
    focusGuardNoteInput(win(2), clock, true);
    g_focus_user_action_tick = clock;
    clock += 10;
    focusGuardNoteInput(win(2), clock, true);
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(4)));
    g_focus_foreign_input_tick.store(clock + 1, .release);
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(4)));
    try std.testing.expectEqual(@as(HANDLE, null), g_focus_return_hwnd);
}
test "user authority expires after 1500 ms, protection after 3000 ms never fights foreign apps" {
    reset();
    focusGuardNoteInput(win(2), clock, true);
    g_focus_user_action_tick = clock;
    clock += 1501;
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(4)));
    g_focus_user_action_tick = 0;
    foreground = win(4);
    clock = 13001;
    try std.testing.expect(!focusGuardReturnFromPane(win(4)));
    foreground = win(9);
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(2)));
}
test "pane show and raise change visibility and z-order without activation" {
    reset();
    focusGuardNoteInput(win(2), clock, true);
    _ = ShowWindow(win(4), SW_SHOW);
    try std.testing.expectEqual(@as(i32, SW_SHOWNOACTIVATE), show_cmd);
    _ = ShowWindowAsync(win(4), SW_RESTORE);
    try std.testing.expectEqual(@as(i32, SW_SHOWNOACTIVATE), show_cmd);
    _ = SetWindowPos(win(4), null, 0, 0, 600, 400, 0);
    try std.testing.expect(position_flags & SWP_NOACTIVATE != 0);
    try std.testing.expectEqual(@as(usize, 0), activation_calls);
}
test "only user-posted messages propagate input authority, never agent bind or notification" {
    reset();
    focusGuardNoteInput(win(2), clock, true);
    g_focus_user_action_tick = clock;
    _ = PostMessageW(win(1), 0x8051, 0, 0);
    g_focus_user_action_tick = 0;
    try std.testing.expectEqual(@as(u64, 0), focusGuardDispatchTick(0x805d, 0, 0));
    try std.testing.expectEqual(clock, focusGuardDispatchTick(0x8051, 0, 0));
    try std.testing.expectEqual(@as(u64, 0), focusGuardDispatchTick(0x8051, 0, 0));
    try std.testing.expectEqual(@as(u64, 0), focusGuardDispatchTick(0x113, 0, 0));
    try std.testing.expectEqual(clock, focusGuardDispatchTick(WM_KEYDOWN, 0, 0));
    try std.testing.expectEqual(clock, focusGuardDispatchTick(@import("win32.zig").WM_NCLBUTTONDOWN, 0, 0));
    foreground = win(9);
    try std.testing.expect(!foregroundIsOurs());
    try std.testing.expectEqual(@as(u64, 0), focusGuardDispatchTick(@import("win32.zig").WM_NCLBUTTONDOWN, 0, 0));
}

test "a different active session cannot redirect restoration away from the user's console" {
    reset();
    focusGuardNoteInput(win(2), clock, true);
    active_shell = 1;
    clock += 50;
    foreground = win(6);
    try std.testing.expect(focusGuardReturnFromPane(win(6)));
    try std.testing.expectEqual(win(2), foreground);
    try std.testing.expectEqual(win(2), keyboard_focus);
}

test "activation grants a 1 s refocus to the typing surface only" {
    reset();
    focusGuardNoteInput(win(3), clock, true);
    clock += 5000;
    foreground = win(9);
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(3)));
    foreground = win(2);
    focusGuardNoteActivation();
    try std.testing.expectEqual(win(3), SetFocus(win(3)));
    try std.testing.expectEqual(@as(BOOL, 1), SetForegroundWindow(win(1)));
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(4)));
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(5)));
    foreground = win(9);
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(3)));
}

test "activation with no typing history refocuses the active console, then expires" {
    reset();
    clock += 5000;
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(2)));
    focusGuardNoteActivation();
    try std.testing.expectEqual(win(2), SetFocus(win(2)));
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(5)));
    clock += 1001;
    try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(2)));
}

test "ISSUE-372 Alt Tab restores the composer after foreign input without granting pane focus" {
    for ([_]bool{ false, true }) |atomic_input| {
        reset();
        g_chat_active = true;
        foreground = win(1);
        keyboard_focus = win(3);
        focusGuardNoteInput(win(3), clock, true);
        clock += 1;
        foreground = win(9);
        if (atomic_input) {
            g_focus_foreign_input_tick.store(clock, .release);
        } else {
            focusGuardNoteInput(null, clock, true);
        }
        foreground = win(1);
        keyboard_focus = win(1);
        focusGuardNoteActivation();
        try std.testing.expectEqual(win(3), SetFocus(win(3)));
        try std.testing.expectEqual(win(3), keyboard_focus);
        try std.testing.expectEqual(@as(HANDLE, null), g_focus_return_hwnd);
        try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(4)));
        clock += 1001;
        try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(3)));
        g_chat_active = false;
        focusGuardNoteActivation();
        try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(3)));
        try std.testing.expectEqual(win(2), SetFocus(win(2)));
        g_chat_active = true;
        g_chat_composer_hwnd = null;
        focusGuardNoteActivation();
        try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(3)));
        try std.testing.expectEqual(win(2), SetFocus(win(2)));
    }
}

test "activation with no known surface falls back to the active console" {
    try std.testing.expect(focusGuardActivationAllows(100, 200, true, win(2), null, win(1), win(2)));
    try std.testing.expect(!focusGuardActivationAllows(100, 200, true, win(5), null, win(1), win(2)));
    try std.testing.expect(!focusGuardActivationAllows(300, 200, true, win(2), null, win(1), win(2)));
    try std.testing.expect(!focusGuardActivationAllows(100, 200, false, win(2), null, win(1), win(2)));
}

test "typing and clicking a second pane never maps to the first owned pane" {
    reset();
    active_shell = 1;
    focusGuardNoteInput(win(6), clock, true);
    foreground = win(6);
    try std.testing.expectEqual(win(6), g_focus_return_hwnd);
    try std.testing.expect(!focusGuardReturnFromPane(win(6)));
    clock += 20;
    g_focus_mouse_hwnd.store(6, .release);
    g_focus_mouse_tick.store(clock, .release);
    focusGuardReadMouse();
    try std.testing.expectEqual(win(6), g_focus_return_hwnd);
    try std.testing.expectEqual(@as(BOOL, 0), SetForegroundWindow(win(4)));
}

test "user screenshot from foreign Chrome grants only the pasted input and frame; agent navigation stays blocked" {
    for ([_]HANDLE{ win(2), win(3) }) |target| {
        reset();
        foreground = win(9);
        try std.testing.expect(!focusGuard(target));
        g_focus_paste_target = target;
        g_focus_authorized_hwnd = target;
        g_focus_authorized_until = clock + 1500;
        try std.testing.expect(focusGuard(target));
        try std.testing.expect(focusGuard(win(1)));
        try std.testing.expect(!focusGuard(win(4)));
        try std.testing.expect(!focusGuard(win(5)));
        try std.testing.expect(!focusGuard(null));
        try std.testing.expectEqual(@as(BOOL, 1), AttachThreadInput(11, 19, 1));
        try std.testing.expectEqual(@as(BOOL, 1), SetForegroundWindow(target));
        try std.testing.expectEqual(target, SetFocus(target));
        g_focus_paste_target = null;
        foreground = win(9);
        try std.testing.expect(!focusGuard(target));
        try std.testing.expect(!focusGuard(win(4)));
    }
}

test "ISSUE-451 frame remembered during Chat activation allows composer with frame or null focus" {
    for ([_]HANDLE{ win(1), null }) |focused| {
        reset();
        g_chat_active = true;
        foreground = win(1);
        keyboard_focus = focused;
        focusGuardNoteInput(win(1), clock, false);
        focusGuardNoteActivation();
        try std.testing.expect(focusGuardComposerRepairAllowed());
        try std.testing.expect(focusGuard(win(3)));
        _ = SetFocus(win(3));
        try std.testing.expectEqual(win(3), keyboard_focus);
    }
}

test "ISSUE-451 remembered composer allows raising frame but refuses keyboard focus without user action" {
    for ([_]bool{ false, true }) |activating| {
        reset();
        g_chat_active = true;
        foreground = win(1);
        keyboard_focus = win(3);
        focusGuardNoteInput(win(3), clock, true);
        if (activating) focusGuardNoteActivation();
        try std.testing.expectEqual(@as(HANDLE, null), SetFocus(win(1)));
        try std.testing.expectEqual(win(3), keyboard_focus);
        try std.testing.expectEqual(@as(BOOL, 1), SetForegroundWindow(win(1)));
        try std.testing.expectEqual(win(3), keyboard_focus);
        g_focus_user_action_tick = clock;
        _ = SetFocus(win(1));
        try std.testing.expectEqual(win(1), keyboard_focus);
    }
}

test "ISSUE-451 activation container fallback rejects expiry foreign foreground and remembered pane or external target" {
    try std.testing.expect(focusGuardActivationAllows(100, 200, true, win(3), win(1), win(1), win(3)));
    try std.testing.expect(!focusGuardActivationAllows(201, 200, true, win(3), win(1), win(1), win(3)));
    try std.testing.expect(!focusGuardActivationAllows(100, 200, false, win(3), win(1), win(1), win(3)));
    for ([_]HANDLE{ win(4), win(6), win(9) }) |remembered| {
        try std.testing.expect(!focusGuardActivationAllows(100, 200, true, win(3), remembered, win(1), win(3)));
    }
}

test "ISSUE-451 activation repair refuses editor find overlays pane modal and expired or competing ownership" {
    reset();
    g_chat_active = true;
    foreground = win(1);
    keyboard_focus = win(1);
    focusGuardNoteInput(win(1), clock, false);
    focusGuardNoteActivation();
    try std.testing.expect(focusGuardComposerRepairAllowed());
    const owners = [_]*bool{ &g_search_active, &g_inbox_active, &g_shortcuts_active, &g_changelog_active, &g_url_picker_active, &g_all_sessions_active, &g_snippet_create_active, &g_chat_find_open };
    for (owners) |owner| {
        owner.* = true;
        try std.testing.expect(!focusGuardComposerRepairAllowed());
        try std.testing.expect(!focusGuard(win(3)));
        owner.* = false;
    }
    g_edit_hwnd = win(7);
    try std.testing.expect(!focusGuardComposerRepairAllowed());
    try std.testing.expect(!focusGuard(win(3)));
    g_edit_hwnd = null;
    g_native_browser_focus_pending_shell_id = 10;
    try std.testing.expect(!focusGuard(win(3)));
    g_native_browser_focus_pending_shell_id = 0;
    g_chat_browser_handoff_until = clock + 100;
    try std.testing.expect(!focusGuard(win(3)));
    g_chat_browser_handoff_until = 0;
    for ([_]HANDLE{ win(4), win(7), win(9), win(8) }) |focused| {
        keyboard_focus = focused;
        try std.testing.expect(!focusGuardComposerRepairAllowed());
        try std.testing.expect(!focusGuard(win(3)));
    }
    keyboard_focus = win(1);
    for ([_]HANDLE{ win(4), win(9), win(8) }) |fg| {
        foreground = fg;
        try std.testing.expect(!focusGuardComposerRepairAllowed());
        try std.testing.expect(!focusGuard(win(3)));
    }
    foreground = win(1);
    for ([_]HANDLE{ win(4), win(9) }) |remembered| {
        g_focus_return_hwnd = remembered;
        try std.testing.expect(!focusGuardComposerRepairAllowed());
        try std.testing.expect(!focusGuard(win(3)));
    }
    g_focus_return_hwnd = win(1);
    clock += 1001;
    try std.testing.expect(!focusGuardComposerRepairAllowed());
    try std.testing.expect(!focusGuard(win(3)));
}
