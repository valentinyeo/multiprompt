const std = @import("std");
const frequent = @import("frequent.zig");

pub const starred: u8 = 0xFE;

pub fn fromDigit(digit: u32) ?u8 {
    return switch (digit) {
        1 => starred,
        2...9 => @intCast(digit - 2),
        else => null,
    };
}

pub fn splitMatches(tab: u32, ws: u32, favorite: bool) bool {
    return switch (frequent.splitKind(tab)) {
        .all, .frequent => true,
        .favorites => favorite,
        .workspace => |workspace| ws == workspace,
    };
}

pub fn contains(is_starred: bool, active: u8, workspace: u8, favorite: bool) bool {
    return splitMatches(if (is_starred) frequent.favorites_split else frequent.workspaceSplit(active), workspace, favorite);
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
            if (splitMatches(frequent.favorites_split, session.workspace, session.favorite)) {
                inbox[ni] = i;
                ni += 1;
            }
            if (contains(true, 0, session.workspace, session.favorite)) {
                workspace[nw] = i;
                nw += 1;
            }
            try std.testing.expect(contains(false, session.workspace, session.workspace, session.favorite));
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
