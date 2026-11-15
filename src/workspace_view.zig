const std = @import("std");
const frequent = @import("frequent.zig");

pub const starred: u8 = 0xFE;
pub const all_view: u8 = 0xFD;
pub const frequent_view: u8 = 0xFC;

pub fn fromDigit(digit: u32) ?u8 {
    return switch (digit) {
        1 => starred,
        2...9 => @intCast(digit - 2),
        else => null,
    };
}

pub fn isView(ws: u32) bool {
    return ws == @as(u32, starred) or ws == @as(u32, all_view) or ws == @as(u32, frequent_view);
}

pub fn viewSplit(ws: u32) u32 {
    return switch (ws) {
        @as(u32, all_view) => frequent.all_split,
        @as(u32, frequent_view) => frequent.frequent_split,
        else => frequent.favorites_split,
    };
}

pub fn viewName(split: u32) []const u8 {
    return switch (frequent.splitKind(split)) {
        .all => "All",
        .frequent => "Frequent",
        .favorites => "Favorites",
        .workspace => "Workspace",
    };
}

pub fn splitMatches(tab: u32, ws: u32, favorite: bool) bool {
    return switch (frequent.splitKind(tab)) {
        .all, .frequent => true,
        .favorites => favorite,
        .workspace => |workspace| ws == workspace,
    };
}

pub fn includes(tab: u32, ws: u32, favorite: bool, visits: []const u64, input: u64, now_ms: u64) bool {
    return switch (frequent.splitKind(tab)) {
        .frequent => frequent.inFrequent(visits, now_ms, if (input != 0) input else null),
        else => splitMatches(tab, ws, favorite),
    };
}

const no_visits: [0]u64 = .{};

pub fn visitSlice(visits: *const frequent.Visits) []const u64 {
    return visits.optional() orelse &no_visits;
}

pub fn recencyKey(tab: u32, la: u64, lv: u64, visits: []const u64, input: u64, now_ms: u64) u64 {
    return switch (frequent.splitKind(tab)) {
        .frequent => frequent.orderKey(visits, now_ms, if (input != 0) input else null),
        else => @max(la, lv),
    };
}

pub const Order = struct {
    la: u64,
    lv: u64,
    att: bool,
    act: u8,
    ws: u32,
    sid: u32,
    input: u64,
    visits: []const u64,
};

pub fn newer(tab: u32, a: Order, b: Order, now_ms: u64) bool {
    const ka = recencyKey(tab, a.la, a.lv, a.visits, a.input, now_ms);
    const kb = recencyKey(tab, b.la, b.lv, b.visits, b.input, now_ms);
    if (ka != kb) return ka > kb;
    if (a.att != b.att) return a.att;
    if ((a.act == 1) != (b.act == 1)) return a.act == 1;
    if (a.la != b.la) return a.la > b.la;
    if (a.ws != b.ws) return a.ws < b.ws;
    return a.sid < b.sid;
}

test "SOFT-2380 all frequent and favorites views share the inbox membership rule" {
    const now: u64 = 1_800_000_000_000;
    try std.testing.expect(includes(frequent.all_split, 0, false, &.{}, 0, now));
    try std.testing.expect(includes(frequent.all_split, 42, false, &.{}, 0, now));
    try std.testing.expect(includes(frequent.favorites_split, 3, true, &.{}, 0, now));
    try std.testing.expect(!includes(frequent.favorites_split, 3, false, &.{}, 0, now));
    try std.testing.expect(!includes(frequent.frequent_split, 0, false, &.{}, 0, now));
    try std.testing.expect(includes(frequent.frequent_split, 0, false, &.{}, now - 1_000, now));
    try std.testing.expect(includes(frequent.frequent_split, 0, false, &.{ now - 3, now - 2, now - 1 }, 0, now));
    try std.testing.expect(!includes(frequent.frequent_split, 0, false, &.{ now - 2, now - 1 }, 0, now));
    try std.testing.expect(includes(frequent.workspaceSplit(4), 4, false, &.{}, 0, now));
    try std.testing.expect(!includes(frequent.workspaceSplit(5), 4, true, &.{}, 0, now));
}

test "SOFT-2380 all orders by displayed recency and frequent by the inbox key" {
    const now: u64 = 1_800_000_000_000;
    const empty: [0]u64 = .{};
    const older = Order{ .la = 10, .lv = 1, .att = true, .act = 1, .ws = 0, .sid = 1, .input = 0, .visits = &empty };
    const fresher = Order{ .la = 20, .lv = 1, .att = false, .act = 0, .ws = 1, .sid = 2, .input = 0, .visits = &empty };
    try std.testing.expect(newer(frequent.all_split, fresher, older, now));
    try std.testing.expect(!newer(frequent.all_split, older, fresher, now));
    const seen = Order{ .la = 0, .lv = 0, .att = false, .act = 0, .ws = 0, .sid = 1, .input = now, .visits = &empty };
    const quiet = Order{ .la = 99, .lv = 99, .att = true, .act = 1, .ws = 0, .sid = 2, .input = 0, .visits = &empty };
    try std.testing.expect(newer(frequent.frequent_split, seen, quiet, now));
    try std.testing.expect(!newer(frequent.frequent_split, quiet, seen, now));
    const viewed = Order{ .la = 5, .lv = 50, .att = false, .act = 0, .ws = 0, .sid = 3, .input = 0, .visits = &empty };
    try std.testing.expect(newer(frequent.favorites_split, viewed, older, now));
    try std.testing.expectEqual(@max(older.la, older.lv), recencyKey(frequent.all_split, older.la, older.lv, empty[0..], 0, now));
}

test "SOFT-2380 view entries map to the inbox splits and keep their names" {
    try std.testing.expectEqual(frequent.all_split, viewSplit(all_view));
    try std.testing.expectEqual(frequent.frequent_split, viewSplit(frequent_view));
    try std.testing.expectEqual(frequent.favorites_split, viewSplit(starred));
    try std.testing.expect(isView(all_view));
    try std.testing.expect(isView(frequent_view));
    try std.testing.expect(isView(starred));
    try std.testing.expect(!isView(0));
    try std.testing.expect(!isView(8));
    try std.testing.expectEqualStrings("All", viewName(frequent.all_split));
    try std.testing.expectEqualStrings("Frequent", viewName(frequent.frequent_split));
    try std.testing.expectEqualStrings("Favorites", viewName(frequent.favorites_split));
}

test "IGSH-457 Starred mirrors inbox favorites after star and unstar across two hosts" {
    const Session = struct { host: u8, workspace: u8, favorite: bool };
    var sessions = [_]Session{
        .{ .host = 0, .workspace = 0, .favorite = false },
        .{ .host = 1, .workspace = 1, .favorite = true },
        .{ .host = 0, .workspace = 2, .favorite = false },
    };
    for ([_]bool{ true, false }) |favorite| {
        sessions[0].favorite = favorite;
        sessions[1].favorite = favorite;
        var inbox: [3]usize = undefined;
        var workspace: [3]usize = undefined;
        var ni: usize = 0;
        var nw: usize = 0;
        for (sessions, 0..) |session, i| {
            if (includes(frequent.favorites_split, session.workspace, session.favorite, &.{}, 0, 0)) {
                inbox[ni] = i;
                ni += 1;
            }
            if (includes(viewSplit(starred), session.workspace, session.favorite, &.{}, 0, 0)) {
                workspace[nw] = i;
                nw += 1;
            }
            try std.testing.expect(includes(frequent.workspaceSplit(session.workspace), session.workspace, session.favorite, &.{}, 0, 0));
        }
        try std.testing.expectEqual(@as(usize, if (favorite) 2 else 0), nw);
        try std.testing.expectEqualSlices(usize, inbox[0..ni], workspace[0..nw]);
        if (favorite) try std.testing.expect(sessions[workspace[0]].host != sessions[workspace[1]].host);
    }
}

test "IGSH-457 Alt digits reserve first workspace for Starred" {
    try std.testing.expectEqual(@as(?u8, starred), fromDigit(1));
    for (2..10) |digit| try std.testing.expectEqual(@as(?u8, @intCast(digit - 2)), fromDigit(@intCast(digit)));
    try std.testing.expectEqual(@as(?u8, null), fromDigit(0));
    try std.testing.expectEqual(@as(?u8, null), fromDigit(10));
}
