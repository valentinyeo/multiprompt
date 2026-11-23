pub fn chatWorkingSync() void {
    if (app_state.g_chat_transcript_hwnd == null) return;
    if ((g_working_rect != null) != chatWorkingDotsVisible()) {
        var rc: RECT = std.mem.zeroes(RECT);
        chatViewClientRect(&rc);
        chatRelayoutPreservingScroll(rc.right - rc.left, rc.bottom - rc.top);
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, null, 0);
    } else if (g_working_rect) |source| {
        var rc = source;
        rc.top -= app_state.g_chat_scroll_y;
        rc.bottom -= app_state.g_chat_scroll_y;
        _ = InvalidateRect(app_state.g_chat_transcript_hwnd, &rc, 0);
    }
}

fn chatPaintWorking(hdc: HANDLE, now: u64) void {
    const source = g_working_rect orelse return;
    if (!chatWorkingDotsVisible()) return;
    var rc = source;
    rc.top -= app_state.g_chat_scroll_y;
    rc.bottom -= app_state.g_chat_scroll_y;
    chatPaintWorkingDots(hdc, rc, now);
}

fn chatPaintWorkingDots(hdc: HANDLE, rc: RECT, now: u64) void {
    const size = uiScaled(WORKING_DOT_SIZE);
    const step = uiScaled(WORKING_DOT_STEP);
    const active = (now / 250) % 3;
    const color = @import("chat_scrollbar.zig").blend(themeConsoleBg(), customColorOr("text", themeConsoleFg()), WORKING_DOT_ALPHA);
    for (0..3) |i| {
        const x = rc.left + uiScaled(CHAT_AGENT_PAD_X) + @as(i32, @intCast(i)) * step;
        const y = rc.top + @divTrunc(rc.bottom - rc.top - size, 2) - (if (i == active) uiScaled(2) else @as(i32, 0));
        @import("smooth.zig").fillEllipse(hdc, .{ .left = x, .top = y, .right = x + size, .bottom = y + size }, color);
    }
}
