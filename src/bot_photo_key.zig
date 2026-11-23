const std = @import("std");

pub fn chatId(sid: []const u8, session: []const u8) ?[32]u8 {
    return normalizeId(sid) orelse if (session.len == 37 and std.mem.startsWith(u8, session, "live-")) normalizeId(session[5..]) else null;
}

fn normalizeId(value: []const u8) ?[32]u8 {
    if (value.len != 32 and value.len != 36) return null;
    var id: [32]u8 = undefined;
    var n: usize = 0;
    for (value, 0..) |c, i| {
        if (value.len == 36 and (i == 8 or i == 13 or i == 18 or i == 23)) {
            if (c != '-') return null;
            continue;
        }
        if (!std.ascii.isHex(c) or n >= id.len) return null;
        id[n] = std.ascii.toLower(c);
        n += 1;
    }
    return if (n == id.len) id else null;
}

pub const Key = union(enum) {
    chat: [32]u8,
    remote: struct { host: u8, session: []const u8 },
    local: [16]u8,

    pub fn digest(self: Key) ?[32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("ZigShell bot avatar v1\x00");
        switch (self) {
            .chat => |id| {
                hash.update("chat\x00");
                hash.update(&id);
            },
            .remote => |remote| {
                if (remote.session.len == 0) return null;
                hash.update("remote\x00");
                hash.update(&.{remote.host});
                for (remote.session) |c| {
                    const lower = std.ascii.toLower(c);
                    hash.update(&.{lower});
                }
            },
            .local => |id| {
                if (std.mem.allEqual(u8, &id, 0)) return null;
                hash.update("local\x00");
                hash.update(&id);
            },
        }
        var result: [32]u8 = undefined;
        hash.final(&result);
        return result;
    }
};

test "remote avatar keys follow host and case insensitive session identity" {
    const a = (Key{ .remote = .{ .host = 1, .session = "My-Bot" } }).digest().?;
    const b = (Key{ .remote = .{ .host = 1, .session = "my-bot" } }).digest().?;
    const other_host = (Key{ .remote = .{ .host = 2, .session = "my-bot" } }).digest().?;
    const other_session = (Key{ .remote = .{ .host = 1, .session = "other" } }).digest().?;
    try std.testing.expectEqualSlices(u8, &a, &b);
    try std.testing.expect(!std.mem.eql(u8, &a, &other_host));
    try std.testing.expect(!std.mem.eql(u8, &a, &other_session));
    try std.testing.expect((Key{ .remote = .{ .host = 1, .session = "" } }).digest() == null);
}

test "remote avatar digest matches cross-device vectors" {
    const first = (Key{ .remote = .{ .host = 1, .session = "My-Bot" } }).digest().?;
    const second = (Key{ .remote = .{ .host = 0, .session = "chief-of-staff" } }).digest().?;
    try std.testing.expectEqualStrings("7fb158a6819a5e497a67662c60c7837ffbd327627773fd876686c60f93d88d5a", &std.fmt.bytesToHex(first, .lower));
    try std.testing.expectEqualStrings("44b6ce7ad143b0f7a96b98865d4055b049f45518e19e9b4753e8a2f6ee121b06", &std.fmt.bytesToHex(second, .lower));
}

test "local avatar keys are isolated and require an identity" {
    const first = (Key{ .local = [_]u8{1} ** 16 }).digest().?;
    const second = (Key{ .local = [_]u8{2} ** 16 }).digest().?;
    const remote = (Key{ .remote = .{ .host = 1, .session = "\x01" ** 16 } }).digest().?;
    try std.testing.expect(!std.mem.eql(u8, &first, &second));
    try std.testing.expect(!std.mem.eql(u8, &first, &remote));
    try std.testing.expect((Key{ .local = [_]u8{0} ** 16 }).digest() == null);
}


test "MUBO-244 canonical chat keys match the shared digest and reject partial aliases" {
    const sid = "11111111-2222-4333-8444-555555555555";
    const compact = "11111111222243338444555555555555";
    const id = chatId(sid, "old-runner").?;
    try std.testing.expectEqualStrings(compact, &id);
    try std.testing.expectEqual(id, chatId("", "live-" ++ compact).?);
    try std.testing.expectEqual(id, chatId("invalid", "live-" ++ compact).?);
    try std.testing.expectEqual(chatId("ABCDEF01-2222-4333-8444-555555555555", "").?, chatId("abcdef01222243338444555555555555", "").?);
    const digest = (Key{ .chat = id }).digest().?;
    try std.testing.expectEqualStrings("e675a29f53a92c0b3b809cf2d0c8ce652f1def6483829a4547ab8f143d7c2576", &std.fmt.bytesToHex(digest, .lower));
    for ([_][]const u8{ "old-runner", "live-short", "live-1111111122224333844455555555555g", "live-h" ++ compact }) |name| try std.testing.expect(chatId("", name) == null);
}
