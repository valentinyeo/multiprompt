const std = @import("std");

pub const FIRST_PORT: u16 = 19548;
pub const PORT_COUNT: usize = 24;

pub const NOTIFY_PORTS = blk: {
    var ports: [PORT_COUNT]u16 = undefined;
    for (&ports, 0..) |*port, i| port.* = FIRST_PORT + @as(u16, @intCast(i));
    break :blk ports;
};

test "the notify port list outlasts the twelve ports a laptop had pinned on 2026-10-25" {
    try std.testing.expect(NOTIFY_PORTS.len >= 24);
    try std.testing.expectEqual(@as(u16, 19548), NOTIFY_PORTS[0]);
    for (NOTIFY_PORTS[1..], 1..) |port, i| try std.testing.expectEqual(NOTIFY_PORTS[i - 1] + 1, port);
}
