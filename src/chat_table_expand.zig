const std = @import("std");

pub const Rect = struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,

    pub fn contains(self: Rect, x: i32, y: i32) bool {
        return x >= self.left and x < self.right and y >= self.top and y < self.bottom;
    }
};

pub const Size = struct { w: i32, h: i32 };

pub const Spacing = struct { pad: i32, margin: i32, close: i32 };

pub const Hit = enum { close, card, outside };

pub const Geometry = struct {
    card: Rect,
    body: Rect,
    close: Rect,

    pub fn hit(self: Geometry, x: i32, y: i32) Hit {
        if (self.close.contains(x, y)) return .close;
        if (self.card.contains(x, y)) return .card;
        return .outside;
    }
};

pub fn bodyLimit(window: Rect, spacing: Spacing) Size {
    const inset = 2 * spacing.margin + spacing.close + spacing.pad;
    return .{ .w = @max(1, window.right - window.left - 2 * inset), .h = @max(1, window.bottom - window.top - 2 * inset) };
}

pub fn place(window: Rect, spacing: Spacing, content: Size) Geometry {
    const limit = bodyLimit(window, spacing);
    const w = std.math.clamp(content.w, 1, limit.w);
    const h = std.math.clamp(content.h, 1, limit.h);
    const left = window.left + @divFloor(window.right - window.left - w, 2);
    const top = window.top + @divFloor(window.bottom - window.top - h, 2);
    const body = Rect{ .left = left, .top = top, .right = left + w, .bottom = top + h };
    return .{
        .body = body,
        .card = .{ .left = body.left - spacing.pad, .top = body.top - spacing.pad, .right = body.right + spacing.pad, .bottom = body.bottom + spacing.pad },
        .close = .{ .left = window.right - spacing.margin - spacing.close, .top = window.top + spacing.margin, .right = window.right - spacing.margin, .bottom = window.top + spacing.margin + spacing.close },
    };
}

pub const Scroll = struct {
    x: i32 = 0,
    y: i32 = 0,

    pub fn by(self: *Scroll, content: Size, view: Size, dx: i32, dy: i32) bool {
        const x: i32 = @intCast(std.math.clamp(@as(i64, self.x) + dx, 0, @max(0, content.w - view.w)));
        const y: i32 = @intCast(std.math.clamp(@as(i64, self.y) + dy, 0, @max(0, content.h - view.h)));
        const moved = x != self.x or y != self.y;
        self.x = x;
        self.y = y;
        return moved;
    }
};

pub const Command = union(enum) {
    none,
    close,
    scroll: struct { dx: i32, dy: i32 },
};

const far: i32 = 1 << 28;

pub fn key(vk: usize, line: i32, page: Size) Command {
    return switch (vk) {
        0x1b => .close,
        0x26 => .{ .scroll = .{ .dx = 0, .dy = -line } },
        0x28 => .{ .scroll = .{ .dx = 0, .dy = line } },
        0x21 => .{ .scroll = .{ .dx = 0, .dy = -page.h } },
        0x22 => .{ .scroll = .{ .dx = 0, .dy = page.h } },
        0x24 => .{ .scroll = .{ .dx = 0, .dy = -far } },
        0x23 => .{ .scroll = .{ .dx = 0, .dy = far } },
        0x25 => .{ .scroll = .{ .dx = -line, .dy = 0 } },
        0x27 => .{ .scroll = .{ .dx = line, .dy = 0 } },
        else => .none,
    };
}

pub fn click(geometry: Geometry, x: i32, y: i32) Command {
    return if (geometry.hit(x, y) == .card) .none else .close;
}

pub fn wheel(delta: i32, step: i32, horizontal: bool, shift: bool) Command {
    const amount = @divTrunc(delta * step, 120);
    if (horizontal) return .{ .scroll = .{ .dx = amount, .dy = 0 } };
    if (shift) return .{ .scroll = .{ .dx = -amount, .dy = 0 } };
    return .{ .scroll = .{ .dx = 0, .dy = -amount } };
}

pub const Nearest = struct {
    view_top: i32,
    view_bottom: i32,
    index: ?usize = null,
    shown: i32 = 0,
    gap: i32 = std.math.maxInt(i32),

    pub fn consider(self: *Nearest, index: usize, top: i32, bottom: i32) void {
        const shown = @min(bottom, self.view_bottom) - @max(top, self.view_top);
        if (shown > 0) {
            if (shown >= self.shown) {
                self.index = index;
                self.shown = shown;
            }
            return;
        }
        if (self.shown > 0) return;
        const gap = if (bottom <= self.view_top) self.view_top - bottom else top - self.view_bottom;
        if (gap <= self.gap) {
            self.index = index;
            self.gap = gap;
        }
    }
};

const test_window = Rect{ .left = 0, .top = 0, .right = 1920, .bottom = 1032 };
const test_spacing = Spacing{ .pad = 12, .margin = 24, .close = 28 };

test "IGSH-1897 a table that fits opens at its natural size in a centered card" {
    const g = place(test_window, test_spacing, .{ .w = 1080, .h = 260 });
    try std.testing.expectEqual(@as(i32, 1080), g.body.right - g.body.left);
    try std.testing.expectEqual(@as(i32, 260), g.body.bottom - g.body.top);
    try std.testing.expectEqual(test_window.right - g.card.right, g.card.left - test_window.left);
    try std.testing.expectEqual(test_window.bottom - g.card.bottom, g.card.top - test_window.top);
    try std.testing.expectEqual(g.body.left - test_spacing.pad, g.card.left);
    try std.testing.expectEqual(g.body.bottom + test_spacing.pad, g.card.bottom);
}

test "IGSH-1897 a table larger than the window is capped and scrolls to its far edges" {
    const g = place(test_window, test_spacing, .{ .w = 4000, .h = 3000 });
    const limit = bodyLimit(test_window, test_spacing);
    try std.testing.expectEqual(limit.w, g.body.right - g.body.left);
    try std.testing.expectEqual(limit.h, g.body.bottom - g.body.top);
    try std.testing.expect(g.card.left > 0 and g.card.top > 0 and g.card.right < test_window.right and g.card.bottom < test_window.bottom);
    try std.testing.expect(g.close.left >= g.card.right or g.close.bottom <= g.card.top);
    var scroll: Scroll = .{};
    const content = Size{ .w = 4000, .h = 3000 };
    try std.testing.expect(!scroll.by(content, limit, -50, -50));
    const end = key(0x23, 20, limit).scroll;
    try std.testing.expect(scroll.by(content, limit, end.dx, end.dy));
    try std.testing.expectEqual(content.h - limit.h, scroll.y);
    const right = key(0x27, 20, limit).scroll;
    try std.testing.expect(scroll.by(content, limit, right.dx, right.dy));
    try std.testing.expectEqual(@as(i32, 20), scroll.x);
    const home = key(0x24, 20, limit).scroll;
    try std.testing.expect(scroll.by(content, limit, home.dx, home.dy));
    try std.testing.expectEqual(@as(i32, 0), scroll.y);
    var small: Scroll = .{};
    try std.testing.expect(!small.by(.{ .w = 300, .h = 200 }, .{ .w = 300, .h = 200 }, 0, 120));
}

test "IGSH-1897 Escape, the X and a click outside close the table; a click on it does not" {
    const g = place(test_window, test_spacing, .{ .w = 800, .h = 300 });
    try std.testing.expectEqual(@as(Command, .close), key(0x1b, 20, .{ .w = 800, .h = 300 }));
    try std.testing.expectEqual(@as(Command, .none), key(0x41, 20, .{ .w = 800, .h = 300 }));
    try std.testing.expectEqual(Hit.close, g.hit(g.close.left + 1, g.close.top + 1));
    try std.testing.expectEqual(@as(Command, .close), click(g, g.close.left + 1, g.close.top + 1));
    try std.testing.expectEqual(@as(Command, .close), click(g, 5, 5));
    try std.testing.expectEqual(@as(Command, .close), click(g, g.card.left - 1, g.card.top + 10));
    try std.testing.expectEqual(@as(Command, .none), click(g, g.card.left, g.card.top));
    try std.testing.expectEqual(@as(Command, .none), click(g, g.body.left + 10, g.body.top + 10));
}

test "IGSH-1897 the mouse wheel scrolls down, Shift and the tilt wheel scroll sideways" {
    try std.testing.expectEqual(@as(i32, 54), wheel(-120, 54, false, false).scroll.dy);
    try std.testing.expectEqual(@as(i32, 0), wheel(-120, 54, false, false).scroll.dx);
    try std.testing.expectEqual(@as(i32, 54), wheel(-120, 54, false, true).scroll.dx);
    try std.testing.expectEqual(@as(i32, 54), wheel(120, 54, true, false).scroll.dx);
}

test "IGSH-1897 the palette picks the most visible table, else the nearest, else the last" {
    const none = Nearest{ .view_top = 100, .view_bottom = 500 };
    try std.testing.expectEqual(@as(?usize, null), none.index);
    var visible = Nearest{ .view_top = 100, .view_bottom = 500 };
    visible.consider(2, 0, 150);
    visible.consider(5, 200, 450);
    visible.consider(9, 480, 900);
    try std.testing.expectEqual(@as(?usize, 5), visible.index);
    var above = Nearest{ .view_top = 1000, .view_bottom = 1400 };
    above.consider(1, 0, 200);
    above.consider(4, 300, 900);
    above.consider(7, 1600, 1800);
    try std.testing.expectEqual(@as(?usize, 4), above.index);
    var tie = Nearest{ .view_top = 1000, .view_bottom = 1400 };
    tie.consider(3, 100, 200);
    tie.consider(6, 2200, 2300);
    try std.testing.expectEqual(@as(?usize, 6), tie.index);
    var equal = Nearest{ .view_top = 0, .view_bottom = 400 };
    equal.consider(0, 0, 100);
    equal.consider(1, 200, 300);
    try std.testing.expectEqual(@as(?usize, 1), equal.index);
}
