const std = @import("std");

pub const Lock = enum { none, chat, shell };

pub fn shouldShow(on: bool, lock: Lock) bool {
    return switch (lock) {
        .none => on,
        .chat => true,
        .shell => false,
    };
}

pub fn setEverywhere(sessions: anytype, on: bool) void {
    for (sessions) |*session| {
        if (session.chat_view_lock == .none) session.chat_view_on = on;
    }
}

pub fn setLock(session: anytype, lock: Lock) void {
    session.chat_view_lock = lock;
    session.chat_view_on = shouldShow(session.chat_view_on, lock);
}

pub fn toggle(session: anytype) void {
    if (session.chat_view_lock == .none) session.chat_view_on = !session.chat_view_on;
}

pub fn savedLock(lock: Lock) []const u8 {
    return switch (lock) {
        .none => "",
        .chat => ",\"chat_view_lock\":\"chat\"",
        .shell => ",\"chat_view_lock\":\"shell\"",
    };
}

const Session = struct { chat_view_on: bool = false, chat_view_lock: Lock = .none };

test "ISSUE-611 on everywhere changes all unlocked sessions and skips both locks" {
    var sessions = [_]Session{ .{}, .{}, .{ .chat_view_lock = .shell }, .{ .chat_view_on = true, .chat_view_lock = .chat } };
    setEverywhere(&sessions, true);
    try std.testing.expect(sessions[0].chat_view_on);
    try std.testing.expect(sessions[1].chat_view_on);
    try std.testing.expect(!sessions[2].chat_view_on);
    try std.testing.expect(sessions[3].chat_view_on);
}

test "ISSUE-611 a later Alt+C toggle sticks across tab switches after on everywhere" {
    var sessions = [_]Session{ .{}, .{} };
    setEverywhere(&sessions, true);
    toggle(&sessions[0]);
    try std.testing.expect(shouldShow(sessions[1].chat_view_on, sessions[1].chat_view_lock));
    for (0..3) |_| try std.testing.expect(!shouldShow(sessions[0].chat_view_on, sessions[0].chat_view_lock));
}

test "ISSUE-611 off everywhere changes unlocked flags without defeating locks" {
    var sessions = [_]Session{ .{ .chat_view_on = true }, .{ .chat_view_on = true }, .{}, .{} };
    setLock(&sessions[2], .chat);
    setLock(&sessions[3], .shell);
    setEverywhere(&sessions, false);
    try std.testing.expect(!sessions[0].chat_view_on);
    try std.testing.expect(!sessions[1].chat_view_on);
    try std.testing.expect(sessions[2].chat_view_on);
    try std.testing.expect(!sessions[3].chat_view_on);
    toggle(&sessions[2]);
    toggle(&sessions[3]);
    try std.testing.expect(sessions[2].chat_view_on);
    try std.testing.expect(!sessions[3].chat_view_on);
    setLock(&sessions[2], .none);
    try std.testing.expect(sessions[2].chat_view_on);
    toggle(&sessions[2]);
    try std.testing.expect(!sessions[2].chat_view_on);
}
