const std = @import("std");

pub fn shouldShow(on: bool) bool {
    return on;
}

pub fn fetchWanted(chat_active: bool, tab_wants_chat: bool) bool {
    return chat_active and tab_wants_chat;
}

test "IGSH-1266 a tab in terminal view schedules no chat fetch" {
    try std.testing.expect(fetchWanted(true, true));
    try std.testing.expect(!fetchWanted(true, false));
    try std.testing.expect(!fetchWanted(false, true));
    try std.testing.expect(!fetchWanted(false, false));
}

pub fn setEverywhere(sessions: anytype, on: bool) void {
    for (sessions) |*session| {
        session.chat_view_on = on;
    }
}

pub fn canToggle(tmux_session: []const u8) bool {
    return !std.mem.startsWith(u8, tmux_session, "live-");
}

test "IGSH-1655 live parking tabs cannot toggle but terminal tabs can" {
    try std.testing.expect(!canToggle("live-test"));
    try std.testing.expect(canToggle("term-test"));
    try std.testing.expect(canToggle(""));
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
