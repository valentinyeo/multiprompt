const std = @import("std");

pub const input_window_ms: u64 = 24 * 60 * 60 * 1000;
pub const window_ms: u64 = 6 * 60 * 60 * 1000;
pub const min_visits: usize = 3;
pub const dwell_ms: u64 = 10 * 1000;
pub const max_visits: usize = 8;
pub const first_ws_split: u32 = 3;
pub const frequent_split: u32 = 0;
pub const all_split: u32 = 1;
pub const favorites_split: u32 = 2;
pub const Settings = struct {
    frequent: bool = true,
    favorites: bool = true,
    all: bool = true,
    frequent_first: bool = true,
};

pub const BuiltinSplits = struct {
    ids: [3]u32 = undefined,
    len: usize = 0,

    pub fn slice(self: *const BuiltinSplits) []const u32 {
        return self.ids[0..self.len];
    }
};

pub fn builtinSplits(settings: Settings) BuiltinSplits {
    var result: BuiltinSplits = .{};
    const order: [3]u32 = if (settings.frequent_first) .{ frequent_split, all_split, favorites_split } else .{ all_split, favorites_split, frequent_split };
    for (order) |id| {
        const visible = switch (id) {
            frequent_split => settings.frequent,
            favorites_split => settings.favorites,
            else => settings.all,
        };
        if (!visible) continue;
        result.ids[result.len] = id;
        result.len += 1;
    }
    if (result.len == 0) {
        result.ids[0] = all_split;
        result.len = 1;
    }
    return result;
}

pub const SplitKind = union(enum) { all, favorites, frequent, workspace: u32 };

pub fn splitKind(tab: u32) SplitKind {
    return switch (tab) {
        frequent_split => .frequent,
        all_split => .all,
        favorites_split => .favorites,
        else => .{ .workspace = tab - first_ws_split },
    };
}

pub fn migrateSplit(tab: u32, visits_order: bool) u32 {
    if (visits_order) return tab;
    return switch (tab) {
        0 => all_split,
        1 => favorites_split,
        2 => frequent_split,
        else => tab,
    };
}

pub fn splitCount(workspaces: u32) u32 {
    return workspaces + first_ws_split;
}

pub fn workspaceSplit(workspace: u32) u32 {
    return workspace + first_ws_split;
}

pub const Visits = extern struct {
    values: [max_visits]u64 = .{0} ** max_visits,
    len: u8 = 0,
    known: u8 = 0,

    pub fn optional(self: *const Visits) ?[]const u64 {
        return if (self.known != 0) self.values[0..self.len] else null;
    }

    pub fn add(self: *Visits, value: u64) void {
        self.known = 1;
        var i: usize = 0;
        while (i < self.len and self.values[i] < value) : (i += 1) {}
        if (i < self.len and self.values[i] == value) return;
        if (self.len == max_visits) {
            if (i == 0) return;
            std.mem.copyForwards(u64, self.values[0 .. max_visits - 1], self.values[1..]);
            self.len -= 1;
            i -= 1;
        }
        std.mem.copyBackwards(u64, self.values[i + 1 .. self.len + 1], self.values[i..self.len]);
        self.values[i] = value;
        self.len += 1;
    }

    pub fn merge(left: ?[]const u64, right: ?[]const u64) Visits {
        var result: Visits = .{};
        if (left) |values| {
            result.known = 1;
            for (values) |v| result.add(v);
        }
        if (right) |values| {
            result.known = 1;
            for (values) |v| result.add(v);
        }
        return result;
    }
};

pub fn writeVisits(out: []u8, visits: Visits) usize {
    const values = visits.optional() orelse return 0;
    const prefix = ",\"visits\":[";
    @memcpy(out[0..prefix.len], prefix);
    var pos: usize = prefix.len;
    for (values, 0..) |v, i| {
        const text = std.fmt.bufPrint(out[pos..], "{s}{d}", .{ if (i == 0) @as([]const u8, "") else ",", v }) catch return 0;
        pos += text.len;
    }
    out[pos] = ']';
    return pos + 1;
}

pub fn writeInput(out: []u8, input: u64) usize {
    if (input == 0) return 0;
    const text = std.fmt.bufPrint(out, ",\"input\":{d}", .{input}) catch return 0;
    return text.len;
}

pub const FrontPeriod = struct {
    sid: ?u32 = null,
    selected: ?u32 = null,
    start_ms: u64 = 0,
    start_tick: u64 = 0,
    recorded: bool = false,

    pub fn select(self: *FrontPeriod, sid: ?u32, user: bool, focused: bool, now_ms: u64, tick: u64) bool {
        if (user) self.selected = sid else if (self.selected != sid) self.selected = null;
        const front = if (focused and self.selected == sid) sid else null;
        if (self.sid == front) return false;
        self.sid = front;
        self.start_ms = now_ms;
        self.start_tick = tick;
        self.recorded = false;
        return true;
    }

    pub fn visit(self: *FrontPeriod, tick: u64) ?u64 {
        if (self.sid == null or self.recorded or tick < self.start_tick or tick - self.start_tick < dwell_ms) return null;
        self.recorded = true;
        return self.start_ms;
    }
};

pub fn unixMs(stored_ms: u64) u64 {
    const windows_epoch_ms = 11_644_473_600_000;
    return if (stored_ms >= windows_epoch_ms) stored_ms - windows_epoch_ms else stored_ms;
}

pub fn newest(visits: []const u64) ?u64 {
    return if (visits.len == 0) null else visits[visits.len - 1];
}

pub fn inputRecent(input: ?u64, now_ms: u64) bool {
    return if (input) |stamp| stamp >= now_ms -| input_window_ms else false;
}

pub fn inFrequent(visits: []const u64, now_ms: u64, input: ?u64) bool {
    if (inputRecent(input, now_ms)) return true;
    var count: usize = 0;
    for (visits) |v| if (v >= now_ms -| window_ms) {
        count += 1;
    };
    return count >= min_visits;
}

pub fn orderKey(visits: []const u64, now_ms: u64, input: ?u64) u64 {
    return if (inputRecent(input, now_ms)) input.? else newest(visits) orelse 0;
}

pub fn bottomOrder(a: u64, b: u64) bool {
    return a < b;
}

pub fn shellInputKey(vk: u32) bool {
    return switch (vk) {
        0x10, 0x11, 0x12, 0x5B, 0x5C, 0xA0...0xA5 => false,
        else => true,
    };
}

test "v2 terminal input includes arrows escape delete tab and function keys not just text" {
    for ([_]u32{ 0x08, 0x09, 0x0D, 0x1B, 0x20, 0x25, 0x26, 0x27, 0x28, 0x2E, 0x41, 0x70, 0xBA }) |vk| try std.testing.expect(shellInputKey(vk));
    for ([_]u32{ 0x10, 0x11, 0x12, 0x5B, 0x5C, 0xA0, 0xA5 }) |vk| try std.testing.expect(!shellInputKey(vk));
}

pub fn shouldStamp(last_used_ms: u64, now_ms: u64, throttled: bool) bool {
    return !throttled or last_used_ms == 0 or (now_ms > last_used_ms and now_ms - last_used_ms > 60 * 1000);
}

test "v2 input exactly 24 hours counts future counts older input and used do not" {
    const now = 1_800_000_000_000;
    try std.testing.expect(inFrequent(&.{}, now, now - input_window_ms));
    try std.testing.expect(inFrequent(&.{}, now, now + 1));
    try std.testing.expect(!inFrequent(&.{}, now, now - input_window_ms - 1));
    try std.testing.expect(!inFrequent(&.{}, now, null));
    try std.testing.expectEqual(now - 1, orderKey(&.{now + 1}, now, now - 1));
}

test "v2 three looks in six hours and no local front or newest anywhere exception" {
    const now = 1_800_000_000_000;
    try std.testing.expect(inFrequent(&.{ now - window_ms, now - 2, now - 1 }, now, null));
    try std.testing.expect(!inFrequent(&.{ now - window_ms - 1, now - 2, now - 1 }, now, null));
    try std.testing.expect(!inFrequent(&.{ now - 2, now - 1 }, now, null));
    try std.testing.expect(!inFrequent(&.{now}, now, null));
    try std.testing.expect(!inFrequent(&.{}, now, null));
}

test "v2 only user selected focused ten second front periods count" {
    var front: FrontPeriod = .{};
    try std.testing.expect(!front.select(1, false, true, 100, 0));
    try std.testing.expectEqual(@as(?u64, null), front.visit(10000));
    try std.testing.expect(front.select(1, true, true, 200, 10000));
    try std.testing.expectEqual(@as(?u64, null), front.visit(19999));
    try std.testing.expectEqual(@as(?u64, 200), front.visit(20000));
    try std.testing.expectEqual(@as(?u64, null), front.visit(30000));
    try std.testing.expect(front.select(2, false, true, 300, 30000));
    try std.testing.expectEqual(@as(?u64, null), front.visit(40000));
    try std.testing.expect(!front.select(2, true, false, 400, 40000));
    try std.testing.expectEqual(@as(?u64, null), front.visit(50000));
    try std.testing.expect(front.select(2, false, true, 500, 50000));
    try std.testing.expect(front.select(2, false, false, 600, 59999));
    try std.testing.expectEqual(@as(?u64, null), front.visit(60000));
    try std.testing.expect(front.select(2, false, true, 700, 70000));
    try std.testing.expectEqual(@as(?u64, null), front.visit(79999));
    try std.testing.expectEqual(@as(?u64, 700), front.visit(80000));
}

test "visits split mapping Frequent first and selected split migration" {
    try std.testing.expectEqual(SplitKind.frequent, splitKind(0));
    try std.testing.expectEqual(SplitKind.all, splitKind(1));
    try std.testing.expectEqual(SplitKind.favorites, splitKind(2));
    for (0..35) |i| {
        const old: u32 = @intCast(i);
        const migrated = migrateSplit(old, false);
        const expected: SplitKind = switch (old) {
            0 => .all,
            1 => .favorites,
            2 => .frequent,
            else => .{ .workspace = old - 3 },
        };
        try std.testing.expectEqual(expected, splitKind(migrated));
        try std.testing.expectEqual(migrated, migrateSplit(migrated, true));
    }
    try std.testing.expectEqual(@as(u32, 35), splitCount(32));
    try std.testing.expectEqual(@as(u32, 7), workspaceSplit(4));
}

test "used Windows clock and stamp throttle unchanged" {
    try std.testing.expectEqual(@as(u64, 1_800_000_000_000), unixMs(13_444_473_600_000));
    try std.testing.expect(shouldStamp(0, 1, true));
    try std.testing.expect(!shouldStamp(1, 60001, true));
    try std.testing.expect(shouldStamp(1, 60002, true));
    try std.testing.expect(!shouldStamp(60002, 1, true));
    try std.testing.expect(shouldStamp(1, 2, false));
}

test "ISSUE-423 builtins order hiding and all-hidden fallback for every flag combination" {
    for (0..16) |bits| {
        const settings = Settings{ .frequent = bits & 1 != 0, .favorites = bits & 2 != 0, .all = bits & 4 != 0, .frequent_first = bits & 8 != 0 };
        const actual = builtinSplits(settings);
        var expected: std.ArrayList(u32) = .empty;
        defer expected.deinit(std.testing.allocator);
        if (settings.frequent and settings.frequent_first) try expected.append(std.testing.allocator, frequent_split);
        if (settings.all) try expected.append(std.testing.allocator, all_split);
        if (settings.favorites) try expected.append(std.testing.allocator, favorites_split);
        if (settings.frequent and !settings.frequent_first) try expected.append(std.testing.allocator, frequent_split);
        if (expected.items.len == 0) try expected.append(std.testing.allocator, all_split);
        try std.testing.expectEqualSlices(u32, expected.items, actual.slice());
    }
    const after_favorites = builtinSplits(.{ .frequent_first = false });
    try std.testing.expectEqualSlices(u32, &.{ all_split, favorites_split, frequent_split }, after_favorites.slice());
    const after_all = builtinSplits(.{ .frequent_first = false, .favorites = false });
    try std.testing.expectEqualSlices(u32, &.{ all_split, frequent_split }, after_all.slice());
    const fallback = builtinSplits(.{ .frequent = false, .favorites = false, .all = false });
    try std.testing.expectEqualSlices(u32, &.{all_split}, fallback.slice());
}
