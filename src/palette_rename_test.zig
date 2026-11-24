const std = @import("std");
const app_state = @import("app_state.zig");
const palette = @import("command_palette.zig");
const w = @import("win32.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;

test "SOFT-1970 old and new names find the same command" {
    const flag_names = .{
        "g_search_active", "g_search_workspace_mode", "g_search_workspace_delete_mode", "g_search_ws_sort_mode",
        "g_search_ws_move_mode", "g_search_group_move_mode", "g_search_skills_mode", "g_search_pi_models_mode",
        "g_search_tabctx_mode", "g_search_groupctx_mode", "g_search_remind_input_mode", "g_search_rename_input_mode",
        "g_search_remind_preset_mode", "g_search_ws_snoozed_mode", "g_search_reminders_mode", "g_search_session_overview_mode",
        "g_search_openall_host_mode", "g_search_pick_repo_mode", "g_search_snippet_mode", "g_search_shells_mode",
        "g_search_open_session_mode", "g_search_theme_mode", "g_browser_url_mode", "g_single_window",
        "g_inbox_active", "g_all_sessions_active", "g_chat_active", "g_chat_sel_active",
    };
    var old_flags: [flag_names.len]bool = undefined;
    inline for (flag_names, 0..) |name, i| {
        old_flags[i] = @field(app_state, name);
        @field(app_state, name) = false;
    }
    const old = .{
        .shell = app_state.shells[0], .shell_count = app_state.shell_count, .active_shell = app_state.active_shell,
        .query = app_state.g_search_buf, .query_len = app_state.g_search_len,
        .results = app_state.g_search_results, .result_count = app_state.g_search_result_count,
        .bot_mode = app_state.g_bot_look_mode, .color_target = app_state.g_workspace_color_target,
        .server_mode = app_state.g_search_workspace_server_mode, .outbox = app_state.g_chat_outbox,
    };
    defer {
        inline for (flag_names, 0..) |name, i| @field(app_state, name) = old_flags[i];
        app_state.shells[0] = old.shell;
        app_state.shell_count = old.shell_count;
        app_state.active_shell = old.active_shell;
        app_state.g_search_buf = old.query;
        app_state.g_search_len = old.query_len;
        app_state.g_search_results = old.results;
        app_state.g_search_result_count = old.result_count;
        app_state.g_bot_look_mode = old.bot_mode;
        app_state.g_workspace_color_target = old.color_target;
        app_state.g_search_workspace_server_mode = old.server_mode;
        app_state.g_chat_outbox = old.outbox;
    }
    app_state.shells[0] = app_state.empty_shell;
    const browser = w.CreateWindowExW(0, L("STATIC"), L(""), 0x80000000, 0, 0, 1, 1, null, null, null, null) orelse return error.TestUnexpectedResult;
    defer _ = w.DestroyWindow(browser);
    app_state.shells[0].kind = .tmux;
    app_state.shells[0].browser_enabled = true;
    app_state.shells[0].browser_hwnd = browser;
    app_state.shell_count = 1;
    app_state.active_shell = 0;
    app_state.shells[0].ai_agent = 1;
    @memcpy(app_state.shells[0].tmux_session[0..9], "test-chat");
    app_state.shells[0].tmux_session_len = 9;
    @memcpy(app_state.shells[0].claude_sid[0..9], "test-chat");
    app_state.shells[0].claude_sid_len = 9;
    app_state.g_chat_active = true;
    app_state.g_chat_sel_active = true;
    app_state.g_bot_look_mode = .none;
    app_state.g_workspace_color_target = null;
    app_state.g_search_workspace_server_mode = 0;
    var outbox: std.ArrayList(app_state.ChatOutboxEntry) = .empty;
    defer outbox.deinit(std.testing.allocator);
    var entry = app_state.ChatOutboxEntry{ .state = .not_sent };
    const key = @import("chat_send.zig").chatOutboxKeyForShell(0, &entry.key);
    entry.key_len = @intCast(key.len);
    try outbox.append(std.testing.allocator, entry);
    app_state.g_chat_outbox = outbox;
    const cases = [_]struct { target: usize, old: []const u8, label: []const u8 }{
        .{ .target = app_state.SEARCH_TABCTX_ARCHIVE, .old = "Archive Session", .label = "Archive chat" },
        .{ .target = app_state.SEARCH_TABCTX_ARCHIVE, .old = "Close Session", .label = "Archive chat" },
        .{ .target = app_state.SEARCH_TABCTX_END_TMUX, .old = "End tmux session", .label = "Delete chat" },
        .{ .target = app_state.SEARCH_TABCTX_END_TMUX, .old = "Delete session", .label = "Delete chat" },
        .{ .target = app_state.SEARCH_TABCTX_PIN_TOP, .old = "Pin to Top", .label = "Pin" },
        .{ .target = app_state.SEARCH_TABCTX_PIN_TOP, .old = "Unpin from Top", .label = "Pin" },
        .{ .target = app_state.SEARCH_FAVORITE_OFFSET, .old = "Favorite: Toggle", .label = "Favorite" },
        .{ .target = app_state.SEARCH_CHAT_REPLY_OFFSET, .old = "Chat View: Reply to latest agent message", .label = "Reply to latest message" },
        .{ .target = app_state.SEARCH_CHAT_FIND_OFFSET, .old = "Chat View: Find in conversation", .label = "Find in conversation" },
        .{ .target = app_state.SEARCH_CLEAN_CHAT_OFFSET, .old = "Chat View: CLEAN chat: ON (toggle)", .label = "Hide read receipts" },
        .{ .target = app_state.SEARCH_CHAT_TOOL_STEPS_OFFSET, .old = "Chat View: Open or fold all tool steps", .label = "Open or fold tool steps" },
        .{ .target = app_state.SEARCH_CHAT_NEWEST_OFFSET, .old = "Chat View: Scroll to newest message", .label = "Scroll to newest message" },
        .{ .target = app_state.SEARCH_CHAT_RESYNC_OFFSET, .old = "Chat View: Resync chat", .label = "Resync chat" },
        .{ .target = app_state.SEARCH_CHAT_RESTART_OFFSET, .old = "Chat View: Restart this chat on the newest version", .label = "Restart this chat on the newest version" },
        .{ .target = app_state.SEARCH_CHAT_RESTART_ALL_OFFSET, .old = "Chat View: Restart every idle live chat", .label = "Restart every idle chat" },
        .{ .target = app_state.SEARCH_CHAT_MORE_MENU_OFFSET, .old = "Chat View: More Menu", .label = "More menu" },
        .{ .target = app_state.SEARCH_CHAT_PLUS_MENU_OFFSET, .old = "Chat View: Plus Menu", .label = "Plus menu" },
        .{ .target = app_state.SEARCH_CHAT_TODO_OFFSET, .old = "Chat View: Toggle todo list", .label = "Toggle todo list" },
        .{ .target = app_state.SEARCH_CHAT_COPY_CODE_OFFSET, .old = "Chat View: Copy Latest Code Block", .label = "Copy latest code block" },
        .{ .target = app_state.SEARCH_CHAT_DICTATION_OFFSET, .old = "Chat View: Toggle Dictation", .label = "Dictate" },
        .{ .target = app_state.SEARCH_CHAT_ATTACH_OFFSET, .old = "Chat View: Attach File", .label = "Attach file" },
        .{ .target = app_state.SEARCH_CHAT_SELECTION_MENU_OFFSET, .old = "Chat View: Add selection to chat", .label = "Add selection to chat" },
        .{ .target = app_state.SEARCH_CHAT_EXPAND_TABLE_OFFSET, .old = "Chat View: Expand table", .label = "Expand table" },
        .{ .target = app_state.SEARCH_CHAT_AC_OFFSET, .old = "Chat View: Insert Command or Skill...", .label = "Insert command or skill" },
        .{ .target = app_state.SEARCH_CHAT_TAB_URL_OFFSET, .old = "Chat View: Insert browser tab URL", .label = "Insert browser page link" },
        .{ .target = app_state.SEARCH_CHAT_RESET_OFFSET, .old = "Chat View: Reset this chat", .label = "Reset this chat" },
        .{ .target = app_state.SEARCH_CHAT_ALLOW_OFFSET, .old = "Chat View: Allow", .label = "Allow" },
        .{ .target = app_state.SEARCH_CHAT_ALWAYS_OFFSET, .old = "Chat View: Always allow", .label = "Always allow" },
        .{ .target = app_state.SEARCH_CHAT_DENY_OFFSET, .old = "Chat View: Deny", .label = "Deny" },
        .{ .target = app_state.SEARCH_CHAT_STOP_OFFSET, .old = "Chat View: Stop the agent", .label = "Stop agent" },
        .{ .target = app_state.SEARCH_CHAT_QUEUE_SEND_OFFSET, .old = "Chat View: Send Queued Messages Now", .label = "Send queued messages now" },
        .{ .target = app_state.SEARCH_CHAT_DISCARD_UNSENT_OFFSET, .old = "Chat View: Discard Unsent Messages", .label = "Clear unsent messages" },
        .{ .target = app_state.SEARCH_CHAT_EDIT_QUEUED_OFFSET, .old = "Chat View: Edit Queued Messages", .label = "Edit queued messages" },
        .{ .target = app_state.SEARCH_HIDESIDEBAR_OFFSET, .old = "Sidebar: expand", .label = "Sidebar" },
        .{ .target = app_state.SEARCH_TABSORT_INBOX_OFFSET, .old = "Tab order: auto", .label = "Tab order" },
        .{ .target = app_state.SEARCH_BROWSER_FOCUS_TOGGLE_OFFSET, .old = "Browser: Switch Focus Between Terminal and Pane", .label = "Browser: Switch focus between chat and pane" },
        .{ .target = app_state.SEARCH_ZSB_REBIND_OFFSET, .old = "Browser: Repair Agent Connection", .label = "Browser: Repair browser connection" },
        .{ .target = app_state.SEARCH_POWER_AUTO_OFFSET, .old = "Power Saver: Auto", .label = "Power Saver" },
        .{ .target = app_state.SEARCH_AI_USAGE_OFFSET, .old = "Usage and servers / collapsed status cards", .label = "Status cards" },
        .{ .target = app_state.SEARCH_LADDER_AUTO_OFFSET, .old = "Token Ladder: Auto", .label = "Token plan" },
        .{ .target = app_state.SEARCH_VOICE_SPEED_100_OFFSET, .old = "Voice Speed: 1x", .label = "Voice speed" },
        .{ .target = app_state.SEARCH_RESTART_OFFSET, .old = "Restart multi bot", .label = "Restart Multi Bot" },
        .{ .target = app_state.SEARCH_QUIT_OFFSET, .old = "Quit multi bot", .label = "Quit Multi Bot" },
        .{ .target = app_state.SEARCH_CUSTOMCMD_EDIT_OFFSET, .old = "Commands: Edit commands.json", .label = "Edit custom commands" },
        .{ .target = app_state.SEARCH_USAGE_LOGIN_PRIMARY_OFFSET, .old = "Usage: Sign In to Primary Claude Account", .label = "Usage: Sign in to Claude" },
    };
    for (cases) |row| {
        for ([_][]const u8{ row.old, row.label }) |query| {
            for (query, 0..) |c, i| app_state.g_search_buf[i] = c;
            app_state.g_search_len = @intCast(query.len);
            palette.updateSearchResults();
            if (std.mem.indexOfScalar(usize, app_state.g_search_results[0..app_state.g_search_result_count], row.target) == null) {
                std.debug.print("Missing palette target {d} for '{s}'\n", .{ row.target, query });
                return error.TestUnexpectedResult;
            }
        }
    }
    app_state.g_search_theme_mode = true;
    for ([_][]const u8{ "Edge Grey", "Grey" }) |query| {
        for (query, 0..) |c, i| app_state.g_search_buf[i] = c;
        app_state.g_search_len = @intCast(query.len);
        palette.updateSearchResults();
        try std.testing.expect(std.mem.indexOfScalar(usize, app_state.g_search_results[0..app_state.g_search_result_count], app_state.SEARCH_THEME_EDGE_GRAY_OFFSET) != null);
    }
    app_state.g_search_theme_mode = false;
    app_state.g_bot_look_mode = .face;
    const look = @import("bot_look.zig");
    try std.testing.expectEqual(look.faces.len, look.face_aliases.len);
    for (look.face_aliases, 0..) |alias, i| {
        if (alias.len == 0) continue;
        for ([_][]const u8{ alias, look.faces[i] }) |query| {
            for (query, 0..) |c, j| app_state.g_search_buf[j] = c;
            app_state.g_search_len = @intCast(query.len);
            palette.updateSearchResults();
            try std.testing.expect(std.mem.indexOfScalar(usize, app_state.g_search_results[0..app_state.g_search_result_count], app_state.SEARCH_BOT_FACE_OFFSET + i) != null);
        }
    }
}
