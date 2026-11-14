const std = @import("std");

pub const Gate = struct {
    outstanding: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    dirty: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn request(self: *Gate) bool {
        self.dirty.store(true, .release);
        return !self.outstanding.swap(true, .acq_rel);
    }

    pub fn failed(self: *Gate) void {
        self.outstanding.store(false, .release);
    }

    pub fn begin(self: *Gate) void {
        self.dirty.store(false, .release);
    }

    pub fn finish(self: *Gate) bool {
        self.outstanding.store(false, .release);
        if (!self.dirty.load(.acquire)) return false;
        return !self.outstanding.swap(true, .acq_rel);
    }
};

test "a burst of requests posts once" {
    var gate: Gate = .{};
    try std.testing.expect(gate.request());
    var i: usize = 0;
    while (i < 1000) : (i += 1) try std.testing.expect(!gate.request());
}

test "work that arrives while the handler runs is deferred, not posted" {
    var gate: Gate = .{};
    try std.testing.expect(gate.request());
    gate.begin();
    try std.testing.expect(!gate.request());
    try std.testing.expect(!gate.request());
    try std.testing.expect(gate.finish());
    try std.testing.expect(!gate.request());
    gate.begin();
    try std.testing.expect(!gate.finish());
    try std.testing.expect(gate.request());
}

test "an idle handler leaves no follow up behind" {
    var gate: Gate = .{};
    try std.testing.expect(gate.request());
    gate.begin();
    try std.testing.expect(!gate.finish());
    try std.testing.expect(gate.request());
}

test "a failed post lets the next request post" {
    var gate: Gate = .{};
    try std.testing.expect(gate.request());
    gate.failed();
    try std.testing.expect(gate.request());
}
