const std = @import("std");
const app_state = @import("app_state.zig");
const win = @import("win32.zig");
const file_io = @import("file_io.zig");
const idle_budget = @import("idle_budget.zig");

const DWORD = win.DWORD;
const HANDLE = win.HANDLE;

pub const SAMPLE_INTERVAL_MS: u32 = 10_000;
pub const WAKE_POLL_MS: u32 = 250;
pub const MAX_ROWS: usize = 512;
pub const BASELINE_SAVE_MS: u64 = 60_000;
const WEIGHT = 10_000;
const PROCESS_TREE_DEPTH: usize = 16;

pub const Row = struct {
    pid: u32 = 0,
    parent_pid: u32 = 0,
    memory_bytes: u64 = 0,
    cpu_100ns: u64 = 0,
};

pub const Reading = struct {
    memory_mb: u32 = 0,
    cpu_percent: u32 = 0,
    processes: u32 = 0,
    peak_memory_mb: u32 = 0,
    peak_processes: u32 = 0,
    known: bool = false,
};

var g_memory_mb: u32 = 0;
var g_cpu_percent: u32 = 0;
var g_processes: u32 = 0;
var g_peak_memory_mb: u32 = 0;
var g_peak_processes: u32 = 0;
var g_known: bool = false;
var g_started: bool = false;
var g_wake: bool = false;
var g_last_sample_ms: u64 = 0;
var g_last_save_ms: u64 = 0;
var g_previous: [MAX_ROWS]Row = [_]Row{.{}} ** MAX_ROWS;
var g_previous_count: usize = 0;

pub fn percentFromDelta(delta_100ns: u64, elapsed_ms: u64) u32 {
    if (elapsed_ms == 0 or delta_100ns == 0) return 0;
    const percent = (delta_100ns * 100) / (@as(u64, elapsed_ms) * WEIGHT);
    return @intCast(@min(percent, 999));
}

pub fn markOwned(rows: []const Row, root_pid: u32, mask: []bool) usize {
    if (rows.len == 0 or mask.len < rows.len) return 0;
    var owned: usize = 0;
    for (rows, 0..) |row, i| {
        mask[i] = row.pid == root_pid and root_pid != 0;
        if (mask[i]) owned += 1;
    }
    var pass: usize = 0;
    var grew = true;
    while (grew and pass < PROCESS_TREE_DEPTH) : (pass += 1) {
        grew = false;
        for (rows, 0..) |row, i| {
            if (mask[i]) continue;
            for (rows, 0..) |parent, j| {
                if (mask[j] and parent.pid == row.parent_pid and row.parent_pid != row.pid) {
                    mask[i] = true;
                    owned += 1;
                    grew = true;
                    break;
                }
            }
        }
    }
    return owned;
}

pub fn formatMemory(buf: []u8, memory_mb: u32) []const u8 {
    if (memory_mb >= 1024) {
        return std.fmt.bufPrint(buf, "{d}.{d} GB", .{ memory_mb / 1024, (memory_mb % 1024) * 10 / 1024 }) catch "";
    }
    return std.fmt.bufPrint(buf, "{d} MB", .{memory_mb}) catch "";
}

pub fn formatReading(buf: []u8, reading_value: Reading) []const u8 {
    if (!reading_value.known) return "measuring";
    var memory_buf: [24]u8 = undefined;
    const memory = formatMemory(&memory_buf, reading_value.memory_mb);
    return std.fmt.bufPrint(buf, "MEM {s} | {d}% CPU | {d} procs", .{ memory, reading_value.cpu_percent, reading_value.processes }) catch "measuring";
}

pub fn formatPeak(buf: []u8, reading_value: Reading) []const u8 {
    if (!reading_value.known or reading_value.peak_memory_mb == 0) return "no peak yet";
    var memory_buf: [24]u8 = undefined;
    const memory = formatMemory(&memory_buf, reading_value.peak_memory_mb);
    return std.fmt.bufPrint(buf, "peak {s}, {d} procs", .{ memory, reading_value.peak_processes }) catch "no peak yet";
}

pub fn formatBaseline(buf: []u8, version: []const u8, peak_memory_mb: u32, peak_processes: u32) []const u8 {
    return std.fmt.bufPrint(buf, "{{\"version\":\"{s}\",\"peak_memory_mb\":{d},\"peak_processes\":{d}}}", .{ version, peak_memory_mb, peak_processes }) catch "";
}

pub fn jsonStringField(json: []const u8, key: []const u8) ?[]const u8 {
    var key_buf: [40]u8 = undefined;
    const needle = std.fmt.bufPrint(&key_buf, "\"{s}\":\"", .{key}) catch return null;
    const key_at = std.mem.indexOf(u8, json, needle) orelse return null;
    const from = key_at + needle.len;
    const end = std.mem.indexOfScalarPos(u8, json, from, '"') orelse return null;
    return json[from..end];
}

pub fn jsonNumberField(json: []const u8, key: []const u8) ?u32 {
    var key_buf: [40]u8 = undefined;
    const needle = std.fmt.bufPrint(&key_buf, "\"{s}\":", .{key}) catch return null;
    const key_at = std.mem.indexOf(u8, json, needle) orelse return null;
    var at = key_at + needle.len;
    while (at < json.len and json[at] == ' ') at += 1;
    const digits_start = at;
    while (at < json.len and json[at] >= '0' and json[at] <= '9') at += 1;
    if (at == digits_start) return null;
    return std.fmt.parseInt(u32, json[digits_start..at], 10) catch null;
}

fn baselinePath(buf: []u8) ?[]const u8 {
    var local_buf: [512]u8 = undefined;
    const len = win.GetEnvironmentVariableA("LOCALAPPDATA", &local_buf, local_buf.len);
    if (len == 0 or len >= local_buf.len) return null;
    const local = local_buf[0..len];
    file_io.win32MakeDir(std.fmt.bufPrint(buf, "{s}\\ZigShell", .{local}) catch return null);
    return std.fmt.bufPrint(buf, "{s}\\ZigShell\\footprint.json", .{local}) catch null;
}

fn loadBaseline(version: []const u8) ?Reading {
    var path_buf: [1024]u8 = undefined;
    const path = baselinePath(&path_buf) orelse return null;
    const text = file_io.readFileAllocWin32(path, 4096) orelse return null;
    defer std.heap.page_allocator.free(text);
    const stored = jsonStringField(text, "version") orelse return null;
    if (!std.mem.eql(u8, stored, version)) return null;
    const memory = jsonNumberField(text, "peak_memory_mb") orelse return null;
    const processes = jsonNumberField(text, "peak_processes") orelse return null;
    return .{ .peak_memory_mb = memory, .peak_processes = processes };
}

fn saveBaseline(version: []const u8, memory_mb: u32, processes: u32) void {
    var path_buf: [1024]u8 = undefined;
    const path = baselinePath(&path_buf) orelse return;
    var json_buf: [128]u8 = undefined;
    const json = formatBaseline(&json_buf, version, memory_mb, processes);
    if (json.len == 0) return;
    _ = file_io.writeFileAtomicSync(path, json);
}

fn readCpuTicks(process: HANDLE) ?u64 {
    var created: win.FILETIME = undefined;
    var exited: win.FILETIME = undefined;
    var kernel: win.FILETIME = undefined;
    var user: win.FILETIME = undefined;
    if (win.GetProcessTimes(process, &created, &exited, &kernel, &user) == 0) return null;
    const kernel_ticks = (@as(u64, kernel.dwHighDateTime) << 32) | kernel.dwLowDateTime;
    const user_ticks = (@as(u64, user.dwHighDateTime) << 32) | user.dwLowDateTime;
    return kernel_ticks + user_ticks;
}

fn readMemoryBytes(process: HANDLE) u64 {
    const get_memory = app_state.g_K32GetProcessMemoryInfo orelse return 0;
    var counters: win.PROCESS_MEMORY_COUNTERS = std.mem.zeroes(win.PROCESS_MEMORY_COUNTERS);
    counters.cb = @sizeOf(win.PROCESS_MEMORY_COUNTERS);
    if (get_memory(process, &counters, @sizeOf(win.PROCESS_MEMORY_COUNTERS)) == 0) return 0;
    return counters.WorkingSetSize;
}

fn scan(rows: []Row) usize {
    const snap = win.CreateToolhelp32Snapshot(win.TH32CS_SNAPPROCESS, 0);
    if (snap == null or snap == win.INVALID_HANDLE_VALUE_PTR) return 0;
    defer _ = win.CloseHandle(snap);

    var count: usize = 0;
    var entry: win.PROCESSENTRY32W = undefined;
    entry.dwSize = @sizeOf(win.PROCESSENTRY32W);
    if (win.Process32FirstW(snap, &entry) == 0) return 0;
    while (count < rows.len) {
        const pid = entry.th32ProcessID;
        if (pid != 0) {
            rows[count] = .{ .pid = pid, .parent_pid = entry.th32ParentProcessID };
            const process = win.OpenProcess(win.PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);
            if (process != null) {
                rows[count].memory_bytes = readMemoryBytes(process);
                rows[count].cpu_100ns = readCpuTicks(process) orelse 0;
                _ = win.CloseHandle(process);
            }
            count += 1;
        }
        if (win.Process32NextW(snap, &entry) == 0) break;
    }
    return count;
}

fn previousCpu(pid: u32) ?u64 {
    for (g_previous[0..g_previous_count]) |row| {
        if (row.pid == pid) return row.cpu_100ns;
    }
    return null;
}

pub fn sampleNow(elapsed_ms: u64) Reading {
    var rows: [MAX_ROWS]Row = [_]Row{.{}} ** MAX_ROWS;
    const count = scan(rows[0..]);
    var mask: [MAX_ROWS]bool = @splat(false);
    const owned = markOwned(rows[0..count], win.GetCurrentProcessId(), mask[0..count]);

    var memory_bytes: u64 = 0;
    var cpu_delta: u64 = 0;
    g_previous_count = 0;
    for (rows[0..count], 0..) |row, i| {
        if (!mask[i]) continue;
        memory_bytes += row.memory_bytes;
        if (previousCpu(row.pid)) |before| {
            if (row.cpu_100ns > before) cpu_delta += row.cpu_100ns - before;
        }
        if (g_previous_count < g_previous.len) {
            g_previous[g_previous_count] = row;
            g_previous_count += 1;
        }
    }

    const memory_mb: u32 = @intCast(@min((memory_bytes + 512 * 1024) / (1024 * 1024), 999_999));
    const cpu_percent = if (elapsed_ms == 0) 0 else percentFromDelta(cpu_delta, elapsed_ms);
    const reading_value = Reading{
        .memory_mb = memory_mb,
        .cpu_percent = cpu_percent,
        .processes = @intCast(owned),
        .known = true,
    };
    @atomicStore(u32, &g_memory_mb, reading_value.memory_mb, .monotonic);
    @atomicStore(u32, &g_cpu_percent, reading_value.cpu_percent, .monotonic);
    @atomicStore(u32, &g_processes, reading_value.processes, .monotonic);
    @atomicStore(bool, &g_known, true, .monotonic);
    return reading_value;
}

pub fn reading() Reading {
    const peak_memory = @atomicLoad(u32, &g_peak_memory_mb, .monotonic);
    const peak_processes = @atomicLoad(u32, &g_peak_processes, .monotonic);
    return .{
        .memory_mb = @atomicLoad(u32, &g_memory_mb, .monotonic),
        .cpu_percent = @atomicLoad(u32, &g_cpu_percent, .monotonic),
        .processes = @atomicLoad(u32, &g_processes, .monotonic),
        .peak_memory_mb = peak_memory,
        .peak_processes = peak_processes,
        .known = @atomicLoad(bool, &g_known, .monotonic),
    };
}

pub fn wake() void {
    @atomicStore(bool, &g_wake, true, .monotonic);
}

fn publishPeak(reading_value: Reading, version: []const u8) bool {
    var changed = false;
    if (reading_value.memory_mb > @atomicLoad(u32, &g_peak_memory_mb, .monotonic)) {
        @atomicStore(u32, &g_peak_memory_mb, reading_value.memory_mb, .monotonic);
        changed = true;
    }
    if (reading_value.processes > @atomicLoad(u32, &g_peak_processes, .monotonic)) {
        @atomicStore(u32, &g_peak_processes, reading_value.processes, .monotonic);
        changed = true;
    }
    if (!changed) return false;
    const now = win.GetTickCount64();
    if (now - g_last_save_ms < BASELINE_SAVE_MS) return true;
    g_last_save_ms = now;
    saveBaseline(version, @atomicLoad(u32, &g_peak_memory_mb, .monotonic), @atomicLoad(u32, &g_peak_processes, .monotonic));
    return true;
}

var g_idle_dump_path: [520]u8 = undefined;
var g_idle_dump_len: usize = 0;

fn loadIdleDumpPath() void {
    const len = win.GetEnvironmentVariableA("MULTIPROMPT_IDLE_COUNTERS", &g_idle_dump_path, g_idle_dump_path.len);
    g_idle_dump_len = if (len > 0 and len < g_idle_dump_path.len) len else 0;
}

fn idleMilliseconds(now: u64) u64 {
    var info = win.LASTINPUTINFO{ .cbSize = @sizeOf(win.LASTINPUTINFO), .dwTime = 0 };
    if (win.GetLastInputInfo(&info) == 0) return 0;
    const now32: u32 = @truncate(now);
    return now32 -% info.dwTime;
}

fn publishIdle(now: u64) void {
    const idle_ms = idleMilliseconds(now);
    idle_budget.tick(now, idle_ms);
    if (g_idle_dump_len == 0) return;
    var buf: [1536]u8 = undefined;
    const json = idle_budget.formatDump(&buf, now, idle_ms, idle_budget.snapshot(), idle_budget.timerSnapshot());
    if (json.len == 0) return;
    _ = file_io.writeFileAtomicSync(g_idle_dump_path[0..g_idle_dump_len], json);
}

fn samplerLoop(version: []const u8) void {
    while (true) {
        var slept: u32 = 0;
        while (slept < SAMPLE_INTERVAL_MS) : (slept += WAKE_POLL_MS) {
            if (@atomicLoad(bool, &g_wake, .monotonic)) {
                @atomicStore(bool, &g_wake, false, .monotonic);
                break;
            }
            win.Sleep(WAKE_POLL_MS);
        }
        const now = win.GetTickCount64();
        const elapsed = if (g_last_sample_ms == 0) 0 else now - g_last_sample_ms;
        g_last_sample_ms = now;
        const sampled = sampleNow(elapsed);
        _ = publishPeak(sampled, version);
        publishIdle(now);
        if (app_state.g_status_card_hover and app_state.g_main_hwnd != null) {
            _ = win.PostMessageW(app_state.g_main_hwnd, win.WM_APP_FOOTPRINT_READY, 0, 0);
        }
    }
}

pub fn start(version: []const u8) void {
    if (g_started) return;
    g_started = true;
    loadIdleDumpPath();
    if (loadBaseline(version)) |stored| {
        @atomicStore(u32, &g_peak_memory_mb, stored.peak_memory_mb, .monotonic);
        @atomicStore(u32, &g_peak_processes, stored.peak_processes, .monotonic);
    }
    const version_copy = std.heap.page_allocator.dupe(u8, version) catch return;
    const thread = std.Thread.spawn(.{}, samplerLoop, .{@as([]const u8, version_copy)}) catch {
        std.heap.page_allocator.free(version_copy);
        return;
    };
    thread.detach();
}

test "cpu percent converts hundred-nanosecond deltas over elapsed time" {
    try std.testing.expectEqual(@as(u32, 0), percentFromDelta(0, 10_000));
    try std.testing.expectEqual(@as(u32, 0), percentFromDelta(5_000_000, 0));
    try std.testing.expectEqual(@as(u32, 100), percentFromDelta(100_000_000, 10_000));
    try std.testing.expectEqual(@as(u32, 500), percentFromDelta(500_000_000, 10_000));
    try std.testing.expectEqual(@as(u32, 999), percentFromDelta(999_000_000, 1));
}

test "owned rows collect the whole process tree" {
    const rows = [_]Row{
        .{ .pid = 10, .parent_pid = 4 },
        .{ .pid = 11, .parent_pid = 10 },
        .{ .pid = 12, .parent_pid = 11 },
        .{ .pid = 13, .parent_pid = 4 },
    };
    var mask: [4]bool = @splat(false);
    try std.testing.expectEqual(@as(usize, 3), markOwned(rows[0..], 10, mask[0..]));
    try std.testing.expect(mask[0] and mask[1] and mask[2]);
    try std.testing.expect(!mask[3]);
    try std.testing.expectEqual(@as(usize, 0), markOwned(rows[0..], 0, mask[0..]));
}

test "footprint lines read as live numbers" {
    var buf: [96]u8 = undefined;
    const live = Reading{ .memory_mb = 2458, .cpu_percent = 7, .processes = 134, .known = true };
    try std.testing.expectEqualStrings("MEM 2.4 GB | 7% CPU | 134 procs", formatReading(&buf, live));
    const small = Reading{ .memory_mb = 980, .cpu_percent = 3, .processes = 12, .known = true };
    try std.testing.expectEqualStrings("MEM 980 MB | 3% CPU | 12 procs", formatReading(&buf, small));
    try std.testing.expectEqualStrings("measuring", formatReading(&buf, .{}));
    const peaked = Reading{ .memory_mb = 100, .cpu_percent = 1, .processes = 20, .peak_memory_mb = 3120, .peak_processes = 141, .known = true };
    try std.testing.expectEqualStrings("peak 3.0 GB, 141 procs", formatPeak(&buf, peaked));
    try std.testing.expectEqualStrings("no peak yet", formatPeak(&buf, .{}));
}

test "baseline json round trips the recorded peak" {
    var buf: [128]u8 = undefined;
    const json = formatBaseline(&buf, "0.28.883", 3120, 141);
    try std.testing.expectEqualStrings("{\"version\":\"0.28.883\",\"peak_memory_mb\":3120,\"peak_processes\":141}", json);
    try std.testing.expectEqualStrings("0.28.883", jsonStringField(json, "version").?);
    try std.testing.expectEqual(@as(u32, 3120), jsonNumberField(json, "peak_memory_mb").?);
    try std.testing.expectEqual(@as(u32, 141), jsonNumberField(json, "peak_processes").?);
    try std.testing.expectEqual(@as(?u32, null), jsonNumberField(json, "peak_threads"));
    try std.testing.expectEqual(@as(?[]const u8, null), jsonStringField(json, "channel"));
}
