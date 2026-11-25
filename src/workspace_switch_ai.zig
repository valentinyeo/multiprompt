const std = @import("std");
const app_state = @import("app_state.zig");
const win32 = @import("win32.zig");
const command_palette = @import("command_palette.zig");
const chat_session = @import("chat_session.zig");
const SessionIdentity = @import("session_identity.zig").Session;

pub const claude_agent: u8 = 1;
pub const codex_agent: u8 = 2;
pub const pi_agent: u8 = 3;
pub const antigravity_agent: u8 = 8;

pub const busy_wait_ms: u32 = 2000;
pub const max_busy_attempts: u8 = 61;

pub const SwitchOutcome = union(enum) {
    switched: struct {
        agent: u8,
        sid: [40]u8 = std.mem.zeroes([40]u8),
        sid_len: u8 = 0,
    },
    already: u8,
    busy,
    refused: []const u8,
    failed: []const u8,
};

pub const SnapshotResult = union(enum) {
    unknown_tab,
    not_chat_tab,
    already: u8,
    ready: struct {
        identity: SessionIdentity,
        current_agent: u8,
    },
    failed: []const u8,
};

pub const WorkspaceSwitchPlan = struct {
    total_chats: u32 = 0,
    already: u32 = 0,
    count: u32 = 0,
    tabs: [app_state.MAX_SHELLS]u32 = undefined,
};

const SwitchEnvelope = struct {
    status: []const u8 = "",
    provider: []const u8 = "",
    sid: []const u8 = "",
    reason: []const u8 = "",
    result: struct {
        status: []const u8 = "",
        provider: []const u8 = "",
        sid: []const u8 = "",
        reason: []const u8 = "",
    } = .{},
};

const UiTaskKind = enum { snapshot, adopt };

const UiTask = struct {
    kind: UiTaskKind,
    tab: u32 = 0,
    target: u8 = 0,
    agent: u8 = 0,
    sid: [40]u8 = std.mem.zeroes([40]u8),
    sid_len: u8 = 0,
    snapshot: SnapshotResult = .unknown_tab,
    adopted: bool = false,
    done_event: win32.HANDLE = null,
    refs: std.atomic.Value(u8) = std.atomic.Value(u8).init(1),
};

const WorkspaceSwitchJob = struct {
    target: u8,
    total_chats: u32,
    already: u32,
    count: u32,
    tabs: [app_state.MAX_SHELLS]u32 = undefined,
};

var g_running = std.atomic.Value(bool).init(false);

pub fn targetAgentId(name: []const u8) ?u8 {
    if (std.mem.eql(u8, name, "claude")) return claude_agent;
    if (std.mem.eql(u8, name, "codex")) return codex_agent;
    if (std.mem.eql(u8, name, "antigravity")) return antigravity_agent;
    return null;
}

pub fn targetName(target: u8) []const u8 {
    return switch (target) {
        claude_agent => "claude",
        codex_agent => "codex",
        antigravity_agent => "antigravity",
        else => "",
    };
}

pub fn targetDisplayName(target: u8) []const u8 {
    return switch (target) {
        claude_agent => "Claude",
        codex_agent => "Codex",
        antigravity_agent => "Antigravity",
        else => "",
    };
}

pub fn isTarget(target: u8) bool {
    return switch (target) {
        claude_agent, codex_agent, antigravity_agent => true,
        else => false,
    };
}

pub fn isAgentChat(agent: u8) bool {
    return agent == claude_agent or agent == codex_agent or agent == pi_agent or agent == antigravity_agent;
}

pub fn agentProviderName(agent: u8) ?[]const u8 {
    return switch (agent) {
        claude_agent => "claude",
        codex_agent => "codex",
        pi_agent => "pi",
        antigravity_agent => "antigravity",
        else => null,
    };
}

pub fn isLiveChatShell(shell: *const app_state.Shell) bool {
    return shell.kind == .tmux and command_palette.canRestartChat(shell.ai_agent, shell.claude_sid_len, shell.tmux_session_len);
}

pub fn isSwitchableChatShell(shell: *const app_state.Shell) bool {
    return isLiveChatShell(shell) and isAgentChat(shell.ai_agent);
}

pub fn paletteTargetFor(row: usize) ?u8 {
    return switch (row) {
        app_state.SEARCH_WS_SWITCH_CLAUDE_OFFSET => claude_agent,
        app_state.SEARCH_WS_SWITCH_CODEX_OFFSET => codex_agent,
        app_state.SEARCH_WS_SWITCH_ANTIGRAVITY_OFFSET => antigravity_agent,
        else => null,
    };
}

pub fn paletteLabel(row: usize) []const u8 {
    return switch (row) {
        app_state.SEARCH_WS_SWITCH_CLAUDE_OFFSET => "Workspace: Switch every chat to Claude",
        app_state.SEARCH_WS_SWITCH_CODEX_OFFSET => "Workspace: Switch every chat to Codex",
        app_state.SEARCH_WS_SWITCH_ANTIGRAVITY_OFFSET => "Workspace: Switch every chat to Antigravity",
        else => "",
    };
}

fn switchSidOk(sid: []const u8) bool {
    if (sid.len == 0 or sid.len > 40) return false;
    for (sid) |c| {
        if (!((c >= '0' and c <= '9') or (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or c == '-' or c == '_')) return false;
    }
    return true;
}

fn switchEnvelopeFields(value: SwitchEnvelope) struct { status: []const u8, provider: []const u8, sid: []const u8, reason: []const u8 } {
    const nested = value.result.status.len != 0 or value.result.provider.len != 0 or value.result.sid.len != 0 or value.result.reason.len != 0;
    if (nested) return .{ .status = value.result.status, .provider = value.result.provider, .sid = value.result.sid, .reason = value.result.reason };
    return .{ .status = value.status, .provider = value.provider, .sid = value.sid, .reason = value.reason };
}

fn switchFailureReason(reason: []const u8) []const u8 {
    if (std.mem.eql(u8, reason, "switch_start_failed")) return "the new AI could not start";
    if (std.mem.eql(u8, reason, "host_disabled")) return "this live chat is not running";
    if (std.mem.eql(u8, reason, "no_chat")) return "this tab has no live chat";
    if (std.mem.eql(u8, reason, "host_handed_over")) return "this chat was already handed over";
    if (std.mem.eql(u8, reason, "history_unavailable")) return "chat history is unavailable";
    if (std.mem.eql(u8, reason, "switch_failed")) return "switch failed";
    return "this live chat cannot switch";
}

pub fn formatSwitchRequest(out: []u8, identity: SessionIdentity, target: u8) ?[]const u8 {
    const to = targetName(target);
    const provider = identity.provider();
    const sid = std.mem.sliceTo(&identity.sid, 0);
    if (provider.len == 0 or sid.len == 0 or to.len == 0) return null;
    return std.fmt.bufPrint(out, "{{\"op\":\"switch_ai\",\"id\":{d},\"host\":{d},\"provider\":\"{s}\",\"sid\":\"{s}\",\"to\":\"{s}\"}}", .{ identity.owner, identity.host.index(), provider, sid, to }) catch null;
}

pub fn parseSwitchReply(allocator: std.mem.Allocator, body: []const u8) SwitchOutcome {
    const parsed = std.json.parseFromSlice(SwitchEnvelope, allocator, std.mem.trim(u8, body, " \r\n"), .{ .ignore_unknown_fields = true }) catch {
        return .{ .failed = "the server did not answer" };
    };
    defer parsed.deinit();
    const fields = switchEnvelopeFields(parsed.value);
    if (std.mem.eql(u8, fields.status, "switched")) {
        const agent = targetAgentId(fields.provider) orelse return .{ .failed = "invalid switch reply" };
        if (!switchSidOk(fields.sid)) return .{ .failed = "invalid switch reply" };
        var sid = std.mem.zeroes([40]u8);
        @memcpy(sid[0..fields.sid.len], fields.sid);
        return .{ .switched = .{ .agent = agent, .sid = sid, .sid_len = @intCast(fields.sid.len) } };
    }
    if (std.mem.eql(u8, fields.status, "busy")) return .busy;
    if (std.mem.eql(u8, fields.status, "refused")) return .{ .refused = fields.reason };
    return .{ .failed = switchFailureReason(fields.reason) };
}

pub fn switchChatWithTransport(identity: SessionIdentity, target: u8, comptime send_fn: anytype) SwitchOutcome {
    var buf: [512]u8 = undefined;
    const request = formatSwitchRequest(&buf, identity, target) orelse return .{ .failed = "this live chat cannot switch" };
    var response: std.ArrayList(u8) = .empty;
    defer response.deinit(std.heap.page_allocator);
    if (!send_fn(identity, request, &response)) return .{ .failed = "the server did not answer" };
    return parseSwitchReply(std.heap.page_allocator, response.items);
}

fn liveSwitchTransport(identity: SessionIdentity, request: []const u8, response: *std.ArrayList(u8)) bool {
    return chat_session.chatHistoryPersistent(identity, request, 65536, response, null);
}

pub fn switchChatLive(identity: SessionIdentity, target: u8) SwitchOutcome {
    return switchChatWithTransport(identity, target, liveSwitchTransport);
}

pub fn snapshotTabOnUi(tab: u32, target: u8) SnapshotResult {
    const index = @import("inbox.zig").findShellById(tab) orelse return .unknown_tab;
    const shell = &app_state.shells[index];
    if (!isSwitchableChatShell(shell)) return .not_chat_tab;
    if (shell.ai_agent == target) return .{ .already = shell.ai_agent };
    const key = chat_session.chatFileIdentityForShell(index);
    const identity = key.checked() orelse return .not_chat_tab;
    if (key.sid[0] == 0 or key.tmux[0] == 0) return .not_chat_tab;
    return .{ .ready = .{ .identity = identity, .current_agent = shell.ai_agent } };
}

fn applyAgentOnUi(shell: *app_state.Shell, agent: u8, sid: []const u8) bool {
    if (!isAgentChat(agent) or !switchSidOk(sid) or sid.len > shell.claude_sid.len) return false;
    shell.ai_agent = agent;
    @memset(shell.claude_sid[0..], 0);
    @memcpy(shell.claude_sid[0..sid.len], sid);
    shell.claude_sid_len = @intCast(sid.len);
    shell.hook_capable = true;
    return true;
}

pub fn adoptChatOnUiWithPersist(shell_id: u32, agent: u8, sid: []const u8, comptime persist_fn: fn () void) bool {
    const index = @import("inbox.zig").findShellById(shell_id) orelse return false;
    const shell = &app_state.shells[index];
    if (!applyAgentOnUi(shell, agent, sid)) return false;
    persist_fn();
    if (app_state.g_chat_active and index == app_state.active_shell) chat_session.chatFileRequest(chat_session.chatFileIdentityForShell(index));
    return true;
}

fn persistLiveSession() void {
    @import("session.zig").saveSession();
    @import("window_layout.zig").invalidateSidebar();
}

fn destroyUiTask(task: *UiTask) void {
    if (task.done_event != null) _ = win32.CloseHandle(task.done_event);
    std.heap.page_allocator.destroy(task);
}

fn releaseUiTask(task: *UiTask) void {
    if (task.refs.fetchSub(1, .acq_rel) == 1) destroyUiTask(task);
}

pub fn handleUiTask(lp: win32.LPARAM) void {
    if (lp == 0) return;
    const task: *UiTask = @ptrFromInt(@as(usize, @bitCast(lp)));
    defer releaseUiTask(task);
    switch (task.kind) {
        .snapshot => {
            task.snapshot = snapshotTabOnUi(task.tab, task.target);
        },
        .adopt => {
            task.adopted = adoptChatOnUiWithPersist(task.tab, task.agent, task.sid[0..task.sid_len], persistLiveSession);
        },
    }
    if (task.done_event != null) _ = win32.SetEvent(task.done_event);
}

fn runUiTaskSync(task: *UiTask) bool {
    const ev = win32.CreateEventW(null, 1, 0, null);
    if (ev == null) {
        std.heap.page_allocator.destroy(task);
        return false;
    }
    task.done_event = ev;
    task.refs.store(2, .release);
    if (app_state.g_main_hwnd == null or @import("focus.zig").PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_WORKSPACE_SWITCH_AI, 0, @bitCast(@intFromPtr(task))) == 0) {
        destroyUiTask(task);
        return false;
    }
    const waited = win32.WaitForSingleObject(ev, 10_000);
    if (waited != 0) {
        releaseUiTask(task);
        return false;
    }
    return true;
}

pub fn snapshotTabFromWorker(tab: u32, target: u8) SnapshotResult {
    const task = std.heap.page_allocator.create(UiTask) catch return .{ .failed = "out_of_memory" };
    task.* = .{ .kind = .snapshot, .tab = tab, .target = target };
    if (!runUiTaskSync(task)) return .{ .failed = "ui_timeout" };
    const result = task.snapshot;
    releaseUiTask(task);
    return result;
}

pub fn adoptTabFromWorker(tab: u32, agent: u8, sid: []const u8) bool {
    if (!switchSidOk(sid)) return false;
    const task = std.heap.page_allocator.create(UiTask) catch return false;
    task.* = .{ .kind = .adopt, .tab = tab, .agent = agent, .sid_len = @intCast(sid.len) };
    @memcpy(task.sid[0..sid.len], sid);
    if (!runUiTaskSync(task)) return false;
    const adopted = task.adopted;
    releaseUiTask(task);
    return adopted;
}

fn postNotice(text: []const u8) void {
    const a = std.heap.page_allocator;
    const notice = a.dupeZ(u8, text) catch return;
    if (app_state.g_main_hwnd == null or @import("focus.zig").PostMessageW(app_state.g_main_hwnd, app_state.WM_APP_CHAT_ATTACH_FAILED, 0, @bitCast(@intFromPtr(notice.ptr))) == 0) a.free(notice);
}

pub fn planWorkspaceSwitch(workspace: u8, target: u8) WorkspaceSwitchPlan {
    var plan: WorkspaceSwitchPlan = .{};
    if (!isTarget(target)) return plan;
    for (0..app_state.shell_count) |i| {
        const shell = &app_state.shells[i];
        if (shell.workspace != workspace) continue;
        if (!isSwitchableChatShell(shell)) continue;
        plan.total_chats += 1;
        if (shell.ai_agent == target) {
            plan.already += 1;
            continue;
        }
        const key = chat_session.chatFileIdentityForShell(@intCast(i));
        if (key.checked() == null or key.sid[0] == 0 or key.tmux[0] == 0) continue;
        plan.tabs[plan.count] = shell.shell_id;
        plan.count += 1;
    }
    return plan;
}

pub fn formatStartNotice(buf: []u8, workspace: u8, target: u8, count: u32, already: u32) []const u8 {
    var name_buf: [32]u8 = undefined;
    const name = @import("workspaces.zig").workspaceDisplayName(workspace, &name_buf);
    const ai = targetDisplayName(target);
    if (already == 0) {
        return std.fmt.bufPrint(buf, "Switching {d} {s} in {s} to {s}, one at a time", .{ count, if (count == 1) "chat" else "chats", name, ai }) catch "Switching chats one at a time";
    }
    return std.fmt.bufPrint(buf, "Switching {d} {s} in {s} to {s} ({d} already there), one at a time", .{ count, if (count == 1) "chat" else "chats", name, ai, already }) catch "Switching chats one at a time";
}

pub fn formatSummary(buf: []u8, target: u8, total_chats: u32, switched: u32, already: u32, busy: u32, refused: u32, failed: u32) []const u8 {
    const ai = targetDisplayName(target);
    if (total_chats == 0) return "No live chats in this workspace";
    if (switched == 0 and busy == 0 and refused == 0 and failed == 0) {
        return std.fmt.bufPrint(buf, "Every chat in this workspace is already on {s}", .{ai}) catch "Already on target AI";
    }
    if (switched > 0 and already == 0 and busy == 0 and refused == 0 and failed == 0) {
        return std.fmt.bufPrint(buf, "Switched {d} {s} to {s}", .{ switched, if (switched == 1) "chat" else "chats", ai }) catch "Workspace chats switched";
    }
    var pos: usize = 0;
    const head = if (switched > 0)
        std.fmt.bufPrint(buf, "Switched {d} to {s} (", .{ switched, ai }) catch return "Workspace switch finished"
    else if (busy > 0 and refused == 0 and failed == 0)
        std.fmt.bufPrint(buf, "Wait for the current reply first (", .{}) catch return "Wait for the current reply first"
    else
        std.fmt.bufPrint(buf, "Workspace switch to {s}: ", .{ai}) catch return "Workspace switch failed";
    pos = head.len;
    const parens = switched > 0 or (busy > 0 and refused == 0 and failed == 0);
    var first = true;
    const parts = [_]struct { count: u32, label: []const u8 }{
        .{ .count = already, .label = "already" },
        .{ .count = busy, .label = "busy" },
        .{ .count = refused, .label = "refused" },
        .{ .count = failed, .label = "failed" },
    };
    for (parts) |part| {
        if (part.count == 0) continue;
        const chunk = std.fmt.bufPrint(buf[pos..], "{s}{d} {s}", .{ if (first) "" else ", ", part.count, part.label }) catch break;
        pos += chunk.len;
        first = false;
    }
    if (parens and pos < buf.len) {
        buf[pos] = ')';
        pos += 1;
    }
    return buf[0..pos];
}

pub fn switchOneTab(tab: u32, target: u8, wait_event: win32.HANDLE) SwitchOutcome {
    var attempt: u8 = 0;
    while (true) : (attempt += 1) {
        switch (snapshotTabFromWorker(tab, target)) {
            .already => |agent| return .{ .already = agent },
            .unknown_tab => return .{ .failed = "this tab is gone" },
            .not_chat_tab => return .{ .failed = "this tab is not a live chat" },
            .failed => |code| return .{ .failed = code },
            .ready => |info| switch (switchChatLive(info.identity, target)) {
                .switched => |done| return .{ .switched = done },
                .already => |agent| return .{ .already = agent },
                .refused => |reason| return .{ .refused = reason },
                .failed => |reason| return .{ .failed = reason },
                .busy => {
                    if (attempt + 1 >= max_busy_attempts) return .busy;
                    if (wait_event != null) _ = win32.WaitForSingleObject(wait_event, busy_wait_ms);
                },
            },
        }
    }
}

fn workspaceSwitchThread(job: *WorkspaceSwitchJob) void {
    defer std.heap.page_allocator.destroy(job);
    defer g_running.store(false, .release);
    const wait_event = win32.CreateEventW(null, 1, 0, null);
    defer {
        if (wait_event != null) _ = win32.CloseHandle(wait_event);
    }
    var switched: u32 = 0;
    var busy: u32 = 0;
    var refused: u32 = 0;
    var failed: u32 = 0;
    for (job.tabs[0..job.count]) |tab| {
        switch (switchOneTab(tab, job.target, wait_event)) {
            .switched => |done| {
                if (adoptTabFromWorker(tab, done.agent, done.sid[0..done.sid_len])) switched += 1 else failed += 1;
            },
            .already => {},
            .busy => busy += 1,
            .refused => refused += 1,
            .failed => failed += 1,
        }
    }
    var notice_buf: [192]u8 = undefined;
    postNotice(formatSummary(&notice_buf, job.target, job.total_chats, switched, job.already, busy, refused, failed));
}

pub fn startWorkspaceSwitch(workspace: u8, target: u8) bool {
    if (!isTarget(target)) return false;
    if (g_running.swap(true, .acq_rel)) {
        postNotice("Workspace switch is already running");
        return true;
    }
    const plan = planWorkspaceSwitch(workspace, target);
    if (plan.count == 0) {
        g_running.store(false, .release);
        var notice_buf: [192]u8 = undefined;
        postNotice(formatSummary(&notice_buf, target, plan.total_chats, 0, plan.already, 0, 0, 0));
        return true;
    }
    var start_buf: [192]u8 = undefined;
    postNotice(formatStartNotice(&start_buf, workspace, target, plan.count, plan.already));
    const job = std.heap.page_allocator.create(WorkspaceSwitchJob) catch {
        g_running.store(false, .release);
        return false;
    };
    job.* = .{ .target = target, .total_chats = plan.total_chats, .already = plan.already, .count = plan.count };
    @memcpy(job.tabs[0..plan.count], plan.tabs[0..plan.count]);
    const thread = std.Thread.spawn(.{ .stack_size = 256 * 1024 }, workspaceSwitchThread, .{job}) catch {
        std.heap.page_allocator.destroy(job);
        g_running.store(false, .release);
        return false;
    };
    thread.detach();
    return true;
}

pub fn activatePalette(hwnd: win32.HANDLE, target: usize) bool {
    const ai = paletteTargetFor(target) orelse return false;
    const ws = command_palette.workspaceColorSlot() orelse command_palette.activeWorkspaceSlot();
    app_state.g_search_active = false;
    app_state.g_search_from_inbox = false;
    app_state.g_shell_focused = false;
    @import("rename.zig").clearSearchBackdrop();
    @import("rename.zig").showActiveShellAfterOverlay();
    _ = startWorkspaceSwitch(ws, ai);
    _ = win32.InvalidateRect(hwnd, null, 0);
    return true;
}

fn makeTestLiveShell(id: u32, workspace: u8, agent: u8, tmux: []const u8, sid: []const u8) app_state.Shell {
    var shell = app_state.empty_shell;
    shell.shell_id = id;
    shell.workspace = workspace;
    shell.kind = .tmux;
    shell.tmux_host = 0;
    shell.ai_agent = agent;
    @memcpy(shell.tmux_session[0..tmux.len], tmux);
    shell.tmux_session_len = @intCast(tmux.len);
    @memcpy(shell.claude_sid[0..sid.len], sid);
    shell.claude_sid_len = @intCast(sid.len);
    return shell;
}

test "MUBO-535 workspace switch plan selects only non-target agent chats in the chosen workspace" {
    const saved_shells = try std.testing.allocator.dupe(app_state.Shell, app_state.shells[0..6]);
    defer {
        @memcpy(app_state.shells[0..saved_shells.len], saved_shells);
        std.testing.allocator.free(saved_shells);
    }
    const saved_count = app_state.shell_count;
    defer app_state.shell_count = saved_count;
    app_state.shell_count = 6;
    app_state.shells[0] = makeTestLiveShell(10, 1, claude_agent, "live-a", "11111111-1111-4111-8111-111111111111");
    app_state.shells[1] = makeTestLiveShell(11, 1, codex_agent, "live-b", "22222222-2222-4222-8222-222222222222");
    app_state.shells[2] = makeTestLiveShell(12, 1, pi_agent, "live-c", "33333333-3333-4333-8333-333333333333");
    app_state.shells[3] = app_state.empty_shell;
    app_state.shells[3].shell_id = 13;
    app_state.shells[3].workspace = 1;
    app_state.shells[3].kind = .tmux;
    @memcpy(app_state.shells[3].tmux_session[0..6], "sh-one");
    app_state.shells[3].tmux_session_len = 6;
    app_state.shells[4] = app_state.empty_shell;
    app_state.shells[4].shell_id = 14;
    app_state.shells[4].workspace = 1;
    app_state.shells[4].kind = .cmd;
    app_state.shells[5] = makeTestLiveShell(15, 2, claude_agent, "live-other", "55555555-5555-4555-8555-555555555555");

    const plan = planWorkspaceSwitch(1, antigravity_agent);
    try std.testing.expectEqual(@as(u32, 3), plan.total_chats);
    try std.testing.expectEqual(@as(u32, 0), plan.already);
    try std.testing.expectEqual(@as(u32, 3), plan.count);
    try std.testing.expectEqual(@as(u32, 10), plan.tabs[0]);
    try std.testing.expectEqual(@as(u32, 12), plan.tabs[2]);

    const codex_plan = planWorkspaceSwitch(1, codex_agent);
    try std.testing.expectEqual(@as(u32, 1), codex_plan.already);
    try std.testing.expectEqual(@as(u32, 2), codex_plan.count);

    const empty_plan = planWorkspaceSwitch(3, codex_agent);
    try std.testing.expectEqual(@as(u32, 0), empty_plan.total_chats);
    try std.testing.expectEqual(@as(u32, 0), empty_plan.count);
}

test "MUBO-535 switch transport uses the switch_ai protocol and classifies switched already busy refused and failed replies" {
    const Fake = struct {
        var last_request: [512]u8 = undefined;
        var last_len: usize = 0;
        var reply: []const u8 = "";
        var ok: bool = true;

        fn send(_: SessionIdentity, request: []const u8, out: *std.ArrayList(u8)) bool {
            @memcpy(last_request[0..request.len], request);
            last_len = request.len;
            if (!ok) return false;
            out.appendSlice(std.heap.page_allocator, reply) catch return false;
            return true;
        }
    };
    var identity = SessionIdentity.remote(0, "live-a", "11111111-1111-4111-8111-111111111111", 1) orelse return error.TestUnexpectedResult;
    identity.owner = 42;

    Fake.ok = true;
    Fake.reply = "{\"id\":42,\"result\":{\"status\":\"switched\",\"provider\":\"antigravity\",\"sid\":\"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee\"}}";
    switch (switchChatWithTransport(identity, antigravity_agent, Fake.send)) {
        .switched => |done| {
            try std.testing.expectEqual(antigravity_agent, done.agent);
            try std.testing.expectEqualStrings("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee", done.sid[0..done.sid_len]);
        },
        else => return error.TestUnexpectedResult,
    }
    const req = Fake.last_request[0..Fake.last_len];
    try std.testing.expectEqualStrings("{\"op\":\"switch_ai\",\"id\":42,\"host\":0,\"provider\":\"claude\",\"sid\":\"11111111-1111-4111-8111-111111111111\",\"to\":\"antigravity\"}", req);

    Fake.reply = "{\"status\":\"busy\",\"reason\":\"chat_busy\"}";
    try std.testing.expect(std.meta.activeTag(switchChatWithTransport(identity, antigravity_agent, Fake.send)) == .busy);

    Fake.reply = "{\"status\":\"refused\",\"reason\":\"unsupported_provider\"}";
    switch (switchChatWithTransport(identity, antigravity_agent, Fake.send)) {
        .refused => |reason| try std.testing.expectEqualStrings("unsupported_provider", reason),
        else => return error.TestUnexpectedResult,
    }

    Fake.reply = "{\"status\":\"error\",\"reason\":\"switch_start_failed\"}";
    switch (switchChatWithTransport(identity, antigravity_agent, Fake.send)) {
        .failed => |reason| try std.testing.expectEqualStrings("the new AI could not start", reason),
        else => return error.TestUnexpectedResult,
    }

    Fake.ok = false;
    switch (switchChatWithTransport(identity, antigravity_agent, Fake.send)) {
        .failed => |reason| try std.testing.expectEqualStrings("the server did not answer", reason),
        else => return error.TestUnexpectedResult,
    }

    var buf: [192]u8 = undefined;
    try std.testing.expectEqualStrings("No live chats in this workspace", formatSummary(&buf, antigravity_agent, 0, 0, 0, 0, 0, 0));
    try std.testing.expectEqualStrings("Every chat in this workspace is already on Antigravity", formatSummary(&buf, antigravity_agent, 2, 0, 2, 0, 0, 0));
    try std.testing.expectEqualStrings("Switched 2 chats to Antigravity", formatSummary(&buf, antigravity_agent, 2, 2, 0, 0, 0, 0));
    try std.testing.expectEqualStrings("Switched 1 to Antigravity (1 already, 1 busy)", formatSummary(&buf, antigravity_agent, 3, 1, 1, 1, 0, 0));
    try std.testing.expectEqualStrings("Wait for the current reply first (2 busy)", formatSummary(&buf, antigravity_agent, 2, 0, 0, 2, 0, 0));
    try std.testing.expectEqualStrings("Workspace switch to Antigravity: 1 refused, 1 failed", formatSummary(&buf, antigravity_agent, 2, 0, 0, 0, 1, 1));
}

test "MUBO-535 a refused switch leaves the chat on its old AI and a later run switches it" {
    const saved = try std.testing.allocator.dupe(app_state.Shell, app_state.shells[0..1]);
    defer {
        @memcpy(app_state.shells[0..saved.len], saved);
        std.testing.allocator.free(saved);
    }
    const saved_count = app_state.shell_count;
    defer app_state.shell_count = saved_count;
    app_state.shell_count = 1;
    const sid = "11111111-1111-4111-8111-111111111111";
    app_state.shells[0] = makeTestLiveShell(10, 1, claude_agent, "live-a", sid);

    const Fake = struct {
        var reply: []const u8 = "";
        fn send(_: SessionIdentity, _: []const u8, out: *std.ArrayList(u8)) bool {
            out.appendSlice(std.heap.page_allocator, reply) catch return false;
            return true;
        }
    };
    const identity = chat_session.chatFileIdentityForShell(0).checked() orelse return error.TestUnexpectedResult;

    Fake.reply = "{\"status\":\"refused\",\"reason\":\"unsupported_provider\"}";
    switch (switchChatWithTransport(identity, antigravity_agent, Fake.send)) {
        .refused => {},
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(claude_agent, app_state.shells[0].ai_agent);
    try std.testing.expectEqualStrings(sid, app_state.shells[0].claude_sid[0..app_state.shells[0].claude_sid_len]);

    Fake.reply = "{\"status\":\"switched\",\"provider\":\"antigravity\",\"sid\":\"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee\"}";
    const outcome = switchChatWithTransport(identity, antigravity_agent, Fake.send);
    switch (outcome) {
        .switched => |done| {
            try std.testing.expect(applyAgentOnUi(&app_state.shells[0], done.agent, done.sid[0..done.sid_len]));
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(antigravity_agent, app_state.shells[0].ai_agent);
    try std.testing.expectEqualStrings("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee", app_state.shells[0].claude_sid[0..app_state.shells[0].claude_sid_len]);
}
