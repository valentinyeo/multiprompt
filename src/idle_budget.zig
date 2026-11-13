const std = @import("std");

pub const Source = enum(u8) {
    server_fetch,
    thread_spawn,
    invalidate,
    timer_fire,
    log_line,
    process_spawn,
};

pub const SOURCE_COUNT: usize = @typeInfo(Source).@"enum".fields.len;
pub const Counts = [SOURCE_COUNT]u32;
pub const TIMER_SLOTS: usize = 256;
pub const TIMER_OVERFLOW: usize = TIMER_SLOTS - 1;
pub const IDLE_AFTER_MS: u64 = 60_000;
pub const LOG_RING_SLOTS: usize = 256;

pub const WM_PAINT: u32 = 0x000F;
pub const WM_TIMER: u32 = 0x0113;
pub const WM_KEYDOWN: u32 = 0x0100;
pub const WM_SYSKEYDOWN: u32 = 0x0104;
pub const WM_LBUTTONDOWN: u32 = 0x0201;
pub const WM_RBUTTONDOWN: u32 = 0x0204;
pub const WM_MBUTTONDOWN: u32 = 0x0207;
pub const WM_MOUSEWHEEL: u32 = 0x020A;
pub const WM_XBUTTONDOWN: u32 = 0x020B;

var g_counts: Counts = @splat(0);
var g_timers: [TIMER_SLOTS]u32 = @splat(0);
var g_input_epoch: u32 = 0;
var g_window: IdleWindow = .{};
var g_published_window_ms: u32 = 0;
var g_published_delta: Counts = @splat(0);
var g_ring: [LOG_RING_SLOTS]u64 = @splat(0);
var g_ring_next: usize = 0;
var g_ring_epoch: u32 = 0;
var g_ring_lock: u32 = 0;

pub fn bump(source: Source) void {
    _ = @atomicRmw(u32, &g_counts[@intFromEnum(source)], .Add, 1, .monotonic);
}

pub fn timerSlot(id: usize) usize {
    return if (id < TIMER_OVERFLOW) id else TIMER_OVERFLOW;
}

pub fn timerFired(id: usize) void {
    _ = @atomicRmw(u32, &g_timers[timerSlot(id)], .Add, 1, .monotonic);
    bump(.timer_fire);
}

pub fn userInput() void {
    _ = @atomicRmw(u32, &g_input_epoch, .Add, 1, .monotonic);
}

pub fn isInputMessage(message: u32) bool {
    return switch (message) {
        WM_KEYDOWN, WM_SYSKEYDOWN, WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_MOUSEWHEEL, WM_XBUTTONDOWN => true,
        else => false,
    };
}

pub fn pumped(message: u32, wparam: usize) void {
    switch (message) {
        WM_TIMER => timerFired(wparam),
        WM_PAINT => bump(.invalidate),
        else => if (isInputMessage(message)) userInput(),
    }
}

pub fn snapshot() Counts {
    var out: Counts = undefined;
    for (&out, 0..) |*slot, i| slot.* = @atomicLoad(u32, &g_counts[i], .monotonic);
    return out;
}

pub fn timerSnapshot() [TIMER_SLOTS]u32 {
    var out: [TIMER_SLOTS]u32 = undefined;
    for (&out, 0..) |*slot, i| slot.* = @atomicLoad(u32, &g_timers[i], .monotonic);
    return out;
}

pub const IdleReport = struct {
    window_ms: u64 = 0,
    delta: Counts = @splat(0),
};

pub const IdleWindow = struct {
    active: bool = false,
    start_ms: u64 = 0,
    end_ms: u64 = 0,
    base: Counts = @splat(0),
    last: Counts = @splat(0),

    pub fn update(self: *IdleWindow, now_ms: u64, idle_ms: u64, current: Counts) void {
        if (idle_ms < IDLE_AFTER_MS) {
            self.active = false;
            return;
        }
        if (!self.active) {
            self.active = true;
            self.start_ms = now_ms;
            self.base = current;
        }
        self.end_ms = now_ms;
        self.last = current;
    }

    pub fn report(self: *const IdleWindow) IdleReport {
        var out: IdleReport = .{ .window_ms = self.end_ms -| self.start_ms };
        for (self.last, self.base, 0..) |last, base, i| out.delta[i] = last -% base;
        return out;
    }
};

pub fn tick(now_ms: u64, idle_ms: u64) void {
    g_window.update(now_ms, idle_ms, snapshot());
    const report = g_window.report();
    const window_ms: u32 = @intCast(@min(report.window_ms, std.math.maxInt(u32)));
    @atomicStore(u32, &g_published_window_ms, window_ms, .release);
    for (report.delta, 0..) |value, i| @atomicStore(u32, &g_published_delta[i], value, .monotonic);
}

pub fn lastIdle() IdleReport {
    var out: IdleReport = .{ .window_ms = @atomicLoad(u32, &g_published_window_ms, .acquire) };
    for (&out.delta, 0..) |*slot, i| slot.* = @atomicLoad(u32, &g_published_delta[i], .monotonic);
    return out;
}

pub fn perMinuteTenths(delta: u32, window_ms: u64) u64 {
    if (window_ms == 0) return 0;
    return (@as(u64, delta) * 600_000 + window_ms / 2) / window_ms;
}

pub fn formatIdle(buf: []u8, report: IdleReport) []const u8 {
    if (report.window_ms == 0) return "idle none";
    const head = std.fmt.bufPrint(buf, "idle {d}s per min:", .{report.window_ms / 1000}) catch return "idle none";
    var len = head.len;
    inline for (@typeInfo(Source).@"enum".fields, 0..) |field, i| {
        const tenths = perMinuteTenths(report.delta[i], report.window_ms);
        const part = std.fmt.bufPrint(buf[len..], " {s}={d}.{d}", .{ field.name, tenths / 10, tenths % 10 }) catch return buf[0..len];
        len += part.len;
    }
    return buf[0..len];
}

pub fn formatDump(buf: []u8, tick_ms: u64, idle_ms: u64, deep_idle: bool, counts: Counts, timers: [TIMER_SLOTS]u32) []const u8 {
    const head = std.fmt.bufPrint(buf, "{{\"tick_ms\":{d},\"idle_ms\":{d},\"deep_idle\":{d}", .{ tick_ms, idle_ms, @intFromBool(deep_idle) }) catch return "";
    var len = head.len;
    inline for (@typeInfo(Source).@"enum".fields, 0..) |field, i| {
        const part = std.fmt.bufPrint(buf[len..], ",\"{s}\":{d}", .{ field.name, counts[i] }) catch return "";
        len += part.len;
    }
    const open = std.fmt.bufPrint(buf[len..], ",\"timers\":{{", .{}) catch return "";
    len += open.len;
    var first = true;
    for (timers, 0..) |value, id| {
        if (value == 0) continue;
        const part = std.fmt.bufPrint(buf[len..], "{s}\"{d}\":{d}", .{ if (first) "" else ",", id, value }) catch return "";
        len += part.len;
        first = false;
    }
    const tail = std.fmt.bufPrint(buf[len..], "}}}}", .{}) catch return "";
    len += tail.len;
    return buf[0..len];
}

pub fn hashLine(msg: []const u8) u64 {
    var hash: u64 = 0xcbf29ce484222325;
    for (msg) |byte| {
        hash ^= byte;
        hash *%= 0x100000001b3;
    }
    return if (hash == 0) 1 else hash;
}

fn ringLock() void {
    while (@cmpxchgWeak(u32, &g_ring_lock, 0, 1, .acquire, .monotonic) != null) std.atomic.spinLoopHint();
}

fn ringUnlock() void {
    @atomicStore(u32, &g_ring_lock, 0, .release);
}

pub fn logFirstTime(msg: []const u8) bool {
    const hash = hashLine(msg);
    ringLock();
    defer ringUnlock();
    const epoch = @atomicLoad(u32, &g_input_epoch, .monotonic);
    if (epoch != g_ring_epoch) {
        g_ring_epoch = epoch;
        g_ring = @splat(0);
        g_ring_next = 0;
    }
    for (g_ring) |seen| {
        if (seen == hash) return false;
    }
    g_ring[g_ring_next] = hash;
    g_ring_next = (g_ring_next + 1) % LOG_RING_SLOTS;
    return true;
}

pub fn resetForTest() void {
    g_counts = @splat(0);
    g_timers = @splat(0);
    g_input_epoch = 0;
    g_window = .{};
    g_published_window_ms = 0;
    g_published_delta = @splat(0);
    g_ring = @splat(0);
    g_ring_next = 0;
    g_ring_epoch = 0;
}

test "bump counts each source on its own slot" {
    resetForTest();
    bump(.server_fetch);
    bump(.server_fetch);
    bump(.process_spawn);
    const counts = snapshot();
    try std.testing.expectEqual(@as(u32, 2), counts[@intFromEnum(Source.server_fetch)]);
    try std.testing.expectEqual(@as(u32, 1), counts[@intFromEnum(Source.process_spawn)]);
    try std.testing.expectEqual(@as(u32, 0), counts[@intFromEnum(Source.thread_spawn)]);
}

test "the pump counts timers per id, paints, and input" {
    resetForTest();
    pumped(WM_TIMER, 2);
    pumped(WM_TIMER, 2);
    pumped(WM_TIMER, 500);
    pumped(WM_PAINT, 0);
    pumped(0x0200, 0);
    const counts = snapshot();
    const timers = timerSnapshot();
    try std.testing.expectEqual(@as(u32, 3), counts[@intFromEnum(Source.timer_fire)]);
    try std.testing.expectEqual(@as(u32, 1), counts[@intFromEnum(Source.invalidate)]);
    try std.testing.expectEqual(@as(u32, 2), timers[2]);
    try std.testing.expectEqual(@as(u32, 1), timers[TIMER_OVERFLOW]);
    try std.testing.expectEqual(@as(u32, 0), @atomicLoad(u32, &g_input_epoch, .monotonic));
    pumped(WM_KEYDOWN, 0x41);
    try std.testing.expectEqual(@as(u32, 1), @atomicLoad(u32, &g_input_epoch, .monotonic));
}

test "the idle window starts after a quiet minute and freezes on input" {
    var window: IdleWindow = .{};
    var counts: Counts = @splat(0);
    window.update(1_000, 5_000, counts);
    try std.testing.expect(!window.active);
    counts[@intFromEnum(Source.server_fetch)] = 7;
    window.update(100_000, 61_000, counts);
    try std.testing.expect(window.active);
    counts[@intFromEnum(Source.server_fetch)] = 17;
    counts[@intFromEnum(Source.log_line)] = 3;
    window.update(400_000, 361_000, counts);
    counts[@intFromEnum(Source.server_fetch)] = 99;
    window.update(410_000, 100, counts);
    try std.testing.expect(!window.active);
    const report = window.report();
    try std.testing.expectEqual(@as(u64, 300_000), report.window_ms);
    try std.testing.expectEqual(@as(u32, 10), report.delta[@intFromEnum(Source.server_fetch)]);
    try std.testing.expectEqual(@as(u32, 3), report.delta[@intFromEnum(Source.log_line)]);
}

test "rates are per minute with one decimal" {
    try std.testing.expectEqual(@as(u64, 0), perMinuteTenths(5, 0));
    try std.testing.expectEqual(@as(u64, 10), perMinuteTenths(5, 300_000));
    try std.testing.expectEqual(@as(u64, 16), perMinuteTenths(8, 300_000));
    try std.testing.expectEqual(@as(u64, 0), perMinuteTenths(0, 300_000));
}

test "the idle line names every source and the window" {
    var buf: [256]u8 = undefined;
    try std.testing.expectEqualStrings("idle none", formatIdle(&buf, .{}));
    var report: IdleReport = .{ .window_ms = 300_000 };
    report.delta[@intFromEnum(Source.server_fetch)] = 480;
    report.delta[@intFromEnum(Source.timer_fire)] = 5;
    try std.testing.expectEqualStrings(
        "idle 300s per min: server_fetch=96.0 thread_spawn=0.0 invalidate=0.0 timer_fire=1.0 log_line=0.0 process_spawn=0.0",
        formatIdle(&buf, report),
    );
}

test "the dump is json with every source and the live timers" {
    var buf: [512]u8 = undefined;
    var counts: Counts = @splat(0);
    counts[@intFromEnum(Source.server_fetch)] = 4;
    counts[@intFromEnum(Source.timer_fire)] = 9;
    var timers: [TIMER_SLOTS]u32 = @splat(0);
    timers[2] = 6;
    timers[27] = 3;
    try std.testing.expectEqualStrings(
        "{\"tick_ms\":1000,\"idle_ms\":70000,\"deep_idle\":1,\"server_fetch\":4,\"thread_spawn\":0,\"invalidate\":0,\"timer_fire\":9,\"log_line\":0,\"process_spawn\":0,\"timers\":{\"2\":6,\"27\":3}}",
        formatDump(&buf, 1000, 70_000, true, counts, timers),
    );
}

test "a short buffer yields an empty dump instead of a broken one" {
    var buf: [16]u8 = undefined;
    const counts: Counts = @splat(0);
    const timers: [TIMER_SLOTS]u32 = @splat(0);
    try std.testing.expectEqualStrings("", formatDump(&buf, 1, 1, false, counts, timers));
}

test "each distinct log line is allowed once until the user acts" {
    resetForTest();
    try std.testing.expect(logFirstTime("[photo-proof] expanded target=1 rect=0,0,10,10"));
    try std.testing.expect(!logFirstTime("[photo-proof] expanded target=1 rect=0,0,10,10"));
    try std.testing.expect(logFirstTime("[photo-proof] expanded target=2 rect=0,0,10,10"));
    try std.testing.expect(!logFirstTime("[photo-proof] expanded target=2 rect=0,0,10,10"));
    pumped(WM_LBUTTONDOWN, 0);
    try std.testing.expect(logFirstTime("[photo-proof] expanded target=1 rect=0,0,10,10"));
}

test "the log ring forgets its oldest line when full" {
    resetForTest();
    var buf: [32]u8 = undefined;
    var i: usize = 0;
    while (i < LOG_RING_SLOTS + 1) : (i += 1) {
        const line = std.fmt.bufPrint(&buf, "line {d}", .{i}) catch unreachable;
        try std.testing.expect(logFirstTime(line));
    }
    try std.testing.expect(logFirstTime("line 0"));
}

test "tick publishes the last idle window for the watchdog" {
    resetForTest();
    tick(1_000, 1_000);
    try std.testing.expectEqual(@as(u64, 0), lastIdle().window_ms);
    tick(100_000, 61_000);
    bump(.server_fetch);
    bump(.server_fetch);
    tick(160_000, 121_000);
    const report = lastIdle();
    try std.testing.expectEqual(@as(u64, 60_000), report.window_ms);
    try std.testing.expectEqual(@as(u32, 2), report.delta[@intFromEnum(Source.server_fetch)]);
    tick(170_000, 50);
    try std.testing.expectEqual(@as(u64, 60_000), lastIdle().window_ms);
}
