const std = @import("std");

pub const Step = enum { snapshot, paint, account, links, telemetry, tabs, browser };
pub const steps = [_]Step{ .snapshot, .paint, .account, .telemetry, .links, .tabs, .browser };

pub const Queue = struct {
    next: usize = 0,
    pub fn pop(self: *Queue) ?Step {
        if (self.next == steps.len) return null;
        defer self.next += 1;
        return steps[self.next];
    }
};

test "ISSUE-502 cached chat and sidebar paint before any deferred startup work" {
    var queue: Queue = .{};
    try std.testing.expectEqual(Step.snapshot, queue.pop().?);
    try std.testing.expectEqual(Step.paint, queue.pop().?);
    for ([_]Step{ .account, .telemetry, .links, .tabs, .browser }) |step| try std.testing.expectEqual(step, queue.pop().?);
    try std.testing.expect(queue.pop() == null);
}
