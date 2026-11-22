    if (msg == WM_TIMER and wp == launch_cache.TIMER_STARTUP) {
        if (app_state.g_account_locked) {
            _ = KillTimer(hwnd, launch_cache.TIMER_STARTUP);
            return 0;
        }
        if (app_state.g_app_closing or initializeDeferred(hwnd)) {
            _ = KillTimer(hwnd, launch_cache.TIMER_STARTUP);
            launch_cache.pending = false;
            launch_cache.changed();
            @import("account_desktop.zig").resumeStartupReply();
        }
        return 0;
    }
