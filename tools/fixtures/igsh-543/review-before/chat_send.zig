pub fn armSshReconnectTimerIfNeeded() void {
    if (chatBenchEnabled() or app_state.g_main_hwnd == null) return;
    var any = ssh_probe_job != null;
    var urgent = any;
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) continue;
        if (shell.ssh_reconnect.phase == .closed) continue;
        any = true;
        if (shell.disconnected or shell.ssh_reconnect.phase != .connected) urgent = true;
    }
    const interval: UINT = if (urgent) 1000 else if (any) 15_000 else 0;
    if (interval == app_state.g_ssh_reconnect_timer_ms) return;
    app_state.g_ssh_reconnect_timer_ms = interval;
    if (interval != 0) {
        _ = SetTimer(app_state.g_main_hwnd, TIMER_SSH_RECONNECT, interval, null);
    } else {
        _ = KillTimer(app_state.g_main_hwnd, TIMER_SSH_RECONNECT);
    }
}

pub fn sshAutoReconnectTick() void {
    if (chatBenchEnabled()) return;
    sshProbeFinish();
    const now = GetTickCount64();
    var attempted = [_]bool{false} ** 256;
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        if (shell.ssh_reconnect.phase == .reconnecting) attempted[shell.tmux_host] = true;
    }
    for (0..app_state.shell_count) |i| {
        const shell = &app_state.shells[i];
        if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) continue;
        if (shell.ssh_reconnect.phase == .closed) continue;
        if (shell.process == null and !shell.disconnected) {
            sshDisconnect(@intCast(i), "process-missing-poll");
        } else if (shell.process != null and !shellProcessAliveForRead(i)) {
            sshDisconnect(@intCast(i), "process-exit-poll");
        } else if (shell.ssh_reconnect.phase == .reconnecting and now -| shell.spawn_tick >= 60_000) {
            sshDisconnect(@intCast(i), "attach-timeout");
        } else if (shell.kind != .tmux and shell.ssh_reconnect.phase == .reconnecting and now -| shell.spawn_tick >= 3000) {
            sshReconnectOk(@intCast(i));
        }
        if (shell.disconnected and shell.ssh_reconnect.phase == .connected) sshReconnectArm(@intCast(i), "link-disconnected");
        const host = shell.tmux_host;
        if (!attempted[host] and shell.ssh_reconnect.due(now)) {
            if (sshNetworkVeto(@intCast(i), now)) continue;
            attempted[host] = true;
            sshReconnectAttempt(@intCast(i));
        }
    }
    sshProbeStart();
    armSshReconnectTimerIfNeeded();
    if (app_state.active_shell < app_state.shell_count and app_state.shells[app_state.active_shell].disconnected) {
        var header: RECT = undefined;
        if (GetClientRect(app_state.g_main_hwnd, &header) != 0) {
            header.top = threadTitleTop();
            header.bottom = header.top + threadTitleHeight();
            _ = InvalidateRect(app_state.g_main_hwnd, &header, 0);
        }
    }
}

pub fn sshDisconnect(idx: u32, reason: []const u8) void {
    if (idx >= app_state.shell_count) return;
    const shell = &app_state.shells[idx];
    if (shell.ssh_reconnect.phase == .closed) return;
    var exit_code: DWORD = std.math.maxInt(DWORD);
    const got_code = shell.process != null and GetExitCodeProcess(shell.process, &exit_code) != 0;
    var buf: [224]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect disconnect id={d} reason={s} exit_code={d} known={} phase={s}", .{ shell.shell_id, reason, exit_code, got_code, @tagName(shell.ssh_reconnect.phase) }) catch "ssh-reconnect disconnect log-overflow");
    shell.ssh_reconnect.confirmDisconnect(GetTickCount64(), reason, shell.process != null and shellProcessAliveForRead(idx));
    markSshTabDisconnected(idx);
}

pub fn sshReconnectNow(idx: u32) void {
    if (idx >= app_state.shell_count) return;
    const shell = &app_state.shells[idx];
    if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) return;
    if (shell.ssh_reconnect.phase == .closed or shell.ssh_reconnect.phase == .reconnecting) return;
    shell.ssh_reconnect.manual(GetTickCount64());
    shell.disconnected = true;
    sshReconnectAttempt(idx);
}

fn sshReconnectAttempt(idx: u32) void {
    const shell = &app_state.shells[idx];
    if (shell.ssh_reconnect.phase != .disconnected) return;
    shell.ssh_reconnect.start();
    var buf: [160]u8 = undefined;
    debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect attempt={d} id={d} delay_ms={d}", .{ shell.ssh_reconnect.attempts, shell.shell_id, shell.ssh_reconnect.delay_ms }) catch return);
    if (!respawnShellInPlace(idx, true)) sshDisconnect(idx, "spawn-failed");
    armSshReconnectTimerIfNeeded();
}

pub fn sshReconnectArm(affected: ?u32, reason: []const u8) void {
    const now = GetTickCount64();
    for (app_state.shells[0..app_state.shell_count], 0..) |*shell, i| {
        if (affected != null and affected.? != i) continue;
        if (shell.kind != .tmux and shell.kind != .vps and shell.kind != .vps2) continue;
        if (shell.ssh_reconnect.phase == .closed) continue;
        if (affected != null) {
            shell.ssh_reconnect.lost(now, now ^ shell.shell_id);
        } else if (shell.process == null or !shellProcessAliveForRead(i)) {
            sshDisconnect(@intCast(i), reason);
        }
    }
    if (affected == null) ssh_probe_next_tick = 0;
    armSshReconnectTimerIfNeeded();
}

fn sshProbeStart() void {
    if (ssh_probe_job != null or GetTickCount64() < ssh_probe_next_tick) return;
    const job = std.heap.page_allocator.create(SshProbeJob) catch return;
    job.* = .{ .started_tick = GetTickCount64() };
    for (app_state.shells[0..app_state.shell_count]) |shell| {
        if (shell.kind != .tmux or shell.ssh_reconnect.phase == .closed or shell.tmux_session_len == 0 or GetTickCount64() -| shell.spawn_tick < 3000) continue;
        job.items[job.count] = .{ .id = shell.shell_id, .host = shell.tmux_host, .session = shell.tmux_session, .len = shell.tmux_session_len };
        job.count += 1;
    }
    if (job.count == 0) {
        std.heap.page_allocator.destroy(job);
        return;
    }
    const thread = std.Thread.spawn(.{}, sshProbeThread, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        debugLog("ssh-probe start-failed reason=thread-spawn");
        ssh_probe_next_tick = GetTickCount64() + 15_000;
        return;
    };
    ssh_probe_job = job;
    thread.detach();
}

fn sshNetworkVeto(idx: u32, now: u64) bool {
    const shell = &app_state.shells[idx];
    const veto = shell.ssh_reconnect.networkVeto(now, chatNetworkReportsConnected());
    if (veto) {
        var buf: [160]u8 = undefined;
        debugLog(std.fmt.bufPrint(&buf, "ssh-reconnect veto reason=windows-network-offline id={d} cap_ms={d}", .{ shell.shell_id, shell.ssh_reconnect.delay_ms }) catch "ssh-reconnect veto reason=windows-network-offline");
    }
    return veto;
}
