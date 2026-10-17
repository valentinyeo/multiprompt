const std = @import("std");

pub const Pending = struct {
    shell_id: u32 = 0,
    painted: bool = false,

    pub fn request(self: *Pending, shell_id: u32) void {
        self.shell_id = shell_id;
        self.painted = false;
    }

    pub fn didPaint(self: *Pending, shell_id: u32) bool {
        if (self.shell_id == 0 or self.shell_id != shell_id or self.painted) return false;
        self.painted = true;
        return true;
    }

    pub fn take(self: *Pending, shell_id: u32) bool {
        if (self.shell_id == 0 or self.shell_id != shell_id or !self.painted) return false;
        self.shell_id = 0;
        return true;
    }

    pub fn cancel(self: *Pending) void {
        self.request(0);
    }
};

test "rapid switches only consume the last painted target" {
    var pending = Pending{};
    pending.request(1);
    try std.testing.expect(!pending.take(1));
    try std.testing.expect(pending.didPaint(1));
    pending.request(2);
    pending.request(3);
    try std.testing.expect(!pending.didPaint(1));
    try std.testing.expect(!pending.take(3));
    try std.testing.expect(pending.didPaint(3));
    try std.testing.expect(!pending.didPaint(3));
    try std.testing.expect(!pending.take(2));
    try std.testing.expect(pending.take(3));
    try std.testing.expect(!pending.take(3));
}

test "cancellation and a new request for the same shell require a new paint" {
    var pending = Pending{};
    pending.request(7);
    _ = pending.didPaint(7);
    pending.cancel();
    try std.testing.expect(!pending.take(7));
    pending.request(7);
    try std.testing.expect(!pending.take(7));
    try std.testing.expect(pending.didPaint(7));
    try std.testing.expect(pending.take(7));
}
