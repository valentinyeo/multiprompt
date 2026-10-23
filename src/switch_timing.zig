const std = @import("std");
const win = @import("win32.zig");
const diagnostics = @import("diagnostics.zig");

pub const Step = enum {
    console_shown,
    hide_prev_browser,
    park,
    browser_visible,
    arm_settle,
    position,
    focus,
    reposition,
    browser_swp,
    browser_show,
    browser_launch,
    browser_wake,
};

pub const Trace = struct {
    started: i64 = 0,
    frequency: i64 = 1,
    ticks: [std.meta.fields(Step).len]i64 = @splat(0),
};

threadlocal var active: ?*Trace = null;

pub fn begin(trace: *Trace) ?*Trace {
    const previous = active;
    if (!diagnostics.verboseLoggingEnabled()) return previous;
    _ = win.QueryPerformanceFrequency(&trace.frequency);
    _ = win.QueryPerformanceCounter(&trace.started);
    active = trace;
    return previous;
}

pub fn start() i64 {
    if (active == null) return 0;
    var now: i64 = 0;
    _ = win.QueryPerformanceCounter(&now);
    return now;
}

pub fn record(step: Step, started: i64) void {
    const trace = active orelse return;
    trace.ticks[@intFromEnum(step)] += start() -| started;
}

pub fn finish(trace: *Trace, previous: ?*Trace, idx: u32) void {
    if (active != trace) return;
    const total = start() -| trace.started;
    active = previous;
    var buf: [1024]u8 = undefined;
    var used: usize = 0;
    const header = std.fmt.bufPrint(&buf, "switch-timing: to={d} total_us={d}", .{ idx, @divTrunc(total * 1_000_000, @max(1, trace.frequency)) }) catch return;
    used = header.len;
    inline for (std.meta.fields(Step), 0..) |field, i| {
        const part = std.fmt.bufPrint(buf[used..], " " ++ field.name ++ "_us={d}", .{@divTrunc(trace.ticks[i] * 1_000_000, @max(1, trace.frequency))}) catch return;
        used += part.len;
    }
    diagnostics.debugLog(buf[0..used]);
}
