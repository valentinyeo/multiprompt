fn initializeDeferred(hwnd: HANDLE) void {
    const hInst = GetModuleHandleW(null);
    launch_cache.step(.account);
    if (!accountBootstrap(hwnd)) {
        _ = DestroyWindow(hwnd);
        return;
    }
    migrateWorkspacesFromSessionFiles();
    reconcileWorkspaceRegistry(true);
    loadBrowserEngineConfig();
    loadEdgeProfileConfig();
    loadEdgeExeConfig();
    loadChromeExeConfig();
    loadEdgeExtensionPathConfig();
    writeCurrentThemeManifest();
    if (app_state.g_browser_engine == .chrome) _ = ensureChromeNativeMessagingRegistration();
    loadSidebarStatusCard();
    ensureCapacityPolicyStarter();
    loadCapacityPolicy();

    if (!app_state.g_account_bypass) {
        app_state.g_single_window = true;
        app_state.g_adopt_hwnd = null;
        app_state.g_empty_workspace = false;
    }
    startStaleAltMouseHookThread();
    _ = syncMainWindowDpi(hwnd, 0);
    setWindowTaskbarIdentity(hwnd);

    app_state.g_job = CreateJobObjectW(null, null);
    if (app_state.g_job != null) {
        var job_info = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
        job_info.basic.limit_flags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        _ = SetInformationJobObject(app_state.g_job, JobObjectExtendedLimitInformation, @ptrCast(&job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
    }
    app_state.g_tunnel_job = CreateJobObjectW(null, null);
    if (app_state.g_tunnel_job != null) {
        var tunnel_job_info = std.mem.zeroes(JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
        tunnel_job_info.basic.limit_flags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        _ = SetInformationJobObject(app_state.g_tunnel_job, JobObjectExtendedLimitInformation, @ptrCast(&tunnel_job_info), @sizeOf(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
    }

    var title_buf: [256]u16 = undefined;
    _ = SetWindowTextW(hwnd, buildWindowTitle(&title_buf));

    const ICON_BIG: WPARAM = 1;
    const ICON_SMALL: WPARAM = 0;
    const big_icon = LoadImageW(hInst, @ptrFromInt(1), IMAGE_ICON, 256, 256, LR_DEFAULTCOLOR);
    const small_icon = LoadImageW(hInst, @ptrFromInt(1), IMAGE_ICON, 32, 32, LR_DEFAULTCOLOR);
    if (big_icon != null) _ = SendMessageW(hwnd, 0x0080, ICON_BIG, @bitCast(@intFromPtr(big_icon)));
    if (small_icon != null) _ = SendMessageW(hwnd, 0x0080, ICON_SMALL, @bitCast(@intFromPtr(small_icon)));

    registerJumpList();

    applyTitleBarTheme();
    const DWMWA_WINDOW_CORNER_PREFERENCE: DWORD = 33;
    const DWMWCP_ROUND: DWORD = 2;
    _ = DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, @ptrCast(&DWMWCP_ROUND), @sizeOf(DWORD));

    installForegroundHook();

    const IDC_SIZEWE: LPCWSTR = @ptrFromInt(32644);
    const IDC_ARROW: LPCWSTR = @ptrFromInt(32512);
    app_state.g_cursor_sizewe = LoadCursorW(null, IDC_SIZEWE);
    app_state.g_cursor_arrow = LoadCursorW(null, IDC_ARROW);

    _ = RegisterHotKey(hwnd, HOTKEY_ID_FOCUS, MOD_CONTROL | MOD_SHIFT, 0x20);

    loadPowerProfile();
    refreshPowerStatusFromSystem();
    registerPowerNotifications(hwnd);
    applyPowerProfile(hwnd);
    setCoalescableTimerInterval(hwnd, TIMER_POWER_IDLE, 30_000);
    launch_cache.step(.telemetry);
    ensureUsageTelemetryCollector();
    requestAiPaceRefresh();

    launch_cache.step(.links);
    if (std.Thread.spawn(.{}, notifyListenerThread, .{})) |notify_thread| {
        notify_thread.detach();
    } else |_| {}
    {
        var waits: u32 = 0;
        while (app_state.g_notify_bound_port == 0 and waits < 50) : (waits += 1) Sleep(10);
    }
    startTunnelInboundListener();
    _ = resolveSshPath(false);
    maintainTunnelKeepers();

    launch_cache.step(.tabs);
    app_state.g_startup_progress = true;
    debugLog("main: checking adopt mode");
    if (app_state.g_adopt_hwnd) |adopt_hwnd_val| {
        debugLog("main: adopt mode ACTIVE");
        const adopt_h: HANDLE = @ptrFromInt(adopt_hwnd_val);

        _ = ShowWindow(adopt_h, SW_HIDE);
        _ = SetParent(adopt_h, hwnd);
        var style = GetWindowLongPtrW(adopt_h, GWL_STYLE);
        style &= ~@as(isize, @intCast(WS_CAPTION | WS_THICKFRAME | WS_BORDER));
        style |= @as(isize, @intCast(WS_CHILD));
        _ = SetWindowLongPtrW(adopt_h, GWL_STYLE, style);
        _ = SetWindowPos(adopt_h, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE);

        const proc = OpenProcess(0x001F0FFF, 0, app_state.g_adopt_pid);
        if (app_state.g_job != null and proc != null) _ = AssignProcessToJobObject(app_state.g_job, proc);

        var new_shell = empty_shell;
        new_shell.hwnd = adopt_h;
        new_shell.process = proc;
        new_shell.pid = app_state.g_adopt_pid;
        new_shell.kind = @enumFromInt(@as(u3, @intCast(app_state.g_adopt_kind)));
        new_shell.name_source = app_state.g_adopt_name_source;
        new_shell.muted = app_state.g_adopt_muted;
        new_shell.pinned_top = app_state.g_adopt_pinned_top;
        new_shell.locked = app_state.g_adopt_locked;
        new_shell.favorite = app_state.g_adopt_favorite;
        new_shell.last_used = app_state.g_adopt_last_used;
        new_shell.input = app_state.g_adopt_input;
        new_shell.visits = app_state.g_adopt_visits;
        if (@as(usize, @intCast(app_state.next_shell_id)) < SPAWN_TITLES.len) {
            new_shell.shell_id = app_state.next_shell_id;
            app_state.next_shell_id += 1;
        }

        if (app_state.g_adopt_name_len > 0) {
            for (0..app_state.g_adopt_name_len) |ni| {
                new_shell.name[ni] = @intCast(app_state.g_adopt_name[ni]);
            }
            new_shell.name_len = app_state.g_adopt_name_len;
        }

        if (app_state.g_adopt_cwd_len > 0) {
            @memcpy(new_shell.cached_cwd[0..app_state.g_adopt_cwd_len], app_state.g_adopt_cwd[0..app_state.g_adopt_cwd_len]);
            new_shell.cached_cwd_len = app_state.g_adopt_cwd_len;
        }

        if (app_state.g_adopt_tmux_len > 0) {
            @memcpy(new_shell.tmux_session[0..app_state.g_adopt_tmux_len], app_state.g_adopt_tmux[0..app_state.g_adopt_tmux_len]);
            new_shell.tmux_session_len = app_state.g_adopt_tmux_len;
        }

        app_state.shells[0] = new_shell;
        app_state.shell_count = 1;
        app_state.active_shell = 0;
        registerShellExitWait(0);
        debugLog("main: adopt — about to ShowWindow");
        const show_result = showShellConsole(app_state.active_shell, SW_SHOW, "main.adopt");
        _ = show_result;
        repositionActive();
        debugLog("main: adopt — repositionActive done");
        _ = SetForegroundWindow(hwnd);
        focusActiveShell();
        requestShellRefocus(120, 8);
        _ = PostMessageW(hwnd, WM_APP_FOCUS, 0, 0);
        debugLog("main: adopt — complete");
    } else if (app_state.g_empty_workspace) {
        debugLog("main: empty workspace receiver");
    } else {
        const restored = restoreSession();
        if (app_state.g_account_base) |server| applyServerLayout(server) catch {};
        loadSnoozedWorkspaces();
        loadChatOutbox();
        if (!IS_DEV and app_state.g_instance_name_len == 0) {
            var seen_buf: [64]u8 = undefined;
            const seen = readChangelogSeen(&seen_buf);
            if (!std.mem.eql(u8, seen, APP_VERSION)) {
                writeChangelogSeen(APP_VERSION);
            }
        }
        if (restored == 0 and !app_state.g_restored_valid_session) {
            if (!spawnShell(.cmd)) {
                std.debug.print("Failed to spawn initial shell\n", .{});
            }
        }
    }
    launch_cache.bindRestoredChat();
    if (app_state.active_shell < app_state.shell_count and
        chatViewShouldShowForTab(app_state.g_chat_view_mode, app_state.shells[app_state.active_shell].chat_view_on, app_state.shells[app_state.active_shell].chat_shell_override, app_state.g_chat_view_restore_on, true))
    {
        openChatView();
    }
    sessionFrontChanged();
    if (chatBenchEnabled()) _ = SetTimer(hwnd, TIMER_CHAT_BENCH, 1000, null);
    applyTitleBarTheme();
    if (app_state.g_multiprompt_theme) startSpinnerTimerIfNeeded();
    updateMainWindowTitle();

    cleanupStaleWindows();

    cleanupStalePanewinFiles();

    _ = EnumWindows(&enumCloseStrayZspane, 0);

    syncInProcessWorkspacesToRegistry();
    publishInboxState();

    updateCardInit();
    if (!startUpdateCardWatch()) _ = SetTimer(hwnd, TIMER_UPDATE_CHECK, UPDATE_CHECK_MS, null);
    updateCardPoll();
    restoreRegisteredWorkspaceWindows();
    checkDueReminders();
    app_state.g_startup_progress = false;
    launch_cache.step(.browser);
    relaunchActiveRestoredBrowserPane();
    updateBrowserVisibility();
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].browser_enabled) {
        armBrowserVisibilitySettle(20);
    }
    _ = InvalidateRect(hwnd, null, 1);

    Sleep(500);
    pollShellNames();
    fetchTmuxSessions();

    if (LOOK_UNIFIED) {
        applyConsoleThemeToAllShells();
        repositionActive();
    }

    if (app_state.shell_count > 0) {
        forceReinstallHooks();
        syncMouseHookForUrlClicks();
        focusActiveShell();
        requestShellRefocus(120, 8);
        _ = PostMessageW(hwnd, WM_APP_FOCUS, 0, 0);
        armStartupConsoleGeometrySettle(hwnd);
    }

    if (!app_state.g_account_bypass) {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        if (captureSessionLayout(arena.allocator(), false)) |current| {
            app_state.g_account_local_base = session_layout.encode(std.heap.page_allocator, current) catch null;
        } else |_| {}
    }

    if (crash_recorder.takeRestartNotice()) showHeaderNoticeAscii(crash_recorder.NOTICE_TEXT, 8000, false);
}
