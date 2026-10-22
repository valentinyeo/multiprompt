pub fn spawnShellWithSession(kind: ShellKind, tmux_session: ?[]const u8, cwd: ?[]const u8, startup_cmd: ?[]const u8) bool {
    if (app_state.g_account_locked) return false;
    const background_workspace = app_state.g_pending_background_workspace;
    if (tmux_session) |session| {
        if (findLocalTmuxTab(app_state.g_pending_tmux_host, session)) |existing| {
            if (!app_state.g_restoring and background_workspace == null) {
                if (app_state.g_focus_user_action_tick != 0) switchToShellByUser(existing) else switchToShell(existing);
            }
            return false;
        }
    }
    if (app_state.shell_count >= MAX_SHELLS) {
        if (background_workspace == null) notifyTabCapReached();
        return false;
    }
    if (@as(usize, @intCast(app_state.next_shell_id)) >= SPAWN_TITLES.len) return false;
    const idx = app_state.shell_count;
    const title_id = app_state.next_shell_id;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.lpTitle = SPAWN_TITLES[title_id];
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(SW_HIDE);

    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd_buf: [2048]u16 = undefined;
    const cmd_ptr = makeCmdLine(kind, &cmd_buf, tmux_session, startup_cmd, title_id) orelse return false;

    if (!@import("launch_cache.zig").pending) {
        var cmd_u8: [2048]u8 = undefined;
        var ci: usize = 0;
        while (ci < cmd_buf.len - 1 and cmd_buf[ci] != 0) : (ci += 1) {
            cmd_u8[ci] = @intCast(cmd_buf[ci] & 0xFF);
        }
        debugLog2("spawnShell cmd: ", cmd_u8[0..ci]);
    }

    var cwd_wide: [512]u16 = @splat(0);
    var cwd_ptr: ?LPCWSTR = null;
    if (cwd) |c| {
        for (c, 0..) |byte, ci| {
            if (ci >= 511) break;
            cwd_wide[ci] = @intCast(byte);
        }
        cwd_wide[c.len] = 0;
        cwd_ptr = @ptrCast(&cwd_wide);
    }

    {
        var abuf: [640]u8 = undefined;
        if (browserWinFilePathA(&abuf, title_id)) |ascii_path| {
            var wbuf: [640]u16 = undefined;
            if (win32WidePath(&wbuf, ascii_path)) |wpath| {
                _ = SetEnvironmentVariableW(L("BROWSER_CLI_WINDOW_FILE"), wpath.ptr);
            }
        }
        var sid_buf: [16]u8 = undefined;
        const sid_text = std.fmt.bufPrint(&sid_buf, "{d}", .{title_id}) catch "";
        setEnvironmentAscii(L("ZIGSHELL_SHELL_ID"), sid_text);
        if (app_state.g_notify_bound_port != 0) {
            var port_buf: [16]u8 = undefined;
            const port_text = std.fmt.bufPrint(&port_buf, "{d}", .{app_state.g_notify_bound_port}) catch "";
            setEnvironmentAscii(L("ZIGSHELL_NOTIFY_PORT"), port_text);
        } else {
            _ = SetEnvironmentVariableW(L("ZIGSHELL_NOTIFY_PORT"), null);
        }
    }
    if (isRemoteShellKind(kind)) {
        setEnvironmentAscii(L("TERM"), SSH_TERM);
        setEnvironmentAscii(L("COLORTERM"), SSH_COLORTERM);
    }

    const asynchronous = @import("launch_cache.zig").pending or app_state.g_account_applying;
    if (asynchronous) {
        const job = std.heap.page_allocator.create(StartupShell) catch return false;
        const environment = @import("win32.zig").GetEnvironmentStringsW() orelse {
            std.heap.page_allocator.destroy(job);
            return false;
        };
        job.* = .{ .shell_id = title_id, .kind = kind, .owner = app_state.g_main_hwnd, .job = app_state.g_job, .command = cmd_buf, .cwd = cwd_wide, .has_cwd = cwd_ptr != null, .environment = environment };
        _ = startup_inflight.fetchAdd(1, .acq_rel);
        const thread = std.Thread.spawn(.{ .stack_size = 256 * 1024 }, startupShellWorker, .{job}) catch {
            _ = startup_inflight.fetchSub(1, .acq_rel);
            _ = @import("win32.zig").FreeEnvironmentStringsW(environment);
            std.heap.page_allocator.destroy(job);
            return false;
        };
        thread.detach();
    }

    if (!asynchronous and CreateProcessW(null, cmd_ptr, null, null, 0, CREATE_NEW_CONSOLE, null, cwd_ptr, &si, &pi) == 0) {
        if (isRemoteShellKind(kind)) sshSpawnFailed();
        debugLog("spawnShell: CreateProcessW FAILED");
        return false;
    }
    if (!asynchronous) {
        _ = CloseHandle(pi.hThread);
        if (app_state.g_job != null) _ = AssignProcessToJobObject(app_state.g_job, pi.hProcess);
    }
    app_state.next_shell_id += 1;

    var cmd_hwnd: HANDLE = null;
    var attempts: u32 = 0;
    while (!asynchronous and attempts < 50) : (attempts += 1) {
        Sleep(100);
        if (kind == .gitbash) {
            if (findWindowByClassAndPid(pi.dwProcessId, "mintty")) |found| {
                cmd_hwnd = found;
                break;
            }
        } else {
            cmd_hwnd = FindWindowW(null, SPAWN_TITLES[title_id]);
            if (cmd_hwnd != null) break;
            if (attempts >= 5) {
                if (findConsoleWindowByPid(pi.dwProcessId)) |found| {
                    cmd_hwnd = found;
                    break;
                }
            }
        }
    }

    if (!asynchronous and cmd_hwnd == null and !isRemoteShellKind(kind)) {
        _ = TerminateProcess(pi.hProcess, 1);
        _ = CloseHandle(pi.hProcess);
        return false;
    }

    if (cmd_hwnd != null and kind != .gitbash) {
        applyBlackConsoleBackground(pi.dwProcessId);
    }

    if (cmd_hwnd != null) {
        _ = ShowWindow(cmd_hwnd, SW_HIDE);
        _ = SetParent(cmd_hwnd, app_state.g_main_hwnd);
        var style = GetWindowLongPtrW(cmd_hwnd, GWL_STYLE);
        style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
        style |= @as(isize, @intCast(WS_CHILD));
        _ = SetWindowLongPtrW(cmd_hwnd, GWL_STYLE, style);
        const no_activate: UINT = if (background_workspace != null) @import("win32.zig").SWP_NOACTIVATE else 0;
        _ = SetWindowPos(cmd_hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE | no_activate);
    }

    app_state.shells[idx] = .{
        .chat_id = app_state.g_pending_chat_id,
        .hwnd = cmd_hwnd,
        .process = pi.hProcess,
        .pid = pi.dwProcessId,
        .kind = kind,
        .name = std.mem.zeroes([64]u16),
        .name_len = 0,
        .name_source = .default,
        .notified = false,
        .activity = .idle,
        .working_since_ms = 0,
        .needs_attention = false,
        .last_title = std.mem.zeroes([256]u16),
        .last_title_len = 0,
        .tmux_session = std.mem.zeroes([64]u8),
        .tmux_session_len = 0,
        .muted = false,
        .favorite = false,
        .inbox_excluded = false,
        .keep_alive = false,
        .cached_cwd = std.mem.zeroes([512]u8),
        .cached_cwd_len = 0,
        .ram_mb = 0,
        .tmux_detect_streak = 0,
        .claude_session = false,
        .wait_handle = null,
        .shell_id = title_id,
        .favicon_hicon = null,
        .favicon_path = std.mem.zeroes([512]u8),
        .group_id = 0,
        .selected = false,
        .favicon_path_len = 0,
        .tmux_host = app_state.g_pending_tmux_host,
        .spawn_tick = if (isRemoteShellKind(kind)) GetTickCount64() else 0,
        .full_width = false,
        .browser_split_permille = BROWSER_SPLIT_DEFAULT_PERMILLE,
        .last_active = 0,
    };
    if (tmux_session) |session| {
        const session_len: u32 = @intCast(@min(session.len, app_state.shells[idx].tmux_session.len - 1));
        if (session_len > 0) {
            @memcpy(app_state.shells[idx].tmux_session[0..session_len], session[0..session_len]);
            app_state.shells[idx].tmux_session_len = session_len;
        }
    }
    setDefaultName(&app_state.shells[idx], kind, app_state.next_shell_id);
    if (background_workspace) |workspace| {
        app_state.shells[idx].workspace = workspace;
    } else if (app_state.g_single_window and !app_state.g_restoring) app_state.shells[idx].workspace = app_state.g_active_workspace;
    app_state.shells[idx].font_gen = app_state.g_font_gen;
    app_state.shell_count += 1;
    if (!app_state.g_restoring and background_workspace == null) app_state.shells[idx].last_active = nowFileTime();
    registerShellExitWait(idx);
    if (cmd_hwnd == null and pi.hProcess != null) @import("chat_send.zig").sshDisconnect(idx, "startup-console-missing");

    if (!app_state.g_restoring and background_workspace == null) {
        if (app_state.g_focus_user_action_tick != 0) switchToShellByUser(idx) else switchToShell(idx);
        requestShellRefocus(20, 12);
        saveSession();
    }
    return true;
}

pub fn respawnShellInPlace(idx: u32, terminate_existing: bool) bool {
    if (app_state.g_account_locked) return false;
    if (idx == app_state.active_shell) {
        app_state.g_front_period.selected = null;
        @import("main.zig").sessionFrontChanged();
    }
    if (idx >= app_state.shell_count) return false;
    const kind = app_state.shells[idx].kind;
    if (kind != .vps and kind != .vps2 and kind != .tmux) return false;
    if (@as(usize, @intCast(app_state.next_shell_id)) >= SPAWN_TITLES.len) return false;

    const saved_chat_id = app_state.shells[idx].chat_id;
    const saved_sync_owned = app_state.shells[idx].sync_owned;
    const saved_name = app_state.shells[idx].name;
    const saved_name_len = app_state.shells[idx].name_len;
    const saved_name_source = app_state.shells[idx].name_source;
    const saved_muted = app_state.shells[idx].muted;
    const saved_inbox_excluded = app_state.shells[idx].inbox_excluded;
    const saved_pinned_top = app_state.shells[idx].pinned_top;
    const saved_locked = app_state.shells[idx].locked;
    const saved_favorite = app_state.shells[idx].favorite;
    const saved_last_used = app_state.shells[idx].last_used;
    const saved_visits = app_state.shells[idx].visits;
    const saved_input = app_state.shells[idx].input;
    const saved_claude = app_state.shells[idx].claude_session;
    const saved_favicon = app_state.shells[idx].favicon_hicon;
    const saved_favicon_path = app_state.shells[idx].favicon_path;
    const saved_favicon_path_len = app_state.shells[idx].favicon_path_len;
    const saved_cwd = app_state.shells[idx].cached_cwd;
    const saved_cwd_len = app_state.shells[idx].cached_cwd_len;
    const saved_tmux = app_state.shells[idx].tmux_session;
    const saved_tmux_len = app_state.shells[idx].tmux_session_len;
    const saved_group_id = app_state.shells[idx].group_id;
    const saved_tmux_host = app_state.shells[idx].tmux_host;
    if (app_state.shells[idx].ssh_reconnect.phase != .reconnecting) app_state.shells[idx].ssh_reconnect.start();
    const saved_ssh_reconnect = app_state.shells[idx].ssh_reconnect;
    const saved_workspace = app_state.shells[idx].workspace;
    const saved_full_width = app_state.shells[idx].full_width;
    const saved_chat_view_on = app_state.shells[idx].chat_view_on;
    const saved_chat_shell_override = app_state.shells[idx].chat_shell_override;
    const saved_last_active = app_state.shells[idx].last_active;
    const saved_last_viewed = app_state.shells[idx].last_viewed;
    const saved_preview = app_state.shells[idx].preview;
    const saved_preview_len = app_state.shells[idx].preview_len;
    const saved_ai_agent = app_state.shells[idx].ai_agent;
    const saved_claude_sid = app_state.shells[idx].claude_sid;
    const saved_claude_sid_len = app_state.shells[idx].claude_sid_len;
    const saved_claude_cwd = app_state.shells[idx].claude_cwd;
    const saved_claude_cwd_len = app_state.shells[idx].claude_cwd_len;
    const saved_browser_hwnd = app_state.shells[idx].browser_hwnd;
    const saved_browser_docking = app_state.shells[idx].browser_docking;
    const saved_browser_enabled = app_state.shells[idx].browser_enabled;
    const saved_browser_url = app_state.shells[idx].browser_url;
    const saved_browser_url_len = app_state.shells[idx].browser_url_len;
    const saved_browser_launch_tick = app_state.shells[idx].browser_launch_tick;
    const saved_browser_suspended = app_state.shells[idx].browser_suspended;
    const saved_browser_native = app_state.shells[idx].browser_native;
    const saved_browser_split_permille = app_state.shells[idx].browser_split_permille;
    const saved_browser_window_id = app_state.shells[idx].browser_window_id;
    const saved_inbox_archived = app_state.shells[idx].inbox_archived;
    const saved_archive_time = app_state.shells[idx].archive_time;
    const saved_archive_done = app_state.shells[idx].archive_done;
    const saved_last_done_time = app_state.shells[idx].last_done_time;
    const saved_last_done_content = app_state.shells[idx].last_done_content;
    const saved_last_done_content_valid = app_state.shells[idx].last_done_content_valid;
    const saved_archive_active = app_state.shells[idx].archive_active;
    const saved_archive_content = app_state.shells[idx].archive_content;
    const saved_archive_content_valid = app_state.shells[idx].archive_content_valid;
    const saved_needs_attention = app_state.shells[idx].needs_attention;
    const saved_hook_capable = app_state.shells[idx].hook_capable;
    const saved_turn_pending = app_state.shells[idx].turn_pending;
    const saved_deferred_done = app_state.shells[idx].deferred_done;
    const saved_blue_dot_source = app_state.shells[idx].last_blue_dot_source;
    const saved_blue_dot_time = app_state.shells[idx].last_blue_dot_time;
    const saved_diag_events = app_state.shells[idx].diag_events;
    const saved_diag_event_lens = app_state.shells[idx].diag_event_lens;
    const saved_diag_event_next = app_state.shells[idx].diag_event_next;
    const saved_diag_event_count = app_state.shells[idx].diag_event_count;

    unregisterShellExitWait(idx);
    if (app_state.shells[idx].hwnd != null) {
        _ = ShowWindow(app_state.shells[idx].hwnd, SW_HIDE);
        app_state.shells[idx].hwnd = null;
    }
    if (terminate_existing and app_state.shells[idx].pid != 0) {
        killProcessTree(app_state.shells[idx].pid);
        Sleep(150);
    }
    if (app_state.shells[idx].process != null) {
        _ = CloseHandle(app_state.shells[idx].process);
        app_state.shells[idx].process = null;
    }
    app_state.shells[idx].pid = 0;

    const title_id = app_state.next_shell_id;

    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.lpTitle = SPAWN_TITLES[title_id];
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(SW_HIDE);

    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    var cmd_buf: [2048]u16 = undefined;
    const tmux_slice: ?[]const u8 = if (saved_tmux_len > 0) saved_tmux[0..saved_tmux_len] else null;
    app_state.g_pending_tmux_host = saved_tmux_host;
    defer app_state.g_pending_tmux_host = 0;
    const cmd_ptr = makeCmdLine(kind, &cmd_buf, tmux_slice, null, title_id) orelse return false;

    if (CreateProcessW(null, cmd_ptr, null, null, 0, CREATE_NEW_CONSOLE, null, null, &si, &pi) == 0) {
        sshSpawnFailed();
        debugLog("respawnShellInPlace: CreateProcessW FAILED");
        return false;
    }
    _ = CloseHandle(pi.hThread);
    if (app_state.g_job != null) _ = AssignProcessToJobObject(app_state.g_job, pi.hProcess);
    app_state.next_shell_id += 1;

    var cmd_hwnd: HANDLE = null;
    var attempts: u32 = 0;
    while (attempts < 50) : (attempts += 1) {
        Sleep(100);
        cmd_hwnd = FindWindowW(null, SPAWN_TITLES[title_id]);
        if (cmd_hwnd != null) break;
        if (attempts >= 5) {
            if (findConsoleWindowByPid(pi.dwProcessId)) |found| {
                cmd_hwnd = found;
                break;
            }
        }
    }
    if (cmd_hwnd == null) {
        var exit_code: DWORD = std.math.maxInt(DWORD);
        const got_code = GetExitCodeProcess(pi.hProcess, &exit_code) != 0;
        var exit_log: [192]u8 = undefined;
        debugLog(std.fmt.bufPrint(&exit_log, "ssh-reconnect exit id={d} reason=respawn-console-missing exit_code={d} known={}", .{ title_id, exit_code, got_code }) catch "ssh-reconnect exit log-overflow");
        _ = TerminateProcess(pi.hProcess, 1);
        _ = CloseHandle(pi.hProcess);
        return false;
    }

    applyBlackConsoleBackground(pi.dwProcessId);

    _ = ShowWindow(cmd_hwnd, SW_HIDE);
    _ = SetParent(cmd_hwnd, app_state.g_main_hwnd);
    var style = GetWindowLongPtrW(cmd_hwnd, GWL_STYLE);
    style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
    style |= @as(isize, @intCast(WS_CHILD));
    _ = SetWindowLongPtrW(cmd_hwnd, GWL_STYLE, style);
    _ = SetWindowPos(cmd_hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);

    if (app_state.shells[idx].kind != .tmux) chatHistoryForget(app_state.shells[idx].shell_id);
    app_state.shells[idx] = .{
        .chat_id = saved_chat_id,
        .sync_owned = saved_sync_owned,
        .hwnd = cmd_hwnd,
        .process = pi.hProcess,
        .pid = pi.dwProcessId,
        .kind = kind,
        .name = saved_name,
        .name_len = saved_name_len,
        .name_source = saved_name_source,
        .notified = false,
        .activity = .idle,
        .working_since_ms = 0,
        .needs_attention = saved_needs_attention,
        .hook_capable = saved_hook_capable,
        .turn_pending = saved_turn_pending,
        .deferred_done = saved_deferred_done,
        .last_blue_dot_source = saved_blue_dot_source,
        .last_blue_dot_time = saved_blue_dot_time,
        .inbox_archived = saved_inbox_archived,
        .archive_time = saved_archive_time,
        .archive_done = saved_archive_done,
        .last_done_time = saved_last_done_time,
        .last_done_content = saved_last_done_content,
        .last_done_content_valid = saved_last_done_content_valid,
        .archive_active = saved_archive_active,
        .archive_content = saved_archive_content,
        .archive_content_valid = saved_archive_content_valid,
        .last_title = std.mem.zeroes([256]u16),
        .last_title_len = 0,
        .tmux_session = saved_tmux,
        .tmux_session_len = saved_tmux_len,
        .muted = saved_muted,
        .inbox_excluded = saved_inbox_excluded,
        .keep_alive = false,
        .pinned_top = saved_pinned_top,
        .locked = saved_locked,
        .favorite = saved_favorite,
        .last_used = saved_last_used,
        .visits = saved_visits,
        .input = saved_input,
        .cached_cwd = saved_cwd,
        .cached_cwd_len = saved_cwd_len,
        .ram_mb = 0,
        .tmux_detect_streak = 0,
        .claude_session = saved_claude,
        .wait_handle = null,
        .shell_id = title_id,
        .favicon_hicon = saved_favicon,
        .favicon_path = saved_favicon_path,
        .favicon_path_len = saved_favicon_path_len,
        .group_id = saved_group_id,
        .selected = false,
        .tmux_host = saved_tmux_host,
        .spawn_tick = GetTickCount64(),
        .ssh_reconnect = saved_ssh_reconnect,
        .disconnected = true,
        .full_width = saved_full_width,
        .chat_view_on = saved_chat_view_on,
        .chat_shell_override = saved_chat_shell_override,
        .last_active = if (saved_last_active != 0) saved_last_active else nowFileTime(),
        .last_viewed = saved_last_viewed,
        .workspace = saved_workspace,
        .preview = saved_preview,
        .preview_len = saved_preview_len,
        .ai_agent = saved_ai_agent,
        .claude_sid = saved_claude_sid,
        .claude_sid_len = saved_claude_sid_len,
        .claude_cwd = saved_claude_cwd,
        .claude_cwd_len = saved_claude_cwd_len,
        .browser_hwnd = saved_browser_hwnd,
        .browser_docking = saved_browser_docking,
        .browser_enabled = saved_browser_enabled,
        .browser_url = saved_browser_url,
        .browser_url_len = saved_browser_url_len,
        .browser_launch_tick = saved_browser_launch_tick,
        .browser_suspended = saved_browser_suspended,
        .browser_native = saved_browser_native,
        .browser_split_permille = saved_browser_split_permille,
        .browser_window_id = saved_browser_window_id,
        .diag_events = saved_diag_events,
        .diag_event_lens = saved_diag_event_lens,
        .diag_event_next = saved_diag_event_next,
        .diag_event_count = saved_diag_event_count,
    };
    registerShellExitWait(idx);

    if (app_state.active_shell == idx) {
        _ = showShellConsole(idx, SW_SHOWNOACTIVATE, "respawnShellInPlace");
        repositionActive();
    }

    invalidateSidebar();
    {
        const knames = [_][]const u8{ "cmd", "pwsh", "vps", "tmux", "vps2", "bash", "gitbash" };
        var pre: [96]u8 = undefined;
        var pp: usize = 0;
        const tag = "respawnShellInPlace ok kind=";
        @memcpy(pre[0..tag.len], tag);
        pp = tag.len;
        const kn = knames[@intFromEnum(kind)];
        @memcpy(pre[pp .. pp + kn.len], kn);
        pp += kn.len;
        const tag2 = " idx=";
        @memcpy(pre[pp .. pp + tag2.len], tag2);
        pp += tag2.len;
        appendDecimal(&pre, &pp, idx);
        const tag3 = " new_id=";
        @memcpy(pre[pp .. pp + tag3.len], tag3);
        pp += tag3.len;
        appendDecimal(&pre, &pp, title_id);
        var nbuf: [64]u8 = undefined;
        var nl: usize = 0;
        var ni: usize = 0;
        while (ni < saved_name_len and nl < nbuf.len) : (ni += 1) {
            const c = saved_name[ni];
            nbuf[nl] = if (c < 128) @intCast(c) else '?';
            nl += 1;
        }
        debugLog2(pre[0..pp], nbuf[0..nl]);
    }
    return true;
}

fn startupShellWorker(job: *StartupShell) void {
    const win = @import("win32.zig");
    const environment = job.environment;
    defer _ = win.FreeEnvironmentStringsW(environment);
    var si = std.mem.zeroes(STARTUPINFOW);
    si.cb = @sizeOf(STARTUPINFOW);
    si.lpTitle = SPAWN_TITLES[job.shell_id];
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = @intCast(SW_HIDE);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    if (CreateProcessW(null, @ptrCast(&job.command), null, null, 0, CREATE_NEW_CONSOLE | 0x400, @ptrCast(job.environment), if (job.has_cwd) @ptrCast(&job.cwd) else null, &si, &pi) != 0) {
        _ = CloseHandle(pi.hThread);
        job.process = pi.hProcess;
        job.pid = pi.dwProcessId;
        if (job.job != null) _ = AssignProcessToJobObject(job.job, pi.hProcess);
        for (0..50) |attempt| {
            if (job.kind == .gitbash) {
                job.hwnd = findWindowByClassAndPid(job.pid, "mintty") orelse null;
            } else {
                job.hwnd = FindWindowW(null, SPAWN_TITLES[job.shell_id]);
                if (job.hwnd == null and attempt >= 5) job.hwnd = findConsoleWindowByPid(job.pid) orelse null;
            }
            if (job.hwnd != null) break;
            if (WaitForSingleObject(job.process, 100) == 0) break;
        }
        if (job.hwnd != null) {
            _ = ShowWindow(job.hwnd, SW_HIDE);
            _ = SetParent(job.hwnd, job.owner);
            var style = GetWindowLongPtrW(job.hwnd, GWL_STYLE);
            style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
            style |= @as(isize, @intCast(WS_CHILD));
            _ = SetWindowLongPtrW(job.hwnd, GWL_STYLE, style);
            _ = SetWindowPos(job.hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE | @import("win32.zig").SWP_NOACTIVATE);
        }
    }
    if (job.hwnd == null and job.process != null and !isRemoteShellKind(job.kind)) {
        _ = TerminateProcess(job.process, 1);
        _ = CloseHandle(job.process);
        job.process = null;
        job.pid = 0;
    }
    if (PostMessageW(job.owner, WM_STARTUP_SHELL_READY, 0, @bitCast(@intFromPtr(job))) == 0) {
        discardStartupShell(job);
        _ = startup_inflight.fetchSub(1, .acq_rel);
    }
}

pub fn finishStartupShell(job: *StartupShell) void {
    defer _ = startup_inflight.fetchSub(1, .acq_rel);
    const idx = findShellById(job.shell_id) orelse {
        discardStartupShell(job);
        return;
    };
    if (app_state.g_app_closing or app_state.g_account_locked) {
        discardStartupShell(job);
        return;
    }
    defer std.heap.page_allocator.destroy(job);
    app_state.shells[idx].process = job.process;
    app_state.shells[idx].pid = job.pid;
    app_state.shells[idx].hwnd = job.hwnd;
    if (job.process != null) registerShellExitWait(idx);
    if (job.hwnd == null) {
        if (isRemoteShellKind(job.kind)) @import("chat_send.zig").sshDisconnect(idx, "startup-console-missing");
        return;
    }
    if (job.kind != .gitbash) applyBlackConsoleBackground(job.pid);
    if (idx == app_state.active_shell) {
        _ = showShellConsole(idx, SW_SHOW, "startup-shell-ready");
        repositionActive();
    }
    _ = InvalidateRect(app_state.g_main_hwnd, null, 0);
}

pub fn markSshTabDisconnected(idx: u32) void {
    if (chatBenchEnabled() or idx >= app_state.shell_count) return;
    const k = app_state.shells[idx].kind;
    if (k != .vps and k != .vps2 and k != .tmux) return;
    if (app_state.shells[idx].ssh_reconnect.phase == .closed) return;
    app_state.shells[idx].ssh_reconnect.confirmDisconnect(GetTickCount64(), "console-missing", app_state.shells[idx].process != null and shellProcessAliveForRead(idx));
    unregisterShellExitWait(idx);
    if (app_state.shells[idx].hwnd != null) {
        _ = ShowWindow(app_state.shells[idx].hwnd, SW_HIDE);
        app_state.shells[idx].hwnd = null;
    }
    if (app_state.shells[idx].pid != 0) killProcessTree(app_state.shells[idx].pid);
    if (app_state.shells[idx].process != null) {
        _ = CloseHandle(app_state.shells[idx].process);
        app_state.shells[idx].process = null;
    }
    app_state.shells[idx].pid = 0;
    app_state.shells[idx].activity = .idle;
    app_state.shells[idx].needs_attention = false;
    app_state.shells[idx].disconnected = true;
    @import("chat_send.zig").sshReconnectArm(idx, "link-exit");
    debugLog("markSshTabDisconnected: preserving SSH/tmux tab for automatic reconnect");
    var reconnect_log: [160]u8 = undefined;
    debugLog(std.fmt.bufPrint(&reconnect_log, "ssh-reconnect scheduled id={d} attempt={d} delay_ms={d}", .{ app_state.shells[idx].shell_id, app_state.shells[idx].ssh_reconnect.attempts +| 1, app_state.shells[idx].ssh_reconnect.delay_ms }) catch "ssh-reconnect scheduled");
    armSshReconnectTimerIfNeeded();
    if (app_state.shells[idx].locked or app_state.shells[idx].pinned_top) {
        logSessionAuditAlways(if (app_state.shells[idx].locked) "locked-session-disconnected-preserved" else "pinned-session-disconnected-preserved");
    }
    repositionActive();
    invalidateSidebar();
    saveSession();
}

pub fn resolveSshPath(force: bool) bool {
    while (!app_state.g_ssh_mutex.tryLock()) Sleep(1);
    defer app_state.g_ssh_mutex.unlock();
    if (!force and app_state.g_ssh_resolved) return app_state.g_ssh_path_len != 0;
    app_state.g_ssh_resolved = true;
    app_state.g_ssh_path_len = 0;
    var override_buf: [520]u8 = undefined;
    var override: []const u8 = "";
    const appdata_len = GetEnvironmentVariableA("APPDATA", &override_buf, override_buf.len);
    if (appdata_len > 0 and appdata_len < override_buf.len - 25) {
        const tail = "\\ZigShell\\ssh-path.txt";
        @memcpy(override_buf[appdata_len .. appdata_len + tail.len], tail);
        if (win32OpenRead(override_buf[0 .. appdata_len + tail.len])) |file| {
            var config: [520]u8 = undefined;
            const len = win32ReadAll(file, &config);
            _ = CloseHandle(file);
            var value = std.mem.trim(u8, config[0..len], " \t\r\n");
            if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') value = value[1 .. value.len - 1];
            if (value.len < override_buf.len) {
                @memcpy(override_buf[0..value.len], value);
                override = override_buf[0..value.len];
            }
        }
    }
    var local_buf: [520]u8 = undefined;
    var local: []const u8 = "";
    const local_len = GetEnvironmentVariableA("LOCALAPPDATA", &local_buf, local_buf.len);
    const local_tail = "\\OpenSSH\\ssh.exe";
    if (local_len > 0 and local_len + local_tail.len < local_buf.len) {
        @memcpy(local_buf[local_len .. local_len + local_tail.len], local_tail);
        local = local_buf[0 .. local_len + local_tail.len];
    }
    var found_wide: [520]u16 = undefined;
    var found_buf: [520]u8 = undefined;
    var on_path: []const u8 = "";
    const found_len = SearchPathW(null, L("ssh.exe"), null, found_wide.len, &found_wide, null);
    if (found_len > 0 and found_len < found_wide.len) {
        const n = std.unicode.utf16LeToUtf8(&found_buf, found_wide[0..found_len]) catch 0;
        on_path = found_buf[0..n];
    }
    for (0..5) |i| {
        const candidate = sshCandidate(i, override, local, on_path);
        if (candidate.len == 0 or candidate.len >= app_state.g_ssh_path.len) continue;
        if (!probeSsh(candidate)) continue;
        @memcpy(app_state.g_ssh_path[0..candidate.len], candidate);
        app_state.g_ssh_path_len = candidate.len;
        debugLog2("ssh: selected working executable: ", candidate);
        return true;
    }
    debugLog("ssh: no working ssh.exe found");
    if (!app_state.g_ssh_notice_sent and app_state.g_main_hwnd != null) {
        app_state.g_ssh_notice_sent = true;
        _ = PostMessageW(app_state.g_main_hwnd, WM_APP_SSH_UNAVAILABLE, 0, 0);
    }
    return false;
}
