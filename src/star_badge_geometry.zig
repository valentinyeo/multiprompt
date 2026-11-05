const std = @import("std");

pub const Marker = enum { disconnected, unread, favorite };

pub fn marker(disconnected: bool, unread: bool, favorite: bool, starred: bool) ?Marker {
    if (disconnected) return .disconnected;
    if (unread) return .unread;
    if (favorite and !starred) return .favorite;
    return null;
}

pub const Geometry = struct {
    center_x: i32,
    center_y: i32,
    diameter: i32,
    ring: i32,
};

pub fn geometry(right: i32, bottom: i32, comptime scale: fn (i32) i32) Geometry {
    return .{ .center_x = right - scale(2), .center_y = bottom - scale(2), .diameter = scale(8), .ring = scale(2) };
}

fn identity(px: i32) i32 {
    return px;
}

fn scale150(px: i32) i32 {
    return @divTrunc(px * 150, 100);
}

test "robot marker precedence and starred visibility" {
    for ([_]bool{ false, true }) |disconnected| {
        for ([_]bool{ false, true }) |unread| {
            for ([_]bool{ false, true }) |favorite| {
                for ([_]bool{ false, true }) |starred| {
                    const expected: ?Marker = if (disconnected) .disconnected else if (unread) .unread else if (favorite and !starred) .favorite else null;
                    try std.testing.expectEqual(expected, marker(disconnected, unread, favorite, starred));
                }
            }
        }
    }
}

test "robot marker geometry at 100 and 150 percent" {
    const normal = geometry(50, 60, identity);
    try std.testing.expectEqual(Geometry{ .center_x = 48, .center_y = 58, .diameter = 8, .ring = 2 }, normal);
    const scaled = geometry(75, 90, scale150);
    try std.testing.expectEqual(Geometry{ .center_x = 72, .center_y = 87, .diameter = 12, .ring = 3 }, scaled);
}
