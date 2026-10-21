const std = @import("std");

pub const Nearest = struct {
    char: usize,
    dy: i64 = std.math.maxInt(i64),
    dx: i64 = std.math.maxInt(i64),
    top: i32 = std.math.maxInt(i32),
    bottom: i32 = std.math.minInt(i32),

    pub fn consider(self: *Nearest, x: i32, y: i32, left: i32, top: i32, right: i32, bottom: i32, char: usize) void {
        const dy = @max(@as(i64, top) - y, @max(0, @as(i64, y) - bottom + 1));
        const dx = @max(@as(i64, left) - x, @max(0, @as(i64, x) - right));
        self.top = @min(self.top, top);
        self.bottom = @max(self.bottom, bottom);
        if (dy < self.dy or (dy == self.dy and dx < self.dx)) {
            self.char = char;
            self.dy = dy;
            self.dx = dx;
        }
    }

    pub fn boundary(self: Nearest, y: i32, start: usize, end: usize) usize {
        if (y < self.top) return start;
        if (y >= self.bottom) return end;
        return self.char;
    }
};

pub fn nearestBlock(rects: anytype, blocks: anytype, y: i32) ?usize {
    var best: ?usize = null;
    var distance: i64 = std.math.maxInt(i64);
    for (rects, blocks, 0..) |rc, block, i| {
        if (block.role == .tool) continue;
        const dy = @max(@as(i64, rc.top) - y, @max(0, @as(i64, y) - rc.bottom));
        if (dy < distance) {
            best = i;
            distance = dy;
        }
    }
    return best;
}

pub fn keepSelection(same_shell: bool, before: []const u16, after: []const u16, end: usize) bool {
    return same_shell and end <= before.len and end <= after.len and std.mem.eql(u16, before[0..end], after[0..end]);
}

test "ISSUE-438 nearest boundary keeps line ends and outside vertical bounds" {
    var hit = Nearest{ .char = 0 };
    hit.consider(90, 5, 0, 0, 30, 10, 3);
    hit.consider(90, 5, 40, 0, 70, 10, 7);
    hit.consider(90, 5, 0, 10, 20, 20, 10);
    try std.testing.expectEqual(@as(usize, 7), hit.boundary(5, 0, 10));
    try std.testing.expectEqual(@as(usize, 10), hit.boundary(30, 0, 10));
    try std.testing.expectEqual(@as(usize, 0), hit.boundary(-1, 0, 10));
}

test "ISSUE-438 streaming append preserves selection but replacement and switching do not" {
    try std.testing.expect(keepSelection(true, &.{ 1, 2 }, &.{ 1, 2, 3 }, 2));
    try std.testing.expect(!keepSelection(true, &.{ 1, 2 }, &.{ 1, 3 }, 2));
    try std.testing.expect(!keepSelection(false, &.{ 1, 2 }, &.{ 1, 2 }, 2));
    try std.testing.expect(!keepSelection(true, &.{ 1, 2 }, &.{1}, 2));
}

test "ISSUE-438 gaps choose the closest selectable block and ignore tool cards" {
    const Rect = struct { top: i32, bottom: i32 };
    const Block = struct { role: enum { user, tool } };
    const rects = [_]Rect{ .{ .top = 10, .bottom = 30 }, .{ .top = 40, .bottom = 50 }, .{ .top = 70, .bottom = 90 } };
    const blocks = [_]Block{ .{ .role = .user }, .{ .role = .tool }, .{ .role = .user } };
    try std.testing.expectEqual(@as(?usize, 0), nearestBlock(&rects, &blocks, 35));
    try std.testing.expectEqual(@as(?usize, 2), nearestBlock(&rects, &blocks, 65));
    try std.testing.expectEqual(@as(?usize, 0), nearestBlock(&rects, &blocks, -20));
    try std.testing.expectEqual(@as(?usize, 2), nearestBlock(&rects, &blocks, 100));
}
