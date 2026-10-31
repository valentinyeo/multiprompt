const app_state = @import("app_state.zig");
const std = @import("std");
const json_reader = @import("json_reader.zig");
const DWORD = @import("win32.zig").DWORD;
const HANDLE = @import("win32.zig").HANDLE;
const DT_SINGLELINE = @import("win32.zig").DT_SINGLELINE;
const DT_VCENTER = @import("win32.zig").DT_VCENTER;
const DT_CENTER = @import("win32.zig").DT_CENTER;
const DT_RIGHT = @import("win32.zig").DT_RIGHT;
const DT_NOPREFIX = @import("win32.zig").DT_NOPREFIX;
const DT_END_ELLIPSIS = @import("win32.zig").DT_END_ELLIPSIS;
const RECT = @import("win32.zig").RECT;
const GetClientRect = @import("win32.zig").GetClientRect;
const FillRect = @import("win32.zig").FillRect;
const CreateSolidBrush = @import("win32.zig").CreateSolidBrush;
const DeleteObject = @import("win32.zig").DeleteObject;
const SetTextColor = @import("win32.zig").SetTextColor;
const SelectObject = @import("win32.zig").SelectObject;
const CreatePen = @import("win32.zig").CreatePen;
const CloseHandle = @import("win32.zig").CloseHandle;
const GetEnvironmentVariableA = @import("win32.zig").GetEnvironmentVariableA;
const GetTickCount64 = @import("win32.zig").GetTickCount64;
const RGB = @import("startup.zig").RGB;
const Shell = @import("app_state.zig").Shell;
const customColorOr = @import("themes.zig").customColorOr;
const SIDEBAR_W = @import("browser_pane.zig").SIDEBAR_W;
const SIDEBAR_STICKY_CARD_H = @import("app_state.zig").SIDEBAR_STICKY_CARD_H;
const SIDEBAR_STICKY_CARD_COLLAPSED_H = @import("app_state.zig").SIDEBAR_STICKY_CARD_COLLAPSED_H;
const SIDEBAR_STICKY_CARD_GAP = @import("app_state.zig").SIDEBAR_STICKY_CARD_GAP;
const TmuxSessionEntry = @import("app_state.zig").TmuxSessionEntry;
const CapacityState = @import("app_state.zig").CapacityState;
const CapacityPolicy = @import("app_state.zig").CapacityPolicy;
const HostCapacity = @import("app_state.zig").HostCapacity;
const AgentSessionBreakdown = @import("app_state.zig").AgentSessionBreakdown;
const updateCardVisible = @import("update_card.zig").updateCardVisible;
const updateCardSpan = @import("update_card.zig").updateCardSpan;
const updateCardRect = @import("update_card.zig").updateCardRect;
const hostBusyAgentCount = @import("update_card.zig").hostBusyAgentCount;
const workspaceBusyAgentCount = @import("update_card.zig").workspaceBusyAgentCount;
const CapacityAdmission = @import("app_state.zig").CapacityAdmission;
const win32OpenRead = @import("file_io.zig").win32OpenRead;
const win32OpenWrite = @import("file_io.zig").win32OpenWrite;
const win32OpenAppend = @import("file_io.zig").win32OpenAppend;
const win32WriteAll = @import("file_io.zig").win32WriteAll;
const win32ReadAll = @import("file_io.zig").win32ReadAll;
const writeAuditEscapedBytes = @import("diagnostics.zig").writeAuditEscapedBytes;
const writeAuditU64 = @import("diagnostics.zig").writeAuditU64;
const SSH_HOST_DE = @import("app_state.zig").SSH_HOST_DE;
const SSH_HOST_UK = @import("app_state.zig").SSH_HOST_UK;
const SSH_HOST_INNE = @import("app_state.zig").SSH_HOST_INNE;
const SSH_TARGET_DE = @import("app_state.zig").SSH_TARGET_DE;
const SSH_TARGET_UK = @import("app_state.zig").SSH_TARGET_UK;
const SSH_TARGET_INNE = @import("app_state.zig").SSH_TARGET_INNE;
const TMUX_HOST_INNE = @import("app_state.zig").TMUX_HOST_INNE;
const SSH_TERM = @import("app_state.zig").SSH_TERM;
const tmuxSshTarget = @import("console.zig").tmuxSshTarget;
const tmuxSshHostArg = @import("console.zig").tmuxSshHostArg;
const showHeaderNoticeAscii = @import("console.zig").showHeaderNoticeAscii;
const tmuxAgentFromPaneCommand = @import("vps.zig").tmuxAgentFromPaneCommand;
const drawAttentionDot = @import("archive.zig").drawAttentionDot;
const drawAscii = @import("drawing.zig").drawAscii;
const drawAsciiRun = @import("drawing.zig").drawAsciiRun;
const asciiTextWidth = @import("drawing.zig").asciiTextWidth;
const formatVpsLoad = @import("status_line.zig").formatVpsLoad;
const uiScaled = @import("drawing.zig").uiScaled;
const nowFileTime = @import("inbox.zig").nowFileTime;

pub fn parseAsciiU64(value: []const u8) u64 {
    var out: u64 = 0;
    for (value) |c| {
        if (c < '0' or c > '9') break;
        out = out *| 10 +| (c - '0');
    }
    return out;
}

pub fn parseDecimalMilli(value: []const u8) u32 {
    var whole: u64 = 0;
    var frac: u32 = 0;
    var frac_digits: u8 = 0;
    var after_dot = false;
    for (value) |c| {
        if (c == '.' and !after_dot) {
            after_dot = true;
            continue;
        }
        if (c < '0' or c > '9') break;
        if (!after_dot) {
            whole = whole *| 10 +| (c - '0');
        } else if (frac_digits < 3) {
            frac = frac * 10 + (c - '0');
            frac_digits += 1;
        }
    }
    while (frac_digits < 3) : (frac_digits += 1) frac *= 10;
    return @intCast(@min(whole *| 1000 +| frac, std.math.maxInt(u32)));
}

fn capacityStateRank(state: CapacityState) u8 {
    return @intFromEnum(state);
}

pub fn capacityStateLabel(state: CapacityState) []const u8 {
    return switch (state) {
        .unknown => "UNKNOWN",
        .green => "GREEN",
        .amber => "AMBER",
        .red => "RED",
        .critical => "CRITICAL",
    };
}

pub fn capacityHostLabel(host: u8) []const u8 {
    return if (host == 1) "Host 2" else "Host 1";
}

fn capacityHostShortLabel(host: u8) []const u8 {
    return if (host == 1) "UK" else "DE";
}

fn capacityStateForMetrics(metrics: HostCapacity, policy: CapacityPolicy) CapacityState {
    if (!metrics.valid or metrics.cores == 0 or metrics.mem_total_kb == 0) return .unknown;
    const normalized_load = metrics.load_milli / @as(u32, metrics.cores);
    const available_pct: u64 = @min(100, metrics.mem_available_kb *| 100 / metrics.mem_total_kb);
    const worst_psi = @max(metrics.cpu_psi_milli, @max(metrics.mem_psi_milli, metrics.io_psi_milli));

    if (normalized_load >= policy.critical_load_per_core_milli or
        available_pct <= policy.critical_mem_available_pct or
        worst_psi >= policy.critical_psi_milli)
        return .critical;
    if (normalized_load >= policy.red_load_per_core_milli or
        available_pct <= policy.red_mem_available_pct or
        worst_psi >= policy.red_psi_milli)
        return .red;
    if (normalized_load >= policy.amber_load_per_core_milli or
        available_pct <= policy.amber_mem_available_pct or
        worst_psi >= policy.amber_psi_milli)
        return .amber;
    return .green;
}

pub fn applyCapacityHysteresis(host: u8, fresh: HostCapacity) HostCapacity {
    if (host >= app_state.g_host_capacity.len) return fresh;
    var next = fresh;
    const desired = capacityStateForMetrics(fresh, app_state.g_capacity_policy);
    const previous = app_state.g_host_capacity[host];
    next.state = desired;
    next.recovery_samples = 0;
    if (previous.valid and capacityStateRank(desired) < capacityStateRank(previous.state)) {
        next.recovery_samples = previous.recovery_samples +| 1;
        if (next.recovery_samples < 4) next.state = previous.state else next.recovery_samples = 0;
    }
    return next;
}

pub fn effectiveCapacityState(host: u8) CapacityState {
    if (host >= app_state.g_host_capacity.len) return .unknown;
    const metrics = app_state.g_host_capacity[host];
    if (!metrics.valid or metrics.updated_tick == 0) return .unknown;
    if (GetTickCount64() -| metrics.updated_tick > 90_000) return .unknown;
    return metrics.state;
}

pub fn remoteHostForShell(shell: *const Shell) ?u8 {
    return switch (shell.kind) {
        .vps => 0,
        .vps2 => 1,
        .tmux => shell.tmux_host,
        else => null,
    };
}

pub fn tmuxHostLongLabel(host: u8) []const u8 {
    return switch (host) {
        1 => "host2",
        2 => "remote-3",
        else => "host1",
    };
}

pub fn tmuxHostShortLabel(host: u8) []const u8 {
    return switch (host) {
        1 => "UK",
        2 => "HOST3",
        else => "DE",
    };
}

pub fn tmuxHostTagLabel(host: u8) []const u8 {
    return switch (host) {
        1 => "UK-TMX",
        2 => "HOST3-TMX",
        else => "DE-TMX",
    };
}

fn chooseSidebarVpsHost(active_host: ?u8, workspace_host_counts: [2]u16) ?u8 {
    if (active_host) |host| {
        if (host < workspace_host_counts.len) return host;
    }
    if (workspace_host_counts[0] == 0 and workspace_host_counts[1] == 0) return null;
    return if (workspace_host_counts[1] > workspace_host_counts[0]) 1 else 0;
}

pub fn sidebarVpsHost() ?u8 {
    var active_host: ?u8 = null;
    if (app_state.active_shell < app_state.shell_count and
        (!app_state.g_single_window or app_state.shells[app_state.active_shell].workspace == app_state.g_active_workspace))
    {
        active_host = remoteHostForShell(&app_state.shells[app_state.active_shell]);
    }

    var counts = [2]u16{ 0, 0 };
    for (0..app_state.shell_count) |i| {
        if (app_state.g_single_window and app_state.shells[i].workspace != app_state.g_active_workspace) continue;
        const host = remoteHostForShell(&app_state.shells[i]) orelse continue;
        if (host < counts.len) counts[host] +|= 1;
    }
    return chooseSidebarVpsHost(active_host, counts);
}

fn agentSessionBreakdownForHost(entries: []const TmuxSessionEntry, host: u8) AgentSessionBreakdown {
    var result = AgentSessionBreakdown{};
    for (entries) |entry| {
        if (entry.host != host) continue;
        switch (entry.agent) {
            1 => result.claude +|= 1,
            2 => result.codex +|= 1,
            3, 4, 5, 6, 7 => result.other +|= 1,
            else => {},
        }
    }
    return result;
}

fn sidebarAgentSessionBreakdown(host: u8) AgentSessionBreakdown {
    return agentSessionBreakdownForHost(app_state.g_tmux_cache[0..app_state.g_tmux_cache_count], host);
}

pub fn sidebarStickyCardSpan() i32 {
    if (app_state.g_hide_sidebar) return 0;
    if (!app_state.g_sidebar_collapsed) return 0;
    return uiScaled(SIDEBAR_STICKY_CARD_COLLAPSED_H) + @import("window_layout.zig").paneGap() + updateCardSpan();
}

pub fn sidebarStickyCardRect() RECT {
    var client: RECT = std.mem.zeroes(RECT);
    if (app_state.g_main_hwnd != null) _ = GetClientRect(app_state.g_main_hwnd, &client);
    if (app_state.g_sidebar_collapsed) return @import("window_layout.zig").activePaneRects(client).burn;
    return .{ .left = uiScaled(12), .top = @max(0, client.bottom - uiScaled(48)), .right = uiScaled(48), .bottom = client.bottom - uiScaled(12) };
}

pub fn sidebarUsageRowRect() RECT {
    return sidebarStickyCardRect();
}

pub fn sidebarStickyCardHoverTest(mx: i32, my: i32) bool {
    if (app_state.g_hide_sidebar or app_state.g_sidebar_collapsed) return false;
    const rect = sidebarUsageRowRect();
    return mx >= rect.left and mx < rect.right and my >= rect.top and my < rect.bottom;
}

pub fn sidebarStickyCardHitTest(my: i32) bool {
    if (app_state.g_hide_sidebar or !app_state.g_sidebar_collapsed or my < 0) return false;
    const rect = sidebarStickyCardRect();
    if (app_state.g_sidebar_collapsed and updateCardVisible()) {
        const ur = updateCardRect();
        if (my >= ur.top and my < ur.bottom) return true;
    }
    return my >= rect.top and my < rect.bottom;
}

fn capacityAdmissionFor(state: CapacityState, host_busy: u16, host_limit: u16) CapacityAdmission {
    if (state == .red or state == .critical) return .block_host_pressure;
    if (host_limit > 0 and host_busy >= host_limit) return .block_host_busy;
    if (state == .amber) return .warn;
    return .allow;
}

fn capacityAuditPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 470) return null;
    const rest = "\\ZigShell\\capacity-audit.tsv";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

fn auditCapacityAdmission(host: u8, workspace: u8, decision: CapacityAdmission, label: []const u8) void {
    var path_buf: [512]u8 = undefined;
    const path = capacityAuditPath(&path_buf) orelse return;
    const h = win32OpenAppend(path) orelse return;
    defer _ = CloseHandle(h);
    writeAuditU64(h, nowFileTime());
    win32WriteAll(h, "\t");
    win32WriteAll(h, capacityHostLabel(host));
    win32WriteAll(h, "\t");
    win32WriteAll(h, capacityStateLabel(effectiveCapacityState(host)));
    win32WriteAll(h, "\t");
    win32WriteAll(h, @tagName(decision));
    win32WriteAll(h, "\tworkspace=");
    writeAuditU64(h, workspace);
    win32WriteAll(h, "\thost_busy=");
    writeAuditU64(h, hostBusyAgentCount(host));
    win32WriteAll(h, "\tworkspace_busy=");
    writeAuditU64(h, workspaceBusyAgentCount(workspace));
    win32WriteAll(h, "\t");
    writeAuditEscapedBytes(h, label);
    win32WriteAll(h, "\r\n");
}

pub fn capacityAdmitNewAgent(host: u8, workspace: u8, label: []const u8) bool {
    const state = effectiveCapacityState(host);
    const host_busy = hostBusyAgentCount(host);
    const host_limit = if (host < app_state.g_capacity_policy.host_busy_limit.len) app_state.g_capacity_policy.host_busy_limit[host] else 0;
    const decision = capacityAdmissionFor(state, host_busy, host_limit);
    auditCapacityAdmission(host, workspace, decision, label);

    var msg_buf: [128]u8 = undefined;
    switch (decision) {
        .allow => return true,
        .warn => {
            const msg = std.fmt.bufPrint(&msg_buf, "{s} AMBER ({d}/{d} busy) - starting {s}", .{ capacityHostLabel(host), host_busy, host_limit, label }) catch "VPS capacity warning";
            showHeaderNoticeAscii(msg, 6000, true);
            return true;
        },
        .block_host_pressure => {
            const msg = std.fmt.bufPrint(&msg_buf, "{s} {s} - {s} blocked; retry after recovery", .{ capacityHostLabel(host), capacityStateLabel(state), label }) catch "VPS overloaded - new agent blocked";
            showHeaderNoticeAscii(msg, 8000, true);
        },
        .block_host_busy => {
            const msg = std.fmt.bufPrint(&msg_buf, "{s} busy-agent limit {d}/{d} - {s} blocked", .{ capacityHostLabel(host), host_busy, host_limit, label }) catch "VPS busy-agent limit reached";
            showHeaderNoticeAscii(msg, 8000, true);
        },
    }
    app_state.g_capacity_block_notice_until = GetTickCount64() + 8000;
    return false;
}

pub fn capacityBlockNoticeActive() bool {
    return GetTickCount64() < app_state.g_capacity_block_notice_until;
}

pub fn announceCapacityTransitions() void {
    for (0..app_state.g_host_capacity.len) |host_usize| {
        const host: u8 = @intCast(host_usize);
        const current = effectiveCapacityState(host);
        const previous = app_state.g_capacity_announced[host_usize];
        if (current == previous) continue;
        app_state.g_capacity_announced[host_usize] = current;
        if (current == .unknown or current == .green and previous == .unknown) continue;

        var msg_buf: [128]u8 = undefined;
        if (current == .green) {
            const msg = std.fmt.bufPrint(&msg_buf, "{s} capacity recovered - new workloads enabled", .{capacityHostLabel(host)}) catch "VPS capacity recovered";
            showHeaderNoticeAscii(msg, 6000, false);
        } else if (current == .amber or current == .red or current == .critical) {
            const metrics = app_state.g_host_capacity[host_usize];
            const load_whole = metrics.load_milli / 1000;
            const load_frac = metrics.load_milli % 1000 / 100;
            const msg = std.fmt.bufPrint(&msg_buf, "{s} {s}: load {d}.{d}/{d}, {d} busy agents", .{
                capacityHostLabel(host),
                capacityStateLabel(current),
                load_whole,
                load_frac,
                metrics.cores,
                hostBusyAgentCount(host),
            }) catch "VPS capacity warning";
            showHeaderNoticeAscii(msg, if (current == .amber) 6000 else 10000, true);
        }
    }
}

pub fn activeCapacityStatus(out: *[48]u16, out_state: *CapacityState) usize {
    if (app_state.active_shell >= app_state.shell_count) return 0;
    const host = remoteHostForShell(&app_state.shells[app_state.active_shell]) orelse return 0;
    const state = effectiveCapacityState(host);
    out_state.* = state;
    const metrics = app_state.g_host_capacity[host];
    var ascii: [48]u8 = undefined;
    const status = switch (state) {
        .unknown => std.fmt.bufPrint(&ascii, "{s} capacity ?", .{capacityHostShortLabel(host)}) catch return 0,
        .green => std.fmt.bufPrint(&ascii, "{s} {d}/{d}", .{ capacityHostShortLabel(host), metrics.load_milli / 1000, metrics.cores }) catch return 0,
        .amber => std.fmt.bufPrint(&ascii, "{s} AMBER {d}/{d}", .{ capacityHostShortLabel(host), metrics.load_milli / 1000, metrics.cores }) catch return 0,
        .red => std.fmt.bufPrint(&ascii, "{s} RED {d}/{d}", .{ capacityHostShortLabel(host), metrics.load_milli / 1000, metrics.cores }) catch return 0,
        .critical => std.fmt.bufPrint(&ascii, "{s} CRIT {d}/{d}", .{ capacityHostShortLabel(host), metrics.load_milli / 1000, metrics.cores }) catch return 0,
    };
    const n = @min(status.len, out.len);
    for (status[0..n], 0..) |c, i| out[i] = c;
    return n;
}

pub fn workspaceCapacityState(workspace: u8) CapacityState {
    var found = false;
    var worst: CapacityState = .unknown;
    for (0..app_state.shell_count) |i| {
        if (app_state.g_single_window and app_state.shells[i].workspace != workspace) continue;
        const host = remoteHostForShell(&app_state.shells[i]) orelse continue;
        found = true;
        const state = effectiveCapacityState(host);
        if (capacityStateRank(state) > capacityStateRank(worst)) worst = state;
    }
    return if (found) worst else .unknown;
}

pub fn commandCreatesAgentWorkload(command: []const u8) bool {
    const words = [_][]const u8{ "claude", "codex", "kimi", "hax", "grok", "cursor", "cursor-agent", "tnn" };
    for (words) |word| {
        if (command.len < word.len) continue;
        var i: usize = 0;
        while (i + word.len <= command.len) : (i += 1) {
            if (!std.ascii.eqlIgnoreCase(command[i .. i + word.len], word)) continue;
            const left_ok = i == 0 or !std.ascii.isAlphanumeric(command[i - 1]);
            const right_ok = i + word.len == command.len or !std.ascii.isAlphanumeric(command[i + word.len]);
            if (left_ok and right_ok) return true;
        }
    }
    return false;
}

test "capacity metrics classify normalized load memory and PSI" {
    var metrics = HostCapacity{ .valid = true, .cores = 18, .load_milli = 9000, .mem_total_kb = 100_000, .mem_available_kb = 50_000 };
    try std.testing.expectEqual(CapacityState.green, capacityStateForMetrics(metrics, CapacityPolicy{}));
    metrics.load_milli = 13_500;
    try std.testing.expectEqual(CapacityState.amber, capacityStateForMetrics(metrics, CapacityPolicy{}));
    metrics.load_milli = 18_000;
    try std.testing.expectEqual(CapacityState.red, capacityStateForMetrics(metrics, CapacityPolicy{}));
    metrics.load_milli = 27_000;
    try std.testing.expectEqual(CapacityState.critical, capacityStateForMetrics(metrics, CapacityPolicy{}));
    metrics.load_milli = 0;
    metrics.mem_available_kb = 7_000;
    try std.testing.expectEqual(CapacityState.critical, capacityStateForMetrics(metrics, CapacityPolicy{}));
}

test "capacity admission blocks host pressure and host saturation only" {
    try std.testing.expectEqual(CapacityAdmission.allow, capacityAdmissionFor(.green, 2, 8));
    try std.testing.expectEqual(CapacityAdmission.warn, capacityAdmissionFor(.amber, 2, 8));
    try std.testing.expectEqual(CapacityAdmission.block_host_pressure, capacityAdmissionFor(.red, 0, 8));
    try std.testing.expectEqual(CapacityAdmission.block_host_busy, capacityAdmissionFor(.green, 8, 8));
}

test "sidebar VPS stats prefer the active host and classify resident agents" {
    try std.testing.expectEqual(@as(?u8, 0), chooseSidebarVpsHost(0, .{ 1, 9 }));
    try std.testing.expectEqual(@as(?u8, 1), chooseSidebarVpsHost(null, .{ 2, 5 }));
    try std.testing.expectEqual(@as(?u8, 0), chooseSidebarVpsHost(null, .{ 3, 3 }));
    try std.testing.expectEqual(@as(?u8, null), chooseSidebarVpsHost(null, .{ 0, 0 }));

    const entries = [_]TmuxSessionEntry{
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 1 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 1 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 2 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 3 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 4 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 5 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 7 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 1, .agent = 0 },
        .{ .name = undefined, .name_len = 0, .activity = 0, .host = 0, .agent = 1 },
    };
    const stats = agentSessionBreakdownForHost(&entries, 1);
    try std.testing.expectEqual(@as(u16, 2), stats.claude);
    try std.testing.expectEqual(@as(u16, 1), stats.codex);
    try std.testing.expectEqual(@as(u16, 4), stats.other);
    try std.testing.expectEqual(@as(u16, 7), stats.total());
}

test "capacity parsers and workload recognition are deterministic" {
    try std.testing.expectEqual(@as(u32, 18_250), parseDecimalMilli("18.25"));
    try std.testing.expectEqual(@as(u32, 10), parseDecimalMilli("0.01"));
    try std.testing.expect(commandCreatesAgentWorkload("cd /srv/app && tnn"));
    try std.testing.expect(commandCreatesAgentWorkload("codex --resume"));
    try std.testing.expect(commandCreatesAgentWorkload("hax"));
    try std.testing.expect(commandCreatesAgentWorkload("grok"));
    try std.testing.expect(commandCreatesAgentWorkload("cursor-agent"));
    try std.testing.expect(!commandCreatesAgentWorkload("python -m pip"));
    try std.testing.expect(!commandCreatesAgentWorkload("tmux new-session -A -s projects -c ~/projects"));
}

test "tmux pane commands identify the current coding agent" {
    try std.testing.expectEqual(@as(u8, 1), tmuxAgentFromPaneCommand("claude"));
    try std.testing.expectEqual(@as(u8, 2), tmuxAgentFromPaneCommand("codex"));
    try std.testing.expectEqual(@as(u8, 3), tmuxAgentFromPaneCommand("pi"));
    try std.testing.expectEqual(@as(u8, 4), tmuxAgentFromPaneCommand("kimi"));
    try std.testing.expectEqual(@as(u8, 4), tmuxAgentFromPaneCommand("kimi-code"));
    try std.testing.expectEqual(@as(u8, 4), tmuxAgentFromPaneCommand("KIMI-CODE"));
    try std.testing.expectEqual(@as(u8, 5), tmuxAgentFromPaneCommand("hax"));
    try std.testing.expectEqual(@as(u8, 5), tmuxAgentFromPaneCommand("HAX"));
    try std.testing.expectEqual(@as(u8, 6), tmuxAgentFromPaneCommand("grok"));
    try std.testing.expectEqual(@as(u8, 6), tmuxAgentFromPaneCommand("GROK"));
    try std.testing.expectEqual(@as(u8, 7), tmuxAgentFromPaneCommand("cursor"));
    try std.testing.expectEqual(@as(u8, 7), tmuxAgentFromPaneCommand("CURSOR-AGENT"));
    try std.testing.expectEqual(@as(u8, 0), tmuxAgentFromPaneCommand("bash"));
}

test "remote SSH routes use the configured host profiles" {
    try std.testing.expectEqualStrings("-t remote-1", SSH_HOST_DE);
    try std.testing.expectEqualStrings("-t remote-2", SSH_HOST_UK);
    try std.testing.expectEqualStrings("-t remote-3", SSH_HOST_INNE);
    try std.testing.expectEqualStrings("remote-1", SSH_TARGET_DE);
    try std.testing.expectEqualStrings("remote-2", SSH_TARGET_UK);
    try std.testing.expectEqualStrings("remote-3", SSH_TARGET_INNE);
    try std.testing.expectEqualStrings(SSH_HOST_INNE, tmuxSshHostArg(TMUX_HOST_INNE));
    try std.testing.expectEqualStrings(SSH_TARGET_INNE, tmuxSshTarget(TMUX_HOST_INNE));
    try std.testing.expectEqualStrings("HOST3-TMX", tmuxHostTagLabel(TMUX_HOST_INNE));
    try std.testing.expectEqualStrings("xterm-256color", SSH_TERM);
}

fn getCapacityJsonPath(buf: *[512]u8) ?[]const u8 {
    const appdata_len = GetEnvironmentVariableA("APPDATA", buf, 512);
    if (appdata_len == 0 or appdata_len >= 480) return null;
    const rest = "\\ZigShell\\capacity.json";
    @memcpy(buf[appdata_len .. appdata_len + rest.len], rest);
    return buf[0 .. appdata_len + rest.len];
}

pub fn ensureCapacityPolicyStarter() void {
    var path_buf: [512]u8 = undefined;
    const path = getCapacityJsonPath(&path_buf) orelse return;
    if (win32OpenRead(path)) |h| {
        _ = CloseHandle(h);
        return;
    }
    const starter =
        "{\n" ++
        "  \"_doc\": \"VPS Capacity Guardian. Load thresholds are per-core percentages; PSI values are Linux avg10 percentages. Red/critical pressure blocks new AI workloads but never blocks attaching, inspecting, or ending an existing tmux session.\",\n" ++
        "  \"host1_busy_agents\": 8,\n" ++
        "  \"host2_busy_agents\": 8,\n" ++
        "  \"amber_load_percent\": 75,\n" ++
        "  \"red_load_percent\": 100,\n" ++
        "  \"critical_load_percent\": 150,\n" ++
        "  \"amber_mem_available_percent\": 25,\n" ++
        "  \"red_mem_available_percent\": 15,\n" ++
        "  \"critical_mem_available_percent\": 8,\n" ++
        "  \"amber_psi_percent\": 10,\n" ++
        "  \"red_psi_percent\": 20,\n" ++
        "  \"critical_psi_percent\": 50\n" ++
        "}\n";
    const h = win32OpenWrite(path) orelse return;
    defer _ = CloseHandle(h);
    win32WriteAll(h, starter);
}

pub fn capacityJsonValue(json: std.json.Value, field: []const u8, fallback: u64, min_value: u64, max_value: u64) u64 {
    const value = json_reader.uint(json, field);
    if (value == 0) return fallback;
    return @max(min_value, @min(value, max_value));
}

pub fn loadCapacityPolicy() void {
    app_state.g_capacity_policy = CapacityPolicy{};
    var path_buf: [512]u8 = undefined;
    const path = getCapacityJsonPath(&path_buf) orelse return;
    const h = win32OpenRead(path) orelse return;
    defer _ = CloseHandle(h);
    var json_buf: [8192]u8 = undefined;
    const n = win32ReadAll(h, &json_buf);
    if (n == 0) return;
    var parsed = json_reader.parse(std.heap.page_allocator, json_buf[0..n]) catch return;
    defer parsed.deinit();
    const json = parsed.value;

    app_state.g_capacity_policy.host_busy_limit[0] = @intCast(capacityJsonValue(json, "host1_busy_agents", 8, 1, 128));
    app_state.g_capacity_policy.host_busy_limit[1] = @intCast(capacityJsonValue(json, "host2_busy_agents", 8, 1, 128));
    app_state.g_capacity_policy.amber_load_per_core_milli = @intCast(capacityJsonValue(json, "amber_load_percent", 75, 10, 1000) * 10);
    app_state.g_capacity_policy.red_load_per_core_milli = @intCast(capacityJsonValue(json, "red_load_percent", 100, 10, 1000) * 10);
    app_state.g_capacity_policy.critical_load_per_core_milli = @intCast(capacityJsonValue(json, "critical_load_percent", 150, 10, 1000) * 10);
    app_state.g_capacity_policy.amber_mem_available_pct = @intCast(capacityJsonValue(json, "amber_mem_available_percent", 25, 1, 99));
    app_state.g_capacity_policy.red_mem_available_pct = @intCast(capacityJsonValue(json, "red_mem_available_percent", 15, 1, 99));
    app_state.g_capacity_policy.critical_mem_available_pct = @intCast(capacityJsonValue(json, "critical_mem_available_percent", 8, 1, 99));
    app_state.g_capacity_policy.amber_psi_milli = @intCast(capacityJsonValue(json, "amber_psi_percent", 10, 1, 100) * 1000);
    app_state.g_capacity_policy.red_psi_milli = @intCast(capacityJsonValue(json, "red_psi_percent", 20, 1, 100) * 1000);
    app_state.g_capacity_policy.critical_psi_milli = @intCast(capacityJsonValue(json, "critical_psi_percent", 50, 1, 100) * 1000);
}

pub fn capacityStateColor(state: CapacityState, dim: DWORD) DWORD {
    return switch (state) {
        .green => if (app_state.g_light_theme) RGB(30, 125, 70) else RGB(85, 190, 115),
        .amber => if (app_state.g_light_theme) RGB(150, 95, 0) else RGB(245, 170, 70),
        .red, .critical => RGB(235, 80, 75),
        .unknown => dim,
    };
}

pub fn capacityLoadPercent(metrics: HostCapacity) u32 {
    if (!metrics.valid or metrics.cores == 0) return 0;
    const normalized_milli = metrics.load_milli / @as(u32, metrics.cores);
    return (normalized_milli + 5) / 10;
}

fn capacityAvailableRamPercent(metrics: HostCapacity) u32 {
    if (!metrics.valid or metrics.mem_total_kb == 0) return 0;
    return @intCast(@min(100, metrics.mem_available_kb *| 100 / metrics.mem_total_kb));
}

fn capacityPsiPercent(milli: u32) u32 {
    return (milli + 500) / 1000;
}

fn formatCapacityCriticalCause(out: []u8, metrics: HostCapacity, effective_state: CapacityState, policy: CapacityPolicy) []const u8 {
    if (!metrics.valid) return "CAUSE: WAITING FOR TELEMETRY";
    const normalized_load = if (metrics.cores > 0) metrics.load_milli / @as(u32, metrics.cores) else 0;
    const ram_free_pct = capacityAvailableRamPercent(metrics);

    if (effective_state == .critical) {
        if (normalized_load >= policy.critical_load_per_core_milli) {
            return std.fmt.bufPrint(out, "CAUSE: LOAD {d}% >={d}%", .{ capacityLoadPercent(metrics), policy.critical_load_per_core_milli / 10 }) catch "CAUSE: LOAD";
        }
        if (ram_free_pct <= policy.critical_mem_available_pct) {
            return std.fmt.bufPrint(out, "CAUSE: RAM FREE {d}% <={d}%", .{ ram_free_pct, policy.critical_mem_available_pct }) catch "CAUSE: RAM FREE";
        }
        if (metrics.cpu_psi_milli >= policy.critical_psi_milli) {
            return std.fmt.bufPrint(out, "CAUSE: CPU WAIT {d}% >={d}%", .{ capacityPsiPercent(metrics.cpu_psi_milli), policy.critical_psi_milli / 1000 }) catch "CAUSE: CPU WAIT";
        }
        if (metrics.mem_psi_milli >= policy.critical_psi_milli) {
            return std.fmt.bufPrint(out, "CAUSE: RAM WAIT {d}% >={d}%", .{ capacityPsiPercent(metrics.mem_psi_milli), policy.critical_psi_milli / 1000 }) catch "CAUSE: RAM WAIT";
        }
        if (metrics.io_psi_milli >= policy.critical_psi_milli) {
            return std.fmt.bufPrint(out, "CAUSE: DISK WAIT {d}% >={d}%", .{ capacityPsiPercent(metrics.io_psi_milli), policy.critical_psi_milli / 1000 }) catch "CAUSE: DISK WAIT";
        }
        return std.fmt.bufPrint(out, "RECOVERING: {d}/4 LOWER CHECKS", .{@min(metrics.recovery_samples, 4)}) catch "RECOVERING";
    }
    return "CURRENTLY BELOW CRITICAL LIMITS";
}

test "VPS card normalizes load and exposes understandable capacity percentages" {
    var metrics = HostCapacity{ .valid = true, .cores = 18, .load_milli = 26_070, .mem_total_kb = 96 * 1024 * 1024, .mem_available_kb = 48 * 1024 * 1024 };
    try std.testing.expectEqual(@as(u32, 145), capacityLoadPercent(metrics));
    try std.testing.expectEqual(@as(u32, 50), capacityAvailableRamPercent(metrics));
    metrics.cpu_psi_milli = 52_970;
    var cause_buf: [96]u8 = undefined;
    const cause = formatCapacityCriticalCause(&cause_buf, metrics, .critical, CapacityPolicy{});
    try std.testing.expect(std.mem.eql(u8, cause, "CAUSE: CPU WAIT 53% >=50%"));
}

pub fn paintSidebarVpsCard(hdc: HANDLE, host: u8, rect: RECT, font_subtitle: HANDLE) void {
    paintSidebarCardFrame(hdc, rect);
    if (host >= app_state.g_host_capacity.len or rect.right <= rect.left + 40) return;
    const metrics = app_state.g_host_capacity[host];
    const state = effectiveCapacityState(host);
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const bright: DWORD = customColorOr("text_active", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(235, 238, 244));
    const state_color = capacityStateColor(state, dim);
    const inner_left = rect.left + uiScaled(10);
    const inner_right = rect.right - uiScaled(10);

    drawAttentionDot(hdc, inner_left + uiScaled(4), @divTrunc(rect.top + rect.bottom, 2), uiScaled(3), state_color);
    _ = SelectObject(hdc, font_subtitle);
    const state_label = capacityStateLabel(state);
    _ = SetTextColor(hdc, state_color);
    var state_rc = RECT{ .left = @max(inner_left, inner_right - asciiTextWidth(hdc, state_label)), .top = rect.top, .right = inner_right, .bottom = rect.bottom };
    drawAscii(hdc, state_label, &state_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);
    const limit = state_rc.left - uiScaled(6);

    _ = SetTextColor(hdc, bright);
    const host_end = drawAsciiRun(hdc, capacityHostLabel(host), inner_left + uiScaled(12), rect.top, rect.bottom, limit);
    var load_buf: [48]u8 = undefined;
    const load = formatVpsLoad(&load_buf, metrics.valid and metrics.mem_total_kb > 0, capacityLoadPercent(metrics), capacityAvailableRamPercent(metrics));
    _ = SetTextColor(hdc, dim);
    _ = drawAsciiRun(hdc, load, host_end + uiScaled(8), rect.top, rect.bottom, limit);
}

pub fn paintSidebarVpsDetail(hdc: HANDLE, host: u8, rect: RECT, font_title: HANDLE, font_subtitle: HANDLE) void {
    if (host >= app_state.g_host_capacity.len) return;
    const y = rect.top;
    const card_h = rect.bottom - rect.top;
    const card_left = rect.left;
    const card_right = rect.right;
    if (card_right <= card_left + 40) return;

    const metrics = app_state.g_host_capacity[host];
    const state = effectiveCapacityState(host);
    const dim: DWORD = customColorOr("muted", if (app_state.g_light_theme) RGB(100, 100, 100) else RGB(135, 142, 152));
    const bright: DWORD = customColorOr("text_active", if (app_state.g_light_theme) RGB(25, 25, 25) else RGB(235, 238, 244));
    const state_color = capacityStateColor(state, dim);
    const border: DWORD = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(210, 214, 220) else RGB(55, 61, 70));

    paintSidebarCardFrame(hdc, rect);

    const inner_left = card_left + uiScaled(10);
    const inner_right = card_right - uiScaled(10);
    const header_top = y + uiScaled(6);
    const header_bottom = y + uiScaled(28);

    drawAttentionDot(hdc, inner_left + uiScaled(4), y + uiScaled(17), uiScaled(3), state_color);
    _ = SelectObject(hdc, font_title);
    _ = SetTextColor(hdc, bright);
    var host_buf: [32]u8 = undefined;
    const host_label = std.fmt.bufPrint(&host_buf, "{s} VPS | 2/3", .{capacityHostLabel(host)}) catch capacityHostLabel(host);
    var host_rc = RECT{ .left = inner_left + uiScaled(12), .top = header_top, .right = inner_right - uiScaled(70), .bottom = header_bottom };
    drawAscii(hdc, host_label, &host_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

    _ = SelectObject(hdc, font_subtitle);
    _ = SetTextColor(hdc, state_color);
    var state_rc = RECT{ .left = inner_right - uiScaled(76), .top = header_top, .right = inner_right, .bottom = header_bottom };
    drawAscii(hdc, capacityStateLabel(state), &state_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);

    var cause_buf: [96]u8 = undefined;
    const cause = formatCapacityCriticalCause(&cause_buf, metrics, state, app_state.g_capacity_policy);
    _ = SetTextColor(hdc, if (state == .critical) state_color else dim);
    var cause_rc = RECT{ .left = inner_left, .top = y + uiScaled(30), .right = inner_right, .bottom = y + uiScaled(52) };
    drawAscii(hdc, cause, &cause_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

    const row1_top = y + uiScaled(55);
    const row2_top = y + uiScaled(78);
    const row3_top = y + uiScaled(101);
    const row_h = uiScaled(20);
    const value_left = card_left + @divTrunc(card_right - card_left, 2);

    _ = SetTextColor(hdc, dim);
    var load_label_rc = RECT{ .left = inner_left, .top = row1_top, .right = value_left, .bottom = row1_top + row_h };
    drawAscii(hdc, "CPU load", &load_label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    var ram_label_rc = RECT{ .left = inner_left, .top = row2_top, .right = value_left, .bottom = row2_top + row_h };
    drawAscii(hdc, "RAM free", &ram_label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    var agents_label_rc = RECT{ .left = inner_left, .top = row3_top, .right = value_left, .bottom = row3_top + row_h };
    drawAscii(hdc, "Agents work/open", &agents_label_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_END_ELLIPSIS);

    _ = SetTextColor(hdc, bright);
    var load_buf: [48]u8 = undefined;
    const load_value = if (metrics.valid)
        std.fmt.bufPrint(&load_buf, "{d}%", .{capacityLoadPercent(metrics)}) catch "?"
    else
        "waiting...";
    var load_rc = RECT{ .left = value_left, .top = row1_top, .right = inner_right, .bottom = row1_top + row_h };
    drawAscii(hdc, load_value, &load_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);

    var ram_buf: [48]u8 = undefined;
    const ram_value = if (metrics.valid and metrics.mem_total_kb > 0)
        std.fmt.bufPrint(&ram_buf, "{d}%", .{capacityAvailableRamPercent(metrics)}) catch "?"
    else
        "waiting...";
    var ram_rc = RECT{ .left = value_left, .top = row2_top, .right = inner_right, .bottom = row2_top + row_h };
    drawAscii(hdc, ram_value, &ram_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);

    const agent_stats = sidebarAgentSessionBreakdown(host);
    var agents_buf: [48]u8 = undefined;
    const agents_value = std.fmt.bufPrint(&agents_buf, "{d} / {d}", .{ hostBusyAgentCount(host), agent_stats.total() }) catch "?";
    var agents_rc = RECT{ .left = value_left, .top = row3_top, .right = inner_right, .bottom = row3_top + row_h };
    drawAscii(hdc, agents_value, &agents_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT | DT_END_ELLIPSIS);

    var divider_rc = RECT{ .left = inner_left, .top = y + uiScaled(125), .right = inner_right, .bottom = y + uiScaled(126) };
    const divider_brush = CreateSolidBrush(border);
    _ = FillRect(hdc, &divider_rc, divider_brush);
    _ = DeleteObject(divider_brush);

    var claude_buf: [24]u8 = undefined;
    var codex_buf: [24]u8 = undefined;
    var other_buf: [24]u8 = undefined;
    const claude_text = std.fmt.bufPrint(&claude_buf, "Claude {d}", .{agent_stats.claude}) catch "Claude ?";
    const codex_text = std.fmt.bufPrint(&codex_buf, "Codex {d}", .{agent_stats.codex}) catch "Codex ?";
    const other_text = std.fmt.bufPrint(&other_buf, "Other {d}", .{agent_stats.other}) catch "Other ?";
    const stats_top = y + uiScaled(129);
    const stats_bottom = y + uiScaled(151);
    const stats_width = @divTrunc(inner_right - inner_left, 3);
    _ = SetTextColor(hdc, dim);
    var claude_rc = RECT{ .left = inner_left, .top = stats_top, .right = inner_left + stats_width, .bottom = stats_bottom };
    drawAscii(hdc, claude_text, &claude_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX);
    var codex_rc = RECT{ .left = inner_left + stats_width, .top = stats_top, .right = inner_left + stats_width * 2, .bottom = stats_bottom };
    drawAscii(hdc, codex_text, &codex_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_CENTER);
    var other_rc = RECT{ .left = inner_left + stats_width * 2, .top = stats_top, .right = inner_right, .bottom = stats_bottom };
    drawAscii(hdc, other_text, &other_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_RIGHT);

    _ = SetTextColor(hdc, dim);
    var starts_load_rc = RECT{ .left = inner_left, .top = y + uiScaled(153), .right = inner_right, .bottom = y + uiScaled(170) };
    drawAscii(hdc, "START: LOAD 150%+ | WAIT 50%+", &starts_load_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_CENTER | DT_END_ELLIPSIS);
    var starts_ram_rc = RECT{ .left = inner_left, .top = y + uiScaled(169), .right = inner_right, .bottom = y + uiScaled(186) };
    drawAscii(hdc, "START: RAM FREE 8%-", &starts_ram_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_CENTER | DT_END_ELLIPSIS);
    var ends_rc = RECT{ .left = inner_left, .top = y + uiScaled(185), .right = inner_right, .bottom = y + card_h - uiScaled(3) };
    drawAscii(hdc, "END: 4 LOWER CHECKS (~1 MIN)", &ends_rc, DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX | DT_CENTER | DT_END_ELLIPSIS);
}

pub fn paintSidebarCardFrame(hdc: HANDLE, rect: RECT) void {
    const card_bg: DWORD = customColorOr("header_bg", if (app_state.g_light_theme) RGB(242, 244, 247) else if (app_state.g_edge_gray_theme) RGB(52, 54, 58) else if (app_state.g_mid_theme) RGB(62, 64, 68) else RGB(24, 27, 32));
    const border: DWORD = customColorOr("overlay_border", if (app_state.g_light_theme) RGB(210, 214, 220) else RGB(55, 61, 70));
    const brush = CreateSolidBrush(card_bg);
    const pen = CreatePen(0, 1, border);
    const old_brush = SelectObject(hdc, brush);
    const old_pen = SelectObject(hdc, pen);
    _ = @import("smooth.zig").drawRoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom, uiScaled(8), uiScaled(8));
    _ = SelectObject(hdc, old_brush);
    _ = SelectObject(hdc, old_pen);
    _ = DeleteObject(brush);
    _ = DeleteObject(pen);
}
