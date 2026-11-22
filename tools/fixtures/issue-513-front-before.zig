fn updateSessionFront(user: bool) void {
    const allowed = !launch_cache.pending and app_state.g_main_hwnd != null and !app_state.g_account_locked and !app_state.g_restoring and !app_state.g_startup_progress and !app_state.g_account_applying;
    const visible = !app_state.g_inbox_active and !app_state.g_all_sessions_active and !app_state.g_search_active and !app_state.g_shortcuts_active and !app_state.g_changelog_active and !app_state.g_url_picker_active;
    const sid: ?u32 = if (allowed and app_state.active_shell < app_state.shell_count and (!app_state.g_single_window or app_state.shells[app_state.active_shell].workspace == app_state.g_active_workspace)) app_state.shells[app_state.active_shell].shell_id else null;
    if (!app_state.g_front_period.select(sid, user, visible and foregroundIsOurs(), frequent.unixMs(@import("inbox.zig").nowFileTime() / 10_000), GetTickCount64())) return;
    _ = KillTimer(app_state.g_main_hwnd, app_state.TIMER_VISIT_DWELL);
    if (app_state.g_front_period.sid != null) _ = SetTimer(app_state.g_main_hwnd, app_state.TIMER_VISIT_DWELL, @intCast(frequent.dwell_ms), null);
}
