const std = @import("std");

pub const Snapshot = struct {
    observed_ms: u64 = 0,
    responsive_ms: u64 = 0,
    unobserved_ms: u64 = 0,
    freezes: u32 = 0,
};

pub const Tracker = struct {
    last: u64,
    until_report: u64 = 60_000,
    snapshot: Snapshot = .{},

    pub fn init(now: u64) Tracker {
        return .{ .last = now };
    }

    pub fn sample(self: *Tracker, now: u64, responsive: bool, freezes: u32) bool {
        const elapsed = now -| self.last;
        self.last = now;
        self.snapshot.freezes +|= freezes;
        if (elapsed <= 2000) {
            self.snapshot.observed_ms +|= elapsed;
            if (responsive) self.snapshot.responsive_ms +|= elapsed;
        } else self.snapshot.unobserved_ms +|= elapsed;
        const covered = self.snapshot.observed_ms;
        if (covered < self.until_report) return false;
        self.until_report = covered +| 3_600_000;
        return true;
    }
};

test "only sampled awake responsive time contributes to coverage" {
    var tracker = Tracker.init(1000);
    try std.testing.expect(!tracker.sample(1500, true, 0));
    try std.testing.expect(!tracker.sample(2000, false, 0));
    try std.testing.expectEqual(@as(u64, 1000), tracker.snapshot.observed_ms);
    try std.testing.expectEqual(@as(u64, 500), tracker.snapshot.responsive_ms);
    try std.testing.expect(!tracker.sample(100_000, true, 0));
    try std.testing.expectEqual(@as(u64, 98_000), tracker.snapshot.unobserved_ms);
    try std.testing.expectEqual(@as(u64, 500), tracker.snapshot.responsive_ms);
    try std.testing.expect(!tracker.sample(1, true, 0));
    try std.testing.expectEqual(@as(u64, 500), tracker.snapshot.responsive_ms);
}

test "first minute and hourly receipts are bounded and cumulative" {
    var tracker = Tracker.init(0);
    var receipts: usize = 0;
    var now: u64 = 500;
    while (now <= 60_000 + 8 * 3_600_000) : (now += 500) {
        if (tracker.sample(now, true, 0)) receipts += 1;
    }
    try std.testing.expectEqual(@as(usize, 9), receipts);
    try std.testing.expectEqual(@as(u64, 60_000 + 8 * 3_600_000), tracker.snapshot.responsive_ms);
}

test "freezes remain visible after recovery and restart resets coverage" {
    var tracker = Tracker.init(0);
    _ = tracker.sample(500, false, 1);
    _ = tracker.sample(1000, true, 0);
    _ = tracker.sample(1500, true, 1);
    try std.testing.expectEqual(@as(u32, 2), tracker.snapshot.freezes);
    tracker = Tracker.init(1500);
    try std.testing.expectEqual(@as(u64, 0), tracker.snapshot.responsive_ms);
    try std.testing.expectEqual(@as(u32, 0), tracker.snapshot.freezes);
}
