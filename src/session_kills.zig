const std = @import("std");
const same = @import("tmux_identity.zig").same;

pub const CAPACITY = 8;
pub const Token = enum(u64) { _ };
pub const Outcome = enum { gone, retry, unsafe, cancelled };
pub const Entry = struct {
    token: Token,
    host: u8,
    session: [64]u8 = @splat(0),
    session_len: usize,
    sid: [40]u8 = @splat(0),
    sid_len: usize,
    phase: union(enum) { pending, running: ?*anyopaque } = .pending,
};

pub const Queue = struct {
    slots: [CAPACITY]?Entry = @splat(null),
    next_token: u64 = 1,

    pub fn add(self: *Queue, host: u8, session: []const u8, sid: []const u8) ?Token {
        if (session.len == 0 or session.len > 63 or sid.len > 40 or self.next_token == 0) return null;
        var free: ?usize = null;
        for (self.slots, 0..) |slot, i| {
            if (slot) |entry| {
                if (same(entry.host, entry.session[0..entry.session_len], host, session)) return entry.token;
            } else if (free == null) free = i;
        }
        const slot = free orelse return null;
        var entry = Entry{ .token = @enumFromInt(self.next_token), .host = host, .session_len = session.len, .sid_len = sid.len };
        self.next_token +%= 1;
        @memcpy(entry.session[0..session.len], session);
        @memcpy(entry.sid[0..sid.len], sid);
        self.slots[slot] = entry;
        return entry.token;
    }

    fn index(self: *const Queue, token: Token) ?usize {
        for (self.slots, 0..) |slot, i| {
            if (slot) |entry| if (entry.token == token) return i;
        }
        return null;
    }

    pub fn begin(self: *Queue, slot: usize) ?Entry {
        const entry = self.slots[slot] orelse return null;
        if (entry.phase != .pending) return null;
        self.slots[slot].?.phase = .{ .running = null };
        return self.slots[slot];
    }

    pub fn attach(self: *Queue, token: Token, process: *anyopaque) bool {
        const i = self.index(token) orelse return false;
        if (self.slots[i].?.phase != .running) return false;
        self.slots[i].?.phase = .{ .running = process };
        return true;
    }

    pub fn detach(self: *Queue, token: Token) bool {
        const i = self.index(token) orelse return false;
        if (self.slots[i].?.phase != .running) return false;
        self.slots[i].?.phase = .{ .running = null };
        return true;
    }

    pub fn finish(self: *Queue, token: Token, outcome: Outcome) void {
        const i = self.index(token) orelse return;
        if (outcome == .retry) {
            self.slots[i].?.phase = .pending;
        } else self.slots[i] = null;
    }

    pub fn cancel(self: *Queue, host: u8, session: []const u8) ?*anyopaque {
        for (self.slots, 0..) |slot, i| {
            const entry = slot orelse continue;
            if (!same(entry.host, entry.session[0..entry.session_len], host, session)) continue;
            self.slots[i] = null;
            return switch (entry.phase) { .pending => null, .running => |process| process };
        }
        return null;
    }
};

test "pending close is idempotent, host-specific, and retried until gone" {
    var queue = Queue{};
    const token = queue.add(0, "session-one", "chat-one").?;
    try std.testing.expectEqual(token, queue.add(0, "SESSION-ONE", "chat-one").?);
    const other = queue.add(1, "session-one", "chat-two").?;
    try std.testing.expect(other != token);
    const entry = queue.begin(0).?;
    try std.testing.expectEqual(token, entry.token);
    try std.testing.expect(queue.begin(0) == null);
    queue.finish(token, .retry);
    try std.testing.expectEqual(token, queue.begin(0).?.token);
    queue.finish(token, .gone);
    try std.testing.expect(queue.begin(0) == null);
    try std.testing.expectEqual(other, queue.begin(1).?.token);
}

test "reopening cancels queued and already-batched retries without resurrection" {
    var queue = Queue{};
    const queued = queue.add(0, "queued", "").?;
    _ = queue.cancel(0, "queued");
    queue.finish(queued, .retry);
    try std.testing.expect(queue.begin(0) == null);
    const running = queue.add(0, "running", "").?;
    _ = queue.begin(0).?;
    const process: *anyopaque = @ptrFromInt(7);
    try std.testing.expect(queue.attach(running, process));
    try std.testing.expectEqual(process, queue.cancel(0, "RUNNING").?);
    try std.testing.expect(!queue.detach(running));
    const reopened_close = queue.add(0, "running", "new-chat").?;
    try std.testing.expect(reopened_close != running);
    queue.finish(running, .retry);
    try std.testing.expectEqual(reopened_close, queue.begin(0).?.token);
    try std.testing.expect(!queue.attach(running, process));
}

test "cancellation before process registration cannot launch stale work" {
    var queue = Queue{};
    const token = queue.add(2, "connecting", "").?;
    _ = queue.begin(0).?;
    _ = queue.cancel(2, "connecting");
    try std.testing.expect(!queue.attach(token, @ptrFromInt(7)));
    queue.finish(token, .retry);
    try std.testing.expect(queue.begin(0) == null);
}

test "bounded queue preserves pending intents and frees cancelled slots" {
    var queue = Queue{};
    for (0..CAPACITY) |i| {
        var name: [32]u8 = undefined;
        _ = queue.add(0, try std.fmt.bufPrint(&name, "session-{d}", .{i}), "").?;
    }
    try std.testing.expect(queue.add(0, "full", "") == null);
    _ = queue.cancel(0, "session-0");
    try std.testing.expect(queue.add(0, "replacement", "") != null);
    try std.testing.expect(queue.add(0, "", "") == null);
}
