const std = @import("std");
const win32 = @import("win32.zig");

pub const Tracker = struct {
    anchor: ?win32.POINT = null,

    pub fn keyboard(self: *Tracker) void {
        var point: win32.POINT = undefined;
        self.anchor = if (win32.GetCursorPos(&point) != 0) point else null;
    }

    pub fn hover(self: *Tracker) bool {
        var point: win32.POINT = undefined;
        if (win32.GetCursorPos(&point) == 0) return false;
        return self.moved(point);
    }

    fn moved(self: *Tracker, point: win32.POINT) bool {
        const anchor = self.anchor orelse {
            self.anchor = point;
            return false;
        };
        if (@abs(@as(i64, point.x) - anchor.x) < 3 and @abs(@as(i64, point.y) - anchor.y) < 3) return false;
        self.anchor = point;
        return true;
    }
};

pub var palette: Tracker = .{};
pub var skills: Tracker = .{};

test "IGSH-836 stationary hover and jitter do not take selection" {
    var tracker: Tracker = .{};
    try std.testing.expect(!tracker.moved(.{ .x = 100, .y = 200 }));
    for (0..10) |_| {
        try std.testing.expect(!tracker.moved(.{ .x = 100, .y = 200 }));
        try std.testing.expect(!tracker.moved(.{ .x = 101, .y = 199 }));
        try std.testing.expect(!tracker.moved(.{ .x = 98, .y = 202 }));
    }
    try std.testing.expect(tracker.moved(.{ .x = 103, .y = 200 }));
    try std.testing.expect(!tracker.moved(.{ .x = 103, .y = 200 }));
    try std.testing.expect(tracker.moved(.{ .x = 103, .y = 197 }));
}

test "IGSH-836 small moves accumulate and keyboard reanchors independently" {
    var tracker: Tracker = .{ .anchor = .{ .x = -100, .y = -200 } };
    try std.testing.expect(!tracker.moved(.{ .x = -99, .y = -200 }));
    try std.testing.expect(!tracker.moved(.{ .x = -98, .y = -200 }));
    try std.testing.expect(tracker.moved(.{ .x = -97, .y = -200 }));
    tracker.anchor = .{ .x = -96, .y = -200 };
    try std.testing.expect(!tracker.moved(.{ .x = -94, .y = -200 }));
    try std.testing.expect(tracker.moved(.{ .x = -93, .y = -200 }));
    var other: Tracker = .{ .anchor = .{ .x = -100, .y = -200 } };
    try std.testing.expect(!other.moved(.{ .x = -100, .y = -200 }));
}
