pub fn restoreSession() u32 {
    if (app_state.g_account_locked) return 0;
    app_state.g_restored_valid_session = false;
    app_state.g_restoring = true;
    defer {
        if (!@import("launch_cache.zig").pending) logSessionAudit("restoreSession:after-spawn-before-save");
        ensureOtherWorkspaceSlot();
        app_state.g_restoring = false;
        saveSession();
    }
    var path_buf: [512]u8 = undefined;
    const path = getSessionPath(&path_buf) orelse {
        logSessionAudit("restoreSession:no-session-path");
        return 0;
    };

    const json_buf = if (@import("launch_cache.zig").pending and startupRestoreReady()) ready: {
        const bytes = startup_bytes;
        startup_bytes = null;
        break :ready bytes;
    } else readSessionBytes(path);
    const bytes = json_buf orelse return 0;
    defer std.heap.page_allocator.free(bytes);

    const prepared = @import("launch_cache.zig").pending and startupRestoreReady();
    var parsed = if (prepared) ready: {
        const value = startup_parsed;
        startup_parsed = null;
        break :ready value orelse return 0;
    } else json_reader.parse(std.heap.page_allocator, bytes) catch return 0;
    defer parsed.deinit();
    const json = parsed.value;

    var tabs: [MAX_SHELLS]SavedTab = undefined;
    const tab_count = json_reader.sessionTabs(json, tabs[0..], MAX_LWS);
    app_state.g_restored_valid_session = true;
    var restored_active_tab: ?u32 = null;
    const active = json_reader.uintDefault(json, "active_tab", std.math.maxInt(u32));
    if (active < tab_count) restored_active_tab = @intCast(active);
    if (json_reader.boolTrue(json, "sound_enabled")) app_state.g_sound_enabled = true;
    if (!prepared) {
        loadGlobalTheme();
        loadBrowserEngineConfig();
        loadEdgeProfileConfig();
        loadEdgeExeConfig();
        loadChromeExeConfig();
    }
    if (IS_DEV) {
        ensureDevThemeInitialized();
        app_state.g_dev_font_idx = app_state.DEFAULT_CONSOLE_FONT_IDX;
        setWideAscii(&app_state.g_dev_theme.console_font, DEV_CONSOLE_FONTS[app_state.g_dev_font_idx]);
        const size = json_reader.uint(json, "dev_console_size");
        if (size >= 8 and size <= 40) app_state.g_dev_theme.console_font_height = @intCast(size);
    }
    if (json_reader.boolTrue(json, "mobile_mode")) app_state.g_mobile_mode = true;
    if (json_reader.boolTrue(json, "hide_sidebar")) app_state.g_hide_sidebar = true;
    if (json_reader.boolTrue(json, "sidebar_collapsed")) app_state.g_sidebar_collapsed = true;
    app_state.g_locked_section_collapsed = json_reader.boolTrue(json, "locked_section_collapsed");
    app_state.g_pinned_section_collapsed = json_reader.boolTrue(json, "pinned_section_collapsed");
    app_state.g_recents_section_collapsed = json_reader.boolTrue(json, "recents_section_collapsed");
    if (IS_DEV and json_reader.boolFalse(json, "thread_title")) app_state.g_thread_title = false;
    const console_font = json_reader.uint(json, "console_font_h");
    if (console_font >= 8 and console_font <= 40) app_state.g_console_font_override = @intCast(console_font);
    if (json == .object and json.object.contains("shell_zoom_scale")) app_state.g_console_font_override = 0;
    const chat_font = json_reader.uint(json, "chat_font_pt");
    if (chat_font >= 10 and chat_font <= 28) app_state.g_chat_font_pt = @intCast(chat_font);
    for (0..2) |a| {
        var i: usize = 20;
        while (i > 0) {
            i -= 1;
            var key_buf: [48]u8 = undefined;
            const key = std.fmt.bufPrint(&key_buf, "chat_ac_{s}_{d}", .{ if (a == 0) @as([]const u8, "claude") else "codex", i }) catch continue;
            var name: [201]u8 = .{0} ** 201;
            const n = json_reader.copyString(json, key, &name);
            if (n > 0) chat_complete.promoteRecent(&app_state.g_chat_ac_mru[a], &app_state.g_chat_ac_mru_count[a], name[0..n]);
        }
    }
    const saved_settings = json_reader.field(json, "settings");
    if (saved_settings != .null) {
        const parsed_settings = std.json.parseFromValue(@import("frequent.zig").Settings, std.heap.page_allocator, saved_settings, .{}) catch null;
        if (parsed_settings) |settings| {
            app_state.g_layout_settings = settings.value;
            settings.deinit();
        }
    }
    app_state.g_inbox_tab = @import("frequent.zig").migrateSplit(@intCast(@min(json_reader.uint(json, "inbox_tab"), std.math.maxInt(u32))), json_reader.boolTrue(json, "inbox_visits_order"));
    const chat_mode = json_reader.string(json_reader.field(json, "chat_view_mode")) orelse "";
    if (std.mem.eql(u8, chat_mode, "everywhere")) {
        app_state.g_chat_view_mode = .everywhere;
    } else if (std.mem.eql(u8, chat_mode, "nowhere")) {
        app_state.g_chat_view_mode = .nowhere;
    }
    if (app_state.g_chat_view_mode == .everywhere and json_reader.boolTrue(json, "chat_active")) app_state.g_chat_view_restore_on = true;
    app_state.g_igsh354_paste_focus = !json_reader.boolFalse(json, "igsh354_paste_focus");
    app_state.g_voice_always_listen = !json_reader.boolFalse(json, "voice_always_listen");
    if (json_reader.boolFalse(json, "eta_numbers")) app_state.g_eta_numbers_on = false;
    if (json_reader.boolFalse(json, "eta_progress")) app_state.g_eta_progress_on = false;
    const voice_speed = json_reader.string(json_reader.field(json, "voice_speed")) orelse "";
    if (std.mem.eql(u8, voice_speed, "1.0")) {
        app_state.g_voice_speed = .s100;
    } else if (std.mem.eql(u8, voice_speed, "1.4")) {
        app_state.g_voice_speed = .s140;
    } else if (std.mem.eql(u8, voice_speed, "1.5")) {
        app_state.g_voice_speed = .s150;
    }
    const scale = json_reader.uint(json, "ui_scale");
    if (scale >= 80 and scale <= 150) app_state.g_ui_scale = @intCast(scale);
    const suspend_min = json_reader.uintDefault(json, "browser_suspend_min", std.math.maxInt(u64));
    if (suspend_min == 0) {
        app_state.g_browser_autosuspend = false;
        app_state.g_browser_suspend_min = BROWSER_SUSPEND_DEFAULT_MIN;
    } else if (suspend_min <= 24 * 60) {
        app_state.g_browser_autosuspend = true;
        app_state.g_browser_suspend_min = @intCast(suspend_min);
    }
    app_state.g_hide_pills = json_reader.boolean(json_reader.field(json, "hide_pills"), app_state.g_hide_pills);

    var saved_last_shell: [MAX_LWS]u32 = [_]u32{0} ** MAX_LWS;
    app_state.g_ws_last_shell = [_]u32{0} ** MAX_LWS;
    var restored_active_ws: u8 = 0;
    if (json_reader.boolTrue(json, "single_window")) app_state.g_single_window = true;
    if (app_state.g_single_window) {
        const workspace = json_reader.uint(json, "active_workspace");
        if (workspace < MAX_LWS) restored_active_ws = @intCast(workspace);
        const count = json_reader.uint(json, "workspace_count");
        if (count >= 1 and count <= MAX_LWS) app_state.g_lws_count = @intCast(count);
        for (json_reader.array(json_reader.field(json, "workspaces")), 0..) |obj, wi| {
            if (wi >= MAX_LWS) break;
            app_state.g_ws_name_len[wi] = json_reader.copyString(obj, "name", &app_state.g_ws_names[wi]);
            var wid_tmp: [64]u8 = std.mem.zeroes([64]u8);
            const wid_n = json_reader.copyString(obj, "wid", &wid_tmp);
            const wid_cap = @min(wid_n, @as(u32, @intCast(app_state.g_ws_ids[wi].len)));
            if (wid_cap > 0) @memcpy(app_state.g_ws_ids[wi][0..wid_cap], wid_tmp[0..wid_cap]);
            app_state.g_ws_id_len[wi] = wid_cap;
            app_state.g_ws_snoozed[wi] = json_reader.boolTrue(obj, "snoozed");
            saved_last_shell[wi] = @intCast(@min(json_reader.uint(obj, "last_shell"), std.math.maxInt(u32)));
        }
    }

    if (restored_active_tab) |at| {
        if (at < tab_count) {
            const winner = tmux_identity.restoreWinner(tabs[0..tab_count], at);
            restored_active_tab = @intCast(winner);
            if (app_state.g_single_window and winner != at) app_state.g_active_workspace = tabs[winner].workspace;
        }
    }
    if (!prepared) logSavedTabsAudit("restoreSession:parsed-session-file", tabs[0..tab_count]);

    app_state.group_count = 0;
    app_state.next_group_id = 1;
    for (json_reader.array(json_reader.field(json, "groups"))) |obj| {
        if (app_state.group_count >= MAX_GROUPS) break;
        const gid: u32 = @truncate(json_reader.uint(obj, "id"));
        var gname: [64]u16 = std.mem.zeroes([64]u16);
        const gname_len = json_reader.copyWide(obj, "name", &gname);
        const gcoll = json_reader.boolTrue(obj, "collapsed");
        const gcolor: u8 = @intCast(json_reader.uint(obj, "color") % GROUP_COLORS.len);
        if (gid != 0) {
            app_state.groups[app_state.group_count] = .{ .id = gid, .name = gname, .name_len = gname_len, .collapsed = gcoll, .color = gcolor };
            app_state.group_count += 1;
            if (gid + 1 > app_state.next_group_id) app_state.next_group_id = gid + 1;
        }
    }

    for (0..if (prepared) 0 else tab_count) |t| {
        if (tabs[t].pid != 0 and !tabs[t].keep_alive) {
            const orphan = OpenProcess(PROCESS_TERMINATE, 0, tabs[t].pid);
            if (orphan != null) {
                var exit_code: DWORD = 0;
                if (GetExitCodeProcess(orphan, &exit_code) != 0 and exit_code == STILL_ACTIVE) {
                    debugLog("restoreSession: killing orphan process tree");
                    killProcessTree(tabs[t].pid);
                }
                _ = CloseHandle(orphan);
            }
        }
    }

    debugLog("restoreSession: starting restore");
    var spawned: u32 = 0;
    var restored_active_shell_id: u32 = 0;
    var restored_shell_ids: [MAX_SHELLS]u32 = [_]u32{0} ** MAX_SHELLS;
    for (0..tab_count) |t| {
        if (@import("launch_cache.zig").closedDuringStartup(tabs[t].chat_id)) continue;
        if (tmux_identity.restoreWinner(tabs[0..tab_count], t) != t) continue;
        const ok = if (chatBenchEnabled() and isRemoteShellKind(tabs[t].kind)) false else spawnSavedTab(&tabs[t], .continue_latest);
        if (ok) {
            const idx = app_state.shell_count - 1;
            app_state.active_shell = idx;
            restored_shell_ids[t] = app_state.shells[idx].shell_id;
            if (restored_active_tab != null and restored_active_tab.? == t) {
                restored_active_shell_id = app_state.shells[idx].shell_id;
            }
            spawned += 1;
        } else {
            debugLog("restoreSession: spawn FAILED");
            if (preserveFailedRemoteSavedTab(&tabs[t])) |idx| {
                app_state.active_shell = idx;
                restored_shell_ids[t] = app_state.shells[idx].shell_id;
                if (restored_active_tab != null and restored_active_tab.? == t) {
                    restored_active_shell_id = app_state.shells[idx].shell_id;
                }
                spawned += 1;
            }
        }
    }

    for (tabs[0..tab_count], 0..) |tab, t| {
        if (tab.shell_id != 0 and saved_last_shell[tab.workspace] == tab.shell_id) {
            app_state.g_ws_last_shell[tab.workspace] = restored_shell_ids[tmux_identity.restoreWinner(tabs[0..tab_count], t)];
        }
    }
    if (restored_active_shell_id != 0) {
        if (findShellById(restored_active_shell_id)) |idx| app_state.active_shell = idx;
    }

    for (0..app_state.shell_count) |si| {
        if (app_state.shells[si].group_id != 0 and findGroupIdx(app_state.shells[si].group_id) == null) {
            app_state.shells[si].group_id = 0;
        }
    }
    pruneEmptyGroups();
    normalizeGroupOrder();

    if (app_state.g_single_window) {
        var max_ws: u8 = 0;
        for (0..app_state.shell_count) |si| {
            if (app_state.shells[si].workspace > max_ws) max_ws = app_state.shells[si].workspace;
        }
        if (@as(u32, max_ws) + 1 > app_state.g_lws_count) app_state.g_lws_count = max_ws + 1;
        if (app_state.g_lws_count < 1) app_state.g_lws_count = 1;
        app_state.g_active_workspace = if (restored_active_shell_id != 0 and app_state.active_shell < app_state.shell_count)
            app_state.shells[app_state.active_shell].workspace
        else if (restored_active_ws < app_state.g_lws_count)
            restored_active_ws
        else
            0;
        compactWorkspaceSlots();
        if (restored_active_shell_id == 0) {
            for (0..app_state.shell_count) |si| {
                if (app_state.shells[si].workspace == app_state.g_active_workspace) {
                    app_state.active_shell = @intCast(si);
                    break;
                }
            }
        }
    }

    const selected_chat = @import("launch_cache.zig").selected_chat_id;
    if (@import("launch_cache.zig").pending and selected_chat != 0) {
        for (app_state.shells[0..app_state.shell_count], 0..) |shell, i| {
            if (shell.chat_id == selected_chat) {
                app_state.active_shell = @intCast(i);
                app_state.g_active_workspace = shell.workspace;
                break;
            }
        }
    }
    const selected_live = @import("launch_cache.zig").selected_live_shell_id;
    if (@import("launch_cache.zig").pending and selected_live != 0) {
        if (findShellById(selected_live)) |idx| {
            app_state.active_shell = idx;
            app_state.g_active_workspace = app_state.shells[idx].workspace;
        }
    }
    seedActiveWorkspaceLastShell(app_state.shells[0..app_state.shell_count], app_state.active_shell, &app_state.g_ws_last_shell);

    if (spawned > 0 and app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].hwnd != null) {
        _ = showShellConsole(app_state.active_shell, SW_SHOW, "restoreSession");
        app_state.g_nudge_repaint = true;
        repositionActive();
        _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
    }

    if (spawned > 0) {
        var lg_buf: [520]u8 = undefined;
        const lg_path = std.fmt.bufPrint(&lg_buf, "{s}.lastgood", .{path}) catch "";
        if (lg_path.len > 0) {
            if (prepared) {
                if (std.heap.page_allocator.dupe(u8, bytes)) |copy| {
                    const thread = std.Thread.spawn(.{}, writeStartupLastgood, .{ lg_buf, lg_path.len, copy }) catch {
                        std.heap.page_allocator.free(copy);
                        return spawned;
                    };
                    thread.detach();
                } else |_| {}
            } else if (win32OpenWrite(lg_path)) |lh| {
                win32WriteAll(lh, bytes);
                _ = CloseHandle(lh);
            }
        }
    }

    return spawned;
}
