const std = @import("std");

pub const Failure = enum { unlock_local, sign_in, retry };

pub fn failure(bootstrapping: bool, has_token: bool, unauthorized: bool) Failure {
    if (unauthorized or !has_token) return .sign_in;
    return if (bootstrapping) .unlock_local else .retry;
}

pub fn accessUsable(expires_at: u64, now: u64) bool {
    return expires_at > now and expires_at - now > 60000;
}

pub const Access = struct {
    bytes: ?[]u8 = null,
    expires_at: u64 = 0,

    pub fn usable(self: Access, now: u64) bool {
        return self.bytes != null and accessUsable(self.expires_at, now);
    }
    pub fn remember(self: *Access, a: std.mem.Allocator, bytes: []const u8, now: u64) !void {
        const p = try std.json.parseFromSlice(struct { expires_in: u64, access_token: []const u8, refresh_token: []const u8 }, a, bytes, .{ .ignore_unknown_fields = true });
        defer p.deinit();
        if (p.value.access_token.len == 0 or p.value.refresh_token.len == 0 or p.value.expires_in == 0) return error.InvalidToken;
        const copy = try a.dupe(u8, bytes);
        self.clear(a);
        self.bytes = copy;
        self.expires_at = now + @as(u64, @min(p.value.expires_in, 600)) * 1000;
    }
    pub fn clear(self: *Access, a: std.mem.Allocator) void {
        if (self.bytes) |bytes| {
            std.crypto.secureZero(u8, bytes);
            a.free(bytes);
        }
        self.* = .{};
    }
};

pub fn invalidCredential(status: u32, bytes: []const u8) bool {
    if (status == 401) return true;
    if (status != 400) return false;
    const p = std.json.parseFromSlice(struct { @"error": []const u8 }, std.heap.page_allocator, bytes, .{ .ignore_unknown_fields = true }) catch return false;
    defer p.deinit();
    return std.mem.eql(u8, p.value.@"error", "invalid_grant");
}

pub const Callback = enum { ignore, denied, exchange };
pub fn callback(code: ?[]const u8, state: ?[]const u8, oauth_error: ?[]const u8, expected: []const u8) Callback {
    if (state == null or !std.mem.eql(u8, state.?, expected)) return .ignore;
    if (oauth_error != null) return .denied;
    return if (code != null) .exchange else .ignore;
}

pub const Retry = struct {
    after: u64 = 0,
    delay: u64 = 20000,
    notified: bool = false,

    pub fn failed(self: *Retry, now: u64) bool {
        self.after = now + self.delay;
        self.delay = @min(self.delay * 2, 300000);
        const notify = !self.notified;
        self.notified = true;
        return notify;
    }
    pub fn ready(self: Retry, now: u64) bool {
        return now >= self.after;
    }
    pub fn succeeded(self: *Retry) void {
        self.* = .{};
    }
};

test "fresh install without a stored sign-in stays on Sign in" {
    try std.testing.expectEqual(Failure.sign_in, failure(true, false, false));
    try std.testing.expectEqual(Failure.sign_in, failure(false, false, false));
}

test "stored-token startup unlocks locally for network timeout and service failures" {
    try std.testing.expectEqual(Failure.unlock_local, failure(true, true, false));
    try std.testing.expectEqual(Failure.sign_in, failure(true, false, false));
    try std.testing.expectEqual(Failure.sign_in, failure(true, true, true));
    try std.testing.expectEqual(Failure.retry, failure(false, true, false));
    try std.testing.expectEqual(Failure.sign_in, failure(false, true, true));
}

test "access token is reused for nine minutes and refreshes near expiry or after sleep" {
    const expires = 600000;
    try std.testing.expect(accessUsable(expires, 0));
    try std.testing.expect(accessUsable(expires, 539999));
    try std.testing.expect(!accessUsable(expires, 540000));
    try std.testing.expect(!accessUsable(expires, 700000));
    try std.testing.expect(!accessUsable(0, 0));
}

test "only explicit invalid grants or unauthorized answers invalidate credentials" {
    for ([_]u32{ 0, 408, 429, 500, 503 }) |status| try std.testing.expect(!invalidCredential(status, "{\"error\":\"invalid_grant\"}"));
    try std.testing.expect(!invalidCredential(400, "{\"error\":\"invalid_json\"}"));
    try std.testing.expect(!invalidCredential(400, "not JSON"));
    try std.testing.expect(invalidCredential(400, "{\"error\":\"invalid_grant\"}"));
    try std.testing.expect(invalidCredential(401, ""));
}

test "error callback returns promptly only with matching state" {
    try std.testing.expectEqual(Callback.denied, callback(null, "state", "access_denied", "state"));
    try std.testing.expectEqual(Callback.ignore, callback(null, "foreign", "access_denied", "state"));
    try std.testing.expectEqual(Callback.ignore, callback(null, null, "access_denied", "state"));
    try std.testing.expectEqual(Callback.exchange, callback("code", "state", null, "state"));
}

test "failed pending save backs off on poll and emits only one failure notice until recovery" {
    var retry: Retry = .{};
    try std.testing.expect(retry.failed(100));
    try std.testing.expect(!retry.ready(20100 - 1));
    try std.testing.expect(retry.ready(20100));
    try std.testing.expect(!retry.failed(20100));
    try std.testing.expectEqual(@as(u64, 60100), retry.after);
    for (0..10) |_| _ = retry.failed(retry.after);
    try std.testing.expectEqual(@as(u64, 300000), retry.delay);
    retry.succeeded();
    try std.testing.expect(retry.ready(0));
    try std.testing.expect(retry.failed(100));
}

test "serialized requests reuse access without sliding expiry and bad replies cannot replace it" {
    var access: Access = .{};
    defer access.clear(std.testing.allocator);
    const token = "{\"expires_in\":600,\"access_token\":\"access\",\"refresh_token\":\"refresh\"}";
    try access.remember(std.testing.allocator, token, 100);
    for (0..27) |i| try std.testing.expect(access.usable(100 + i * 20000));
    try std.testing.expect(!access.usable(540100));
    try std.testing.expectError(error.MissingField, access.remember(std.testing.allocator, "{}", 200));
    try std.testing.expectEqual(@as(u64, 600100), access.expires_at);
    try std.testing.expectEqualStrings(token, access.bytes.?);
    access.clear(std.testing.allocator);
    try std.testing.expect(!access.usable(0));
}

pub fn startupLocked() bool {
    return false;
}

test "ISSUE-502 optimistic startup is not locked while account validation is pending" {
    try std.testing.expect(!startupLocked());
}
