const std = @import("std");
const builtin = @import("builtin");
const win = @import("win32.zig");
const crash = @import("crash_recorder.zig");

pub const NOTICE_TEXT = "Multiprompt froze last time, a report was saved";
pub const THRESHOLD_MS = 5000;
const EVENT_COUNT = 16;
pub const View = enum(u3) { terminal, chat, browser, inbox, search, sessions, shortcuts, changelog };

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
const module_names = .{ "multiprompt.exe", "ntdll.dll", "kernelbase.dll", "kernel32.dll", "user32.dll", "win32u.dll", "gdi32.dll", "gdi32full.dll", "dwrite.dll" };
var g_modules: [module_names.len]Module = @splat(.{});

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

var g_window: win.HANDLE = null;
var g_main_thread: win.HANDLE = null;
var g_stop: win.HANDLE = null;
var g_worker: win.HANDLE = null;
var g_version: []const u8 = "";
var g_sequence = std.atomic.Value(u32).init(0);
var g_events: [EVENT_COUNT]std.atomic.Value(u64) = @splat(std.atomic.Value(u64).init(0));
var g_last_event: u32 = 0;

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
    g_window = window;
    g_version = version;
    inline for (0..g_modules.len) |i| {
        const handle = if (i == 0) win.GetModuleHandleW(null) else win.GetModuleHandleW(std.unicode.utf8ToUtf16LeStringLiteral(module_names[i]));
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
    g_worker = win.CreateThread(null, 256 * 1024, worker, null, 0, null);
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
    while (win.WaitForSingleObject(g_stop, 500) == 0x102) {
        if (win.IsWindow(g_window) == 0) break;
        const started = awakeMillis();
        var reply: usize = 0;
        const responsive = win.SendMessageTimeoutW(g_window, 0, 0, 0, 0x0001 | 0x0020, 1000, &reply) != 0;
        if (win.WaitForSingleObject(g_stop, 0) == 0) break;
        if (detector.probe(responsive, started, awakeMillis())) record(awakeMillis() -| detector.missed_since.?);
    }
    return 0;
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
    inline for (g_modules, module_names) |module, name| {
        if (module.base != 0 and ip >= module.base and ip - module.base < module.size) {
            b.print("instruction: {s}+0x{X}\n", .{ name, ip - module.base });
            return;
        }
    }
    b.add("instruction: unavailable\n");
}

fn record(unresponsive_ms: u64) void {
    const location = capture();
    var memory: [8192]u8 = undefined;
    var b: crash.Buf = .{ .data = &memory };
    var time: std.os.windows.FILETIME = undefined;
    GetSystemTimeAsFileTime(&time);
    const timestamp = ((@as(u64, time.dwHighDateTime) << 32) | time.dwLowDateTime) / 10_000_000 - 11_644_473_600;
    b.print("multiprompt freeze report\nversion: {s}\ntime_unix: {d}\nunresponsive_ms: {d}\nthread_context: {s}\n", .{ g_version, timestamp, unresponsive_ms, if (location.captured) "captured" else "unavailable" });
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
    const name = std.fmt.bufPrint(&name_buf, "freeze-{d}-{d}-{d}.txt", .{ timestamp, win.GetCurrentProcessId(), win.GetTickCount64() }) catch return;
    crash.writeFreezeReport(name, b.slice());
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
