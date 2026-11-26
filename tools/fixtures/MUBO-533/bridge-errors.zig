const std = @import("std");
const stderr = ("z" ** 8991) ++ "last-byte";
var stderr_pos: usize = 0;
var logged: std.ArrayList(u8) = .empty;
var process_exited = true;
var process_terminated = false;
const Process = struct { hProcess: usize = 1 };
const Job = struct {
    error_text: [2048]u8 = undefined,
    error_len: usize = 0,
    output_len: usize = 0,
    success: bool = false,
    timed_out: bool = false,
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};
const diagnostics = struct {
    fn syncLog(message: []const u8) void {
        logged.appendSlice(std.testing.allocator, message) catch unreachable;
        logged.append(std.testing.allocator, '\n') catch unreachable;
    }
};
const w = struct {
    const DWORD = u32;
    const HANDLE = usize;
    fn PeekNamedPipe(_: HANDLE, _: ?*anyopaque, _: DWORD, _: ?*DWORD, available: *DWORD, _: ?*DWORD) i32 {
        available.* = @intCast(stderr.len - stderr_pos);
        return 1;
    }
    fn ReadFile(_: HANDLE, buffer: *[4096]u8, length: usize, count: *DWORD, _: ?*anyopaque) i32 {
        @memcpy(buffer[0..length], stderr[stderr_pos .. stderr_pos + length]);
        stderr_pos += length;
        count.* = @intCast(length);
        return 1;
    }
    fn WaitForSingleObject(_: HANDLE, _: DWORD) DWORD {
        return if (process_exited) 0 else 258;
    }
    fn TerminateProcess(_: HANDLE, _: DWORD) i32 {
        process_terminated = true;
        process_exited = true;
        return 1;
    }
    fn GetExitCodeProcess(_: HANDLE, code: *DWORD) i32 {
        std.debug.assert(process_exited);
        code.* = if (process_terminated) 1 else 2;
        return 1;
    }
};

test "failed bridge logs every stderr byte beyond the dialog cap and its exit code" {
    defer logged.deinit(std.testing.allocator);
    logged = .empty;
    stderr_pos = 0;
    process_exited = true;
    process_terminated = false;
    var job = Job{};
    finish(&job, .{}, 2);
    try std.testing.expectEqual(stderr.len, stderr_pos);
    try std.testing.expectEqual(job.error_text.len, job.error_len);
    try std.testing.expectEqualSlices(u8, stderr[0..2048], job.error_text[0..job.error_len]);
    try std.testing.expectEqual(@as(usize, 8991), std.mem.count(u8, logged.items, "z"));
    try std.testing.expect(std.mem.indexOf(u8, logged.items, "last-byte") != null);
    try std.testing.expect(std.mem.indexOf(u8, logged.items, "bridge failed exit_code=2 exit_code_known=true reply_bytes=0") != null);
    try std.testing.expect(!process_terminated);
}

test "failed bridge is reaped before its exit code and remaining stderr are logged" {
    defer logged.deinit(std.testing.allocator);
    logged = .empty;
    stderr_pos = 0;
    process_exited = false;
    process_terminated = false;
    var job = Job{ .timed_out = true };
    finish(&job, .{}, 2);
    try std.testing.expect(process_terminated);
    try std.testing.expect(std.mem.indexOf(u8, logged.items, "exit_code=1 exit_code_known=true") != null);
    try std.testing.expect(std.mem.indexOf(u8, logged.items, "last-byte") != null);
    try std.testing.expect(std.mem.indexOf(u8, logged.items, "timed_out=true") != null);
}

test "successful bridge has no failure log" {
    defer logged.deinit(std.testing.allocator);
    logged = .empty;
    stderr_pos = stderr.len;
    process_exited = true;
    process_terminated = false;
    var job = Job{ .success = true };
    finish(&job, .{}, 2);
    try std.testing.expect(std.mem.indexOf(u8, logged.items, "bridge reply received") != null);
    try std.testing.expect(std.mem.indexOf(u8, logged.items, "bridge failed") == null);
}
