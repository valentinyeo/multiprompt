const std = @import("std");

pub const VaultGetResult = struct { revision: i64, envelope: []u8 };

pub fn parseVaultGetResponse(a: std.mem.Allocator, body: []const u8) !VaultGetResult {
    var parsed = try std.json.parseFromSlice(std.json.Value, a, body, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.Malformed;
    const revision = parsed.value.object.get("revision") orelse return error.Malformed;
    if (revision != .integer) return error.Malformed;
    const envelope = parsed.value.object.get("envelope") orelse return error.Malformed;
    if (envelope != .string or envelope.string.len == 0) return error.Malformed;
    return .{ .revision = revision.integer, .envelope = try a.dupe(u8, envelope.string) };
}

pub fn parseVaultPutRevision(a: std.mem.Allocator, body: []const u8) !i64 {
    var parsed = try std.json.parseFromSlice(std.json.Value, a, body, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return error.Malformed;
    const revision = parsed.value.object.get("revision") orelse return error.Malformed;
    if (revision != .integer) return error.Malformed;
    return revision.integer;
}

pub fn buildVaultPutBody(a: std.mem.Allocator, expected_revision: i64, envelope: []const u8) ![]u8 {
    var obj: std.json.ObjectMap = .empty;
    defer obj.deinit(a);
    try obj.put(a, "expectedRevision", .{ .integer = expected_revision });
    try obj.put(a, "envelope", .{ .string = envelope });
    const value = std.json.Value{ .object = obj };

    var out: std.Io.Writer.Allocating = .init(a);
    defer out.deinit();
    try std.json.Stringify.value(value, .{}, &out.writer);
    return a.dupe(u8, out.written());
}

pub const VaultAction = enum { create_new, unlock_with_passphrase };

pub fn decideVaultAction(remote_vault_exists: bool) VaultAction {
    return if (remote_vault_exists) .unlock_with_passphrase else .create_new;
}

test "parses a vault GET response" {
    const a = std.testing.allocator;
    const result = try parseVaultGetResponse(a, "{\"revision\":3,\"envelope\":\"{\\\"v\\\":1}\"}");
    defer a.free(result.envelope);
    try std.testing.expectEqual(@as(i64, 3), result.revision);
    try std.testing.expectEqualStrings("{\"v\":1}", result.envelope);
}

test "rejects a malformed vault GET response" {
    const a = std.testing.allocator;
    try std.testing.expectError(error.Malformed, parseVaultGetResponse(a, "{}"));
    try std.testing.expectError(error.Malformed, parseVaultGetResponse(a, "{\"revision\":\"3\",\"envelope\":\"x\"}"));
    try std.testing.expectError(error.SyntaxError, parseVaultGetResponse(a, "not json"));
}

test "parses the revision a vault PUT reports" {
    const a = std.testing.allocator;
    try std.testing.expectEqual(@as(i64, 2), try parseVaultPutRevision(a, "{\"revision\":2}"));
    try std.testing.expectEqual(@as(i64, 0), try parseVaultPutRevision(a, "{\"revision\":0}"));
    try std.testing.expectError(error.Malformed, parseVaultPutRevision(a, "{}"));
    try std.testing.expectError(error.Malformed, parseVaultPutRevision(a, "{\"revision\":\"1\"}"));
}

test "builds a vault PUT body with the expected fields and JSON-escapes the envelope" {
    const a = std.testing.allocator;
    const body = try buildVaultPutBody(a, 0, "{\"v\":1,\"note\":\"has \\\"quotes\\\"\"}");
    defer a.free(body);
    var parsed = try std.json.parseFromSlice(std.json.Value, a, body, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(i64, 0), parsed.value.object.get("expectedRevision").?.integer);
    try std.testing.expectEqualStrings("{\"v\":1,\"note\":\"has \\\"quotes\\\"\"}", parsed.value.object.get("envelope").?.string);
}

test "vault action decision follows remote existence" {
    try std.testing.expectEqual(VaultAction.create_new, decideVaultAction(false));
    try std.testing.expectEqual(VaultAction.unlock_with_passphrase, decideVaultAction(true));
}
