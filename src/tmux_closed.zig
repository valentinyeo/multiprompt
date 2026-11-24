const std = @import("std");
const builtin = @import("builtin");
const json_reader = @import("json_reader.zig");
const same = @import("tmux_identity.zig").same;

pub const Entry = struct {
    host: u8,
    name: [64]u8 = @splat(0),
    len: usize,
    face: ?u8 = null,
    color: ?u8 = null,
    closed_at: ?u64 = null,
    listed: bool = false,

    pub fn jsonStringify(self: Entry, json: anytype) !void {
        try json.beginObject();
        try json.objectField("host");
        try json.write(self.host);
        try json.objectField("session");
        try json.write(self.name[0..self.len]);
        if (self.face) |face| {
            try json.objectField("face");
            try json.write(face);
        }
        if (self.color) |color| {
            try json.objectField("color");
            try json.write(color);
        }
        if (self.closed_at) |closed_at| {
            try json.objectField("closed_at");
            try json.write(closed_at);
        }
        if (self.listed) {
            try json.objectField("listed");
            try json.write(true);
        }
        try json.endObject();
    }
};

pub const LayoutTab = struct { host: u8, session: []const u8 };

pub fn now() ?u64 {
    const seconds: u64 = switch (builtin.os.tag) {
        .windows => windowsSeconds(),
        .linux => linuxSeconds(),
        else => return null,
    };
    return if (seconds > 0) seconds else null;
}

fn windowsSeconds() u64 {
    const win = @import("win32.zig");
    var stamp: [2]win.DWORD = undefined;
    win.GetSystemTimeAsFileTime(&stamp);
    const ticks = (@as(u64, stamp[1]) << 32) | stamp[0];
    return (ticks / 10_000_000) -| 11_644_473_600;
}

fn linuxSeconds() u64 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(.REALTIME, &ts);
    return if (ts.sec > 0) @intCast(ts.sec) else 0;
}

pub const Closed = struct {
    restored: bool = false,
    entries: std.ArrayList(Entry) = .empty,

    pub fn contains(self: *const Closed, host: u8, name: []const u8) bool {
        for (self.entries.items) |entry| {
            if (same(entry.host, entry.name[0..entry.len], host, name)) return true;
        }
        return false;
    }

    pub fn close(self: *Closed, a: std.mem.Allocator, host: u8, name: []const u8, closed_at: ?u64) !void {
        if (name.len == 0 or self.contains(host, name)) return;
        var entry = Entry{ .host = host, .len = name.len, .closed_at = closed_at, .listed = closed_at != null };
        @memcpy(entry.name[0..name.len], name);
        try self.entries.append(a, entry);
    }

    pub fn reopenEverywhere(self: *Closed, name: []const u8) void {
        if (name.len == 0) return;
        var i = self.entries.items.len;
        while (i > 0) {
            i -= 1;
            const entry = self.entries.items[i];
            if (std.ascii.eqlIgnoreCase(entry.name[0..entry.len], name)) _ = self.entries.orderedRemove(i);
        }
    }

    pub fn hold(self: *Closed, a: std.mem.Allocator, host: u8, name: []const u8) void {
        if (name.len == 0) return;
        for (self.entries.items) |*entry| {
            if (!same(entry.host, entry.name[0..entry.len], host, name)) continue;
            entry.listed = true;
            if (entry.closed_at == null) entry.closed_at = now();
            return;
        }
        self.close(a, host, name, now()) catch {};
    }

    pub fn reconcile(self: *Closed, layout: []const LayoutTab) void {
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const entry = &self.entries.items[i];
            var listed = false;
            for (layout) |tab| {
                if (!same(entry.host, entry.name[0..entry.len], tab.host, tab.session)) continue;
                listed = true;
                break;
            }
            if (!listed) {
                entry.listed = false;
                i += 1;
                continue;
            }
            if (entry.closed_at == null or !entry.listed) {
                _ = self.entries.orderedRemove(i);
                continue;
            }
            i += 1;
        }
    }

    pub fn restore(self: *Closed, a: std.mem.Allocator, value: std.json.Value) !void {
        self.restored = true;
        if (value != .array) return;
        records: for (value.array.items) |item| {
            if (item != .object) continue;
            const host = item.object.get("host") orelse continue;
            const session = item.object.get("session") orelse continue;
            const slot = json_reader.unsigned(host, 256);
            if (slot > 2 or session != .string or session.string.len > 63) continue;
            for (session.string) |c| {
                if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_' and c != '.' and c != ':') continue :records;
            }
            if (!self.contains(@intCast(slot), session.string)) {
                const closed_at = json_reader.unsigned(json_reader.field(item, "closed_at"), 0);
                try self.close(a, @intCast(slot), session.string, if (closed_at > 0) closed_at else null);
                if (session.string.len > 0) {
                    const entry = &self.entries.items[self.entries.items.len - 1];
                    const face = json_reader.uintDefault(item, "face", 20);
                    const color = json_reader.uintDefault(item, "color", @import("session_layout.zig").color_count);
                    entry.face = if (face < 20) @intCast(face) else null;
                    entry.color = if (color < @import("session_layout.zig").color_count) @intCast(color) else null;
                    entry.listed = json_reader.boolTrue(item, "listed");
                }
            }
        }
    }
};

test "IGSH-1043 close intent outlives recent history and respects host identity" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    for (0..20) |i| {
        var name: [64]u8 = undefined;
        try closed.close(a, 0, try std.fmt.bufPrint(&name, "runner-{d}", .{i}), now());
    }
    try closed.close(a, 0, "runner-0", now());
    try std.testing.expectEqual(@as(usize, 20), closed.entries.items.len);
    try std.testing.expect(closed.contains(0, "runner-0"));
    try std.testing.expect(!closed.contains(1, "runner-0"));
    closed.reopenEverywhere("runner-0");
    try std.testing.expect(!closed.contains(0, "runner-0"));
    try std.testing.expect(closed.contains(0, "runner-1"));
}

test "IGSH-1043 saved close intent restores without erasing newer local closes" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    try closed.close(a, 2, "runner-one", now());
    const encoded = try std.json.Stringify.valueAlloc(a, closed.entries.items, .{});
    defer a.free(encoded);
    var parsed = try json_reader.parse(a, encoded);
    defer parsed.deinit();
    var restored = Closed{};
    defer restored.entries.deinit(a);
    try restored.close(a, 0, "newer-close", now());
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
    var parsed = try json_reader.parse(a, "[{\"host\":3,\"session\":\"wrong-host\"},{\"host\":0,\"session\":\"bad;command\"},{\"host\":1,\"session\":\"Runner.One\"}]");
    defer parsed.deinit();
    try closed.restore(a, parsed.value);
    try std.testing.expectEqual(@as(usize, 1), closed.entries.items.len);
    try std.testing.expect(closed.contains(1, "runner.one"));
    closed.reopenEverywhere("RUNNER.ONE");
    try std.testing.expectEqual(@as(usize, 0), closed.entries.items.len);
}

test "SOFT-3135 a chat moved to another server clears its closed entry on every host" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    try closed.close(a, 1, "chat-one", now());
    try std.testing.expect(closed.contains(1, "chat-one"));
    closed.reopenEverywhere("chat-one");
    try std.testing.expectEqual(@as(usize, 0), closed.entries.items.len);
    const layout = [_]LayoutTab{.{ .host = 1, .session = "chat-one" }};
    closed.reconcile(layout[0..]);
    try std.testing.expect(!closed.contains(1, "chat-one"));
    try closed.close(a, 0, "chat-two", now());
    try closed.close(a, 1, "chat-two", now());
    closed.reopenEverywhere("chat-two");
    try std.testing.expectEqual(@as(usize, 0), closed.entries.items.len);
}

test "SOFT-3135 a closed chat stays closed while the layout still lists it" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    try closed.close(a, 1, "chat-three", now());
    const layout = [_]LayoutTab{.{ .host = 1, .session = "chat-three" }};
    closed.reconcile(layout[0..]);
    closed.reconcile(layout[0..]);
    try std.testing.expect(closed.contains(1, "chat-three"));
    const encoded = try std.json.Stringify.valueAlloc(a, closed.entries.items, .{});
    defer a.free(encoded);
    var parsed = try json_reader.parse(a, encoded);
    defer parsed.deinit();
    var restored = Closed{};
    defer restored.entries.deinit(a);
    try restored.restore(a, parsed.value);
    restored.reconcile(layout[0..]);
    try std.testing.expect(restored.contains(1, "chat-three"));
}

test "SOFT-3135 a layout that adds a chat back after it left shows it again" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    try closed.close(a, 1, "chat-four", now());
    const before = [_]LayoutTab{.{ .host = 0, .session = "other-chat" }};
    closed.reconcile(before[0..]);
    try std.testing.expect(closed.contains(1, "chat-four"));
    const added = [_]LayoutTab{.{ .host = 1, .session = "chat-four" }};
    closed.reconcile(added[0..]);
    try std.testing.expect(!closed.contains(1, "chat-four"));
    try std.testing.expectEqual(@as(usize, 0), closed.entries.items.len);
}

test "SOFT-3135 untimed closes clear once the layout lists the same host" {
    const a = std.testing.allocator;
    var closed = Closed{};
    defer closed.entries.deinit(a);
    var parsed = try json_reader.parse(a, "[{\"host\":1,\"session\":\"chat-five\"},{\"host\":1,\"session\":\"chat-six\"}]");
    defer parsed.deinit();
    try closed.restore(a, parsed.value);
    const layout = [_]LayoutTab{.{ .host = 1, .session = "chat-five" }, .{ .host = 0, .session = "chat-six" }};
    closed.reconcile(layout[0..]);
    try std.testing.expect(!closed.contains(1, "chat-five"));
    try std.testing.expect(closed.contains(1, "chat-six"));
}
