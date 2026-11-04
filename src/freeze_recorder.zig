const std = @import("std");
const builtin = @import("builtin");
const win = @import("win32.zig");
const crash = @import("crash_recorder.zig");
const upload = @import("report_upload.zig");
extern "user32" fn PostMessageW(win.HANDLE, u32, usize, isize) callconv(.winapi) i32;
extern "user32" fn RegisterWindowMessageW([*:0]const u16) callconv(.winapi) u32;

pub const NOTICE_TEXT = "Multi Bot froze last time, a report was saved";
pub const THRESHOLD_MS = 5000;
const EVENT_COUNT = 16;
const Reason = enum(u2) { blank_chat, heartbeat, paint };
pub const View = enum(u3) { terminal, chat, browser, inbox, search, sessions, shortcuts, changelog };

extern "kernel32" fn CreateThread(?*anyopaque, usize, *const fn (?*anyopaque) callconv(.winapi) u32, ?*anyopaque, u32, ?*u32) callconv(.winapi) win.HANDLE;
extern "kernel32" fn OpenThread(u32, i32, u32) callconv(.winapi) win.HANDLE;
extern "kernel32" fn SuspendThread(win.HANDLE) callconv(.winapi) u32;
extern "kernel32" fn ResumeThread(win.HANDLE) callconv(.winapi) u32;
extern "kernel32" fn GetThreadContext(win.HANDLE, *std.os.windows.CONTEXT) callconv(.winapi) i32;
extern "kernel32" fn ReadProcessMemory(win.HANDLE, usize, [*]u8, usize, ?*usize) callconv(.winapi) i32;
extern "kernel32" fn GetSystemTimeAsFileTime(*std.os.windows.FILETIME) callconv(.winapi) void;
extern "kernel32" fn VirtualQuery(usize, *MemoryInfo, usize) callconv(.winapi) usize;

const MemoryInfo = extern struct {
    base: usize,
    allocation_base: usize,
    allocation_protect: u32,
    partition: u16,
    region_size: usize,
    state: u32,
    protect: u32,
    kind: u32,
};
const Module = struct { base: usize = 0, size: usize = 0 };
const module_fields = std.meta.fields(upload.Module);
var g_modules: [module_fields.len]Module = @splat(.{});

extern "kernel32" fn QueryUnbiasedInterruptTime(*u64) callconv(.winapi) i32;

pub const Detector = struct {
    missed_since: ?u64 = null,
    recorded: bool = false,

    pub fn probe(self: *Detector, responsive: bool, started: u64, now: u64) bool {
        if (responsive) {
            self.* = .{};
            return false;
        }
        if (self.missed_since == null) self.missed_since = started;
        if (self.recorded or now -| self.missed_since.? <= THRESHOLD_MS) return false;
        self.recorded = true;
        return true;
    }
};

const PaintDetector = struct {
    demand: u64 = 0,
    recorded: bool = false,

    fn probe(self: *PaintDetector, demand: u64, now: u64) bool {
        if (self.demand != demand) self.* = .{ .demand = demand };
        if (demand == 0 or self.recorded or now -| (demand - 1) <= THRESHOLD_MS) return false;
        self.recorded = true;
        return true;
    }
};

var g_paint_demand = std.atomic.Value(u64).init(0);
var g_active = false;

pub fn activation(active: bool) void {
    if (active == g_active) return;
    g_active = active;
    g_paint_demand.store(if (active) awakeMillis() +| 1 else 0, .release);
}

pub fn painted() void {
    g_paint_demand.store(0, .release);
}

var g_window: win.HANDLE = null;
var g_main_thread: win.HANDLE = null;
var g_stop: win.HANDLE = null;
var g_worker: win.HANDLE = null;
var g_version: []const u8 = "";
var g_sequence = std.atomic.Value(u32).init(0);
var g_events: [EVENT_COUNT]std.atomic.Value(u64) = @splat(std.atomic.Value(u64).init(0));
var g_last_event: u32 = 0;
var g_message: u32 = 0;
var g_ack = std.atomic.Value(u32).init(0);
var g_blank_pending = std.atomic.Value(bool).init(false);
var g_blank = false;

pub fn heartbeat(message: u32, token: usize) bool {
    if (g_message == 0 or message != g_message) return false;
    g_ack.store(@truncate(token), .release);
    return true;
}

pub fn blankChat(blank: bool) void {
    if (blank and !g_blank) g_blank_pending.store(true, .release);
    g_blank = blank;
}

fn awakeMillis() u64 {
    var ticks: u64 = 0;
    if (QueryUnbiasedInterruptTime(&ticks) == 0) return win.GetTickCount64();
    return ticks / 10_000;
}

pub fn note(message: u32, tab: usize, view: View) void {
    if (message == 0 or g_worker == null) return;
    const event: u32 = (message & 0xFFFF) | (@as(u32, @intCast(@min(tab, 0x1FFF))) << 16) | (@as(u32, @intFromEnum(view)) << 29);
    if (event == g_last_event) return;
    g_last_event = event;
    const sequence = g_sequence.load(.monotonic);
    const entry = (@as(u64, @as(u32, @truncate(win.GetTickCount64()))) << 32) | event;
    g_events[sequence % EVENT_COUNT].store(entry, .release);
    g_sequence.store(sequence +% 1, .release);
}

pub fn start(window: win.HANDLE, version: []const u8) void {
    if (g_worker != null) return;
    g_message = RegisterWindowMessageW(std.unicode.utf8ToUtf16LeStringLiteral("Multiprompt.FreezeHeartbeat"));
    if (g_message == 0) return;
    g_window = window;
    g_version = version;
    inline for (0..g_modules.len) |i| {
        const handle = if (i == 0) win.GetModuleHandleW(null) else win.GetModuleHandleW(std.unicode.utf8ToUtf16LeStringLiteral(module_fields[i].name));
        const base = @intFromPtr(handle);
        if (base != 0) {
            const pe: [*]const u8 = @ptrFromInt(base);
            const nt = std.mem.readInt(u32, pe[0x3C..][0..4], .little);
            g_modules[i].base = base;
            g_modules[i].size = std.mem.readInt(u32, pe[nt + 24 + 56 ..][0..4], .little);
        }
    }
    g_main_thread = OpenThread(0x0002 | 0x0008, 0, win.GetCurrentThreadId());
    if (g_main_thread == null) return;
    g_stop = win.CreateEventW(null, 1, 0, null);
    if (g_stop == null) {
        _ = win.CloseHandle(g_main_thread);
        g_main_thread = null;
        return;
    }
    g_worker = CreateThread(null, 256 * 1024, worker, null, 0, null);
    if (g_worker == null) {
        _ = win.CloseHandle(g_stop);
        _ = win.CloseHandle(g_main_thread);
        g_stop = null;
        g_main_thread = null;
    }
}

pub fn closing() void {
    if (g_stop != null) _ = win.SetEvent(g_stop);
}

pub fn stop() void {
    if (g_worker == null) return;
    _ = win.SetEvent(g_stop);
    _ = win.WaitForSingleObject(g_worker, 0xFFFFFFFF);
    _ = win.CloseHandle(g_worker);
    _ = win.CloseHandle(g_stop);
    _ = win.CloseHandle(g_main_thread);
    g_worker = null;
    g_stop = null;
    g_main_thread = null;
}

fn worker(_: ?*anyopaque) callconv(.winapi) u32 {
    var detector: Detector = .{};
    var paint_detector: PaintDetector = .{};
    var token: u32 = 1;
    var started = awakeMillis();
    const session_clock = started;
    const session_timestamp = unixTime();
    var health = @import("watchdog_health.zig").Tracker.init(started);
    var health_sequence: u32 = 0;
    if (PostMessageW(g_window, g_message, token, 0) == 0) return 0;
    while (win.WaitForSingleObject(g_stop, 500) == 0x102) {
        if (win.IsWindow(g_window) == 0) break;
        const now = awakeMillis();
        const responsive = g_ack.load(.acquire) == token;
        var freezes: u32 = 0;
        if (detector.probe(responsive, started, now)) {
            freezes += 1;
            record(.freeze, now -| detector.missed_since.?, .heartbeat);
        }
        const demand = g_paint_demand.load(.acquire);
        if (responsive and paint_detector.probe(demand, now) and g_paint_demand.load(.acquire) == demand) {
            freezes += 1;
            record(.freeze, now -| (demand - 1), .paint);
        }
        if (g_blank_pending.swap(false, .acq_rel)) record(.blank_chat, 0, .blank_chat);
        if (health.sample(now, responsive, freezes)) {
            publishHealth(session_timestamp, session_clock, health_sequence, health.snapshot);
            health_sequence +%= 1;
        }
        if (responsive) {
            token +%= 1;
            started = now;
            if (PostMessageW(g_window, g_message, token, 0) == 0) break;
        }
    }
    return 0;
}

fn unixTime() i64 {
    var time: std.os.windows.FILETIME = undefined;
    GetSystemTimeAsFileTime(&time);
    return @intCast(((@as(u64, time.dwHighDateTime) << 32) | time.dwLowDateTime) / 10_000_000 - 11_644_473_600);
}

fn publishHealth(session_timestamp: i64, session_clock: u64, sequence: u32, health: @import("watchdog_health.zig").Snapshot) void {
    var id_buffer: [64]u8 = undefined;
    const id = std.fmt.bufPrint(&id_buffer, "watchdog-{d}-{d}-{d}-{d}", .{ session_timestamp, win.GetCurrentProcessId(), session_clock, sequence }) catch return;
    upload.queueWatchdog(id, g_version, unixTime(), health);
}

const Location = struct {
    ip: usize = 0,
    rvas: [24]usize = @splat(0),
    count: usize = 0,
    captured: bool = false,
};

fn capture() Location {
    var result: Location = .{};
    const base = g_modules[0].base;
    if (base == 0) return result;
    const image_size = g_modules[0].size;
    var context = std.mem.zeroes(std.os.windows.CONTEXT);
    context.ContextFlags = if (builtin.cpu.arch == .aarch64) 0x00400003 else 0x00100003;
    var stack: [8192]u8 = undefined;
    var got: usize = 0;
    if (SuspendThread(g_main_thread) == 0xFFFFFFFF) return result;
    {
        defer _ = ResumeThread(g_main_thread);
        if (GetThreadContext(g_main_thread, &context) == 0) return result;
        const regs = context.getRegs();
        result.ip = regs.ip;
        result.captured = true;
        var region: MemoryInfo = undefined;
        if (VirtualQuery(regs.sp, &region, @sizeOf(MemoryInfo)) != 0 and region.state == 0x1000 and region.protect & (0x100 | 0x01) == 0) {
            const available = region.base +| region.region_size -| regs.sp;
            _ = ReadProcessMemory(win.GetCurrentProcess(), regs.sp, &stack, @min(stack.len, available), &got);
        }
    }
    if (result.ip >= base and result.ip - base < image_size) {
        result.rvas[result.count] = result.ip - base;
        result.count += 1;
    }
    if (builtin.cpu.arch == .aarch64) {
        const lr = context.DUMMYUNIONNAME.DUMMYSTRUCTNAME.Lr;
        if (lr >= base and lr - base < image_size) {
            result.rvas[result.count] = lr - base;
            result.count += 1;
        }
    }
    var offset: usize = 0;
    while (offset + 8 <= got and result.count < result.rvas.len) : (offset += 8) {
        const address = std.mem.readInt(u64, stack[offset..][0..8], .little);
        if (address >= base and address - base < image_size) {
            result.rvas[result.count] = @intCast(address - base);
            result.count += 1;
        }
    }
    return result;
}

fn instruction(b: *crash.Buf, ip: usize) void {
    inline for (g_modules, module_fields) |module, field| {
        if (module.base != 0 and ip >= module.base and ip - module.base < module.size) {
            b.print("instruction: {s}+0x{X}\n", .{ field.name, ip - module.base });
            return;
        }
    }
    b.add("instruction: unavailable\n");
}

fn record(kind: upload.FreezeKind, unresponsive_ms: u64, reason: Reason) void {
    const location = capture();
    var memory: [8192]u8 = undefined;
    var b: crash.Buf = .{ .data = &memory };
    var time: std.os.windows.FILETIME = undefined;
    GetSystemTimeAsFileTime(&time);
    const timestamp = ((@as(u64, time.dwHighDateTime) << 32) | time.dwLowDateTime) / 10_000_000 - 11_644_473_600;
    b.print("multiprompt {s} report\nversion: {s}\ntime_unix: {d}\nunresponsive_ms: {d}\nthread_context: {s}\n", .{ if (kind == .freeze) "freeze" else "blank chat", g_version, timestamp, unresponsive_ms, if (location.captured) "captured" else "unavailable" });
    b.print("reason: {d}\n", .{@intFromEnum(reason)});
    var frame: win.RECT = std.mem.zeroes(win.RECT);
    var client: win.RECT = std.mem.zeroes(win.RECT);
    if (win.GetWindowRect(g_window, &frame) != 0 and win.GetClientRect(g_window, &client) != 0) {
        b.print("frame_size: {d} {d}\nclient_size: {d} {d}\n", .{ frame.right - frame.left, frame.bottom - frame.top, client.right - client.left, client.bottom - client.top });
    }
    instruction(&b, location.ip);
    b.add("stack_rvas:\n");
    for (location.rvas[0..location.count]) |rva| b.print("  0x{X}\n", .{rva});
    b.add("app_events (uptime_ms message_id tab_index view):\n");
    const sequence = g_sequence.load(.acquire);
    const count = @min(sequence, EVENT_COUNT);
    for (0..count) |i| {
        const event = g_events[(sequence -% count +% i) % EVENT_COUNT].load(.acquire);
        b.print("  {d} 0x{X} {d} {s}\n", .{ event >> 32, event & 0xFFFF, (event >> 16) & 0x1FFF, @tagName(@as(View, @enumFromInt((event >> 29) & 7))) });
    }
    var name_buf: [96]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "{s}-{d}-{d}-{d}.txt", .{ if (kind == .freeze) "freeze" else "blank-chat", timestamp, win.GetCurrentProcessId(), win.GetTickCount64() }) catch return;
    crash.writeDiagnosticReport(name, b.slice(), kind == .freeze);
    var context: upload.FreezeContext = .unavailable;
    if (location.captured) {
        context = .{ .captured = null };
        for (g_modules, 0..) |module, i| {
            if (module.base != 0 and location.ip >= module.base and location.ip - module.base < module.size) {
                context = .{ .captured = .{ .module = @enumFromInt(i), .rva = location.ip - module.base } };
                break;
            }
        }
    }
    upload.queueFreeze(kind, g_version, @intCast(timestamp), location.rvas[0..location.count], context);
}

test "activation demand is not extended by repeated activation or idle paints" {
    defer {
        g_active = false;
        g_paint_demand.store(0, .release);
    }
    activation(false);
    activation(true);
    const first = g_paint_demand.load(.acquire);
    try std.testing.expect(first != 0);
    activation(true);
    try std.testing.expectEqual(first, g_paint_demand.load(.acquire));
    painted();
    activation(true);
    try std.testing.expectEqual(@as(u64, 0), g_paint_demand.load(.acquire));
    activation(false);
    activation(true);
    try std.testing.expect(g_paint_demand.load(.acquire) != 0);
    activation(false);
    try std.testing.expectEqual(@as(u64, 0), g_paint_demand.load(.acquire));
}

test "paint demand threshold cancellation and recovery" {
    var detector: PaintDetector = .{};
    try std.testing.expect(!detector.probe(0, 100000));
    try std.testing.expect(!detector.probe(101, 5100));
    try std.testing.expect(detector.probe(101, 5101));
    try std.testing.expect(!detector.probe(101, 20000));
    try std.testing.expect(!detector.probe(0, 20001));
    try std.testing.expect(!detector.probe(30001, 35000));
    try std.testing.expect(detector.probe(30001, 35001));
    try std.testing.expect(!detector.probe(40001, 1));
    try std.testing.expect(!detector.probe(0, 50000));
}

test "freeze threshold, one report per stall, recovery permits a later report" {
    var detector: Detector = .{};
    try std.testing.expect(!detector.probe(true, 0, 10000));
    try std.testing.expect(!detector.probe(false, 10000, 11000));
    try std.testing.expect(!detector.probe(false, 14000, 15000));
    try std.testing.expect(detector.probe(false, 15000, 15001));
    try std.testing.expect(!detector.probe(false, 15001, 30000));
    try std.testing.expect(!detector.probe(true, 30000, 30001));
    try std.testing.expect(!detector.probe(false, 40000, 41000));
    try std.testing.expect(detector.probe(false, 45000, 46000));
}

test "healthy probes and time rollback never record a freeze" {
    var detector: Detector = .{};
    for (0..100) |i| try std.testing.expect(!detector.probe(true, i * 1000, i * 1000 + 100));
    try std.testing.expect(!detector.probe(false, 5000, 1));
}
