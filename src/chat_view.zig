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

pub fn isLive(tmux_session: []const u8) bool {
    return std.mem.startsWith(u8, tmux_session, "live-");
}

pub fn canToggle(tmux_session: []const u8) bool {
    return !isLive(tmux_session);
}

pub fn forSession(tmux_session: []const u8, wanted: bool) bool {
    return wanted or isLive(tmux_session);
}

pub fn setEverywhere(sessions: anytype, on: bool) void {
    for (sessions) |*session| {
        if (comptime @hasField(@TypeOf(session.*), "tmux_session_len")) {
            session.chat_view_on = forSession(session.tmux_session[0..session.tmux_session_len], on);
        } else {
            session.chat_view_on = on;
        }
    }
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

const NamedSession = struct { chat_view_on: bool = false, tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0 };

fn named(name: []const u8) NamedSession {
    var session: NamedSession = .{};
    @memcpy(session.tmux_session[0..name.len], name);
    session.tmux_session_len = @intCast(name.len);
    return session;
}

test "IGSH-1762 every live chat name keeps chat view while terminal tabs follow the user" {
    for ([_][]const u8{ "live-0123456789ab8def81230123456789ab", "live-h0123456789ab8def81230123456789ab", "live-project-abc123", "live-1a2b3c", "live-" }) |name| {
        try std.testing.expect(isLive(name));
        try std.testing.expect(forSession(name, false));
        try std.testing.expect(forSession(name, true));
    }
    for ([_][]const u8{ "", "term-abc", "main", "live", "xlive-abc" }) |name| {
        try std.testing.expect(!isLive(name));
        try std.testing.expect(!forSession(name, false));
        try std.testing.expect(forSession(name, true));
    }
}

test "IGSH-1762 chat view off everywhere leaves live chats in chat view" {
    var sessions = [_]NamedSession{ named("live-project-abc123"), named("term-abc"), named("live-0123456789ab8def81230123456789ab"), .{} };
    setEverywhere(&sessions, true);
    for (sessions) |session| try std.testing.expect(shouldShow(session.chat_view_on));
    setEverywhere(&sessions, false);
    try std.testing.expect(shouldShow(sessions[0].chat_view_on));
    try std.testing.expect(!shouldShow(sessions[1].chat_view_on));
    try std.testing.expect(shouldShow(sessions[2].chat_view_on));
    try std.testing.expect(!shouldShow(sessions[3].chat_view_on));
}

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
