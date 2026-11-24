const std = @import("std");

pub const Phase = enum { connected, disconnected, reconnecting, ended, closed };

pub fn backoffMs(attempt: u8, jitter: u64) u64 {
    const base = @min(@as(u64, 1000) << @as(u6, @intCast(@min(attempt, 5))), 30_000);
    return @min(base + jitter % (base / 4 + 1), 30_000);
}

pub fn eventEffects(is_active: bool) struct { invalidate_content: bool, relayout: bool, focus: bool } {
    return .{ .invalidate_content = is_active, .relayout = false, .focus = false };
}

pub const State = struct {
    phase: Phase = .connected,
    attempts: u8 = 0,
    awaiting_probe: bool = false,
    create_session: bool = false,
    healthy_attach: bool = false,
    gone_results: u8 = 0,
    next_tick: u64 = 0,
    delay_ms: u64 = 0,
    veto_until: ?u64 = null,
    disconnect_since: ?u64 = null,
    disconnect_reason: ?enum { exited, missing, timeout, detached, spawn } = null,

    pub fn confirmDisconnect(self: *State, now: u64, reason: []const u8, process_alive: bool) void {
        if (self.phase == .closed) return;
        const confirmed: @TypeOf(self.disconnect_reason) = if (std.mem.eql(u8, reason, "tmux-detached"))
            .detached
        else if (std.mem.eql(u8, reason, "attach-timeout"))
            .timeout
        else if (std.mem.eql(u8, reason, "spawn-failed") or std.mem.eql(u8, reason, "restore-spawn-failed"))
            .spawn
        else if (!process_alive and (std.mem.eql(u8, reason, "process-exit-event") or std.mem.eql(u8, reason, "process-exit-poll")))
            .exited
        else if (!process_alive and !std.mem.eql(u8, reason, "probe-unreachable"))
            .missing
        else
            null;
        if (confirmed) |cause| {
            if (self.disconnect_since == null) self.disconnect_since = now;
            if (self.disconnect_reason == null or cause != .missing) self.disconnect_reason = cause;
        }
    }

    pub fn noticeReason(self: State, now: u64, disconnected: bool) ?[]const u8 {
        if (!disconnected or self.phase != .disconnected or self.attempts == 0) return null;
        const since = self.disconnect_since orelse return null;
        if (now -| since < 10_000) return null;
        return switch (self.disconnect_reason orelse return null) {
            .exited => "SSH exited",
            .missing => "SSH process missing",
            .timeout => "attach timed out",
            .detached => "remote session detached",
            .spawn => "SSH could not start",
        };
    }

    pub fn lost(self: *State, now: u64, jitter: u64) void {
        if (self.phase == .closed or self.phase == .ended or self.phase == .disconnected) return;
        self.phase = .disconnected;
        self.delay_ms = backoffMs(self.attempts, jitter);
        self.next_tick = now + self.delay_ms;
    }

    pub fn networkVeto(self: *State, now: u64, connected: bool) bool {
        if (connected) return false;
        if (self.veto_until == null) self.veto_until = now + self.delay_ms;
        return now < self.veto_until.?;
    }

    pub fn due(self: State, now: u64) bool {
        return self.phase == .disconnected and !self.awaiting_probe and now >= self.next_tick;
    }

    pub fn start(self: *State) void {
        if (self.phase == .closed or self.phase == .ended) return;
        self.phase = .reconnecting;
        self.attempts +|= 1;
        self.veto_until = null;
    }

    pub fn manual(self: *State, now: u64) void {
        if (self.phase == .closed or self.phase == .reconnecting) return;
        if (self.phase == .ended) self.create_session = true;
        self.awaiting_probe = false;
        self.phase = .disconnected;
        self.next_tick = now;
        self.delay_ms = 0;
    }

    pub fn ok(self: *State) void {
        if (self.phase == .closed or self.phase == .ended) return;
        self.* = .{ .healthy_attach = true };
    }

    pub fn observeGone(self: *State, gone: bool, process_alive: bool) bool {
        const eligible = self.phase != .reconnecting and !self.create_session and self.healthy_attach;
        self.gone_results = if (gone and eligible and !process_alive) self.gone_results +| 1 else 0;
        return self.gone_results >= 2;
    }

    pub fn end(self: *State) void {
        if (self.phase == .closed) return;
        self.phase = .ended;
        self.next_tick = 0;
        self.awaiting_probe = false;
    }

    pub fn close(self: *State) void {
        self.phase = .closed;
        self.next_tick = 0;
    }
};

pub fn attached(output: []const u8, session: []const u8) bool {
    var lines = std.mem.tokenizeAny(u8, output, "\r\n");
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, session)) return true;
    }
    return false;
}

pub fn sessionExists(output: []const u8, session: []const u8) bool {
    var lines = std.mem.tokenizeAny(u8, output, "\r\n");
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "@@S ") and std.mem.eql(u8, line[4..], session)) return true;
    }
    return false;
}

pub fn sessionGone(output: []const u8, session: []const u8, ssh_ok: bool, exit_code: u32) bool {
    return ssh_ok and exit_code == 0 and attached(output, "@@MP_LIVE@@") and attached(output, "@@LS_OK@@") and !sessionExists(output, session);
}

test "ISSUE-521 reconnect effects only invalidate active content and never layout or focus" {
    for ([_]bool{ false, true }) |is_active| {
        const effects = eventEffects(is_active);
        try std.testing.expectEqual(is_active, effects.invalidate_content);
        try std.testing.expect(!effects.relayout);
        try std.testing.expect(!effects.focus);
    }
}

test "ISSUE-521 session gone requires successful complete probe and exact session names" {
    const output = "work\r\n@@S work-long\r\n@@S other\n@@LS_OK@@\n@@MP_LIVE@@\n";
    try std.testing.expect(sessionGone(output, "work", true, 0));
    try std.testing.expect(!sessionGone(output, "work-long", true, 0));
    try std.testing.expect(!sessionGone(output, "work", false, 0));
    try std.testing.expect(!sessionGone(output, "work", true, 255));
    try std.testing.expect(!sessionGone("@@S other\n", "work", true, 0));
    try std.testing.expect(!sessionGone("banner @@MP_LIVE@@\n", "work", true, 0));
    try std.testing.expect(!sessionGone("", "work", false, 1));
    try std.testing.expect(!sessionGone("@@MP_LIVE@@\n", "work", true, 0));
    try std.testing.expect(sessionGone("@@LS_OK@@\n@@MP_LIVE@@\n", "work", true, 0));
    try std.testing.expect(!sessionGone("@@S work\n@@MP_LIVE@@\n", "work", true, 0));
}

test "ISSUE-521 ended tabs never reconnect until explicit new session request" {
    var state: State = .{};
    state.end();
    state.lost(100, 1);
    state.start();
    state.ok();
    try std.testing.expectEqual(Phase.ended, state.phase);
    try std.testing.expect(!state.due(std.math.maxInt(u64)));
    state.manual(200);
    try std.testing.expect(state.create_session);
    try std.testing.expect(state.due(200));
    state.start();
    state.ok();
    try std.testing.expect(!state.create_session);
    state.lost(300, 0);
    state.awaiting_probe = true;
    try std.testing.expect(!state.due(std.math.maxInt(u64)));
    state.awaiting_probe = false;
    try std.testing.expect(state.due(std.math.maxInt(u64)));
}

pub fn probeMisses(previous: u8, ok: bool) u8 {
    return if (ok) 0 else previous +| 1;
}

pub fn probeUnreachable(misses: u8, process_alive: bool) bool {
    return misses >= 3 and !process_alive;
}

test "ISSUE-511 probe misses count per result reset on success and saturate" {
    var misses: u8 = 0;
    for (1..4) |expected| {
        misses = probeMisses(misses, false);
        try std.testing.expectEqual(@as(u8, @intCast(expected)), misses);
    }
    try std.testing.expectEqual(@as(u8, 0), probeMisses(misses, true));
    try std.testing.expectEqual(@as(u8, 1), probeMisses(probeMisses(misses, true), false));
    try std.testing.expectEqual(std.math.maxInt(u8), probeMisses(std.math.maxInt(u8), false));
}

test "ISSUE-511 failed probes never override a live transport and require three misses" {
    for (0..256) |count| {
        const misses: u8 = @intCast(count);
        try std.testing.expect(!probeUnreachable(misses, true));
        try std.testing.expectEqual(count >= 3, probeUnreachable(misses, false));
    }
}

test "ISSUE-501 backoff grows caps bounds jitter and resets after success" {
    const bases = [_]u64{ 1000, 2000, 4000, 8000, 16000, 30000, 30000 };
    for (bases, 0..) |base, i| {
        try std.testing.expectEqual(base, backoffMs(@intCast(i), 0));
        for (0..1000) |seed| {
            const delay = backoffMs(@intCast(i), seed);
            try std.testing.expect(delay >= base and delay <= @min(base + base / 4, 30000));
        }
    }
    var state: State = .{ .attempts = 9, .phase = .reconnecting };
    state.ok();
    state.lost(500, 0);
    try std.testing.expectEqual(@as(u64, 1500), state.next_tick);
    try std.testing.expectEqual(@as(u8, 0), state.attempts);
}

test "ISSUE-501 exits and silent loss schedule reconnect and manual skips wait closed stops" {
    for (0..2) |_| {
        var state: State = .{};
        state.lost(100, 0);
        try std.testing.expectEqual(Phase.disconnected, state.phase);
        try std.testing.expect(!state.due(1099));
        try std.testing.expect(state.due(1100));
        state.start();
        try std.testing.expectEqual(Phase.reconnecting, state.phase);
        state.lost(1200, 0);
        state.manual(1201);
        try std.testing.expect(state.due(1201));
        state.start();
        state.ok();
        try std.testing.expectEqual(Phase.connected, state.phase);
        state.close();
        state.lost(2000, 0);
        state.manual(2000);
        state.start();
        state.ok();
        try std.testing.expectEqual(Phase.closed, state.phase);
        try std.testing.expect(!state.due(std.math.maxInt(u64)));
    }
}

test "ISSUE-501 attachment probe distinguishes detached and exact session names" {
    try std.testing.expect(attached("work\r\nother\n", "work"));
    try std.testing.expect(!attached("work-long\n", "work"));
    try std.testing.expect(!attached("", "work"));
}

test "ISSUE-512 only a confirmed loss surviving debounce and a reconnect attempt can warn" {
    var state: State = .{};
    state.lost(0, 0);
    try std.testing.expect(state.noticeReason(60_000, true) == null);
    state.confirmDisconnect(0, "process-exit-event", false);
    try std.testing.expect(state.noticeReason(10_000, true) == null);
    state.start();
    try std.testing.expect(state.noticeReason(60_000, true) == null);
    state.lost(500, 0);
    try std.testing.expect(state.noticeReason(9999, true) == null);
    try std.testing.expectEqualStrings("SSH exited", state.noticeReason(10_000, true).?);
    try std.testing.expect(state.noticeReason(10_000, false) == null);
    state.confirmDisconnect(11_000, "process-exit-poll", false);
    try std.testing.expectEqual(@as(?u64, 0), state.disconnect_since);
    try std.testing.expectEqualStrings("SSH exited", state.noticeReason(11_000, true).?);
}

test "ISSUE-512 live transport and failed health probes never confirm a notice" {
    for ([_][]const u8{ "probe-unreachable", "process-exit-event", "console-missing", "power-resume", "time-change" }) |reason| {
        var state: State = .{};
        state.confirmDisconnect(100, reason, true);
        state.lost(100, 0);
        state.start();
        state.lost(200, 0);
        try std.testing.expect(state.noticeReason(60_000, true) == null);
    }
}

test "ISSUE-512 recovery cancels pending and visible warnings and a new loss gets a fresh debounce" {
    for ([_]u64{ 500, 20_000 }) |recovered_at| {
        var state: State = .{};
        state.confirmDisconnect(100, "tmux-detached", true);
        state.lost(100, 0);
        state.start();
        state.lost(200, 0);
        state.ok();
        try std.testing.expect(state.noticeReason(recovered_at, true) == null);
        try std.testing.expect(state.disconnect_since == null);
        state.confirmDisconnect(recovered_at, "attach-timeout", true);
        state.lost(recovered_at, 0);
        state.start();
        state.lost(recovered_at + 100, 0);
        try std.testing.expect(state.noticeReason(recovered_at + 9999, true) == null);
        try std.testing.expectEqualStrings("attach timed out", state.noticeReason(recovered_at + 10_000, true).?);
    }
}

test "ISSUE-512 confirmed failures explain their cause and manual retry still skips backoff" {
    const cases = .{
        .{ "process-exit-poll", false, "SSH exited" },
        .{ "process-missing-poll", false, "SSH process missing" },
        .{ "tmux-detached", true, "remote session detached" },
        .{ "attach-timeout", true, "attach timed out" },
        .{ "spawn-failed", false, "SSH could not start" },
        .{ "restore-spawn-failed", false, "SSH could not start" },
    };
    inline for (cases) |case| {
        var state: State = .{};
        state.confirmDisconnect(100, case[0], case[1]);
        state.lost(100, 0);
        state.start();
        state.lost(200, 0);
        state.confirmDisconnect(300, "console-missing", false);
        try std.testing.expectEqualStrings(case[2], state.noticeReason(10_100, true).?);
        state.manual(10_101);
        try std.testing.expect(state.due(10_101));
        state.start();
        try std.testing.expect(state.noticeReason(10_101, true) == null);
        state.close();
        state.confirmDisconnect(20_000, "spawn-failed", false);
        state.manual(20_000);
        try std.testing.expect(!state.due(20_000));
        try std.testing.expect(state.noticeReason(20_000, true) == null);
    }
}

test "ISSUE-511 gone requires two consecutive results and never overrides a live transport" {
    var state: State = .{ .healthy_attach = true };
    try std.testing.expect(!state.observeGone(true, false));
    try std.testing.expect(!state.observeGone(false, false));
    try std.testing.expect(!state.observeGone(true, false));
    try std.testing.expect(!state.observeGone(true, true));
    try std.testing.expectEqual(@as(u8, 0), state.gone_results);
    try std.testing.expect(!state.observeGone(true, false));
    try std.testing.expect(state.observeGone(true, false));
}

test "ISSUE-511 creating reconnecting and never attached tabs cannot be gone" {
    for ([_]State{ .{}, .{ .phase = .reconnecting, .healthy_attach = true }, .{ .create_session = true, .healthy_attach = true } }) |initial| {
        var state = initial;
        for (0..4) |_| try std.testing.expect(!state.observeGone(true, false));
        state.ok();
        try std.testing.expect(!state.observeGone(true, false));
        try std.testing.expect(state.observeGone(true, false));
    }
}
