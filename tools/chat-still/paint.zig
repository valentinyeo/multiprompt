fn chatStillFrame(hwnd: HANDLE) void {
    var enabled: [2]u8 = undefined;
    if (GetEnvironmentVariableA("MULTIPROMPT_CHAT_STILL_PROOF", &enabled, enabled.len) == 0) return;
    if (app_state.active_shell >= app_state.shell_count) return;
    var client: RECT = undefined;
    if (GetClientRect(hwnd, &client) == 0) return;
    const view_h = @max(1, client.bottom - app_state.g_chat_bottom_inset);
    var log: [384]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log, "[chat-still] begin shell={d} dirty={d} width={d} layout={d} height={d} view_h={d} view_top={d}", .{ app_state.shells[app_state.active_shell].shell_id, @intFromBool(app_state.g_chat_layout_dirty), client.right, app_state.g_chat_layout_width, app_state.g_chat_content_h, view_h, app_state.g_chat_top_pad }) catch return);
    for (app_state.g_chat_blocks[0..app_state.g_chat_block_count], 0..) |block, i| {
        if (block.role == .tool or g_reaction_view.hides(i)) continue;
        const bounds = chatMessageBounds(i);
        if (bounds.first != i) continue;
        var rc = chatMessageRect(i);
        rc.top -= app_state.g_chat_scroll_y;
        rc.bottom -= app_state.g_chat_scroll_y;
        if (rc.bottom <= app_state.g_chat_top_pad or rc.top >= view_h) continue;
        debugLog(std.fmt.bufPrint(&log, "[chat-still] row message={d} offset={d} rect={d},{d},{d},{d}", .{ block.message_id, block.source_offset, rc.left, rc.top, rc.right, rc.bottom }) catch return);
    }
    debugLog("[chat-still] end");
}
