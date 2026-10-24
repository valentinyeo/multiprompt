pub fn paintSidebarUpdateCard(hdc: HANDLE, font_title: HANDLE, font_subtitle: HANDLE) void {
    if (!updateCardVisible()) return;
    const card = updateCardRect();
    paintSidebarCardFrame(hdc, card);
    const bright: DWORD = customColorOr("text_active", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(235, 238, 244));
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const accent: DWORD = customColorOr("selected_bg", if (app_state.g_light_theme) RGB(54, 118, 232) else RGB(63, 120, 190));
    var text_buf: [96]u8 = undefined;
    const text = std.fmt.bufPrint(&text_buf, "Update ready: restart to get v{s}", .{app_state.g_update_ver[0..app_state.g_update_ver_len]}) catch "Update is ready";
    _ = SelectObject(hdc, font_title);
    _ = SetTextColor(hdc, bright);
    var text_rc = RECT{ .left = card.left + uiScaled(10), .top = card.top + uiScaled(5), .right = card.right - uiScaled(26), .bottom = card.top + uiScaled(46) };
    drawAscii(hdc, text, &text_rc, DT_WORDBREAK | DT_NOPREFIX | DT_END_ELLIPSIS);

    _ = SelectObject(hdc, font_subtitle);
    var close_rc = updateCardCloseRect(card);
    _ = SetTextColor(hdc, if (app_state.g_update_hover == 2) bright else dim);
    drawAscii(hdc, "x", &close_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);

    const btn = updateCardButtonRect(card);
    const btn_color: DWORD = if (app_state.g_update_hover == 1) lightenColor(accent, 28) else accent;
    const brush = CreateSolidBrush(btn_color);
    const pen = CreatePen(0, 1, btn_color);
    const old_brush = SelectObject(hdc, brush);
    const old_pen = SelectObject(hdc, pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, btn.left, btn.top, btn.right, btn.bottom, uiScaled(6), uiScaled(6));
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(brush);
    _ = DeleteObject(pen);
    _ = SetTextColor(hdc, RGB(255, 255, 255));
    var btn_rc = btn;
    drawAscii(hdc, "Restart", &btn_rc, DT_SINGLELINE | DT_VCENTER | DT_CENTER | DT_NOPREFIX);
}

