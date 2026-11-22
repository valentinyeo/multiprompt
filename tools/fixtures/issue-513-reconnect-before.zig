pub fn armSshReconnectTimerIfNeeded() void {
    if (chatBenchEnabled() or app_state.g_main_hwnd == null) return;
    var any = false;
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        if (shell.kind == .tmux or shell.kind == .vps or shell.kind == .vps2) {
            any = true;
            break;
        }
    }
    if (any and !app_state.g_ssh_reconnect_timer_on) {
        app_state.g_ssh_reconnect_timer_on = true;
        _ = SetTimer(app_state.g_main_hwnd, TIMER_SSH_RECONNECT, 1000, null);
    } else if (!any and app_state.g_ssh_reconnect_timer_on) {
        app_state.g_ssh_reconnect_timer_on = false;
        _ = KillTimer(app_state.g_main_hwnd, TIMER_SSH_RECONNECT);
    }
}
