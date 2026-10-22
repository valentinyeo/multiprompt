pub fn restore() void {
    step(.snapshot);
    if (state.g_empty_workspace or state.g_adopt_hwnd != null) return;
    var buf: [560]u8 = undefined;
    const filename = path(&buf) orelse return;
    const bytes = io.readFileAllocWin32(filename, snapshot.MAX_BYTES + 1) orelse return;
    defer std.heap.page_allocator.free(bytes);
    const parsed = (snapshot.decode(std.heap.page_allocator, bytes) catch null) orelse return;
    defer parsed.deinit();
    const s = parsed.value;
    if (s.groups.len > state.MAX_GROUPS) return;
    state.shell_count = @intCast(s.rows.len);
    state.g_single_window = s.single_window;
    state.g_tab_sort_auto = s.sort_auto;
    state.g_sidebar_collapsed = s.sidebar_collapsed;
    state.g_sidebar_scroll = s.sidebar_scroll;
    state.g_active_workspace = s.workspace;
    state.g_lws_count = @intCast(@max(s.workspaces.len, @as(usize, s.workspace) + 1));
    for (s.workspaces, 0..) |name, i| {
        @memcpy(state.g_ws_names[i][0..name.len], name);
        state.g_ws_name_len[i] = @intCast(name.len);
    }
    for (s.rows, 0..) |row, i| {
        var shell = state.empty_shell;
        shell.shell_id = row.id;
        state.next_shell_id = @max(state.next_shell_id, row.id +| 1);
        cached_ids[i] = row.id;
        cached_chat_ids[i] = row.chat_id;
        shell.chat_id = row.chat_id;
        shell.kind = @enumFromInt(row.kind);
        shell.workspace = row.workspace;
        shell.group_id = row.group_id;
        shell.ai_agent = row.agent;
        shell.pinned_top = row.pinned;
        shell.favorite = row.favorite;
        shell.muted = row.muted;
        shell.needs_attention = row.unread;
        shell.last_active = row.last_active;
        shell.last_viewed = row.last_viewed;
        @memcpy(shell.name[0..row.name.len], row.name);
        shell.name_len = @intCast(row.name.len);
        state.shells[i] = shell;
        if (row.id == s.active) state.active_shell = @intCast(i);
    }
    state.group_count = @intCast(s.groups.len);
    for (s.groups, 0..) |group, i| {
        state.groups[i] = .{ .id = group.id, .name = @splat(0), .name_len = @intCast(group.name.len), .collapsed = group.collapsed, .color = group.color };
        @memcpy(state.groups[i].name[0..group.name.len], group.name);
    }
    chat_id = state.shells[state.active_shell].chat_id;
    state.g_sidebar_w_full = s.sidebar_width;
    state.g_chat_font_pt = s.font;
    if (s.chat) {
        state.g_chat_view_mode = .per_session;
        state.g_chat_last_len = s.text.len;
        @memcpy(state.g_chat_capture[0..s.text.len], s.text);
        state.g_chat_block_count = s.blocks.len;
        @memcpy(state.g_chat_blocks[0..s.blocks.len], s.blocks);
        state.g_chat_cache_shell_id = s.active;
        state.g_chat_layout_dirty = true;
        @import("chat_composer.zig").openChatView();
        @import("chat_composer.zig").layoutChatControls();
    }
    cached_count = s.rows.len;
    cached = true;
    debugLog("launch snapshot-restored");
    var log_buf: [128]u8 = undefined;
    debugLog(std.fmt.bufPrint(&log_buf, "launch cached-chat rows={d} active={d} blocks={d}", .{ s.rows.len, s.active, state.g_chat_block_count }) catch return);
}

pub fn deferred() void {
    var buf: [96]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "launch deferred-start ms={d}", .{elapsed()}) catch return);
    if (cached) {
        const selected_id = if (state.active_shell < state.shell_count) state.shells[state.active_shell].shell_id else 0;
        if (state.active_shell < state.shell_count) selected_chat_id = state.shells[state.active_shell].chat_id;
        for (cached_ids[0..cached_count], cached_chat_ids[0..cached_count]) |id, chat| {
            var present = false;
            for (state.shells[0..state.shell_count]) |shell| {
                if (shell.shell_id == id) {
                    present = true;
                    break;
                }
            }
            if (!present and chat != 0) {
                closed_chats[closed_count] = chat;
                closed_count += 1;
            }
        }
        var kept: u32 = 0;
        state.next_shell_id = 1;
        for (0..state.shell_count) |i| {
            const shell = state.shells[i];
            if (std.mem.indexOfScalar(u32, cached_ids[0..cached_count], shell.shell_id) != null) continue;
            state.shells[kept] = shell;
            if (shell.shell_id == selected_id) selected_live_shell_id = shell.shell_id;
            state.next_shell_id = @max(state.next_shell_id, shell.shell_id +| 1);
            kept += 1;
        }
        state.shell_count = kept;
        state.active_shell = 0;
        state.group_count = 0;
    }
}

pub fn closedDuringStartup(chat: u64) bool {
    return pending and chat != 0 and std.mem.indexOfScalar(u64, closed_chats[0..closed_count], chat) != null;
}
