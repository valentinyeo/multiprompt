pub fn paintDisconnectedShell(hdc: HANDLE) void {
    if (app_state.g_chat_active or app_state.g_search_active or app_state.g_inbox_active or app_state.g_all_sessions_active or app_state.g_shortcuts_active or app_state.g_changelog_active or app_state.g_url_picker_active or app_state.g_snippet_create_active) return;
    var client: RECT = undefined;
    _ = GetClientRect(app_state.g_main_hwnd, &client);
    if (reconnectButtonRect(client.right) == null) return;
    var rc = RECT{ .left = SIDEBAR_W() + uiScaled(16), .top = threadTitleTop() + threadTitleHeight() + uiScaled(40), .right = threadTitleBandRightFor(client.right) - uiScaled(16), .bottom = threadTitleTop() + threadTitleHeight() + uiScaled(100) };
    _ = SetBkMode(hdc, TRANSPARENT);
    const old_font = SelectObject(hdc, uiFontTitle());
    defer _ = SelectObject(hdc, old_font);
    _ = SetTextColor(hdc, themeConsoleFg());
    _ = DrawTextW(hdc, L("Disconnected. Your session will reconnect automatically."), -1, &rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX | DT_END_ELLIPSIS);
}
