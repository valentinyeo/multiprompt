const std = @import("std");

pub const Step = enum { snapshot, paint, account, links, telemetry, tabs, browser };
pub const steps = [_]Step{ .snapshot, .paint, .account, .telemetry, .links, .tabs, .browser };

pub const Deferred = enum {
    account,
    workspace_registry,
    browser_config,
    integrations,
    window_identity,
    jobs,
    icons,
    jump_list,
    hooks,
    power,
    telemetry,
    links,
    tabs,
    chat,
    cleanup,
    publish,
    updates,
    browser,
    theme,
    focus,
    account_base,
    done,
};

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

pub fn isInput(message: u32) bool {
    return switch (message) {
        0x0100, 0x0102, 0x0104, 0x0201, 0x0203, 0x0204, 0x0207, 0x020A, 0x020B, 0x020E => true,
        else => false,
    };
}

test "ISSUE-543 first accepted input excludes paint timers and synthetic focus" {
    for ([_]u32{ 0x0100, 0x0102, 0x0104, 0x0201, 0x020A }) |message| try std.testing.expect(isInput(message));
    for ([_]u32{ 0x0007, 0x000F, 0x0113, 0x0200, 0x8000 + 502 }) |message| try std.testing.expect(!isInput(message));
}

test "ISSUE-543 cleanup follows reclaim and browser follows local restore" {
    try std.testing.expect(@intFromEnum(Deferred.links) < @intFromEnum(Deferred.tabs));
    try std.testing.expect(@intFromEnum(Deferred.tabs) < @intFromEnum(Deferred.cleanup));
    try std.testing.expect(@intFromEnum(Deferred.tabs) < @intFromEnum(Deferred.browser));
}
