const std = @import("std");

pub const paint_deadline_ms = 300;

pub const Pending = struct {
    shell_id: u32 = 0,
    painted: bool = false,
    requested_at: u64 = 0,

    pub fn request(self: *Pending, shell_id: u32, now: u64) void {
        self.shell_id = shell_id;
        self.painted = false;
        self.requested_at = now;
    }

    pub fn overdue(self: Pending, shell_id: u32, now: u64) bool {
        return self.shell_id != 0 and self.shell_id == shell_id and !self.painted and
            now -| self.requested_at >= paint_deadline_ms;
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
        self.* = .{};
    }
};

test "rapid switches only consume the last painted target" {
    var pending = Pending{};
    pending.request(1, 1000);
    try std.testing.expect(!pending.take(1));
    try std.testing.expect(pending.didPaint(1));
    pending.request(2, 1000);
    pending.request(3, 1000);
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
    pending.request(7, 1000);
    _ = pending.didPaint(7);
    pending.cancel();
    try std.testing.expect(!pending.take(7));
    pending.request(7, 1000);
    try std.testing.expect(!pending.take(7));
    try std.testing.expect(pending.didPaint(7));
    try std.testing.expect(pending.take(7));
}

test "a switch whose paint never arrives is released after the deadline" {
    var pending = Pending{};
    pending.request(7, 1000);
    try std.testing.expect(!pending.overdue(7, 1299));
    try std.testing.expect(!pending.take(7));
    try std.testing.expect(pending.overdue(7, 1300));
    try std.testing.expect(pending.didPaint(7));
    try std.testing.expect(!pending.overdue(7, 1301));
    try std.testing.expect(pending.take(7));
    try std.testing.expect(!pending.overdue(7, 1400));
}

test "replacement and cancellation cannot inherit an expired paint deadline" {
    var pending = Pending{};
    pending.request(7, 1000);
    pending.request(8, 1250);
    try std.testing.expect(!pending.overdue(7, 1400));
    try std.testing.expect(!pending.overdue(8, 1400));
    try std.testing.expect(pending.overdue(8, 1550));
    pending.request(8, 1600);
    try std.testing.expect(!pending.overdue(8, 1899));
    try std.testing.expect(!pending.overdue(8, 1500));
    pending.cancel();
    try std.testing.expect(!pending.overdue(8, 2000));
    try std.testing.expect(!pending.overdue(0, 2000));
}
