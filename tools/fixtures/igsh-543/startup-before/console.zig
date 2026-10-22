pub fn spawnShellWithSession(kind: ShellKind, tmux_session: ?[]const u8, cwd: ?[]const u8, startup_cmd: ?[]const u8) bool {
    if (app_state.g_account_locked) return false;
    if (tmux_session) |session| {
        if (findLocalTmuxTab(app_state.g_pending_tmux_host, session)) |existing| {
            if (!app_state.g_restoring) {
                if (app_state.g_focus_user_action_tick != 0) switchToShellByUser(existing) else switchToShell(existing);
            }
            return false;
        }
    }
    if (app_state.shell_count >= MAX_SHELLS) {
        notifyTabCapReached();
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

    {
        var cmd_u8: [2048]u8 = undefined;
        var ci: usize = 0;
        while (ci < cmd_buf.len - 1 and cmd_buf[ci] != 0) : (ci += 1) {
            cmd_u8[ci] = @intCast(cmd_buf[ci] & 0xFF);
        }
        debugLog2("spawnShell cmd: ", cmd_u8[0..ci]);
    }

    var cwd_wide: [512]u16 = undefined;
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

    if (CreateProcessW(null, cmd_ptr, null, null, 0, CREATE_NEW_CONSOLE, null, cwd_ptr, &si, &pi) == 0) {
        if (isRemoteShellKind(kind)) sshSpawnFailed();
        debugLog("spawnShell: CreateProcessW FAILED");
        return false;
    }
    _ = CloseHandle(pi.hThread);
    if (app_state.g_job != null) _ = AssignProcessToJobObject(app_state.g_job, pi.hProcess);
    app_state.next_shell_id += 1;

    var cmd_hwnd: HANDLE = null;
    var attempts: u32 = 0;
    while (attempts < 50) : (attempts += 1) {
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

    if (cmd_hwnd == null and !isRemoteShellKind(kind)) {
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
        _ = SetWindowPos(cmd_hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);
    }

    app_state.shells[idx] = .{
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
    if (app_state.g_single_window and !app_state.g_restoring) app_state.shells[idx].workspace = app_state.g_active_workspace;
    app_state.shells[idx].font_gen = app_state.g_font_gen;
    app_state.shell_count += 1;
    if (!app_state.g_restoring) app_state.shells[idx].last_active = nowFileTime();
    registerShellExitWait(idx);
    if (cmd_hwnd == null) @import("chat_send.zig").sshDisconnect(idx, "startup-console-missing");

    if (!app_state.g_restoring) {
        if (app_state.g_focus_user_action_tick != 0) switchToShellByUser(idx) else switchToShell(idx);
        requestShellRefocus(20, 12);
        saveSession();
    }
    return true;
}
