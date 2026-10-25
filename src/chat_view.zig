const std = @import("std");

pub fn shouldShow(on: bool) bool {
    return on;
}

pub fn setEverywhere(sessions: anytype, on: bool) void {
    for (sessions) |*session| {
        session.chat_view_on = on;
    }
}

pub fn toggle(session: anytype) void {
    session.chat_view_on = !session.chat_view_on;
}

const Session = struct { chat_view_on: bool = false, pinned_top: bool = false };

test "IGSH-820 everywhere actions and later toggles work on pinned and unpinned sessions" {
    var sessions = [_]Session{ .{}, .{ .pinned_top = true } };
    setEverywhere(&sessions, true);
    for (sessions) |session| try std.testing.expect(shouldShow(session.chat_view_on));
    for (&sessions) |*session| {
        toggle(session);
        try std.testing.expect(!shouldShow(session.chat_view_on));
        toggle(session);
        try std.testing.expect(shouldShow(session.chat_view_on));
    }
    setEverywhere(&sessions, false);
    for (sessions) |session| try std.testing.expect(!shouldShow(session.chat_view_on));
    try std.testing.expect(sessions[1].pinned_top);
}

test "ISSUE-611 a later Alt+C toggle sticks across tab switches after on everywhere" {
    var sessions = [_]Session{ .{}, .{} };
    setEverywhere(&sessions, true);
    toggle(&sessions[0]);
    try std.testing.expect(shouldShow(sessions[1].chat_view_on));
    for (0..3) |_| try std.testing.expect(!shouldShow(sessions[0].chat_view_on));
}
