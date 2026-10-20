const std = @import("std");

pub const ISSUE_355_DOUBLE_CLICK_TOGGLE = true;

pub fn chatTargetBlank(rects: anytype, x: i32, y: i32, selected: bool, interactive: bool) bool {
    if (selected or interactive) return false;
    for (rects) |rc| {
        if (x >= rc.left and x < rc.right and y >= rc.top and y < rc.bottom) return false;
    }
    return true;
}

pub fn shellCellBlank(char: u16) bool {
    return char == 0 or char == ' ';
}

pub fn doubleClick(elapsed: u32, dx: i64, dy: i64, time: u32, width: i32, height: i32) bool {
    return elapsed <= time and width > 0 and height > 0 and
        @abs(dx) * 2 <= @as(u64, @intCast(width)) and @abs(dy) * 2 <= @as(u64, @intCast(height));
}

pub const TrackedMouseAction = enum { ignore, clear, need_eligibility };

pub fn trackedMouseAction(mouse_move: bool, within: ?bool) TrackedMouseAction {
    const valid = within orelse return .ignore;
    if (!valid) return .clear;
    return if (mouse_move) .ignore else .need_eligibility;
}

test "ISSUE-355 mouse moves never need eligibility and untracked releases are ignored" {
    try std.testing.expectEqual(TrackedMouseAction.ignore, trackedMouseAction(true, null));
    try std.testing.expectEqual(TrackedMouseAction.ignore, trackedMouseAction(true, true));
    try std.testing.expectEqual(TrackedMouseAction.clear, trackedMouseAction(true, false));
    try std.testing.expectEqual(TrackedMouseAction.ignore, trackedMouseAction(false, null));
    try std.testing.expectEqual(TrackedMouseAction.clear, trackedMouseAction(false, false));
    try std.testing.expectEqual(TrackedMouseAction.need_eligibility, trackedMouseAction(false, true));
}

test "ISSUE-355 Chat background excludes block rectangles, selection and interactive targets" {
    const Rect = struct { left: i32, top: i32, right: i32, bottom: i32 };
    const rects = [_]Rect{
        .{ .left = 20, .top = 10, .right = 200, .bottom = 40 },
        .{ .left = 40, .top = 60, .right = 200, .bottom = 90 },
    };
    try std.testing.expect(!chatTargetBlank(&rects, 25, 15, false, false));
    try std.testing.expect(!chatTargetBlank(&rects, 199, 39, false, false));
    try std.testing.expect(chatTargetBlank(&rects, 25, 40, false, false));
    try std.testing.expect(chatTargetBlank(&rects, 25, 50, false, false));
    try std.testing.expect(chatTargetBlank(&rects, 10, 15, false, false));
    try std.testing.expect(chatTargetBlank(&rects, 50, 100, false, false));
    try std.testing.expect(!chatTargetBlank(&rects, 50, 100, true, false));
    for ([_][]const u8{ "tool", "copy", "image", "link", "find" }) |_| {
        try std.testing.expect(!chatTargetBlank(&rects, 50, 100, false, true));
    }
}

test "ISSUE-355 only space and NUL console cells are blank" {
    try std.testing.expect(shellCellBlank(0));
    try std.testing.expect(shellCellBlank(' '));
    for ([_]u16{ 'a', '1', '\t', '\n', 0xa0, 0x3000, 0x4e2d, 0xd83d, 0xde00 }) |char| {
        try std.testing.expect(!shellCellBlank(char));
    }
}

test "ISSUE-355 double click respects system time and half rectangle distance" {
    try std.testing.expect(doubleClick(500, 2, -2, 500, 4, 4));
    try std.testing.expect(!doubleClick(501, 0, 0, 500, 4, 4));
    try std.testing.expect(!doubleClick(100, 3, 0, 500, 4, 4));
    try std.testing.expect(!doubleClick(100, 0, -3, 500, 4, 4));
    try std.testing.expect(!doubleClick(100, 0, 0, 500, 0, 4));
    try std.testing.expect(!doubleClick(100, 0, 0, 500, 4, -1));
    try std.testing.expect(!doubleClick(100, std.math.maxInt(i32), std.math.minInt(i32), 500, 4, 4));
    try std.testing.expect(doubleClick(@as(u32, 10) -% @as(u32, 0xfffffff0), 0, 0, 500, 4, 4));
}
