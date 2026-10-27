const std = @import("std");
const same = @import("tmux_identity.zig").same;

pub const Entry = struct {
    host: u8,
    name: [64]u8 = @splat(0),
    len: usize,

    pub fn jsonStringify(self: Entry, json: anytype) !void {
        try json.beginObject();
        try json.objectField("host");
        try json.write(self.host);
        try json.objectField("session");
        try json.write(self.name[0..self.len]);
        try json.endObject();
    }
};

pub const Closed = struct {
    restored: bool = false,
    entries: std.ArrayList(Entry) = .empty,

    pub fn contains(self: *const Closed, host: u8, name: []const u8) bool {
        for (self.entries.items) |entry| {
            if (same(entry.host, entry.name[0..entry.len], host, name)) return true;
        }
        return false;
    }

    pub fn close(self: *Closed, a: std.mem.Allocator, host: u8, name: []const u8) !void {
        if (name.len == 0 or self.contains(host, name)) return;
        var entry = Entry{ .host = host, .len = name.len };
        @memcpy(entry.name[0..name.len], name);
        try self.entries.append(a, entry);
    }

    pub fn reopen(self: *Closed, host: u8, name: []const u8) void {
        for (self.entries.items, 0..) |entry, i| {
            if (same(entry.host, entry.name[0..entry.len], host, name)) {
                _ = self.entries.orderedRemove(i);
                return;
            }
        }
    }

    pub fn restore(self: *Closed, a: std.mem.Allocator, value: std.json.Value) !void {
        self.restored = true;
        if (value != .array) return;
        records: for (value.array.items) |item| {
            if (item != .object) continue;
            const host = item.object.get("host") orelse continue;
            const session = item.object.get("session") orelse continue;
            if (host != .integer or host.integer < 0 or host.integer > 2 or session != .string or session.string.len > 63) continue;
            for (session.string) |c| {
                if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_' and c != '.' and c != ':') continue :records;
            }
            try self.close(a, @intCast(host.integer), session.string);
        }
    }
};

test "IGSH-1043 close intent outlives recent history and respects host identity" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    for (0..20) |i| {
        var name: [64]u8 = undefined;
        try closed.close(a, 0, try std.fmt.bufPrint(&name, "runner-{d}", .{i}));
    }
    try closed.close(a, 0, "runner-0");
    try std.testing.expectEqual(@as(usize, 20), closed.entries.items.len);
    try std.testing.expect(closed.contains(0, "runner-0"));
    try std.testing.expect(!closed.contains(1, "runner-0"));
    closed.reopen(0, "runner-0");
    try std.testing.expect(!closed.contains(0, "runner-0"));
    try std.testing.expect(closed.contains(0, "runner-1"));
}

test "IGSH-1043 saved close intent restores without erasing newer local closes" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    try closed.close(a, 2, "runner-one");
    const encoded = try std.json.Stringify.valueAlloc(a, closed.entries.items, .{});
    defer a.free(encoded);
    var parsed = try std.json.parseFromSlice(std.json.Value, a, encoded, .{});
    defer parsed.deinit();
    var restored = Closed{};
    defer restored.entries.deinit(a);
    try restored.close(a, 0, "newer-close");
    try restored.restore(a, parsed.value);
    try restored.restore(a, parsed.value);
    try std.testing.expect(restored.contains(2, "runner-one"));
    try std.testing.expect(restored.contains(0, "newer-close"));
    try std.testing.expectEqual(@as(usize, 2), restored.entries.items.len);
}

test "IGSH-1043 restored close intent validates host and native session names" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    var parsed = try std.json.parseFromSlice(std.json.Value, a, "[{\"host\":3,\"session\":\"wrong-host\"},{\"host\":0,\"session\":\"bad;command\"},{\"host\":1,\"session\":\"Runner.One\"}]", .{});
    defer parsed.deinit();
    try closed.restore(a, parsed.value);
    try std.testing.expectEqual(@as(usize, 1), closed.entries.items.len);
    try std.testing.expect(closed.contains(1, "runner.one"));
    closed.reopen(1, "RUNNER.ONE");
    try std.testing.expectEqual(@as(usize, 0), closed.entries.items.len);
}
