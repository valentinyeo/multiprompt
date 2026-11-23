const app_state = @import("app_state.zig");
const HANDLE = @import("win32.zig").HANDLE;
const WM_APP_BROWSER_FOCUS_TOGGLE = @import("win32.zig").WM_APP_BROWSER_FOCUS_TOGGLE;
const InvalidateRect = @import("win32.zig").InvalidateRect;
const PostMessageW = @import("focus.zig").PostMessageW;
const SetForegroundWindow = @import("focus.zig").SetForegroundWindow;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const closeAllSessions = @import("archive.zig").closeAllSessions;
const cancelPendingNativeBrowserFocus = @import("focus.zig").cancelPendingNativeBrowserFocus;
const activeBrowserHasForegroundFocus = @import("browser_pane.zig").activeBrowserHasForegroundFocus;
const webView2HasInputFocus = @import("browser_pane.zig").webView2HasInputFocus;
const clearSearchBackdrop = @import("rename.zig").clearSearchBackdrop;
const closeInbox = @import("inbox.zig").closeInbox;

pub fn showPickRepoFailure(saving_folder: bool) void {
    const palette = @import("command_palette.zig");
    if (palette.g_pick_repo_offline) {
        showHeaderNoticeAscii("Pick repo: server is offline", 4000, true);
        return;
    }
    if (saving_folder) {
        showHeaderNoticeAscii("Set workspace folder: could not save", 4000, true);
        return;
    }
    if (palette.g_pick_row_gone) {
        showHeaderNoticeAscii("Pick repo: that row is gone; open the list again", 4000, true);
        return;
    }
    switch (palette.g_start_fail) {
        .capacity => {},
        .launch_command => showHeaderNoticeAscii("Pick repo: that folder path cannot start a session", 5000, true),
        .spawn_shell => showHeaderNoticeAscii("Pick repo: the new tab did not start", 5000, true),
        .none => showHeaderNoticeAscii("Pick repo: nothing started", 4000, true),
    }
}

pub fn openNewRoom(hwnd: HANDLE) void {
    app_state.g_search_active = false;
    clearSearchBackdrop();
    if (app_state.g_inbox_active) closeInbox(hwnd);
    if (app_state.g_all_sessions_active) closeAllSessions(hwnd);
    @import("room_frontend.zig").openCreate();
    _ = InvalidateRect(hwnd, null, 0);
}

pub fn browserFocusHotkey() void {
    const pane_foreground = activeBrowserHasForegroundFocus() or webView2HasInputFocus();
    if (pane_foreground) {
        if (app_state.g_chat_find_open) @import("chat_find_ui.zig").close(false);
        cancelPendingNativeBrowserFocus();
        app_state.g_chat_browser_handoff_until = 0;
        app_state.g_browser_focus_mode = false;
        app_state.g_shell_focused = true;
        @import("focus.zig").focusActiveShellFromBrowserInput();
    } else {
        _ = SetForegroundWindow(app_state.g_main_hwnd);
        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_BROWSER_FOCUS_TOGGLE, 0, 0);
    }
}
