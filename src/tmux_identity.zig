const std = @import("std");

pub fn same(host_a: u8, session_a: []const u8, host_b: u8, session_b: []const u8) bool {
    return session_a.len > 0 and host_a == host_b and std.ascii.eqlIgnoreCase(session_a, session_b);
}

pub const Pane = struct {
    active: bool = false,
    visible: bool = false,
    last_viewed: u64 = 0,
};

pub fn prefer(candidate: Pane, current: Pane) bool {
    if (candidate.active != current.active) return candidate.active;
    if (candidate.visible != current.visible) return candidate.visible;
    return candidate.last_viewed > current.last_viewed;
}

pub fn restoreWinner(tabs: anytype, index: usize) usize {
    const tab = &tabs[index];
    var winner = index;
    for (tabs, 0..) |*other, i| {
        if (!same(tab.tmux_host, tab.tmux_session[0..tab.tmux_session_len], other.tmux_host, other.tmux_session[0..other.tmux_session_len])) continue;
        if (other.last_viewed > tabs[winner].last_viewed or
            (other.last_viewed == tabs[winner].last_viewed and i < winner)) winner = i;
    }
    return winner;
}

test "pane choice prefers active then visible then last viewed with stable ties" {
    try std.testing.expect(prefer(.{ .active = true }, .{ .visible = true, .last_viewed = 999 }));
    try std.testing.expect(!prefer(.{ .visible = true, .last_viewed = 999 }, .{ .active = true }));
    try std.testing.expect(prefer(.{ .visible = true }, .{ .last_viewed = 999 }));
    try std.testing.expect(prefer(.{ .last_viewed = 20 }, .{ .last_viewed = 10 }));
    try std.testing.expect(!prefer(.{ .last_viewed = 10 }, .{ .last_viewed = 10 }));
}

test "restore dedupe keeps newest full record and name, separating hosts and empty identities" {
    const Tab = struct {
        tmux_host: u8 = 0,
        tmux_session: []const u8 = "remote-3",
        tmux_session_len: usize = 8,
        last_viewed: u64 = 0,
        name: []const u8,
        locked: bool = false,
    };
    var tabs = [_]Tab{
        .{ .name = "secondary Growth Bot", .last_viewed = 10 },
        .{ .name = "Meta Klaviyo Connection", .last_viewed = 30, .pinned_top = true },
        .{ .name = "other host", .tmux_host = 1 },
        .{ .name = "local", .tmux_session_len = 0 },
        .{ .name = "local 2", .tmux_session_len = 0 },
        .{ .name = "tie", .last_viewed = 30 },
    };
    var kept: usize = 0;
    for (&tabs, 0..) |_, i| {
        const winner = restoreWinner(&tabs, i);
        if (i == winner) kept += 1;
        if (i == 0 or i == 1 or i == 5) {
            try std.testing.expectEqual(@as(usize, 1), winner);
            try std.testing.expectEqualStrings("Meta Klaviyo Connection", tabs[winner].name);
            try std.testing.expect(tabs[winner].pinned_top);
        } else try std.testing.expectEqual(i, winner);
    }
    try std.testing.expectEqual(@as(usize, 4), kept);
}

test "open and adoption identity excludes empty sessions and other hosts" {
    try std.testing.expect(same(0, "remote-3", 0, "remote-3"));
    try std.testing.expect(!same(0, "remote-3", 1, "remote-3"));
    try std.testing.expect(!same(0, "remote-3", 0, "remote-3-2"));
    try std.testing.expect(!same(0, "", 0, ""));
}
