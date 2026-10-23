fn pollBrowserUrlTick() void {
    if (app_state.active_shell >= app_state.shell_count) return;
    if (!app_state.shells[app_state.active_shell].browser_enabled) return;
    if (app_state.shells[app_state.active_shell].browser_hwnd == null) return;
    if (app_state.shells[app_state.active_shell].browser_window_id == 0) {
        if (app_state.g_main_hwnd != null) _ = KillTimer(app_state.g_main_hwnd, TIMER_BROWSER_URL_POLL);
        return;
    }
    if (app_state.shells[app_state.active_shell].browser_suspended) return;
    if (IsIconic(app_state.g_main_hwnd) != 0) return;
    if (!foregroundIsOurs()) return;
    if (app_state.g_browser_url_poll_pending) return;
    app_state.g_browser_url_poll_pending = true;
    app_state.g_browser_url_poll_shell_id = app_state.shells[app_state.active_shell].shell_id;
    app_state.g_browser_url_poll_window_id = app_state.shells[app_state.active_shell].browser_window_id;
    const t = std.Thread.spawn(.{}, browserUrlPollThread, .{app_state.shells[app_state.active_shell].browser_profile_token}) catch {
        app_state.g_browser_url_poll_pending = false;
        return;
    };
    t.detach();
}

fn launchBrowserForShellEx(idx: u32, user_initiated: bool) void {
    const timing_started = switch_timing.start();
    defer switch_timing.record(.browser_launch, timing_started);
    if (app_state.g_app_closing or idx >= app_state.shell_count or !app_state.shells[idx].browser_enabled or webView2OwnsShell(idx)) return;
    if (app_state.shells[idx].browser_launch_tick != 0 or app_state.shells[idx].browser_open_failed) return;
    const launch_now = GetTickCount64();
    if (app_state.shells[idx].browser_relaunch_after_tick != 0 and launch_now < app_state.shells[idx].browser_relaunch_after_tick) return;
    if (app_state.shells[idx].browser_hwnd) |existing| {
        if (IsWindow(existing) != 0 and windowOwnerProcessStillActive(existing)) return;
        forgetCrashedBrowserPane(idx, launch_now);
        return;
    }
    ensureBrowserDefaultUrl(idx);
    assignBrowserProfileForLaunch(idx);
    app_state.shells[idx].browser_suspended = false;
    app_state.shells[idx].browser_native = app_state.g_browser_native_default;
    const now = launch_now;
    app_state.g_browser_nonce_counter += 1;
    beginBrowserOpening(&app_state.shells[idx], now, app_state.g_browser_nonce_counter);
    const nonce_slice = std.fmt.bufPrint(
        &app_state.g_browser_adopt_nonce,
        "ZSPANE{d}-{d}",
        .{ app_state.g_browser_nonce_counter, now & 0xFFFFFF },
    ) catch b: {
        const fb = "ZSPANE0";
        @memcpy(app_state.g_browser_adopt_nonce[0..fb.len], fb);
        break :b app_state.g_browser_adopt_nonce[0..fb.len];
    };
    app_state.g_browser_adopt_nonce_len = nonce_slice.len;
    var nonce_url_buf: [256]u8 = undefined;
    const nonce_url = browserBeaconUrl(&nonce_url_buf, nonce_slice);
    app_state.g_browser_adopt_count = 0;
    app_state.g_browser_adopt_target_idx = idx;
    app_state.g_browser_adopt_foreground_launch = user_initiated and idx == app_state.active_shell and app_state.g_main_hwnd != null and
        IsIconic(app_state.g_main_hwnd) == 0 and foregroundIsOurs() and
        !browserChromeHiddenForOverlay() and !webView2OwnsShell(idx);
    _ = EnumWindows(&enumBrowserSnapshot, 0);
    @memcpy(app_state.shells[idx].browser_bind_nonce[0..nonce_slice.len], nonce_slice);
    app_state.shells[idx].browser_bind_nonce_len = @intCast(nonce_slice.len);
    publishInboxState();
    app_state.g_browser_adopt_deadline = now + 6000;
    browserTraceN("launchBrowserForShell idx=", idx);
    if (verboseLoggingEnabled()) debugLog2("[browser] launch nonce=", nonce_slice);
    app_state.g_browser_adopt_via_extension = !user_initiated and isolatedBrowserHasLivePane(idx) and
        requestInactivePaneWindow(idx, nonce_url);
    if (!app_state.g_browser_adopt_via_extension) {
        if (!user_initiated) lockForegroundForRequestLaunch();
        shellExecuteEdgeUrl(nonce_url, true, app_state.shells[idx].browser_native, idx);
    }
    if (app_state.g_main_hwnd != null) _ = SetTimer(app_state.g_main_hwnd, TIMER_BROWSER_ADOPT, 150, null);
}

fn enumBrowserAdopt(hwnd: HANDLE, lp: LPARAM) callconv(WINAPI) BOOL {
    if (!edgeWindowClassMatches(hwnd)) return 1;
    if (browserSnapshotContains(hwnd)) return 1;
    var wr: RECT = std.mem.zeroes(RECT);
    if (GetWindowRect(hwnd, &wr) == 0) return 1;
    if (wr.right <= wr.left or wr.bottom <= wr.top) return 1;
    if (app_state.g_browser_adopt_nonce_len == 0) return 1;
    var title: [64]u16 = undefined;
    const tlen = InternalGetWindowText(hwnd, &title, 64);
    if (tlen <= 0) return 1;
    const nonce = app_state.g_browser_adopt_nonce[0..app_state.g_browser_adopt_nonce_len];
    const title_len: usize = @intCast(tlen);
    var found_nonce = false;
    if (title_len >= nonce.len) {
        var start: usize = 0;
        while (start <= title_len - nonce.len) : (start += 1) {
            var match = true;
            for (nonce, 0..) |nc, ni| {
                if (title[start + ni] != @as(u16, nc)) {
                    match = false;
                    break;
                }
            }
            if (match) {
                found_nonce = true;
                break;
            }
        }
    }
    if (!found_nonce) return 1;
    const ctx: *BrowserAdoptCtx = @ptrFromInt(@as(usize, @bitCast(lp)));
    ctx.found_hwnd = hwnd;
    return 0;
}
