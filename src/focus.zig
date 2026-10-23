const app_state = @import("app_state.zig");
const std = @import("std");
const WINAPI = @import("win32.zig").WINAPI;
const BOOL = @import("win32.zig").BOOL;
const DWORD = @import("win32.zig").DWORD;
const UINT = @import("win32.zig").UINT;
const LONG = @import("win32.zig").LONG;
const LONG_PTR = @import("win32.zig").LONG_PTR;
const WPARAM = @import("win32.zig").WPARAM;
const LPARAM = @import("win32.zig").LPARAM;
const HANDLE = @import("win32.zig").HANDLE;
const WS_POPUP = @import("win32.zig").WS_POPUP;
const WS_CHILD = @import("win32.zig").WS_CHILD;
const WS_CAPTION = @import("win32.zig").WS_CAPTION;
const WS_THICKFRAME = @import("win32.zig").WS_THICKFRAME;
const WS_BORDER = @import("win32.zig").WS_BORDER;
const GWL_STYLE = @import("win32.zig").GWL_STYLE;
const GWL_EXSTYLE = @import("win32.zig").GWL_EXSTYLE;
const GWLP_HWNDPARENT = @import("win32.zig").GWLP_HWNDPARENT;
const SWP_FRAMECHANGED = @import("win32.zig").SWP_FRAMECHANGED;
const SWP_NOZORDER = @import("win32.zig").SWP_NOZORDER;
const SWP_NOACTIVATE = @import("win32.zig").SWP_NOACTIVATE;
const WS_EX_TOOLWINDOW = @import("win32.zig").WS_EX_TOOLWINDOW;
const WS_EX_NOACTIVATE = @import("win32.zig").WS_EX_NOACTIVATE;
const GW_HWNDFIRST = @import("win32.zig").GW_HWNDFIRST;
const GW_HWNDLAST = @import("win32.zig").GW_HWNDLAST;
const GW_HWNDNEXT = @import("win32.zig").GW_HWNDNEXT;
const GW_HWNDPREV = @import("win32.zig").GW_HWNDPREV;
const WM_LBUTTONDOWN = @import("win32.zig").WM_LBUTTONDOWN;
const WM_LBUTTONUP = @import("win32.zig").WM_LBUTTONUP;
const WM_LBUTTONDBLCLK = @import("win32.zig").WM_LBUTTONDBLCLK;
const SW_SHOW = @import("win32.zig").SW_SHOW;
const SW_SHOWNOACTIVATE = @import("win32.zig").SW_SHOWNOACTIVATE;
const SW_RESTORE = @import("win32.zig").SW_RESTORE;
const WH_KEYBOARD_LL = @import("win32.zig").WH_KEYBOARD_LL;
const WH_MOUSE_LL = @import("win32.zig").WH_MOUSE_LL;
const EVENT_SYSTEM_FOREGROUND = @import("win32.zig").EVENT_SYSTEM_FOREGROUND;
const EVENT_OBJECT_DESTROY = @import("win32.zig").EVENT_OBJECT_DESTROY;
const WINEVENT_OUTOFCONTEXT = @import("win32.zig").WINEVENT_OUTOFCONTEXT;
const OBJID_WINDOW = @import("win32.zig").OBJID_WINDOW;
const WM_KEYDOWN = @import("win32.zig").WM_KEYDOWN;
const WM_APP_OPEN_URL_AT = @import("win32.zig").WM_APP_OPEN_URL_AT;
const WM_MOUSEWHEEL = @import("win32.zig").WM_MOUSEWHEEL;
const TIMER_REFOCUS = @import("win32.zig").TIMER_REFOCUS;
const TIMER_NATIVE_BROWSER_FOCUS = @import("win32.zig").TIMER_NATIVE_BROWSER_FOCUS;
const TIMER_CHAT_FOREGROUND_RETRY = @import("win32.zig").TIMER_CHAT_FOREGROUND_RETRY;
const RECT = @import("win32.zig").RECT;
const IsIconic = @import("win32.zig").IsIconic;
const IsChild = @import("win32.zig").IsChild;
const GetFocus = @import("win32.zig").GetFocus;
const GUITHREADINFO = @import("win32.zig").GUITHREADINFO;
const GetGUIThreadInfo = @import("win32.zig").GetGUIThreadInfo;
const GetWindowRect = @import("win32.zig").GetWindowRect;
const SW_MAXIMIZE = @import("win32.zig").SW_MAXIMIZE;
const IsWindow = @import("win32.zig").IsWindow;
const IsWindowVisible = @import("win32.zig").IsWindowVisible;
const GetWindow = @import("win32.zig").GetWindow;
const GetLastActivePopup = @import("win32.zig").GetLastActivePopup;
const GetPropW = @import("win32.zig").GetPropW;
const SetParent = @import("win32.zig").SetParent;
const SetWindowLongPtrW = @import("win32.zig").SetWindowLongPtrW;
const GetWindowLongPtrW = @import("win32.zig").GetWindowLongPtrW;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const InternalGetWindowText = @import("win32.zig").InternalGetWindowText;
const GetForegroundWindow = @import("win32.zig").GetForegroundWindow;
const GetAsyncKeyState = @import("win32.zig").GetAsyncKeyState;
const SetWindowsHookExW = @import("win32.zig").SetWindowsHookExW;
const UnhookWindowsHookEx = @import("win32.zig").UnhookWindowsHookEx;
const SetWinEventHook = @import("win32.zig").SetWinEventHook;
const UnhookWinEvent = @import("win32.zig").UnhookWinEvent;
const Sleep = @import("win32.zig").Sleep;
const GetModuleHandleW = @import("win32.zig").GetModuleHandleW;
const GetLastError = @import("win32.zig").GetLastError;
const DwmGetWindowAttribute = @import("win32.zig").DwmGetWindowAttribute;
const GetWindowThreadProcessId = @import("win32.zig").GetWindowThreadProcessId;
const GetCurrentThreadId = @import("win32.zig").GetCurrentThreadId;
const GetCurrentProcessId = @import("win32.zig").GetCurrentProcessId;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const GetParent = @import("win32.zig").GetParent;
const GetAncestor = @import("win32.zig").GetAncestor;
const WM_RBUTTONDOWN = @import("win32.zig").WM_RBUTTONDOWN;
const L = @import("startup.zig").L;
const GA_ROOT = @import("app_state.zig").GA_ROOT;
const GA_ROOTOWNER = @import("app_state.zig").GA_ROOTOWNER;
const FocusNative = @import("app_state.zig").FocusNative;
const SYSTEM_ALT_TAB_SUPPRESS_MS = @import("app_state.zig").SYSTEM_ALT_TAB_SUPPRESS_MS;
const HOOK_REINSTALL_THROTTLE_MS = @import("app_state.zig").HOOK_REINSTALL_THROTTLE_MS;
const BrowserPopupEvidence = @import("app_state.zig").BrowserPopupEvidence;
const BrowserPopupDisposition = @import("app_state.zig").BrowserPopupDisposition;
const u16ContainsU8Insensitive = @import("shell_poll.zig").u16ContainsU8Insensitive;
const verboseLoggingEnabled = @import("diagnostics.zig").verboseLoggingEnabled;
const focusTrace = @import("diagnostics.zig").focusTrace;
const debugLog = @import("diagnostics.zig").debugLog;
const browserTrace = @import("diagnostics.zig").browserTrace;
const altqLog = @import("diagnostics.zig").altqLog;
const altqPtr = @import("diagnostics.zig").altqPtr;
const appendDecimal = @import("diagnostics.zig").appendDecimal;
const GetClassNameW = @import("win32.zig").GetClassNameW;
const keybd_event = @import("win32.zig").keybd_event;
const VK_MENU = @import("app_state.zig").VK_MENU;
const KEYEVENTF_KEYUP = @import("app_state.zig").KEYEVENTF_KEYUP;
const activeBrowserHwndLive = @import("browser_pane.zig").activeBrowserHwndLive;
const activeBrowserHasForegroundFocus = @import("browser_pane.zig").activeBrowserHasForegroundFocus;
const activeBrowserTransientPopupHasForegroundFocus = @import("browser_pane.zig").activeBrowserTransientPopupHasForegroundFocus;
const leftMouseButtonDown = @import("browser_pane.zig").leftMouseButtonDown;
const syncPaneFocusModeFromForeground = @import("browser_pane.zig").syncPaneFocusModeFromForeground;
const clearSelectedTabDotOnReturn = @import("sidebar.zig").clearSelectedTabDotOnReturn;
const activePaneBorderOn = @import("browser_pane.zig").activePaneBorderOn;
const paneRingState = @import("browser_pane.zig").paneRingState;
const paneRingRepaintNeeded = @import("browser_pane.zig").paneRingRepaintNeeded;
const invalidateBrowserBottomMask = @import("browser_pane.zig").invalidateBrowserBottomMask;
const hideBrowserEdgeMasks = @import("browser_pane.zig").hideBrowserEdgeMasks;
const suspendBrowserEdgeMaskRaiseForPopup = @import("browser_pane.zig").suspendBrowserEdgeMaskRaiseForPopup;
const armBrowserEdgeMaskRaise = @import("browser_pane.zig").armBrowserEdgeMaskRaise;
const webView2OwnsActiveShell = @import("browser_pane.zig").webView2OwnsActiveShell;
const chatComposerFocusAllowed = @import("chat_composer.zig").chatComposerFocusAllowed;
const chatViewOwnsInput = @import("chat_composer.zig").chatViewOwnsInput;
const WM_SYSKEYDOWN = @import("app_state.zig").WM_SYSKEYDOWN;
const keyboardHookProc = @import("shortcuts.zig").keyboardHookProc;
const armStaleAltBrowserClickRepair = @import("shortcuts.zig").armStaleAltBrowserClickRepair;
const mouseHookProc = @import("shortcuts.zig").mouseHookProc;
const SetTimer = @import("win32.zig").SetTimer;
const KillTimer = @import("win32.zig").KillTimer;

fn focusGuardPolicy(now: u64, action_tick: u64, same_surface: bool, authorized: bool, foreground_owned: bool) bool {
    return (action_tick != 0 and now >= action_tick and now - action_tick <= 1500) or
        (foreground_owned and (same_surface or authorized));
}

fn focusGuardActivationAllows(now: u64, until: u64, foreground_owned: bool, target: HANDLE, return_hwnd: HANDLE, main_hwnd: HANDLE, active_console: HANDLE) bool {
    if (target == null or !foreground_owned or now > until) return false;
    if (return_hwnd != null and return_hwnd != main_hwnd) return target == return_hwnd or target == main_hwnd;
    return target == main_hwnd or target == active_console;
}

pub fn focusGuardNoteActivation() void {
    app_state.g_focus_activation_until = GetTickCount64() + 1000;
}

fn focusGuardSurface(hwnd: HANDLE) HANDLE {
    if (hwnd == null) return null;
    const root = GetAncestor(hwnd, GA_ROOT);
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].browser_hwnd) |bh| {
            if (hwnd == bh or root == bh) return bh;
        }
        if (app_state.shells[i].hwnd) |sh| {
            if (hwnd == sh or IsChild(sh, hwnd) != 0) return sh;
        }
    }
    if (hwnd == app_state.g_main_hwnd or IsChild(app_state.g_main_hwnd, hwnd) != 0 or GetAncestor(hwnd, GA_ROOTOWNER) == app_state.g_main_hwnd) return hwnd;
    return null;
}

pub fn focusGuardNoteInput(hwnd: HANDLE, tick: u64, typing: bool) void {
    if (tick < app_state.g_focus_input_tick) return;
    app_state.g_focus_input_tick = tick;
    app_state.g_focus_return_hwnd = focusGuardSurface(hwnd);
    app_state.g_focus_authorized_hwnd = null;
    app_state.g_focus_authorized_until = 0;
    app_state.g_focus_browser_shell_id = 0;
    app_state.g_focus_typing_tick = if (typing and app_state.g_focus_return_hwnd != null) tick else 0;
}

pub fn focusGuardReadMouse() void {
    const foreign_tick = app_state.g_focus_foreign_input_tick.load(.acquire);
    if (foreign_tick > app_state.g_focus_input_tick) focusGuardNoteInput(null, foreign_tick, false);
    const tick = app_state.g_focus_mouse_tick.load(.acquire);
    if (tick == 0 or tick == app_state.g_focus_mouse_seen) return;
    app_state.g_focus_mouse_seen = tick;
    const hwnd: HANDLE = @ptrFromInt(app_state.g_focus_mouse_hwnd.load(.acquire));
    focusGuardNoteInput(hwnd, tick, false);
}

pub fn PostMessageW(hwnd: HANDLE, msg: UINT, wp: WPARAM, lp: LPARAM) BOOL {
    if (hwnd == app_state.g_main_hwnd and GetCurrentThreadId() == GetWindowThreadProcessId(app_state.g_main_hwnd, null) and app_state.g_focus_user_action_tick != 0) {
        const slot = &app_state.g_focus_user_messages[app_state.g_focus_user_message_next];
        slot.* = .{ .msg = msg, .wp = wp, .lp = lp, .tick = app_state.g_focus_user_action_tick };
        app_state.g_focus_user_message_next = (app_state.g_focus_user_message_next + 1) % app_state.g_focus_user_messages.len;
        const result = FocusNative.PostMessageW(hwnd, msg, wp, lp);
        if (result == 0) slot.tick = 0;
        return result;
    }
    return FocusNative.PostMessageW(hwnd, msg, wp, lp);
}

pub fn focusGuardDispatchTick(msg: UINT, wp: WPARAM, lp: LPARAM) u64 {
    focusGuardReadMouse();
    const now = GetTickCount64();
    if (msg == WM_APP_OPEN_URL_AT and lp > 0 and @as(u64, @intCast(lp)) == app_state.g_focus_mouse_seen and now -| app_state.g_focus_mouse_seen <= 1500) return app_state.g_focus_mouse_seen;
    for (&app_state.g_focus_user_messages) |*entry| {
        if (entry.tick != 0 and entry.msg == msg and entry.wp == wp and entry.lp == lp) {
            const tick = entry.tick;
            entry.tick = 0;
            return if (now -| tick <= 1500) tick else 0;
        }
    }
    const native_input = switch (msg) {
        WM_KEYDOWN, WM_SYSKEYDOWN, 0x0102, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK, WM_RBUTTONDOWN, 0x0205, WM_MOUSEWHEEL => true,
        else => false,
    };
    return if (native_input and app_state.g_focus_input_tick != 0 and now -| app_state.g_focus_input_tick <= 1500 and foregroundIsOurs()) app_state.g_focus_input_tick else 0;
}

fn focusGuardPasteAllows(target: HANDLE, paste_target: HANDLE, main_hwnd: HANDLE) bool {
    return target != null and paste_target != null and
        (target == paste_target or (target == main_hwnd and IsChild(main_hwnd, paste_target) != 0));
}

pub noinline fn focusGuard(target: HANDLE) bool {
    return focusGuardAt(target, @returnAddress(), false);
}

fn focusGuardAt(target: HANDLE, caller: usize, raise_container: bool) bool {
    focusGuardReadMouse();
    const now = GetTickCount64();
    if (focusGuardPasteAllows(target, app_state.g_focus_paste_target, app_state.g_main_hwnd)) {
        focusTrace(.allowed, target, caller);
        return true;
    }
    const action_tick = if (app_state.g_focus_user_action_tick >= app_state.g_focus_input_tick) app_state.g_focus_user_action_tick else 0;
    const user_action = action_tick != 0 and now -| action_tick <= 1500;
    const pane_authorized = app_state.active_shell < app_state.shell_count and app_state.g_focus_browser_shell_id == app_state.shells[app_state.active_shell].shell_id and
        target != null and target == app_state.shells[app_state.active_shell].browser_hwnd and now <= app_state.g_focus_authorized_until;
    const authorized = now <= app_state.g_focus_authorized_until and (target == app_state.g_focus_authorized_hwnd or pane_authorized or
        (target == app_state.g_main_hwnd and app_state.g_focus_authorized_hwnd != null and IsChild(app_state.g_main_hwnd, app_state.g_focus_authorized_hwnd) != 0));
    const same_surface = target != null and (target == app_state.g_focus_return_hwnd or
        (raise_container and target == app_state.g_main_hwnd and app_state.g_focus_return_hwnd != null and !focusGuardConsole(app_state.g_focus_return_hwnd) and IsChild(app_state.g_main_hwnd, app_state.g_focus_return_hwnd) != 0));
    if (target != null and focusGuardPolicy(now, action_tick, same_surface, authorized, foregroundIsOurs())) {
        if (user_action) {
            app_state.g_focus_authorized_hwnd = target;
            app_state.g_focus_authorized_until = app_state.g_focus_user_action_tick + 1500;
        }
        focusTrace(.allowed, target, caller);
        return true;
    }
    if ((raise_container or target != app_state.g_main_hwnd or app_state.g_focus_return_hwnd == null or app_state.g_focus_return_hwnd == app_state.g_main_hwnd) and focusGuardActivationAllows(now, app_state.g_focus_activation_until, foregroundIsOurs(), target, app_state.g_focus_return_hwnd, app_state.g_main_hwnd, focusGuardActivationTarget())) {
        focusTrace(.activation_refocus, target, caller);
        return true;
    }
    focusTrace(.blocked, target, caller);
    return false;
}

pub noinline fn SetForegroundWindow(hwnd: HANDLE) BOOL {
    if (!focusGuardAt(hwnd, @returnAddress(), true)) return 0;
    const result = FocusNative.SetForegroundWindow(hwnd);
    if (result != 0 and hwnd != app_state.g_main_hwnd) focusGuardLanded(hwnd);
    return result;
}

pub noinline fn SetFocus(hwnd: HANDLE) HANDLE {
    if (!focusGuardAt(hwnd, @returnAddress(), false)) return null;
    const result = FocusNative.SetFocus(hwnd);
    if (GetFocus() == hwnd) focusGuardLanded(hwnd);
    return result;
}

fn focusGuardLanded(hwnd: HANDLE) void {
    const now = GetTickCount64();
    const requested_pane = app_state.active_shell < app_state.shell_count and app_state.g_focus_browser_shell_id == app_state.shells[app_state.active_shell].shell_id and hwnd == app_state.shells[app_state.active_shell].browser_hwnd;
    if (hwnd == app_state.g_focus_paste_target or (app_state.g_focus_user_action_tick != 0 and now -| app_state.g_focus_user_action_tick <= 1500) or
        (now <= app_state.g_focus_authorized_until and (hwnd == app_state.g_focus_authorized_hwnd or requested_pane)))
    {
        if (app_state.g_focus_return_hwnd != hwnd) app_state.g_focus_typing_tick = 0;
        app_state.g_focus_return_hwnd = focusGuardSurface(hwnd);
        app_state.g_focus_authorized_hwnd = null;
        app_state.g_focus_authorized_until = 0;
        app_state.g_focus_browser_shell_id = 0;
        @import("workspaces.zig").captureWorkspaceFocus();
    }
}

pub noinline fn AttachThreadInput(from: DWORD, to: DWORD, attach: BOOL) BOOL {
    if (attach != 0 and !focusGuardAt(if (app_state.g_focus_authorized_hwnd != null) app_state.g_focus_authorized_hwnd else if (app_state.g_focus_return_hwnd != null) app_state.g_focus_return_hwnd else activeShellHwndForFocusGuard(), @returnAddress(), false)) return 0;
    return FocusNative.AttachThreadInput(from, to, attach);
}

pub noinline fn SwitchToThisWindow(hwnd: HANDLE, alt_tab: BOOL) void {
    if (focusGuardAt(hwnd, @returnAddress(), false)) FocusNative.SwitchToThisWindow(hwnd, alt_tab);
}

pub noinline fn AllowSetForegroundWindow(pid: DWORD) BOOL {
    if (!focusGuardAt(app_state.g_main_hwnd, @returnAddress(), false)) return 0;
    return FocusNative.AllowSetForegroundWindow(pid);
}

pub noinline fn ShowWindow(hwnd: HANDLE, cmd: i32) BOOL {
    const activating = cmd == SW_SHOW or cmd == SW_RESTORE or cmd == SW_MAXIMIZE;
    return FocusNative.ShowWindow(hwnd, if (activating and !focusGuardAt(hwnd, @returnAddress(), false)) SW_SHOWNOACTIVATE else cmd);
}

pub noinline fn ShowWindowAsync(hwnd: HANDLE, cmd: i32) BOOL {
    const activating = cmd == SW_SHOW or cmd == SW_RESTORE or cmd == SW_MAXIMIZE;
    return FocusNative.ShowWindowAsync(hwnd, if (activating and !focusGuardAt(hwnd, @returnAddress(), false)) SW_SHOWNOACTIVATE else cmd);
}

pub fn SetWindowPos(hwnd: HANDLE, after: HANDLE, x: i32, y: i32, w: i32, h: i32, flags: UINT) BOOL {
    return FocusNative.SetWindowPos(hwnd, after, x, y, w, h, flags | SWP_NOACTIVATE);
}

pub fn focusGuardReturnFromPane(hwnd: HANDLE) bool {
    focusGuardReadMouse();
    if (app_state.g_focus_restoring or app_state.g_focus_return_hwnd == null or hwnd == app_state.g_focus_return_hwnd) return false;
    const now = GetTickCount64();
    if (app_state.g_focus_typing_tick == 0 or now -| app_state.g_focus_typing_tick > 3000 or IsWindow(app_state.g_focus_return_hwnd) == 0) return false;
    var is_pane = false;
    const root = GetAncestor(hwnd, GA_ROOT);
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].browser_hwnd) |bh| {
            if (hwnd == bh or root == bh) {
                if (app_state.g_focus_browser_shell_id == app_state.shells[i].shell_id and now <= app_state.g_focus_authorized_until) return false;
                is_pane = true;
                break;
            }
        }
    }
    if (!is_pane or (hwnd == app_state.g_focus_authorized_hwnd and now <= app_state.g_focus_authorized_until)) return false;
    const target = app_state.g_focus_return_hwnd;
    if (!focusGuard(target)) return false;
    app_state.g_focus_restoring = true;
    defer app_state.g_focus_restoring = false;
    const our_thread = GetCurrentThreadId();
    const pane_thread = GetWindowThreadProcessId(hwnd, null);
    const target_thread = GetWindowThreadProcessId(target, null);
    const pane_attached = pane_thread != our_thread and AttachThreadInput(our_thread, pane_thread, 1) != 0;
    const target_attached = target_thread != our_thread and target_thread != pane_thread and AttachThreadInput(our_thread, target_thread, 1) != 0;
    const foreground_target = if (IsChild(app_state.g_main_hwnd, target) != 0 and !focusGuardConsole(target)) app_state.g_main_hwnd else target;
    _ = SetForegroundWindow(foreground_target);
    _ = SetFocus(target);
    if (target_attached) _ = AttachThreadInput(our_thread, target_thread, 0);
    if (pane_attached) _ = AttachThreadInput(our_thread, pane_thread, 0);
    if (GetForegroundWindow() == foreground_target) {
        app_state.g_browser_focus_mode = false;
        app_state.g_shell_focused = true;
        debugLog("focus guard: returned focus to user's typing surface");
        return true;
    }
    return false;
}

fn focusGuardConsole(hwnd: HANDLE) bool {
    for (0..app_state.shell_count) |i| {
        if (hwnd != null and hwnd == app_state.shells[i].hwnd) return true;
    }
    return false;
}

pub fn activeShellHwndForFocusGuard() HANDLE {
    return if (app_state.active_shell < app_state.shell_count) app_state.shells[app_state.active_shell].hwnd else null;
}
pub fn focusGuardActivationTarget() HANDLE {
    if (app_state.g_chat_active and app_state.g_chat_composer_hwnd != null) {
        const focused = GetFocus();
        return if (chatComposerFocusAllowed() and (focused == null or focused == app_state.g_main_hwnd)) app_state.g_chat_composer_hwnd else null;
    }
    return activeShellHwndForFocusGuard();
}
pub fn focusGuardComposerRepairAllowed() bool {
    return app_state.g_chat_composer_hwnd != null and focusGuardActivationTarget() == app_state.g_chat_composer_hwnd and focusGuard(app_state.g_chat_composer_hwnd);
}
pub fn installHook() void {
    if (app_state.g_hook == null) {
        var attempt: u8 = 0;
        while (attempt < 4) : (attempt += 1) {
            app_state.g_hook = SetWindowsHookExW(WH_KEYBOARD_LL, keyboardHookProc, GetModuleHandleW(null), 0);
            if (app_state.g_hook != null) break;
            const err = GetLastError();
            var buf: [80]u8 = undefined;
            var pos: usize = 0;
            const tag = "installHook: KEYBOARD_LL retry=";
            @memcpy(buf[0..tag.len], tag);
            pos = tag.len;
            appendDecimal(&buf, &pos, attempt);
            const tag2 = " err=";
            @memcpy(buf[pos .. pos + tag2.len], tag2);
            pos += tag2.len;
            appendDecimal(&buf, &pos, err);
            debugLog(buf[0..pos]);
            Sleep(80);
        }
        if (app_state.g_hook == null) {
            debugLog("installHook: KEYBOARD_LL gave up after retries");
        }
        if (app_state.g_hook != null) {
            app_state.g_last_kb_hook_tick = GetTickCount64();
            debugLog("installHook: KEYBOARD_LL installed");
        }
    }
}

pub fn installMouseHook() void {
    if (app_state.g_mouse_hook == null) {
        var attempt: u8 = 0;
        while (attempt < 4) : (attempt += 1) {
            app_state.g_mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, mouseHookProc, GetModuleHandleW(null), 0);
            if (app_state.g_mouse_hook != null) break;
            const err = GetLastError();
            var buf: [80]u8 = undefined;
            var pos: usize = 0;
            const tag = "installHook: MOUSE_LL retry=";
            @memcpy(buf[0..tag.len], tag);
            pos = tag.len;
            appendDecimal(&buf, &pos, attempt);
            const tag2 = " err=";
            @memcpy(buf[pos .. pos + tag2.len], tag2);
            pos += tag2.len;
            appendDecimal(&buf, &pos, err);
            debugLog(buf[0..pos]);
            Sleep(80);
        }
        if (app_state.g_mouse_hook == null) {
            debugLog("installHook: MOUSE_LL gave up after retries");
        }
        if (app_state.g_mouse_hook != null) app_state.g_last_mouse_hook_tick = GetTickCount64();
    }
}

fn foregroundWinEventProc(hook: HANDLE, event: DWORD, hwnd: HANDLE, idObject: LONG, idChild: LONG, eventThread: DWORD, eventTime: DWORD) callconv(WINAPI) void {
    _ = hook;
    _ = eventThread;
    _ = eventTime;
    if (event != EVENT_SYSTEM_FOREGROUND) return;
    if (idObject != OBJID_WINDOW or idChild != 0) return;
    @import("main.zig").sessionFrontChanged();
    if (focusGuardReturnFromPane(hwnd)) return;
    syncPaneFocusModeFromForeground(hwnd, leftMouseButtonDown());
    clearSelectedTabDotOnReturn();
    if (app_state.g_main_hwnd == null) return;
    if (foregroundHwndIsOurs(hwnd)) {
        const browser_popup_active = activeBrowserTransientPopupHasForegroundFocus();
        if (browser_popup_active) {
            browserTrace("FGevt Edge popup -> suspend maskRaise");
            suspendBrowserEdgeMaskRaiseForPopup();
        } else {
            browserTrace("FGevt ours -> maskRaise(z)");
        }
        if (!browser_popup_active and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
            armBrowserEdgeMaskRaise();
        }
    } else {
        browserTrace("FGevt not-ours -> hide masks");
        hideBrowserEdgeMasks();
    }
    if (paneRingRepaintNeeded(&app_state.g_pane_ring_state, paneRingState()) and activePaneBorderOn()) {
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
        invalidateBrowserBottomMask();
    }
}

fn browserOrphanWinEventProc(hook: HANDLE, event: DWORD, hwnd: HANDLE, idObject: LONG, idChild: LONG, eventThread: DWORD, eventTime: DWORD) callconv(WINAPI) void {
    _ = hook;
    _ = hwnd;
    _ = eventThread;
    _ = eventTime;
    if (event == EVENT_OBJECT_DESTROY and idObject == OBJID_WINDOW and idChild == 0 and !app_state.g_app_closing) app_state.g_browser_orphan_dirty = true;
}

pub fn installForegroundHook() void {
    if (app_state.g_browser_orphan_hook == null) {
        app_state.g_browser_orphan_hook = SetWinEventHook(EVENT_OBJECT_DESTROY, EVENT_OBJECT_DESTROY, null, browserOrphanWinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT);
        if (app_state.g_browser_orphan_hook == null) debugLog("browser orphan: destroy hook unavailable, polling");
    }
    if (app_state.g_foreground_hook != null) return;
    app_state.g_foreground_hook = SetWinEventHook(
        EVENT_SYSTEM_FOREGROUND,
        EVENT_SYSTEM_FOREGROUND,
        null,
        foregroundWinEventProc,
        0,
        0,
        WINEVENT_OUTOFCONTEXT,
    );
    if (app_state.g_foreground_hook == null) debugLog("installHook: foreground WinEvent hook failed");
}

pub fn uninstallForegroundHook() void {
    if (app_state.g_browser_orphan_hook != null) {
        _ = UnhookWinEvent(app_state.g_browser_orphan_hook);
        app_state.g_browser_orphan_hook = null;
    }
    app_state.g_browser_orphan_dirty = false;
    if (app_state.g_foreground_hook != null) {
        _ = UnhookWinEvent(app_state.g_foreground_hook);
        app_state.g_foreground_hook = null;
    }
}

pub fn forceReinstallHooks() void {
    uninstallHook();
    installHook();
    syncMouseHookForUrlClicks();
}

pub fn forceReinstallHooksThrottled() void {
    const now = GetTickCount64();
    if (app_state.g_hook != null and now -| app_state.g_last_hook_reinstall_tick < HOOK_REINSTALL_THROTTLE_MS) {
        syncMouseHookForUrlClicks();
        return;
    }
    app_state.g_last_hook_reinstall_tick = now;
    forceReinstallHooks();
}

pub fn uninstallHook() void {
    uninstallKeyboardHook();
    uninstallMouseHook();
}

pub fn uninstallKeyboardHook() void {
    app_state.g_browser_toggle_chord_held = false;
    app_state.g_chat_toggle_chord_held = false;
    app_state.g_browser_focus_chord_held = false;
    app_state.g_palette_chord_held = false;
    app_state.g_favorite_chord_held = false;
    app_state.g_screenshot_chord_held = false;
    app_state.g_tab_url_chord_held = false;
    if (app_state.g_hook != null) {
        _ = UnhookWindowsHookEx(app_state.g_hook);
        app_state.g_hook = null;
    }
}

pub fn uninstallMouseHook() void {
    if (app_state.g_mouse_hook != null) {
        _ = UnhookWindowsHookEx(app_state.g_mouse_hook);
        app_state.g_mouse_hook = null;
    }
}

fn wantMouseHookForUrlClicks() bool {
    if (app_state.g_main_hwnd != null and IsIconic(app_state.g_main_hwnd) != 0) return false;
    return app_state.active_shell < app_state.shell_count and
        (app_state.shells[app_state.active_shell].browser_enabled or webView2OwnsActiveShell() or app_state.g_external_browser_links) and
        isCtrlDown();
}

pub fn syncMouseHookForUrlClicks() void {
    if (wantMouseHookForUrlClicks()) {
        installMouseHook();
    } else {
        uninstallMouseHook();
    }
}

pub fn isCtrlDown() bool {
    return (GetAsyncKeyState(0x11) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
}

pub fn browserFocusChord(msg: usize, vk: usize, ctrl: bool, alt: bool) bool {
    return (msg == WM_KEYDOWN or msg == WM_SYSKEYDOWN) and alt and !ctrl and (vk == 0x51 or vk == 0x4D);
}

test "ISSUE-716 Alt+Q and Alt+M escape Find in both keydown forms" {
    for ([_]usize{ WM_KEYDOWN, WM_SYSKEYDOWN }) |msg| {
        for ([_]usize{ 0x51, 0x4D }) |vk| {
            try std.testing.expect(browserFocusChord(msg, vk, false, true));
            try std.testing.expect(!browserFocusChord(msg, vk, true, true));
            try std.testing.expect(!browserFocusChord(msg, vk, false, false));
        }
    }
    try std.testing.expect(!browserFocusChord(0x0101, 0x51, false, true));
    try std.testing.expect(!browserFocusChord(0x0105, 0x4D, false, true));
    try std.testing.expect(!browserFocusChord(WM_SYSKEYDOWN, 0x41, false, true));
}

pub fn browserFocusReturnsToInput(pane_present: bool, chat_owns: bool, focus_drifted: bool) bool {
    return !pane_present or (chat_owns and focus_drifted);
}

test "ISSUE-716 no pane always restores input and drifted Chat View returns to the composer" {
    for ([_]bool{ false, true }) |chat_owns| {
        for ([_]bool{ false, true }) |drifted| {
            try std.testing.expect(browserFocusReturnsToInput(false, chat_owns, drifted));
        }
    }
    try std.testing.expect(browserFocusReturnsToInput(true, true, true));
    try std.testing.expect(!browserFocusReturnsToInput(true, true, false));
    try std.testing.expect(!browserFocusReturnsToInput(true, false, true));
    try std.testing.expect(!browserFocusReturnsToInput(true, false, false));
}

pub fn isAltDown(flags: DWORD) bool {
    return (flags & 0x20) != 0 or
        (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
}

fn classifyBrowserPopup(evidence: BrowserPopupEvidence) BrowserPopupDisposition {
    if (!evidence.same_edge_process or !evidence.chrome_widget) return .{};

    if (evidence.owner_link) {
        return .{
            .owns_pane_foreground = true,
            .suppress_shell_refocus = true,
            .suppress_mask_raise = true,
        };
    }

    if ((!evidence.popup_style and !evidence.tool_window) or !evidence.titleless) return .{};
    const popup_w = evidence.popup_right - evidence.popup_left;
    const popup_h = evidence.popup_bottom - evidence.popup_top;
    const pane_w = evidence.pane_right - evidence.pane_left;
    const pane_h = evidence.pane_bottom - evidence.pane_top;
    if (popup_w <= 0 or popup_h <= 0 or pane_w <= 0 or pane_h <= 0) return .{};
    const meaningfully_smaller = popup_w < pane_w or popup_h < pane_h;
    if (!meaningfully_smaller) return .{};

    const slack: i32 = 128;
    const intersects = evidence.popup_right > evidence.pane_left and
        evidence.popup_left < evidence.pane_right and
        evidence.popup_bottom > evidence.pane_top and
        evidence.popup_top < evidence.pane_bottom;
    const bounded = evidence.popup_left >= evidence.pane_left - slack and
        evidence.popup_top >= evidence.pane_top - slack and
        evidence.popup_right <= evidence.pane_right + slack and
        evidence.popup_bottom <= evidence.pane_bottom + slack;
    if (!intersects or !bounded) return .{};
    return .{
        .owns_pane_foreground = true,
        .suppress_shell_refocus = true,
        .suppress_mask_raise = true,
    };
}

pub fn browserTransientPopupDisposition(fg: HANDLE, pane: HANDLE) BrowserPopupDisposition {
    if (fg == null or pane == null or fg == pane) return .{};
    if (IsWindow(fg) == 0 or IsWindow(pane) == 0) return .{};

    var fg_pid: DWORD = 0;
    var pane_pid: DWORD = 0;
    _ = GetWindowThreadProcessId(fg, &fg_pid);
    _ = GetWindowThreadProcessId(pane, &pane_pid);
    if (fg_pid == 0 or fg_pid != pane_pid) return .{};

    var class_buf: [64]u16 = undefined;
    const class_len = GetClassNameW(fg, &class_buf, @intCast(class_buf.len));
    if (class_len <= 0 or !u16ContainsU8Insensitive(class_buf[0..@intCast(class_len)], "chrome_widgetwin")) return .{};
    var title_buf: [2]u16 = undefined;
    const title_len = InternalGetWindowText(fg, &title_buf, @intCast(title_buf.len));
    var popup_rect: RECT = std.mem.zeroes(RECT);
    var pane_rect: RECT = std.mem.zeroes(RECT);
    const have_rects = GetWindowRect(fg, &popup_rect) != 0 and GetWindowRect(pane, &pane_rect) != 0;
    const pane_owner: LONG_PTR = @bitCast(@intFromPtr(pane));
    const owner_link = GetAncestor(fg, GA_ROOT) == pane or
        GetAncestor(fg, GA_ROOTOWNER) == pane or
        GetWindowLongPtrW(fg, GWLP_HWNDPARENT) == pane_owner;
    const style: usize = @bitCast(GetWindowLongPtrW(fg, GWL_STYLE));
    const ex_style: usize = @bitCast(GetWindowLongPtrW(fg, GWL_EXSTYLE));

    return classifyBrowserPopup(.{
        .same_edge_process = fg_pid != 0 and fg_pid == pane_pid,
        .chrome_widget = class_len > 0 and
            u16ContainsU8Insensitive(class_buf[0..@intCast(class_len)], "chrome_widgetwin"),
        .owner_link = owner_link,
        .popup_style = (style & @as(usize, WS_POPUP)) != 0,
        .tool_window = (ex_style & @as(usize, WS_EX_TOOLWINDOW)) != 0,
        .titleless = title_len == 0,
        .popup_left = if (have_rects) popup_rect.left else 0,
        .popup_top = if (have_rects) popup_rect.top else 0,
        .popup_right = if (have_rects) popup_rect.right else 0,
        .popup_bottom = if (have_rects) popup_rect.bottom else 0,
        .pane_left = if (have_rects) pane_rect.left else 0,
        .pane_top = if (have_rects) pane_rect.top else 0,
        .pane_right = if (have_rects) pane_rect.right else 0,
        .pane_bottom = if (have_rects) pane_rect.bottom else 0,
    });
}

test "native Edge popup ownership excludes regular and foreign windows" {
    const pane = BrowserPopupEvidence{
        .same_edge_process = true,
        .chrome_widget = true,
        .popup_style = true,
        .titleless = true,
        .popup_left = 0,
        .popup_top = 0,
        .popup_right = 1200,
        .popup_bottom = 800,
        .pane_left = 0,
        .pane_top = 0,
        .pane_right = 1200,
        .pane_bottom = 800,
    };

    var owned_menu = pane;
    owned_menu.owner_link = true;
    owned_menu.popup_left = 1080;
    owned_menu.popup_right = 1320;
    owned_menu.popup_bottom = 620;
    const owned = classifyBrowserPopup(owned_menu);
    try std.testing.expect(owned.owns_pane_foreground);
    try std.testing.expect(owned.suppress_shell_refocus);
    try std.testing.expect(owned.suppress_mask_raise);

    var bounded_menu = owned_menu;
    bounded_menu.owner_link = false;
    bounded_menu.popup_right = 1250;
    try std.testing.expect(classifyBrowserPopup(bounded_menu).owns_pane_foreground);

    var foreign_menu = bounded_menu;
    foreign_menu.same_edge_process = false;
    try std.testing.expect(!classifyBrowserPopup(foreign_menu).owns_pane_foreground);

    const full_size_window = pane;
    try std.testing.expect(!classifyBrowserPopup(full_size_window).owns_pane_foreground);

    var regular_pwa = bounded_menu;
    regular_pwa.popup_style = false;
    regular_pwa.titleless = false;
    try std.testing.expect(!classifyBrowserPopup(regular_pwa).owns_pane_foreground);

    var unrelated_popup = bounded_menu;
    unrelated_popup.popup_left = 1800;
    unrelated_popup.popup_right = 2100;
    try std.testing.expect(!classifyBrowserPopup(unrelated_popup).owns_pane_foreground);
}

pub fn browserPaneOwnsForegroundHwnd(fg: HANDLE, bh: HANDLE) bool {
    if (fg == null) return false;
    const pane = bh orelse return false;
    if (IsWindow(pane) == 0) return false;
    if (fg == pane and GetPropW(pane, L("ZigShellPaneOwner")) == app_state.g_main_hwnd) return true;
    if (GetPropW(fg, L("ZigShellPaneOwner")) == app_state.g_main_hwnd) return true;

    if (GetAncestor(fg, GA_ROOT) == pane) return true;

    var parent = GetParent(fg);
    var depth: u8 = 0;
    while (parent != null and depth < 8) : (depth += 1) {
        if (parent == pane) return true;
        parent = GetParent(parent);
    }

    if (browserTransientPopupDisposition(fg, pane).owns_pane_foreground) return true;

    return false;
}

pub fn foregroundHwndIsOurs(fg: HANDLE) bool {
    if (fg == null or app_state.g_main_hwnd == null) return false;
    if (fg == app_state.g_main_hwnd) return true;
    if (app_state.g_urlbar_hwnd) |ub| {
        if (fg == ub and IsWindow(ub) != 0) {
            const owner: LONG_PTR = @bitCast(@intFromPtr(app_state.g_main_hwnd));
            if (GetWindowLongPtrW(ub, GWLP_HWNDPARENT) == owner) return true;
        }
    }
    for (0..app_state.shell_count) |i| {
        if (app_state.shells[i].hwnd) |sh| {
            if (fg == sh and IsWindow(sh) != 0 and GetParent(sh) == app_state.g_main_hwnd) return true;
        }
        if (app_state.shells[i].browser_hwnd) |bh| {
            if (browserPaneOwnsForegroundHwnd(fg, bh)) return true;
        }
    }
    return false;
}

pub fn foregroundIsOurs() bool {
    return foregroundHwndIsOurs(GetForegroundWindow());
}

pub fn parkMainWindowBeforeActiveShellRemoval(idx: usize) bool {
    if (app_state.g_main_hwnd == null or idx >= app_state.shell_count or idx != app_state.active_shell) return false;
    const fg = GetForegroundWindow();
    if (!foregroundHwndIsOurs(fg) or !focusGuard(app_state.g_main_hwnd)) return false;
    if (fg == app_state.g_main_hwnd) return true;

    const our_thread = GetCurrentThreadId();
    const fg_thread = if (fg != null) GetWindowThreadProcessId(fg, null) else 0;
    const attached_fg = fg_thread != 0 and fg_thread != our_thread and AttachThreadInput(our_thread, fg_thread, 1) != 0;
    _ = SetForegroundWindow(app_state.g_main_hwnd);
    _ = SetFocus(app_state.g_main_hwnd);
    if (attached_fg) _ = AttachThreadInput(our_thread, fg_thread, 0);

    const parked = GetForegroundWindow() == app_state.g_main_hwnd;
    if (verboseLoggingEnabled()) {
        debugLog(if (parked) "[close-focus] parked foreground on frame" else "[close-focus] frame park failed");
    }
    return parked;
}

pub fn focusActiveShell() void {
    focusActiveShellInner(true);
}

fn focusActiveShellSoft() void {
    focusActiveShellInner(false);
}

fn focusActiveShellInner(use_alt_trick: bool) void {
    const focus_target = if (app_state.g_chat_active) app_state.g_chat_composer_hwnd else activeShellHwndForFocusGuard();
    if (!focusGuard(focus_target)) return;
    if (app_state.g_inbox_active) return;
    if (app_state.g_all_sessions_active) return;
    if (app_state.g_chat_active) {
        altqLog("shell_back enter chat_owns={} composer={X} fg_ours={} fg={X} main={X} alt_trick={} mode={} pending={}", .{ chatViewOwnsInput(), altqPtr(app_state.g_chat_composer_hwnd), foregroundIsOurs(), altqPtr(GetForegroundWindow()), altqPtr(app_state.g_main_hwnd), use_alt_trick, app_state.g_browser_focus_mode, app_state.g_native_browser_focus_pending_shell_id });
        if (!(chatViewOwnsInput() and app_state.g_chat_composer_hwnd != null and foregroundIsOurs())) return;
        if (app_state.g_browser_focus_mode and activeBrowserHasForegroundFocus()) {
            altqLog("shell_back skip pane_owns_focus", .{});
            return;
        }
        if (GetForegroundWindow() != app_state.g_main_hwnd) {
            const phys_alt = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
            const tap_alt = use_alt_trick and !phys_alt and !isCtrlDown();
            if (tap_alt) keybd_event(VK_MENU, 0, 0, 0);
            _ = SetForegroundWindow(app_state.g_main_hwnd);
            if (tap_alt) keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
            if (GetForegroundWindow() != app_state.g_main_hwnd and use_alt_trick and app_state.g_main_hwnd != null) {
                app_state.g_chat_foreground_retries = 40;
                _ = SetTimer(app_state.g_main_hwnd, TIMER_CHAT_FOREGROUND_RETRY, 30, null);
                altqLog("shell_back retry_armed phys_alt={} tap_alt={} fg={X}", .{ (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0, tap_alt, altqPtr(GetForegroundWindow()) });
            }
        }
        _ = SetFocus(app_state.g_chat_composer_hwnd);
        altqLog("shell_back result fg={X} main_fg={} focus={X} composer={X} retries={}", .{ altqPtr(GetForegroundWindow()), app_state.g_main_hwnd != null and GetForegroundWindow() == app_state.g_main_hwnd, altqPtr(GetFocus()), altqPtr(app_state.g_chat_composer_hwnd), app_state.g_chat_foreground_retries });
        return;
    }
    if (app_state.active_shell >= app_state.shell_count) return;
    if (app_state.shells[app_state.active_shell].hwnd == null) return;
    if (!foregroundIsOurs()) return;

    if (use_alt_trick) {
        const phys_alt = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
        if (phys_alt) {
            keybd_event(VK_MENU, 0, 0, 0);
            _ = SetForegroundWindow(app_state.g_main_hwnd);
            _ = SetFocus(app_state.g_main_hwnd);
            app_state.g_ws_switch_focus_grace = GetTickCount64() + 2000;
            app_state.g_refocus_waiting_for_alt_release = true;
            requestShellRefocus(80, 40);
            return;
        }
        if (isCtrlDown()) {
            const fg_now = GetForegroundWindow();
            var fg_is_shell = false;
            for (0..app_state.shell_count) |si| {
                if (fg_now == app_state.shells[si].hwnd) {
                    fg_is_shell = true;
                    break;
                }
            }
            if (!fg_is_shell) {
                _ = SetForegroundWindow(app_state.g_main_hwnd);
                _ = SetFocus(app_state.g_main_hwnd);
            }
            app_state.g_ws_switch_focus_grace = GetTickCount64() + 2000;
            app_state.g_refocus_waiting_for_alt_release = true;
            requestShellRefocus(80, 40);
            return;
        }
    }

    const target_hwnd = app_state.shells[app_state.active_shell].hwnd;

    const fg = GetForegroundWindow();
    var fg_is_ours = (fg == app_state.g_main_hwnd or fg == target_hwnd);
    if (!fg_is_ours) {
        for (0..app_state.shell_count) |si| {
            if (fg == app_state.shells[si].hwnd) {
                fg_is_ours = true;
                break;
            }
        }
    }
    const target_is_foreground = fg == target_hwnd;

    const need_alt = use_alt_trick and !target_is_foreground;
    if (need_alt) {
        keybd_event(VK_MENU, 0, 0, 0);
    }

    if (!fg_is_ours) {
        _ = SetForegroundWindow(app_state.g_main_hwnd);
    }

    const target_thread = GetWindowThreadProcessId(target_hwnd, null);
    const fg_thread = if (fg != null) GetWindowThreadProcessId(fg, null) else 0;
    const our_thread = GetCurrentThreadId();
    const attached_target = target_thread != 0 and target_thread != our_thread and AttachThreadInput(our_thread, target_thread, 1) != 0;
    const attached_fg = fg_thread != 0 and fg_thread != our_thread and fg_thread != target_thread and AttachThreadInput(our_thread, fg_thread, 1) != 0;
    _ = activateConsoleForeground(target_hwnd);
    _ = SetFocus(target_hwnd);
    if (attached_fg) _ = AttachThreadInput(our_thread, fg_thread, 0);
    if (attached_target) _ = AttachThreadInput(our_thread, target_thread, 0);

    if (need_alt) {
        keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
    }

    app_state.g_shell_focused = true;
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn activateConsoleForeground(target: HANDLE) BOOL {
    if (SetForegroundWindow(target) != 0) {
        const now_fg = GetForegroundWindow();
        if (now_fg == null or now_fg == target) return 1;
    }
    if (!app_state.g_igsh354_paste_focus) return 0;
    return SetForegroundWindow(GetAncestor(target, GA_ROOT));
}

pub fn pasteFocusLanded(target: HANDLE) bool {
    if (target == null) return false;
    const foreground_hwnd = GetForegroundWindow();
    if (foreground_hwnd == target) return true;
    if (foreground_hwnd != GetAncestor(target, GA_ROOT)) return false;
    var info = std.mem.zeroes(GUITHREADINFO);
    info.cbSize = @sizeOf(GUITHREADINFO);
    if (GetGUIThreadInfo(GetWindowThreadProcessId(target, null), &info) == 0) return false;
    return info.hwndFocus == target or (info.hwndFocus != null and IsChild(target, info.hwndFocus) != 0);
}

pub fn activeShellHasForegroundFocus() bool {
    if (app_state.active_shell >= app_state.shell_count) return false;
    const target = app_state.shells[app_state.active_shell].hwnd;
    if (target == null) return false;
    return if (app_state.g_igsh354_paste_focus) pasteFocusLanded(target) else GetForegroundWindow() == target;
}

pub fn focusActiveBrowserPane() void {
    const bh = activeBrowserHwndLive() orelse return;
    if (!focusGuard(bh)) return;
    const phys_alt = (GetAsyncKeyState(@as(i32, VK_MENU)) & @as(i16, @bitCast(@as(u16, 0x8000)))) != 0;
    altqLog("pane_hop enter pane={X} phys_alt={} pane_fg={} fg={X} chat={} mode={}", .{ altqPtr(bh), phys_alt, activeBrowserHasForegroundFocus(), altqPtr(GetForegroundWindow()), app_state.g_chat_active, app_state.g_browser_focus_mode });
    if (phys_alt) return;
    cancelShellRefocus(app_state.g_main_hwnd);
    app_state.g_shell_focused = false;

    keybd_event(VK_MENU, 0, 0, 0);
    const fg = GetForegroundWindow();
    const target_thread = GetWindowThreadProcessId(bh, null);
    const fg_thread = if (fg != null) GetWindowThreadProcessId(fg, null) else 0;
    const our_thread = GetCurrentThreadId();
    const attached_target = target_thread != 0 and target_thread != our_thread and AttachThreadInput(our_thread, target_thread, 1) != 0;
    const attached_fg = fg_thread != 0 and fg_thread != our_thread and fg_thread != target_thread and AttachThreadInput(our_thread, fg_thread, 1) != 0;
    app_state.g_chat_browser_handoff_until = GetTickCount64() + 1500;
    _ = SetForegroundWindow(bh);
    _ = SetFocus(bh);
    if (attached_fg) _ = AttachThreadInput(our_thread, fg_thread, 0);
    if (attached_target) _ = AttachThreadInput(our_thread, target_thread, 0);
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
    armBrowserEdgeMaskRaise();
    altqLog("pane_hop result bh_fg={} fg={X} main_fg={} pane={X} chat={} handoff_left={}", .{ activeBrowserHasForegroundFocus(), altqPtr(GetForegroundWindow()), app_state.g_main_hwnd != null and GetForegroundWindow() == app_state.g_main_hwnd, altqPtr(bh), app_state.g_chat_active, app_state.g_chat_browser_handoff_until -| GetTickCount64() });
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn cancelPendingNativeBrowserFocus() void {
    altqLog("pending_cancel sid={} retries={} attempts={} mode={}", .{ app_state.g_native_browser_focus_pending_shell_id, app_state.g_native_browser_focus_retries, app_state.g_native_browser_focus_attempts, app_state.g_browser_focus_mode });
    app_state.g_native_browser_focus_pending_shell_id = 0;
    app_state.g_native_browser_focus_retries = 0;
    app_state.g_native_browser_focus_attempts = 0;
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_NATIVE_BROWSER_FOCUS);
}

pub fn requestNativeBrowserFocus() void {
    focusGuardReadMouse();
    if (app_state.g_focus_user_action_tick == 0 or app_state.g_focus_user_action_tick < app_state.g_focus_input_tick or GetTickCount64() -| app_state.g_focus_user_action_tick > 1500) {
        debugLog("focus guard: blocked browser focus request without user action");
        return;
    }
    if (app_state.active_shell < app_state.shell_count) {
        app_state.g_focus_browser_shell_id = app_state.shells[app_state.active_shell].shell_id;
        app_state.g_focus_authorized_until = app_state.g_focus_user_action_tick + 1500;
    }
    altqLog("request_native chat={} chat_owns={} enabled={} pane_fg={} fg={X}", .{ app_state.g_chat_active, chatViewOwnsInput(), app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled, activeBrowserHasForegroundFocus(), altqPtr(GetForegroundWindow()) });
    if (app_state.active_shell >= app_state.shell_count or !app_state.shells[app_state.active_shell].browser_enabled) return;
    cancelShellRefocus(app_state.g_main_hwnd);
    if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_CHAT_FOREGROUND_RETRY);
    app_state.g_browser_focus_mode = true;
    app_state.g_shell_focused = false;
    app_state.g_native_browser_focus_pending_shell_id = app_state.shells[app_state.active_shell].shell_id;
    app_state.g_native_browser_focus_retries = 500;
    app_state.g_native_browser_focus_attempts = 12;
    _ = KillTimer(app_state.g_main_hwnd, TIMER_NATIVE_BROWSER_FOCUS);
    _ = SetTimer(app_state.g_main_hwnd, TIMER_NATIVE_BROWSER_FOCUS, 30, null);
    altqLog("request_native armed sid={} retries={} attempts={} chat={}", .{ app_state.g_native_browser_focus_pending_shell_id, app_state.g_native_browser_focus_retries, app_state.g_native_browser_focus_attempts, app_state.g_chat_active });
}

pub fn requestShellRefocus(delay_ms: UINT, extra_retries: u32) void {
    if (!focusGuard(activeShellHwndForFocusGuard())) return;
    if (app_state.g_main_hwnd == null or app_state.shell_count == 0) return;
    if (app_state.g_inbox_active) return;
    if (app_state.g_all_sessions_active) return;
    if (app_state.g_chat_active) return;
    const inbox_force = GetTickCount64() < app_state.g_inbox_shell_focus_until;
    if (!inbox_force and (app_state.g_browser_focus_mode or activeBrowserHasForegroundFocus())) return;
    if (app_state.g_popup_menu_active or app_state.g_move_size_active) return;
    if (!foregroundIsOurs()) return;
    app_state.g_shell_focused = true;
    if (extra_retries > app_state.g_refocus_remaining) app_state.g_refocus_remaining = extra_retries;
    _ = SetTimer(app_state.g_main_hwnd, TIMER_REFOCUS, delay_ms, null);
}

pub fn cancelShellRefocus(hwnd: HANDLE) void {
    app_state.g_refocus_remaining = 0;
    app_state.g_refocus_waiting_for_alt_release = false;
    app_state.g_ws_switch_focus_grace = 0;
    const timer_hwnd = if (hwnd != null) hwnd else app_state.g_main_hwnd;
    if (timer_hwnd != null) _ = KillTimer(timer_hwnd, TIMER_REFOCUS);
}

pub fn systemAltTabSuppressionActive() bool {
    return GetTickCount64() < app_state.g_system_alt_tab_until;
}

pub fn noteSystemAltTab() void {
    if (activeBrowserHasForegroundFocus()) armStaleAltBrowserClickRepair();
    app_state.g_system_alt_tab_until = GetTickCount64() + SYSTEM_ALT_TAB_SUPPRESS_MS;
    app_state.g_sysmenu_pending = false;
    cancelShellRefocus(app_state.g_main_hwnd);
}

fn altTabWindowBelongsToZigShell(hwnd: HANDLE) bool {
    if (hwnd == null or app_state.g_main_hwnd == null) return false;
    if (foregroundHwndIsOurs(hwnd)) return true;
    if (GetPropW(hwnd, L("ZigShellPaneOwner")) == app_state.g_main_hwnd) return true;
    if (GetAncestor(hwnd, GA_ROOT) == app_state.g_main_hwnd or GetAncestor(hwnd, GA_ROOTOWNER) == app_state.g_main_hwnd) return true;
    var pid: DWORD = 0;
    _ = GetWindowThreadProcessId(hwnd, &pid);
    return pid != 0 and pid == GetCurrentProcessId();
}

fn altTabWindowEligible(hwnd: HANDLE) bool {
    if (hwnd == null or IsWindow(hwnd) == 0 or IsWindowVisible(hwnd) == 0) return false;
    if (altTabWindowBelongsToZigShell(hwnd)) return false;
    const ex_style: usize = @bitCast(GetWindowLongPtrW(hwnd, GWL_EXSTYLE));
    if ((ex_style & (WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE)) != 0) return false;

    const root_owner = GetAncestor(hwnd, GA_ROOTOWNER);
    if (root_owner == null) return false;
    var task_window = root_owner;
    var depth: u8 = 0;
    while (depth < 16) : (depth += 1) {
        const popup = GetLastActivePopup(task_window);
        if (popup == null or popup == task_window) break;
        task_window = popup;
        if (IsWindowVisible(task_window) != 0) break;
    }
    if (task_window != hwnd) return false;

    const DWMWA_CLOAKED: DWORD = 14;
    var cloaked: DWORD = 0;
    if (DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, @ptrCast(&cloaked), @sizeOf(DWORD)) >= 0 and cloaked != 0) return false;
    return true;
}

fn systemAltTabForeignTarget(reverse: bool) ?HANDLE {
    if (app_state.g_main_hwnd == null) return null;
    const direction: UINT = if (reverse) GW_HWNDPREV else GW_HWNDNEXT;
    var candidate = GetWindow(app_state.g_main_hwnd, direction);
    var wrapped = false;
    var checked: u32 = 0;
    while (checked < 512) : (checked += 1) {
        if (candidate == null) {
            if (wrapped) return null;
            wrapped = true;
            const first = GetWindow(app_state.g_main_hwnd, GW_HWNDFIRST);
            candidate = if (reverse) GetWindow(first, GW_HWNDLAST) else first;
            continue;
        }
        if (candidate == app_state.g_main_hwnd) return null;
        if (altTabWindowEligible(candidate)) return candidate;
        candidate = GetWindow(candidate, direction);
    }
    return null;
}

pub fn switchSystemAltTabToForeign(reverse: bool) bool {
    const target = systemAltTabForeignTarget(reverse) orelse return false;
    if (!focusGuard(target)) return false;
    keybd_event(0xFF, 0, 0, 0);
    keybd_event(0xFF, 0, KEYEVENTF_KEYUP, 0);
    if (IsIconic(target) != 0) _ = ShowWindow(target, SW_RESTORE);
    SwitchToThisWindow(target, 1);
    if (GetForegroundWindow() != target) {
        const target_thread = GetWindowThreadProcessId(target, null);
        const our_thread = GetCurrentThreadId();
        const attached = target_thread != 0 and target_thread != our_thread and AttachThreadInput(our_thread, target_thread, 1) != 0;
        _ = SetForegroundWindow(target);
        if (attached) _ = AttachThreadInput(our_thread, target_thread, 0);
    }
    return true;
}

pub fn verifyShellWindowSize(sh: HANDLE, x: i32, y: i32, w: i32, h: i32) void {
    if (sh == null or app_state.g_main_hwnd == null) return;
    if (w <= 16 or h <= 16) return;
    var got: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(sh, &got) == 0) return;
    if (@abs((got.right - got.left) - w) <= 48 and @abs((got.bottom - got.top) - h) <= 48) return;
    if (verboseLoggingEnabled()) {
        var kbuf: [160]u8 = undefined;
        const ks = std.fmt.bufPrint(&kbuf, "[conhost-kick] asked={d}x{d} got={d}x{d}", .{ w, h, got.right - got.left, got.bottom - got.top }) catch "";
        debugLog(ks);
    }
    var wr: RECT = std.mem.zeroes(RECT);
    _ = GetWindowRect(app_state.g_main_hwnd, &wr);
    _ = SetParent(sh, null);
    _ = SetWindowPos(sh, null, wr.left + 60, wr.top + 60, w, h, SWP_NOZORDER);
    _ = SetParent(sh, app_state.g_main_hwnd);
    var style = GetWindowLongPtrW(sh, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
    style |= @as(isize, @intCast(WS_CHILD));
    _ = SetWindowLongPtrW(sh, GWL_STYLE, style);
    _ = SetWindowPos(sh, null, x, y, w, h, SWP_FRAMECHANGED | SWP_NOZORDER);
}
