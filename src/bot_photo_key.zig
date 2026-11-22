const std = @import("std");

pub const Key = union(enum) {
    remote: struct { host: u8, session: []const u8 },
    local: [16]u8,

    pub fn digest(self: Key) ?[32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("ZigShell bot avatar v1\x00");
        switch (self) {
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
