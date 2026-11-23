const w = @import("win32.zig");
const app_state = @import("app_state.zig");

extern fn mp_terminal_window_repair_caret(w.HANDLE) void;

pub fn repairActiveSessionCaret() void {
    if (w.GetCaretBlinkTime() == 0xFFFFFFFF) return;
    const focus = w.GetFocus();
    if (app_state.g_chat_composer_hwnd != null and focus == app_state.g_chat_composer_hwnd) {
        _ = w.ShowCaret(focus);
        return;
    }
    if (app_state.active_shell >= app_state.shell_count) return;
    const shell = &app_state.shells[app_state.active_shell];
    const hwnd = shell.hwnd orelse return;
    if (shell.native_terminal) {
        mp_terminal_window_repair_caret(hwnd);
        return;
    }
    const target = if (focus != null and w.IsChild(hwnd, focus) != 0) focus else hwnd;
    if (target != null) _ = w.ShowCaret(target);
}