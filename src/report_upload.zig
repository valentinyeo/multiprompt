const std = @import("std");
const win = @import("win32.zig");
const client = @import("account_client.zig");
const INVALID = std.math.maxInt(usize);
pub const Kind = enum { freeze, crash, blank_chat };
pub const FreezeKind = enum { freeze, blank_chat };
pub const Module = enum { @"multiprompt.exe", @"ntdll.dll", @"kernelbase.dll", @"kernel32.dll", @"user32.dll", @"win32u.dll", @"gdi32.dll", @"gdi32full.dll", @"dwrite.dll" };
pub const FreezeContext = union(enum) {
    unavailable,
    captured: ?struct { module: Module, rva: usize },
};
extern "kernel32" fn AcquireSRWLockExclusive(*usize) callconv(.winapi) void;
extern "kernel32" fn ReleaseSRWLockExclusive(*usize) callconv(.winapi) void;
extern "kernel32" fn CreateThread(?*anyopaque, usize, *const fn (?*anyopaque) callconv(.winapi) u32, ?*anyopaque, u32, ?*u32) callconv(.winapi) win.HANDLE;
var g_directory: [300]u16 = @splat(0);
var g_directory_len: usize = 0;
var g_lock: usize = 0;
var g_token: [8192]u8 = @splat(0);
var g_token_len: usize = 0;
var g_wake: win.HANDLE = null;
var g_thread: win.HANDLE = null;
var g_stopping = std.atomic.Value(bool).init(false);

pub fn initialize(directory: []const u16) void {
    if (directory.len == 0 or directory.len >= g_directory.len) return;
    @memcpy(g_directory[0..directory.len], directory);
    g_directory_len = directory.len;
}

fn path(out: []u16, name: []const u8) ?[:0]const u16 {
    const n = g_directory_len;
    if (n == 0 or n + name.len + 2 > out.len) return null;
    @memcpy(out[0..n], g_directory[0..n]);
    out[n] = '\\';
    for (name, 0..) |c, i| out[n + 1 + i] = c;
    out[n + 1 + name.len] = 0;
    return out[0 .. n + 1 + name.len :0];
}

pub fn setAccess(token: []const u8) void {
    AcquireSRWLockExclusive(&g_lock);
    defer ReleaseSRWLockExclusive(&g_lock);
    std.crypto.secureZero(u8, &g_token);
    g_token_len = if (token.len <= g_token.len) token.len else 0;
    @memcpy(g_token[0..g_token_len], token[0..g_token_len]);
    if (g_wake != null) _ = win.SetEvent(g_wake);
}

pub fn start() void {
    if (g_thread != null or g_directory_len == 0) return;
    g_stopping.store(false, .release);
    g_wake = win.CreateEventW(null, 0, 0, null);
    if (g_wake == null) return;
    g_thread = CreateThread(null, 0, worker, null, 0, null);
    if (g_thread == null) {
        _ = win.CloseHandle(g_wake);
        g_wake = null;
    }
}

pub fn stop() void {
    if (g_thread == null) return;
    g_stopping.store(true, .release);
    _ = win.SetEvent(g_wake);
    _ = win.WaitForSingleObject(g_thread, 0xFFFFFFFF);
    _ = win.CloseHandle(g_thread);
    _ = win.CloseHandle(g_wake);
    g_thread = null;
    g_wake = null;
    setAccess("");
}

pub fn payload(out: []u8, id: []const u8, kind: Kind, version: []const u8, timestamp: i64, code: u32, rvas: []const usize) ?[]const u8 {
    return contextualPayload(out, id, kind, version, timestamp, code, rvas, null);
}

fn contextualPayload(out: []u8, id: []const u8, kind: Kind, version: []const u8, timestamp: i64, code: u32, rvas: []const usize, context: ?FreezeContext) ?[]const u8 {
    if (id.len < 8 or id.len > 64 or version.len == 0 or version.len > 64) return null;
    for (id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-') return null;
    for (version) |c| if (!std.ascii.isAlphanumeric(c) and c != '.' and c != '-') return null;
    var trace: [2048]u8 = undefined;
    var written = std.fmt.bufPrint(&trace, "exception_code: 0x{X}\\n", .{code}) catch return null;
    if (context) |capture| {
        const details = switch (capture) {
            .unavailable => std.fmt.bufPrint(trace[written.len..], "thread_context: unavailable\\nsampled_instruction: unavailable\\n", .{}),
            .captured => |sample| if (sample) |location|
                std.fmt.bufPrint(trace[written.len..], "thread_context: captured\\nsampled_instruction: {s}+0x{X}\\n", .{ @tagName(location.module), location.rva })
            else
                std.fmt.bufPrint(trace[written.len..], "thread_context: captured\\nsampled_instruction: unmapped\\n", .{}),
        } catch return null;
        written = trace[0 .. written.len + details.len];
    }
    const heading = std.fmt.bufPrint(trace[written.len..], "stack_rvas:\\n", .{}) catch return null;
    written = trace[0 .. written.len + heading.len];
    for (rvas[0..@min(rvas.len, 24)]) |rva| {
        const line = std.fmt.bufPrint(trace[written.len..], "  0x{X}\\n", .{rva}) catch return null;
        written = trace[0 .. written.len + line.len];
    }
    return std.fmt.bufPrint(out, "{{\"id\":\"{s}\",\"captured_at\":{d},\"app_version\":\"{s}\",\"android_version\":\"Windows\",\"thread\":\"main\",\"summary\":\"Windows {s}\",\"stack_trace\":\"{s}\"}}", .{ id, timestamp, version, @tagName(kind), written }) catch null;
}

pub fn queue(kind: Kind, version: []const u8, timestamp: i64, code: u32, rvas: []const usize) void {
    queueContext(kind, version, timestamp, code, rvas, null);
}

pub fn queueFreeze(kind: FreezeKind, version: []const u8, timestamp: i64, rvas: []const usize, context: FreezeContext) void {
    queueContext(switch (kind) { .freeze => .freeze, .blank_chat => .blank_chat }, version, timestamp, 0, rvas, context);
}

fn queueContext(kind: Kind, version: []const u8, timestamp: i64, code: u32, rvas: []const usize, context: ?FreezeContext) void {
    var id_buf: [64]u8 = undefined;
    const id = std.fmt.bufPrint(&id_buf, "{s}-{d}-{d}-{d}", .{ if (kind == .blank_chat) "blank" else @tagName(kind), timestamp, win.GetCurrentProcessId(), win.GetTickCount64() }) catch return;
    var bytes: [8192]u8 = undefined;
    const body = contextualPayload(&bytes, id, kind, version, timestamp, code, rvas, context) orelse return;
    queueBody(id, body);
}

pub fn watchdogPayload(out: []u8, id: []const u8, version: []const u8, timestamp: i64, health: @import("watchdog_health.zig").Snapshot) ?[]const u8 {
    if (id.len < 8 or id.len > 64 or version.len == 0 or version.len > 64 or health.responsive_ms > health.observed_ms) return null;
    for (id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-') return null;
    for (version) |c| if (!std.ascii.isAlphanumeric(c) and c != '.' and c != '-') return null;
    return std.fmt.bufPrint(out, "{{\"id\":\"{s}\",\"captured_at\":{d},\"app_version\":\"{s}\",\"android_version\":\"Windows\",\"thread\":\"watchdog\",\"summary\":\"Windows watchdog health\",\"stack_trace\":\"observed_ms: {d}\\nresponsive_ms: {d}\\nunobserved_ms: {d}\\nfreezes: {d}\\n\"}}", .{ id, timestamp, version, health.observed_ms, health.responsive_ms, health.unobserved_ms, health.freezes }) catch null;
}

pub fn queueWatchdog(id: []const u8, version: []const u8, timestamp: i64, health: @import("watchdog_health.zig").Snapshot) void {
    var bytes: [2048]u8 = undefined;
    const body = watchdogPayload(&bytes, id, version, timestamp, health) orelse return;
    queueBody(id, body);
}

fn queueBody(id: []const u8, body: []const u8) void {
    var name_buf: [96]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "upload-{s}.json", .{id}) catch return;
    var temp_buf: [100]u8 = undefined;
    const temp = std.fmt.bufPrint(&temp_buf, "{s}.tmp", .{name}) catch return;
    var temp_path: [420]u16 = undefined;
    const tw = path(&temp_path, temp) orelse return;
    const file = win.CreateFileW(tw.ptr, 0x40000000, 0, null, 2, 0x80, null);
    if (file == null or @intFromPtr(file) == INVALID) return;
    var n: u32 = 0;
    const ok = win.WriteFile(file, body.ptr, @intCast(body.len), &n, null) != 0 and n == body.len;
    _ = win.CloseHandle(file);
    if (!ok) {
        _ = win.DeleteFileW(tw.ptr);
        return;
    }
    var final_path: [420]u16 = undefined;
    const fw = path(&final_path, name) orelse return;
    if (win.MoveFileExW(tw.ptr, fw.ptr, 0x8) == 0) return;
    if (g_wake != null) _ = win.SetEvent(g_wake);
}

fn drain(token: []const u8) void {
    var glob: [420]u16 = undefined;
    const pattern = path(&glob, "upload-*.json") orelse return;
    var data: win.WIN32_FIND_DATAW = undefined;
    const found = win.FindFirstFileW(pattern.ptr, &data);
    if (found == null or @intFromPtr(found) == INVALID) return;
    defer _ = win.FindClose(found);
    while (!g_stopping.load(.acquire)) {
        const name = std.mem.sliceTo(&data.cFileName, 0);
        if (g_directory_len + name.len + 2 <= glob.len and data.dwFileAttributes & 0x10 == 0) {
            @memcpy(glob[0..g_directory_len], g_directory[0..g_directory_len]);
            glob[g_directory_len] = '\\';
            @memcpy(glob[g_directory_len + 1 ..][0..name.len], name);
            glob[g_directory_len + name.len + 1] = 0;
            const file = win.CreateFileW(@ptrCast(&glob), 0x80000000, 1, null, 3, 0x80, null);
            if (file != null and @intFromPtr(file) != INVALID) {
                var size: i64 = 0;
                var bytes: [8192]u8 = undefined;
                var n: u32 = 0;
                const ok = win.GetFileSizeEx(file, &size) != 0 and size > 0 and size <= bytes.len and win.ReadFile(file, &bytes, @intCast(size), &n, null) != 0 and n == size;
                _ = win.CloseHandle(file);
                if (ok) {
                    const reply = client.request("POST", "/v1/crash-reports", token, bytes[0..n]) catch return;
                    defer reply.deinit();
                    if (reply.status == 200 or reply.status == 201) {
                        const ack = std.json.parseFromSlice(struct { stored: bool, duplicate: bool = false }, std.heap.page_allocator, reply.bytes, .{ .ignore_unknown_fields = true }) catch return;
                        defer ack.deinit();
                        if (ack.value.stored or ack.value.duplicate) _ = win.DeleteFileW(@ptrCast(&glob));
                    } else return;
                }
            }
        }
        if (win.FindNextFileW(found, &data) == 0) break;
    }
}

fn worker(_: ?*anyopaque) callconv(.winapi) u32 {
    while (!g_stopping.load(.acquire)) {
        var token: [8192]u8 = undefined;
        AcquireSRWLockExclusive(&g_lock);
        const n = g_token_len;
        @memcpy(token[0..n], g_token[0..n]);
        ReleaseSRWLockExclusive(&g_lock);
        if (n > 0) drain(token[0..n]);
        std.crypto.secureZero(u8, &token);
        _ = win.WaitForSingleObject(g_wake, 5000);
    }
    return 0;
}

test "upload payload contains only typed diagnostic values" {
    var out: [8192]u8 = undefined;
    const body = payload(&out, "freeze-12345", .freeze, "0.28.1", 1793016000, 0, &.{ 0x1234, 0x5678 }).?;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("Windows freeze", parsed.value.object.get("summary").?.string);
    try std.testing.expectEqualStrings("exception_code: 0x0\nstack_rvas:\n  0x1234\n  0x5678\n", parsed.value.object.get("stack_trace").?.string);
    try std.testing.expect(payload(&out, "bad\"-name", .crash, "0.28.1", 1, 0, &.{}) == null);
    try std.testing.expect(payload(&out, "crash-12345", .crash, "private/path", 1, 0, &.{}) == null);
}

test "freeze context appears in the reported JSON without changing its keys" {
    var out: [8192]u8 = undefined;
    const cases = [_]struct { context: FreezeContext, trace: []const u8 }{
        .{ .context = .unavailable, .trace = "exception_code: 0x0\nthread_context: unavailable\nsampled_instruction: unavailable\nstack_rvas:\n  0x1234\n" },
        .{ .context = .{ .captured = null }, .trace = "exception_code: 0x0\nthread_context: captured\nsampled_instruction: unmapped\nstack_rvas:\n  0x1234\n" },
        .{ .context = .{ .captured = .{ .module = .@"ntdll.dll", .rva = 0x9876 } }, .trace = "exception_code: 0x0\nthread_context: captured\nsampled_instruction: ntdll.dll+0x9876\nstack_rvas:\n  0x1234\n" },
    };
    for (cases) |case| {
        const body = contextualPayload(&out, "freeze-12345", .freeze, "0.28.1", 123, 0, &.{0x1234}, case.context).?;
        const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
        defer parsed.deinit();
        const object = parsed.value.object;
        try std.testing.expectEqual(@as(usize, 7), object.count());
        for ([_][]const u8{ "id", "captured_at", "app_version", "android_version", "thread", "summary", "stack_trace" }) |key| try std.testing.expect(object.contains(key));
        try std.testing.expectEqualStrings("Windows freeze", object.get("summary").?.string);
        try std.testing.expectEqualStrings(case.trace, object.get("stack_trace").?.string);
    }
    const blank = contextualPayload(&out, "blank-12345", .blank_chat, "0.28.1", 123, 0, &.{}, .unavailable).?;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, blank, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("Windows blank_chat", parsed.value.object.get("summary").?.string);
}

test "legacy payloads remain byte exact" {
    var out: [8192]u8 = undefined;
    try std.testing.expectEqualStrings("{\"id\":\"freeze-12345\",\"captured_at\":123,\"app_version\":\"0.28.1\",\"android_version\":\"Windows\",\"thread\":\"main\",\"summary\":\"Windows freeze\",\"stack_trace\":\"exception_code: 0x0\\nstack_rvas:\\n  0x1234\\n\"}", payload(&out, "freeze-12345", .freeze, "0.28.1", 123, 0, &.{0x1234}).?);
    try std.testing.expectEqualStrings("{\"id\":\"crash-12345\",\"captured_at\":123,\"app_version\":\"0.28.1\",\"android_version\":\"Windows\",\"thread\":\"main\",\"summary\":\"Windows crash\",\"stack_trace\":\"exception_code: 0xC0000005\\nstack_rvas:\\n  0x1234\\n\"}", payload(&out, "crash-12345", .crash, "0.28.1", 123, 0xC0000005, &.{0x1234}).?);
}

test "freeze payload bounds and canonical module names" {
    var out: [8192]u8 = undefined;
    const names = [_][]const u8{ "multiprompt.exe", "ntdll.dll", "kernelbase.dll", "kernel32.dll", "user32.dll", "win32u.dll", "gdi32.dll", "gdi32full.dll", "dwrite.dll" };
    inline for (std.meta.fields(Module), names) |field, name| {
        const context: FreezeContext = .{ .captured = .{ .module = @enumFromInt(field.value), .rva = 0x42 } };
        const body = contextualPayload(&out, "freeze-12345", .freeze, "0.28.1", 123, 0, &.{}, context).?;
        const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
        defer parsed.deinit();
        var expected: [256]u8 = undefined;
        const trace = try std.fmt.bufPrint(&expected, "exception_code: 0x0\nthread_context: captured\nsampled_instruction: {s}+0x42\nstack_rvas:\n", .{name});
        try std.testing.expectEqualStrings(trace, parsed.value.object.get("stack_trace").?.string);
    }
    const context: FreezeContext = .{ .captured = .{ .module = .@"user32.dll", .rva = 0x1042 - 0x1000 } };
    const equivalent: FreezeContext = .{ .captured = .{ .module = .@"user32.dll", .rva = 0x9042 - 0x9000 } };
    const candidates = [_]usize{0xABC} ** 25;
    var other: [8192]u8 = undefined;
    const body = contextualPayload(&out, "freeze-12345", .freeze, "0.28.1", 123, 0, &candidates, context).?;
    const same = contextualPayload(&other, "freeze-12345", .freeze, "0.28.1", 123, 0, &candidates, equivalent).?;
    try std.testing.expectEqualStrings(body, same);
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 24), std.mem.count(u8, parsed.value.object.get("stack_trace").?.string, "  0xABC\n"));
    var small: [32]u8 = undefined;
    try std.testing.expect(contextualPayload(&small, "freeze-12345", .freeze, "0.28.1", 123, 0, &candidates, context) == null);
}
