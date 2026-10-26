const std = @import("std");

pub const Action = enum { none, start, up, down, open, leave };

pub const Step = union(enum) { focus: usize, leave, stay };

pub fn action(active: bool, vk: usize, composer_empty: bool, suggestions_open: bool, ctrl: bool, shift: bool, alt: bool) Action {
    if (ctrl or shift or alt) return .none;
    if (!active) {
        if (vk == 0x26 and composer_empty and !suggestions_open) return .start;
        return .none;
    }
    return switch (vk) {
        0x26 => .up,
        0x28 => .down,
        0x0D => .open,
        0x1B => .leave,
        else => .none,
    };
}

pub fn step(current: ?usize, up: bool, eligible: []const bool) Step {
    if (current) |index| {
        if (up) {
            var i = @min(index, eligible.len);
            while (i > 0) {
                i -= 1;
                if (eligible[i]) return .{ .focus = i };
            }
            return .stay;
        }
        var i = index + 1;
        while (i < eligible.len) : (i += 1) {
            if (eligible[i]) return .{ .focus = i };
        }
        return .leave;
    }
    if (!up) return .stay;
    var i = eligible.len;
    while (i > 0) {
        i -= 1;
        if (eligible[i]) return .{ .focus = i };
    }
    return .stay;
}

pub const Anchor = struct { source: u64, segment: u64, stamp: i64 };

pub fn resolve(anchor: Anchor, hint: usize, sources: []const u64, segments: []const u64, stamps: []const i64) ?usize {
    const count = @min(sources.len, @min(segments.len, stamps.len));
    if (hint < count and matches(anchor, sources[hint], segments[hint], stamps[hint])) return hint;
    for (0..count) |i| {
        if (matches(anchor, sources[i], segments[i], stamps[i])) return i;
    }
    return null;
}

fn matches(anchor: Anchor, source: u64, segment: u64, stamp: i64) bool {
    return anchor.source == source and anchor.segment == segment and anchor.stamp == stamp;
}

test "IGSH-992 Up in an empty box starts message focus and a draft or suggestions keep Up" {
    try std.testing.expectEqual(Action.start, action(false, 0x26, true, false, false, false, false));
    try std.testing.expectEqual(Action.none, action(false, 0x26, false, false, false, false, false));
    try std.testing.expectEqual(Action.none, action(false, 0x26, true, true, false, false, false));
    try std.testing.expectEqual(Action.none, action(false, 0x28, true, false, false, false, false));
}

test "IGSH-992 Enter in the box still sends and plain keys never start message focus" {
    for ([_]usize{ 0x0D, 0x1B, 0x41, 0x20 }) |vk| {
        try std.testing.expectEqual(Action.none, action(false, vk, true, false, false, false, false));
        try std.testing.expectEqual(Action.none, action(false, vk, false, false, false, false, false));
    }
}

test "IGSH-992 Enter opens the options only while a message is focused" {
    try std.testing.expectEqual(Action.open, action(true, 0x0D, true, false, false, false, false));
    try std.testing.expectEqual(Action.none, action(false, 0x0D, true, false, false, false, false));
    try std.testing.expectEqual(Action.leave, action(true, 0x1B, true, false, false, false, false));
    try std.testing.expectEqual(Action.up, action(true, 0x26, true, false, false, false, false));
    try std.testing.expectEqual(Action.down, action(true, 0x28, true, false, false, false, false));
}

test "IGSH-992 modified keys never drive message focus" {
    for ([_]bool{ false, true }) |active| {
        for ([_]usize{ 0x26, 0x28, 0x0D, 0x1B }) |vk| {
            try std.testing.expectEqual(Action.none, action(active, vk, true, false, true, false, false));
            try std.testing.expectEqual(Action.none, action(active, vk, true, false, false, true, false));
            try std.testing.expectEqual(Action.none, action(active, vk, true, false, false, false, true));
        }
    }
}

test "IGSH-992 first Up lands on the newest message and skips rows that are not messages" {
    const eligible = [_]bool{ true, true, false, true, false };
    try std.testing.expectEqual(Step{ .focus = 3 }, step(null, true, &eligible));
    try std.testing.expectEqual(Step{ .focus = 1 }, step(3, true, &eligible));
    try std.testing.expectEqual(Step{ .focus = 0 }, step(1, true, &eligible));
    try std.testing.expectEqual(@as(Step, .stay), step(0, true, &eligible));
}

test "IGSH-992 Down walks toward the newest message and leaves past it" {
    const eligible = [_]bool{ true, false, true, true, false };
    try std.testing.expectEqual(Step{ .focus = 2 }, step(0, false, &eligible));
    try std.testing.expectEqual(Step{ .focus = 3 }, step(2, false, &eligible));
    try std.testing.expectEqual(@as(Step, .leave), step(3, false, &eligible));
    try std.testing.expectEqual(@as(Step, .stay), step(null, false, &eligible));
}

test "IGSH-992 an empty transcript has nothing to focus" {
    try std.testing.expectEqual(@as(Step, .stay), step(null, true, &[_]bool{}));
    try std.testing.expectEqual(@as(Step, .stay), step(null, true, &[_]bool{ false, false }));
}

test "IGSH-992 focus follows its message when older history is added above it" {
    const anchor = Anchor{ .source = 700, .segment = 2, .stamp = 55 };
    const before_sources = [_]u64{ 500, 700 };
    const before_segments = [_]u64{ 1, 2 };
    const before_stamps = [_]i64{ 10, 55 };
    try std.testing.expectEqual(@as(?usize, 1), resolve(anchor, 1, &before_sources, &before_segments, &before_stamps));
    const after_sources = [_]u64{ 100, 200, 500, 700 };
    const after_segments = [_]u64{ 0, 1, 1, 2 };
    const after_stamps = [_]i64{ 1, 5, 10, 55 };
    try std.testing.expectEqual(@as(?usize, 3), resolve(anchor, 1, &after_sources, &after_segments, &after_stamps));
    try std.testing.expectEqual(@as(?usize, null), resolve(anchor, 1, &before_sources, &before_segments, &[_]i64{ 10, 56 }));
}
