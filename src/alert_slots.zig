const std = @import("std");

pub const hosts = 3;
pub const slots_per_host = 32;

const Slot = struct {
    id: u32 = 0,
    generation: u32 = 0,
    done: bool = false,
    payload: ?[]u8 = null,
};

pub const Ready = struct {
    id: u32,
    payload: ?[]u8,
};

pub const Table = struct {
    slots: [hosts][slots_per_host]Slot,
    generation: [hosts]u32,

    pub fn empty() Table {
        var table: Table = .{
            .slots = undefined,
            .generation = @splat(0),
        };
        for (&table.slots) |*row| row.* = @splat(.{});
        return table;
    }

    pub fn begin(self: *Table, allocator: std.mem.Allocator, host: u8) u32 {
        if (host >= hosts) return 0;
        self.drop(allocator, host, null);
        return self.bump(host);
    }

    pub fn end(self: *Table, allocator: std.mem.Allocator, host: u8, generation: u32) void {
        if (host >= hosts or generation == 0 or self.generation[host] != generation) return;
        self.drop(allocator, host, generation);
        _ = self.bump(host);
    }

    pub fn claim(self: *Table, host: u8, generation: u32, id: u32) bool {
        if (host >= hosts or id == 0 or generation == 0 or self.generation[host] != generation) return false;
        for (&self.slots[host]) |slot| {
            if (slot.id == id and slot.generation == generation) return false;
        }
        for (&self.slots[host]) |*slot| {
            if (slot.id != 0) continue;
            slot.* = .{ .id = id, .generation = generation };
            return true;
        }
        return false;
    }

    pub fn release(self: *Table, allocator: std.mem.Allocator, host: u8, generation: u32, id: u32) void {
        if (host >= hosts or id == 0 or generation == 0) return;
        for (&self.slots[host]) |*slot| {
            if (slot.id != id or slot.generation != generation) continue;
            if (slot.payload) |bytes| allocator.free(bytes);
            slot.* = .{};
            return;
        }
    }

    pub fn finish(self: *Table, allocator: std.mem.Allocator, host: u8, generation: u32, id: u32, payload: ?[]u8) void {
        if (host < hosts and id != 0 and generation != 0 and self.generation[host] == generation) {
            for (&self.slots[host]) |*slot| {
                if (slot.id != id or slot.generation != generation or slot.done) continue;
                slot.payload = payload;
                slot.done = true;
                return;
            }
        }
        if (payload) |bytes| allocator.free(bytes);
    }

    pub fn takeReady(self: *Table, host: u8, generation: u32) ?Ready {
        if (host >= hosts or generation == 0 or self.generation[host] != generation) return null;
        for (&self.slots[host]) |*slot| {
            if (slot.id == 0 or slot.generation != generation or !slot.done) continue;
            const ready = Ready{ .id = slot.id, .payload = slot.payload };
            slot.* = .{};
            return ready;
        }
        return null;
    }

    pub fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        for (0..hosts) |host| self.drop(allocator, @intCast(host), null);
    }

    fn bump(self: *Table, host: u8) u32 {
        self.generation[host] +%= 1;
        if (self.generation[host] == 0) self.generation[host] = 1;
        return self.generation[host];
    }

    fn drop(self: *Table, allocator: std.mem.Allocator, host: u8, generation: ?u32) void {
        for (&self.slots[host]) |*slot| {
            if (generation) |generation_id| {
                if (slot.generation != generation_id) continue;
            }
            if (slot.payload) |bytes| allocator.free(bytes);
            slot.* = .{};
        }
    }
};

fn own(allocator: std.mem.Allocator, text: []const u8) []u8 {
    return allocator.dupe(u8, text) catch unreachable;
}

fn expectReady(table: *Table, host: u8, generation: u32, id: u32, text: ?[]const u8) !void {
    const ready = table.takeReady(host, generation) orelse return error.MissingReply;
    defer if (ready.payload) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expectEqual(id, ready.id);
    if (text) |expected| {
        try std.testing.expectEqualStrings(expected, ready.payload orelse return error.EmptyReply);
    } else {
        try std.testing.expect(ready.payload == null);
    }
}

test "two servers keep the same call id apart" {
    const allocator = std.testing.allocator;
    var table = Table.empty();
    defer table.deinit(allocator);
    const left = table.begin(allocator, 0);
    const right = table.begin(allocator, 1);
    try std.testing.expect(table.claim(0, left, 1));
    try std.testing.expect(table.claim(1, right, 1));
    table.finish(allocator, 0, left, 1, own(allocator, "left"));
    table.finish(allocator, 1, right, 1, own(allocator, "right"));
    try expectReady(&table, 0, left, 1, "left");
    try expectReady(&table, 1, right, 1, "right");
    try std.testing.expect(table.takeReady(0, left) == null);
    try std.testing.expect(table.takeReady(1, right) == null);
}

test "a reply is not flushed to the other server when ids differ" {
    const allocator = std.testing.allocator;
    var table = Table.empty();
    defer table.deinit(allocator);
    const left = table.begin(allocator, 0);
    const right = table.begin(allocator, 1);
    try std.testing.expect(table.claim(0, left, 7));
    try std.testing.expect(table.claim(1, right, 8));
    table.finish(allocator, 1, right, 8, own(allocator, "right-eight"));
    try std.testing.expect(table.takeReady(0, left) == null);
    try expectReady(&table, 1, right, 8, "right-eight");
    table.finish(allocator, 0, left, 7, own(allocator, "left-seven"));
    try expectReady(&table, 0, left, 7, "left-seven");
    try std.testing.expect(table.takeReady(1, right) == null);
}

test "replies leave in completion order on the server that owns them" {
    const allocator = std.testing.allocator;
    var table = Table.empty();
    defer table.deinit(allocator);
    const left = table.begin(allocator, 0);
    const right = table.begin(allocator, 1);
    try std.testing.expect(table.claim(0, left, 1));
    try std.testing.expect(table.claim(0, left, 2));
    try std.testing.expect(table.claim(1, right, 1));
    table.finish(allocator, 0, left, 2, own(allocator, "second"));
    table.finish(allocator, 1, right, 1, own(allocator, "other"));
    try expectReady(&table, 0, left, 2, "second");
    try expectReady(&table, 1, right, 1, "other");
    try std.testing.expect(table.takeReady(0, left) == null);
    table.finish(allocator, 0, left, 1, own(allocator, "first"));
    try expectReady(&table, 0, left, 1, "first");
}

test "a dropped connection forgets in-flight replies before the next one" {
    const allocator = std.testing.allocator;
    var table = Table.empty();
    defer table.deinit(allocator);
    const first = table.begin(allocator, 0);
    try std.testing.expect(table.claim(0, first, 1));
    table.finish(allocator, 0, first, 1, own(allocator, "stale"));
    table.end(allocator, 0, first);
    try std.testing.expect(!table.claim(0, first, 1));
    table.finish(allocator, 0, first, 1, own(allocator, "late"));
    const second = table.begin(allocator, 0);
    try std.testing.expect(second != first);
    try std.testing.expect(!table.claim(0, first, 1));
    try std.testing.expect(table.claim(0, second, 1));
    try std.testing.expect(table.takeReady(0, second) == null);
    table.finish(allocator, 0, second, 1, own(allocator, "fresh"));
    try expectReady(&table, 0, second, 1, "fresh");
}

test "an unfinished call is dropped on disconnect and the same id can be claimed again" {
    const allocator = std.testing.allocator;
    var table = Table.empty();
    defer table.deinit(allocator);
    const first = table.begin(allocator, 0);
    try std.testing.expect(table.claim(0, first, 4));
    table.end(allocator, 0, first);
    const second = table.begin(allocator, 0);
    try std.testing.expect(table.claim(0, second, 4));
    table.finish(allocator, 0, second, 4, null);
    try expectReady(&table, 0, second, 4, null);
}

test "each server keeps a 32 call waiting limit" {
    const allocator = std.testing.allocator;
    var table = Table.empty();
    defer table.deinit(allocator);
    const left = table.begin(allocator, 0);
    const right = table.begin(allocator, 1);
    var id: u32 = 1;
    while (id <= slots_per_host) : (id += 1) {
        try std.testing.expect(table.claim(0, left, id));
    }
    try std.testing.expect(!table.claim(0, left, slots_per_host + 1));
    try std.testing.expect(table.claim(1, right, 1));
    try std.testing.expect(!table.claim(0, left, 1));
}

test "a repeated id on the same connection does not replace the open call" {
    const allocator = std.testing.allocator;
    var table = Table.empty();
    defer table.deinit(allocator);
    const generation = table.begin(allocator, 0);
    try std.testing.expect(table.claim(0, generation, 3));
    try std.testing.expect(!table.claim(0, generation, 3));
    table.finish(allocator, 0, generation, 3, own(allocator, "once"));
    table.finish(allocator, 0, generation, 3, own(allocator, "twice"));
    try expectReady(&table, 0, generation, 3, "once");
}
