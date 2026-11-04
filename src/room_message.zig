const std = @import("std");

pub const Binding = struct { alias: []const u8, id: []const u8 };
pub const Plan = struct {
    aliases: [64][]const u8 = undefined,
    alias_count: usize = 0,
    targets: [64][]const u8 = undefined,
    target_count: usize = 0,

    pub fn recipients(self: *const Plan) []const []const u8 {
        return self.aliases[0..self.alias_count];
    }
};

fn aliasChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '-';
}

pub fn plan(text: []const u8, members: []const Binding) !Plan {
    if (text.len == 0 or text.len > 65536 or !std.unicode.utf8ValidateSlice(text) or std.mem.indexOfScalar(u8, text, 0) != null or std.mem.trim(u8, text, " \t\r\n").len == 0 or members.len == 0 or members.len > 64) return error.InvalidMessage;
    var result: Plan = .{};
    var pos: usize = 0;
    while (pos < text.len) : (pos += 1) {
        if (text[pos] != '@') continue;
        if (pos > 0) {
            const previous = text[pos - 1];
            if (aliasChar(previous) or previous >= 128 or previous == '@' or previous == '.' or previous == '\\' or previous == '+') continue;
        }
        const start = pos + 1;
        var end = start;
        while (end < text.len and aliasChar(text[end])) : (end += 1) {}
        if (start == end) return error.InvalidMention;
        const alias = text[start..end];
        var found: ?[]const u8 = null;
        for (members) |member| if (std.mem.eql(u8, member.alias, alias)) {
            if (found != null) return error.InvalidMembers;
            found = member.id;
        };
        const id = found orelse return error.InvalidMention;
        var known = false;
        for (result.recipients()) |old| if (std.mem.eql(u8, old, alias)) {
            known = true;
            break;
        };
        if (!known) {
            if (result.alias_count == result.aliases.len) return error.InvalidMention;
            result.aliases[result.alias_count] = alias;
            result.alias_count += 1;
            result.targets[result.target_count] = id;
            result.target_count += 1;
        }
        pos = end - 1;
    }
    if (result.alias_count == 0) {
        for (members) |member| {
            result.targets[result.target_count] = member.id;
            result.target_count += 1;
        }
    }
    return result;
}

test "unaddressed room messages reach every member" {
    const members = [_]Binding{ .{ .alias = "alpha", .id = "a" }, .{ .alias = "beta", .id = "b" } };
    const result = try plan("Agree on the next step", &members);
    try std.testing.expectEqual(@as(usize, 0), result.alias_count);
    try std.testing.expectEqual(@as(usize, 2), result.target_count);
    try std.testing.expectEqualStrings("a", result.targets[0]);
    try std.testing.expectEqualStrings("b", result.targets[1]);
}

test "room mentions select only named members and deduplicate" {
    const members = [_]Binding{ .{ .alias = "alpha", .id = "a" }, .{ .alias = "beta", .id = "b" } };
    const result = try plan("(@beta), ask @beta again", &members);
    try std.testing.expectEqual(@as(usize, 1), result.alias_count);
    try std.testing.expectEqualStrings("beta", result.aliases[0]);
    try std.testing.expectEqual(@as(usize, 1), result.target_count);
    try std.testing.expectEqualStrings("b", result.targets[0]);
    try std.testing.expectError(error.InvalidMention, plan("@unknown reply", &members));
    try std.testing.expectError(error.InvalidMention, plan("@ reply", &members));
}

test "email and escaped at signs do not address a room member" {
    const members = [_]Binding{ .{ .alias = "alpha", .id = "a" }, .{ .alias = "beta", .id = "b" } };
    for ([_][]const u8{ "user@alpha", "\\@alpha", ".@alpha", "+@alpha", "-@alpha", "é@alpha" }) |text| {
        const result = try plan(text, &members);
        try std.testing.expectEqual(@as(usize, 0), result.alias_count);
        try std.testing.expectEqual(@as(usize, 2), result.target_count);
    }
    try std.testing.expectError(error.InvalidMention, plan("@@alpha", &members));
    try std.testing.expectError(error.InvalidMessage, plan("  \n", &members));
    try std.testing.expectError(error.InvalidMessage, plan("hello\x00", &members));
    try std.testing.expectError(error.InvalidMessage, plan("hello", &.{}));
}
