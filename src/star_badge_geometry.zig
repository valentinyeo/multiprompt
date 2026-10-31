const std = @import("std");

pub const Geometry = struct {
    center_x: i32,
    center_y: i32,
    diameter: i32,
    ring: i32,
    star: i32,
};

pub fn diameter(avatar: i32) i32 {
    return @min(18, @max(11, @divTrunc(avatar * 2 + 4, 5)));
}

pub fn geometry(right: i32, bottom: i32, avatar: i32, comptime scale: fn (i32) i32) Geometry {
    const size = scale(diameter(avatar));
    const offset = scale(4);
    return .{ .center_x = right - offset, .center_y = bottom - offset, .diameter = size, .ring = scale(2), .star = @divTrunc(size * 62, 100) };
}

fn identity(px: i32) i32 {
    return px;
}

fn scale150(px: i32) i32 {
    return @divTrunc(px * 150, 100);
}

test "star badge geometry at 100 and 150 percent" {
    try std.testing.expectEqual(@as(i32, 11), diameter(24));
    try std.testing.expectEqual(@as(i32, 15), diameter(36));
    try std.testing.expectEqual(@as(i32, 16), diameter(40));
    try std.testing.expectEqual(@as(i32, 18), diameter(56));
    const cases = [_]struct { avatar: i32, right: i32, bottom: i32, size: i32, ring: i32, x: i32, y: i32, star: i32, scaled: bool }{
        .{ .avatar = 40, .right = 50, .bottom = 60, .size = 16, .ring = 2, .x = 46, .y = 56, .star = 9, .scaled = false },
        .{ .avatar = 40, .right = 75, .bottom = 90, .size = 24, .ring = 3, .x = 69, .y = 84, .star = 14, .scaled = true },
        .{ .avatar = 56, .right = 66, .bottom = 76, .size = 18, .ring = 2, .x = 62, .y = 72, .star = 11, .scaled = false },
        .{ .avatar = 56, .right = 99, .bottom = 114, .size = 27, .ring = 3, .x = 93, .y = 108, .star = 16, .scaled = true },
    };
    for (cases) |case| {
        const g = if (case.scaled) geometry(case.right, case.bottom, case.avatar, scale150) else geometry(case.right, case.bottom, case.avatar, identity);
        try std.testing.expectEqual(case.x, g.center_x);
        try std.testing.expectEqual(case.y, g.center_y);
        try std.testing.expectEqual(case.size, g.diameter);
        try std.testing.expectEqual(case.ring, g.ring);
        try std.testing.expectEqual(case.star, g.star);
        try std.testing.expect(g.star > 0 and g.star < g.diameter);
        try std.testing.expect(g.center_x < case.right and g.center_y < case.bottom);
        try std.testing.expect(g.center_x + @divTrunc(g.diameter, 2) + g.ring > case.right);
    }
}
