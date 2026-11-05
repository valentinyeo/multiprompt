const std = @import("std");
const account_keys = @import("account_keys.zig");
const account_hosts = @import("account_hosts.zig");
const app_state = struct {
    const SSH_TARGET_DE = "alpha";
    const SSH_TARGET_UK = "beta";
    const SSH_TARGET_INNE = "gamma";
};
const AccountJobKind = enum { pull, device_keys, decide_keys };
const AccountJob = struct { kind: AccountJobKind, edited: ?[]const u8 = null };
const LayoutReply = struct { job: AccountJob, bytes: ?[]const u8 = null, device_keys: ?[]const u8 = null, key_error: ?[]const u8 = null };
var g_account_hosts_cache = .{ .hosts = &[_]account_hosts.Host{
    .{ .slot = 0, .name = "First server", .hostname = "alpha.example", .port = 22, .user = "user" },
    .{ .slot = 1, .name = "Friendly server", .hostname = "beta.example", .port = 22, .user = "user" },
    .{ .slot = 2, .name = "Third server", .hostname = "gamma.example", .port = 22, .user = "user" },
} };
var g_account_keys_cache = .{ .last_check_ms = @as(?u64, null) };
var down: u8 = 0;
var attempts: u8 = 0;
var posts: u8 = 0;
var attempts_at_post: u8 = 0;
var post_status: u16 = 200;
var fail_second_post = false;
var second_down: ?u8 = null;
var revoked = false;
var escaped_removal = false;
var stored: ?[]const u8 = null;
const aliases = [_][]const u8{ "alpha", "beta", "gamma" };
const decision_yes = "[{\"device_id\":\"other\",\"public_key\":\"ssh-ed25519 AAAA\",\"approve\":true}]";
const decision_no = "[{\"device_id\":\"other\",\"public_key\":\"ssh-ed25519 AAAA\",\"approve\":false}]";
const decision_two = "[{\"device_id\":\"other\",\"public_key\":\"ssh-ed25519 AAAA\",\"approve\":true},{\"device_id\":\"second\",\"public_key\":\"ssh-ed25519 BBBB\",\"approve\":true}]";
const pending = "{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"other\",\"name\":\"Phone\",\"public_key\":\"ssh-ed25519 AAAA\",\"status\":\"pending\"},{\"device_id\":\"second\",\"name\":\"Tablet\",\"public_key\":\"ssh-ed25519 BBBB\",\"status\":\"pending\"}]}";
const removed = "{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"other\",\"name\":\"Phone\",\"public_key\":\"ssh-ed25519 AAAA\",\"status\":\"revoked\"}]}";
fn GetTickCount64() u64 { return 1000000; }
fn debugLog2(_: []const u8, _: []const u8) void {}
fn accountPublishDeviceKey(_: std.mem.Allocator, _: []const u8, _: []const u8, _: AccountJobKind) anyerror!void {}
fn accountKnownKeyHosts(_: std.mem.Allocator, _: []const u8, _: *LayoutReply) ![]const []const u8 { return &aliases; }
fn accountSshOutput(_: std.mem.Allocator, command: []const u8, _: u32) ![]const u8 {
    if (std.mem.indexOf(u8, command, "\\\"$tmp\\\"") != null) escaped_removal = true;
    for (aliases, 0..) |alias, i| {
        const needle = switch (i) { 0 => " alpha ", 1 => " beta ", else => " gamma " };
        _ = alias;
        if (std.mem.indexOf(u8, command, needle) != null) {
            attempts |= @as(u8, 1) << @intCast(i);
            const failures = if (posts > 0) second_down orelse down else down;
            if ((failures & (@as(u8, 1) << @intCast(i))) != 0) return error.Unreachable;
            return "";
        }
    }
    return error.BadCommand;
}
const account_client = struct {
    const Response = struct { status: u16, bytes: []const u8, fn deinit(_: @This()) void {} };
    fn request(method: []const u8, _: []const u8, _: []const u8, _: []const u8) !Response {
        if (std.mem.eql(u8, method, "POST")) { posts += 1; attempts_at_post = attempts; return .{ .status = if (fail_second_post and posts == 2) 500 else post_status, .bytes = "" }; }
        return .{ .status = 200, .bytes = if (revoked) removed else pending };
    }
};
fn readDpapiFile(_: []const u8, _: usize) ?[]const u8 { return if (stored) |s| std.heap.page_allocator.dupe(u8, s) catch unreachable else null; }
fn writeDpapiFile(_: []const u8, bytes: []const u8) bool {
    if (stored) |s| std.heap.page_allocator.free(s);
    stored = std.heap.page_allocator.dupe(u8, bytes) catch unreachable;
    return true;
}
fn reset() void {
    down = 0; attempts = 0; posts = 0; attempts_at_post = 0; post_status = 200; fail_second_post = false; second_down = null; revoked = false; escaped_removal = false;
    g_account_keys_cache.last_check_ms = null;
    if (stored) |s| std.heap.page_allocator.free(s);
    stored = null;
}
fn freeReply(reply: LayoutReply) void {
    if (reply.bytes) |s| std.heap.page_allocator.free(s);
    if (reply.key_error) |s| std.heap.page_allocator.free(s);
    if (reply.device_keys) |s| std.heap.page_allocator.free(s);
}

test "IGSH-1636 partial names configured server" {
    reset(); down = 2;
    const job: AccountJob = .{ .kind = .decide_keys, .edited = decision_yes };
    var reply: LayoutReply = .{ .job = job }; defer freeReply(reply);
    try accountSyncDeviceKeys("", job, &reply);
    try std.testing.expectEqual(@as(u8, 7), attempts);
    try std.testing.expectEqual(@as(u8, 1), posts);
    try std.testing.expectEqual(@as(u8, 7), attempts_at_post);
    try std.testing.expect(reply.bytes != null);
    try std.testing.expect(std.mem.indexOf(u8, reply.bytes.?, "Phone approved on reachable servers. Could not reach: Friendly server") != null);
}
test "IGSH-1636 confirmed partial survives later API error" {
    reset(); down = 2; second_down = 4; fail_second_post = true;
    const job: AccountJob = .{ .kind = .decide_keys, .edited = decision_two };
    var reply: LayoutReply = .{ .job = job }; defer freeReply(reply);
    requestDeviceKeys(job, &reply);
    try std.testing.expectEqual(@as(u8, 2), posts);
    try std.testing.expect(reply.bytes == null);
    try std.testing.expect(reply.key_error != null);
    const message = reply.key_error.?;
    try std.testing.expect(std.mem.indexOf(u8, message, "Could not update device approvals") != null);
    try std.testing.expect(std.mem.indexOf(u8, message, "Phone approved on reachable servers. Could not reach: Friendly server") != null);
    try std.testing.expect(std.mem.indexOf(u8, message, "Tablet approved") == null);
    try std.testing.expect(std.mem.indexOf(u8, message, "Third server") == null);
}
test "IGSH-1636 two confirmed devices retain their own failed servers" {
    reset(); down = 2; second_down = 4;
    const job: AccountJob = .{ .kind = .decide_keys, .edited = decision_two };
    var reply: LayoutReply = .{ .job = job }; defer freeReply(reply);
    try accountSyncDeviceKeys("", job, &reply);
    try std.testing.expectEqual(@as(u8, 2), posts);
    try std.testing.expect(reply.bytes != null);
    const message = reply.bytes.?;
    try std.testing.expect(std.mem.indexOf(u8, message, "Phone approved on reachable servers. Could not reach: Friendly server") != null);
    try std.testing.expect(std.mem.indexOf(u8, message, "Tablet approved on reachable servers. Could not reach: Third server") != null);
}
test "IGSH-1636 all down cannot approve" {
    reset(); down = 7;
    const job: AccountJob = .{ .kind = .decide_keys, .edited = decision_yes };
    var reply: LayoutReply = .{ .job = job }; defer freeReply(reply);
    try std.testing.expectError(error.Process, accountSyncDeviceKeys("", job, &reply));
    try std.testing.expectEqual(@as(u8, 7), attempts);
    try std.testing.expectEqual(@as(u8, 0), posts);
    try std.testing.expect(std.mem.indexOf(u8, reply.key_error.?, "Friendly server") != null);
}
test "IGSH-1636 success and deny" {
    reset();
    const job: AccountJob = .{ .kind = .decide_keys, .edited = decision_yes };
    var reply: LayoutReply = .{ .job = job }; defer freeReply(reply);
    try accountSyncDeviceKeys("", job, &reply);
    try std.testing.expect(reply.bytes == null);
    try std.testing.expectEqual(@as(u8, 1), posts);
    reset();
    const deny: AccountJob = .{ .kind = .decide_keys, .edited = decision_no };
    var denied: LayoutReply = .{ .job = deny }; defer freeReply(denied);
    try accountSyncDeviceKeys("", deny, &denied);
    try std.testing.expectEqual(@as(u8, 0), attempts);
    try std.testing.expectEqual(@as(u8, 1), posts);
}
test "IGSH-1636 API error clears notice" {
    reset(); down = 2; post_status = 500;
    const job: AccountJob = .{ .kind = .decide_keys, .edited = decision_yes };
    var reply: LayoutReply = .{ .job = job }; defer freeReply(reply);
    requestDeviceKeys(job, &reply);
    try std.testing.expectEqual(@as(u8, 1), posts);
    try std.testing.expect(reply.bytes == null);
    try std.testing.expect(reply.key_error != null);
}
test "IGSH-1636 quiet revoked cleanup retries" {
    reset(); defer reset(); down = 2; revoked = true;
    const job: AccountJob = .{ .kind = .pull };
    var reply: LayoutReply = .{ .job = job }; defer freeReply(reply);
    try accountSyncDeviceKeys("", job, &reply);
    try std.testing.expect(reply.bytes == null and reply.key_error == null and stored == null);
    try std.testing.expectEqual(@as(u8, 7), attempts);
    try std.testing.expect(escaped_removal);
    down = 0; attempts = 0; g_account_keys_cache.last_check_ms = null;
    if (reply.device_keys) |s| std.heap.page_allocator.free(s);
    reply.device_keys = null;
    try accountSyncDeviceKeys("", job, &reply);
    try std.testing.expectEqual(@as(u8, 7), attempts);
    try std.testing.expect(stored != null);
}
