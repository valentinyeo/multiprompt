const std = @import("std");

pub const Key = enum { ctrl_down, ctrl_up, alt_down, digit_down, other_down, focus_lost };

pub const State = struct {
    ctrl_held: bool = false,
    shown: bool = false,
};

pub var state: State = .{};

pub fn classify(vk: u32, scan: u32, down: bool) ?Key {
    if (vk == 0xA2 and (scan & 0x200) != 0) return if (down) .alt_down else .ctrl_up;
    if (vk == 0x11 or vk == 0xA2 or vk == 0xA3) return if (down) .ctrl_down else .ctrl_up;
    if (!down) return null;
    if (vk == 0x12 or vk == 0xA4 or vk == 0xA5) return .alt_down;
    if (vk >= 0x31 and vk <= 0x39) return .digit_down;
    return .other_down;
}

pub fn next(current: State, key: Key, alt: bool, may_show: bool) State {
    return switch (key) {
        .ctrl_down => .{ .ctrl_held = true, .shown = !alt and (if (current.ctrl_held) current.shown else may_show) },
        .ctrl_up, .focus_lost => .{},
        .alt_down, .other_down => .{ .ctrl_held = current.ctrl_held, .shown = false },
        .digit_down => .{ .ctrl_held = current.ctrl_held, .shown = current.shown and !alt },
    };
}

pub const Rect = struct { left: i32, top: i32, right: i32, bottom: i32 };

pub fn badgeRect(avatar_left: i32, avatar_top: i32, comptime scale: fn (i32) i32) Rect {
    const diameter = scale(16);
    const left = avatar_left - scale(4);
    const top = avatar_top - scale(4);
    return .{ .left = left, .top = top, .right = left + diameter, .bottom = top + diameter };
}

fn press(current: State, vk: u32, scan: u32, down: bool, alt: bool, may_show: bool) State {
    return next(current, classify(vk, scan, down).?, alt, may_show);
}

fn identity(px: i32) i32 {
    return px;
}

test "ctrl down shows badges and ctrl up hides them" {
    var s = press(.{}, 0xA2, 0x1D, true, false, true);
    try std.testing.expect(s.shown);
    s = press(s, 0xA2, 0x1D, true, false, true);
    try std.testing.expect(s.shown);
    s = press(s, 0x33, 0x04, true, false, true);
    try std.testing.expect(s.shown);
    s = press(s, 0xA2, 0x1D, false, false, true);
    try std.testing.expectEqual(State{}, s);
}

test "ctrl over another app shows nothing" {
    try std.testing.expect(!press(.{}, 0xA3, 0x1D, true, false, false).shown);
}

test "non digit chord hides badges until ctrl is pressed again" {
    var s = press(.{}, 0xA2, 0x1D, true, false, true);
    s = press(s, 0x43, 0x2E, true, false, true);
    try std.testing.expect(!s.shown);
    s = press(s, 0xA2, 0x1D, true, false, true);
    try std.testing.expect(!s.shown);
    s = press(s, 0xA2, 0x1D, false, false, true);
    s = press(s, 0xA2, 0x1D, true, false, true);
    try std.testing.expect(s.shown);
}

test "altgr never shows badges" {
    var s = press(.{}, 0xA2, 0x21D, true, false, true);
    try std.testing.expect(!s.shown);
    s = press(s, 0xA5, 0x38, true, true, true);
    try std.testing.expect(!s.shown);
    s = press(s, 0xA2, 0x21D, true, true, true);
    try std.testing.expect(!s.shown);
    s = press(.{}, 0xA4, 0x38, true, true, true);
    s = press(s, 0xA2, 0x1D, true, true, true);
    try std.testing.expect(!s.shown);
    s = press(.{}, 0xA2, 0x1D, true, false, true);
    s = press(s, 0xA4, 0x38, true, true, true);
    try std.testing.expect(!s.shown);
}

test "focus loss hides badges" {
    const s = press(.{}, 0xA2, 0x1D, true, false, true);
    try std.testing.expectEqual(State{}, next(s, .focus_lost, false, false));
}

test "badge sits on the avatar top left corner" {
    try std.testing.expectEqual(Rect{ .left = 8, .top = 16, .right = 24, .bottom = 32 }, badgeRect(12, 20, identity));
}
