const std = @import("std");

pub const Phase = enum { connected, disconnected, reconnecting, closed };

pub fn backoffMs(attempt: u8, jitter: u64) u64 {
    const base = @min(@as(u64, 1000) << @as(u6, @intCast(@min(attempt, 5))), 30_000);
    return @min(base + jitter % (base / 4 + 1), 30_000);
}

pub const State = struct {
    phase: Phase = .connected,
    attempts: u8 = 0,
    next_tick: u64 = 0,
    delay_ms: u64 = 0,

    pub fn lost(self: *State, now: u64, jitter: u64) void {
        if (self.phase == .closed or self.phase == .disconnected) return;
        self.phase = .disconnected;
        self.delay_ms = backoffMs(self.attempts, jitter);
        self.next_tick = now + self.delay_ms;
    }

    pub fn due(self: State, now: u64) bool {
        return self.phase == .disconnected and now >= self.next_tick;
    }

    pub fn start(self: *State) void {
        if (self.phase == .closed) return;
        self.phase = .reconnecting;
        self.attempts +|= 1;
    }

    pub fn manual(self: *State, now: u64) void {
        if (self.phase == .closed) return;
        self.phase = .disconnected;
        self.next_tick = now;
        self.delay_ms = 0;
    }

    pub fn ok(self: *State) void {
        if (self.phase == .closed) return;
        self.* = .{};
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
