const app_state = @import("app_state.zig");
const win32 = @import("win32.zig");

pub fn busy() bool {
    const hwnd = app_state.g_main_hwnd orelse return false;
    return win32.GetCurrentThreadId() == win32.GetWindowThreadProcessId(hwnd, null);
}