const std = @import("std");
const hosts = @import("account_hosts.zig");
const Allocator = std.mem.Allocator;

pub fn validKey(key: []const u8) bool {
    return key.len <= 200 and std.mem.startsWith(u8, key, "ssh-ed25519 ") and
        std.mem.indexOf(u8, key, "PRIVATE") == null and std.mem.indexOf(u8, key, "BEGIN") == null and hosts.validKey(key);
}

pub fn parsePublicKey(a: Allocator, bytes: []const u8) ![]const u8 {
    var fields = std.mem.tokenizeAny(u8, bytes, " \t\r\n");
    const kind = fields.next() orelse return error.InvalidKey;
    const data = fields.next() orelse return error.InvalidKey;
    const key = try std.fmt.allocPrint(a, "{s} {s}", .{ kind, data });
    errdefer a.free(key);
    if (!validKey(key)) return error.InvalidKey;
    return key;
}

pub const add_template = "umask 077 && mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && if awk -v t=ssh-ed25519 -v k='{s}' '$1 == t && $2 == k {{ found=1 }} END {{ exit found ? 0 : 3 }}' ~/.ssh/authorized_keys; then :; else r=$?; [ $r = 3 ] && printf '\\n%s\\n' '{s}' >> ~/.ssh/authorized_keys; fi";
pub const remove_template = "umask 077 && if [ -f ~/.ssh/authorized_keys ]; then tmp=$(mktemp ~/.ssh/authorized_keys.XXXXXX) && trap 'rm -f \"$tmp\"' EXIT && awk -v t=ssh-ed25519 -v k='{s}' '$1 != t || $2 != k' ~/.ssh/authorized_keys > \"$tmp\" && mv \"$tmp\" ~/.ssh/authorized_keys; fi";

pub fn addCommand(a: Allocator, key: []const u8) ![]const u8 {
    if (!validKey(key)) return error.InvalidKey;
    return std.fmt.allocPrint(a, add_template, .{ key[12..], key });
}

pub fn removeCommand(a: Allocator, key: []const u8) ![]const u8 {
    if (!validKey(key)) return error.InvalidKey;
    return std.fmt.allocPrint(a, remove_template, .{key[12..]});
}

pub const Status = enum { pending, approved, denied, revoked };
pub const Device = struct { device_id: []const u8, name: []const u8, public_key: []const u8, status: Status };
pub const Listing = struct { device_id: []const u8, keys: []const Device };
pub const Decision = struct { device_id: []const u8, public_key: []const u8, approve: bool };

pub const SyncPolicy = struct { check: bool, publish: bool, show_error: bool };

pub fn syncPolicy(job_kind: anytype, now_ms: u64, last_check_ms: ?u64, last_published_key: ?[]const u8, current_key: ?[]const u8) SyncPolicy {
    const explicit = job_kind == .device_keys;
    const decision = job_kind == .decide_keys;
    return .{
        .check = explicit or decision or last_check_ms == null or now_ms -| last_check_ms.? >= 5 * 60 * 1000,
        .publish = if (current_key) |key| explicit or last_published_key == null or !std.mem.eql(u8, last_published_key.?, key) else false,
        .show_error = explicit or decision,
    };
}

pub fn validDeviceId(id: []const u8) bool {
    if (id.len == 0 or id.len > 128) return false;
    for (id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') return false;
    return true;
}

pub fn parseListing(a: Allocator, bytes: []const u8) !std.json.Parsed(Listing) {
    const parsed = try std.json.parseFromSlice(Listing, a, bytes, .{ .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    if (!validDeviceId(parsed.value.device_id)) return error.InvalidDevice;
    for (parsed.value.keys) |key| {
        if (!validDeviceId(key.device_id) or !validKey(key.public_key)) return error.InvalidKey;
    }
    return parsed;
}

pub fn isCleaned(state: []const u8, key: []const u8) bool {
    var lines = std.mem.splitScalar(u8, state, '\n');
    while (lines.next()) |line| if (std.mem.eql(u8, line, key)) return true;
    return false;
}

test "public key parsing drops comments and normalizes whitespace" {
    const a = std.testing.allocator;
    const key = try parsePublicKey(a, "ssh-ed25519\tAAAA+/== multiprompt\r\n");
    defer a.free(key);
    try std.testing.expectEqualStrings("ssh-ed25519 AAAA+/==", key);
}

test "command builders reject invalid keys and cannot interpolate quotes or newlines" {
    const a = std.testing.allocator;
    for ([_][]const u8{ "", "ssh-rsa AAAA", "ssh-ed25519 ", "ssh-ed25519 A=A", "ssh-ed25519 AAA===", "ssh-ed25519 AAA'", "ssh-ed25519 AAA\"", "ssh-ed25519 AAA\n", "ssh-ed25519 AAA;id", "ssh-ed25519 BEGIN", "ssh-ed25519 PRIVATE" }) |key| {
        try std.testing.expectError(error.InvalidKey, addCommand(a, key));
        try std.testing.expectError(error.InvalidKey, removeCommand(a, key));
    }
    try std.testing.expectError(error.InvalidKey, parsePublicKey(a, "ssh-rsa AAAA comment"));
    try std.testing.expectError(error.InvalidKey, parsePublicKey(a, "ssh-ed25519 AA' comment"));
    const add = try addCommand(a, "ssh-ed25519 AAAA+/==");
    defer a.free(add);
    const remove = try removeCommand(a, "ssh-ed25519 AAAA+/==");
    defer a.free(remove);
    try std.testing.expect(std.mem.indexOfScalar(u8, add, '\n') == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, remove, '\n') == null);
    try std.testing.expect(std.mem.indexOf(u8, add, "$1 == t && $2 == k") != null);
    try std.testing.expect(std.mem.indexOf(u8, remove, "$1 != t || $2 != k") != null);
}

test "idempotent add compares key fields not comments and removal preserves other keys" {
    const a = std.testing.allocator;
    const add = try addCommand(a, "ssh-ed25519 AAAA");
    defer a.free(add);
    try std.testing.expectEqualStrings("umask 077 && mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && if awk -v t=ssh-ed25519 -v k='AAAA' '$1 == t && $2 == k { found=1 } END { exit found ? 0 : 3 }' ~/.ssh/authorized_keys; then :; else r=$?; [ $r = 3 ] && printf '\\n%s\\n' 'ssh-ed25519 AAAA' >> ~/.ssh/authorized_keys; fi", add);
    const remove = try removeCommand(a, "ssh-ed25519 AAAA");
    defer a.free(remove);
    try std.testing.expectEqualStrings("umask 077 && if [ -f ~/.ssh/authorized_keys ]; then tmp=$(mktemp ~/.ssh/authorized_keys.XXXXXX) && trap 'rm -f \"$tmp\"' EXIT && awk -v t=ssh-ed25519 -v k='AAAA' '$1 != t || $2 != k' ~/.ssh/authorized_keys > \"$tmp\" && mv \"$tmp\" ~/.ssh/authorized_keys; fi", remove);
}

test "listing accepts exact API shape and cleanup matches whole keys" {
    const listing = try parseListing(std.testing.allocator, "{\"device_id\":\"self\",\"keys\":[{\"device_id\":\"other\",\"name\":\"Laptop\",\"public_key\":\"ssh-ed25519 AAAA\",\"status\":\"pending\",\"requested\":1,\"decided\":null}]}");
    defer listing.deinit();
    try std.testing.expectEqual(Status.pending, listing.value.keys[0].status);
    try std.testing.expect(isCleaned("ssh-ed25519 AAAA\n", "ssh-ed25519 AAAA"));
    try std.testing.expect(!isCleaned("ssh-ed25519 AAAAB\n", "ssh-ed25519 AAAA"));
    try std.testing.expect(!validDeviceId("../other"));
}

test "public comments cannot inject into generated commands and oversized keys are rejected" {
    const a = std.testing.allocator;
    const key = try parsePublicKey(a, "ssh-ed25519 AAAA comment'\"; touch /tmp/unwanted\n");
    defer a.free(key);
    const add = try addCommand(a, key);
    defer a.free(add);
    const remove = try removeCommand(a, key);
    defer a.free(remove);
    try std.testing.expect(std.mem.indexOf(u8, add, "unwanted") == null);
    try std.testing.expect(std.mem.indexOf(u8, remove, "unwanted") == null);
    var oversized: [201]u8 = @splat('A');
    @memcpy(oversized[0..12], "ssh-ed25519 ");
    try std.testing.expectError(error.InvalidKey, addCommand(a, &oversized));
    try std.testing.expectError(error.InvalidKey, removeCommand(a, &oversized));
}

test "background device checks run initially and only every five minutes, including after Cancel or errors" {
    const Job = enum { startup, login, pull, push, device_keys, decide_keys };
    for ([_]Job{ .startup, .login, .pull, .push }) |job| {
        try std.testing.expect(syncPolicy(job, 0, null, null, null).check);
        try std.testing.expect(!syncPolicy(job, 300999, 1000, null, null).check);
        try std.testing.expect(syncPolicy(job, 301000, 1000, null, null).check);
        try std.testing.expect(syncPolicy(job, 301001, 1000, null, null).check);
        try std.testing.expect(!syncPolicy(job, 0, 1000, null, null).check);
        try std.testing.expect(!syncPolicy(job, 20000, 1000, null, null).show_error);
    }
}

test "explicit device checks and decisions bypass cadence and show errors" {
    const Job = enum { device_keys, decide_keys };
    for ([_]Job{ .device_keys, .decide_keys }) |job| {
        const policy = syncPolicy(job, 1001, 1000, "ssh-ed25519 AAAA", "ssh-ed25519 AAAA");
        try std.testing.expect(policy.check);
        try std.testing.expect(policy.show_error);
        try std.testing.expectEqual(job == .device_keys, policy.publish);
    }
}

test "publication is deduplicated after success but key changes and explicit palette checks republish" {
    const Job = enum { pull, device_keys, decide_keys };
    const key = "ssh-ed25519 AAAA";
    try std.testing.expect(syncPolicy(Job.pull, 0, null, null, key).publish);
    try std.testing.expect(!syncPolicy(Job.pull, 600000, 0, key, key).publish);
    try std.testing.expect(!syncPolicy(Job.decide_keys, 1, 0, key, key).publish);
    try std.testing.expect(syncPolicy(Job.pull, 1, 0, key, "ssh-ed25519 BBBB").publish);
    try std.testing.expect(syncPolicy(Job.device_keys, 1, 0, key, key).publish);
    try std.testing.expect(!syncPolicy(Job.device_keys, 1, 0, key, null).publish);
}
