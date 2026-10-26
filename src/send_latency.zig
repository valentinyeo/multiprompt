const std = @import("std");
const win = @import("win32.zig");
const diagnostics = @import("diagnostics.zig");

var pressed: i64 = 0;
var enqueued: i64 = 0;
var pending_id: u64 = 0;
var drawn_id: u64 = 0;

fn now() i64 {
    var value: i64 = 0;
    _ = win.QueryPerformanceCounter(&value);
    return value;
}

fn micros(from: i64, to: i64) i64 {
    var frequency: i64 = 1;
    _ = win.QueryPerformanceFrequency(&frequency);
    return @divTrunc((to -| from) * 1_000_000, @max(1, frequency));
}

pub fn markPressed() void {
    if (!diagnostics.verboseLoggingEnabled()) return;
    pending_id = 0;
    pressed = now();
}

pub fn markEnqueued(id: u64) void {
    if (!diagnostics.verboseLoggingEnabled() or pressed == 0) return;
    enqueued = now();
    pending_id = id;
}

pub fn noteDrawn(id: u64) void {
    if (pending_id != 0 and id == pending_id) drawn_id = id;
}

pub fn markPainted() void {
    const id = drawn_id;
    drawn_id = 0;
    if (id == 0 or pending_id != id) return;
    pending_id = 0;
    const painted = now();
    var buf: [160]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "[chat] send-latency id={d} enqueue_us={d} painted_us={d}", .{ id, micros(pressed, enqueued), micros(pressed, painted) }) catch return;
    diagnostics.debugLog(line);
}
