const std = @import("std");

pub const Action = enum { none, start, stop };

pub const IDLE_SKIP_MS: i64 = 5 * 60_000;
pub const IDLE_WAIT_MS: u32 = 5 * 60_000;
pub const BATTERY_WAIT_MS: u32 = 60_000;
pub const ACTIVE_WAIT_MS: u32 = 15_000;

pub fn decide(wanted: bool, running: bool) Action {
    if (wanted and !running) return .start;
    if (!wanted and running) return .stop;
    return .none;
}

pub fn skipRefresh(idle_ms: i64) bool {
    return idle_ms > IDLE_SKIP_MS;
}

pub fn pollWaitMs(idle_ms: i64, battery: bool) u32 {
    if (skipRefresh(idle_ms)) return IDLE_WAIT_MS;
    return if (battery) BATTERY_WAIT_MS else ACTIVE_WAIT_MS;
}

test "a wanted meter starts one worker and an unwanted one stops it" {
    try std.testing.expectEqual(Action.start, decide(true, false));
    try std.testing.expectEqual(Action.stop, decide(false, true));
}

test "a worker in the right state is left alone" {
    try std.testing.expectEqual(Action.none, decide(true, true));
    try std.testing.expectEqual(Action.none, decide(false, false));
}

test "polling slows down on battery and pauses after five idle minutes" {
    try std.testing.expectEqual(ACTIVE_WAIT_MS, pollWaitMs(0, false));
    try std.testing.expectEqual(BATTERY_WAIT_MS, pollWaitMs(0, true));
    try std.testing.expect(!skipRefresh(IDLE_SKIP_MS));
    try std.testing.expect(skipRefresh(IDLE_SKIP_MS + 1));
    try std.testing.expectEqual(IDLE_WAIT_MS, pollWaitMs(IDLE_SKIP_MS + 1, true));
}
