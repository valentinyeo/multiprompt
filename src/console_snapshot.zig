const std = @import("std");
const win = @import("win32.zig");
const W = std.unicode.utf8ToUtf16LeStringLiteral;

const Request = extern struct { pid: u32, sid: u32 };
const Header = extern struct { request: Request, width: u32 = 0, rows: u32 = 0, chars: u32 = 0 };
const Reply = extern struct { header: Header, raw: [262144]u16 = undefined };
pub const Snapshot = struct { width: usize, rows: usize, raw: []const u16 };
var input: win.HANDLE = null;
var output: win.HANDLE = null;
var process: win.HANDLE = null;
var pending = false;
var discard = false;
var reply: Reply = undefined;
var received: usize = 0;

pub fn invalidate() void {
    discard = pending;
}

pub fn close() void {
    if (input != null) _ = win.CloseHandle(input);
    if (output != null) _ = win.CloseHandle(output);
    if (process != null) _ = win.CloseHandle(process);
    input = null;
    output = null;
    process = null;
    pending = false;
    discard = false;
    received = 0;
}

fn start() bool {
    var exe: [520:0]u16 = @splat(0);
    const len = win.GetModuleFileNameW(null, &exe, exe.len);
    if (len == 0 or len >= exe.len) return false;
    var command: [600:0]u16 = @splat(0);
    command[0] = '"';
    @memcpy(command[1..][0..len], exe[0..len]);
    const suffix = "\" --console-snapshot";
    for (suffix, 0..) |c, i| command[len + 1 + i] = c;
    var sa = win.SECURITY_ATTRIBUTES{ .nLength = @sizeOf(win.SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var child_input: win.HANDLE = null;
    if (win.CreatePipe(&child_input, &input, &sa, 0) == 0) return false;
    defer _ = win.CloseHandle(child_input);
    var child_output: win.HANDLE = null;
    if (win.CreatePipe(&output, &child_output, &sa, 1 << 20) == 0) return false;
    defer _ = win.CloseHandle(child_output);
    if (win.SetHandleInformation(input, 1, 0) == 0 or win.SetHandleInformation(output, 1, 0) == 0) return false;
    var si = std.mem.zeroes(win.STARTUPINFOW);
    si.cb = @sizeOf(win.STARTUPINFOW);
    si.dwFlags = 0x100;
    si.hStdInput = child_input;
    si.hStdOutput = child_output;
    si.hStdError = child_output;
    var pi = std.mem.zeroes(win.PROCESS_INFORMATION);
    if (win.CreateProcessW(&exe, &command, null, null, 1, 0x08000000, null, null, &si, &pi) == 0) return false;
    _ = win.CloseHandle(pi.hThread);
    process = pi.hProcess;
    return true;
}

pub fn poll(pid: u32, sid: u32) ?Snapshot {
    if (process == null and !start()) {
        close();
        return null;
    }
    var result: ?Snapshot = null;
    if (pending) {
        const bytes = std.mem.asBytes(&reply);
        while (received < bytes.len) {
            var available: u32 = 0;
            if (win.PeekNamedPipe(output, null, 0, null, &available, null) == 0) {
                close();
                return null;
            }
            if (available == 0) break;
            var count: u32 = 0;
            if (win.ReadFile(output, bytes[received..].ptr, @intCast(@min(available, bytes.len - received)), &count, null) == 0 or count == 0) {
                close();
                return null;
            }
            received += count;
            if (received < @sizeOf(Header)) continue;
            const h = reply.header;
            if (h.chars > reply.raw.len or h.width > reply.raw.len or h.rows > 70 or h.width * @as(u64, h.rows) != h.chars) {
                close();
                return null;
            }
            if (received < @sizeOf(Header) + h.chars * @sizeOf(u16)) continue;
            pending = false;
            received = 0;
            if (!discard and h.request.pid == pid and h.request.sid == sid and h.width > 0) result = .{ .width = h.width, .rows = h.rows, .raw = reply.raw[0..h.chars] };
            discard = false;
            break;
        }
    }
    if (!pending) {
        const request = Request{ .pid = pid, .sid = sid };
        var count: u32 = 0;
        if (win.WriteFile(input, std.mem.asBytes(&request), @sizeOf(Request), &count, null) == 0 or count != @sizeOf(Request)) {
            close();
            return result;
        }
        pending = true;
    }
    return result;
}

fn readExact(handle: win.HANDLE, bytes: []u8) bool {
    var pos: usize = 0;
    while (pos < bytes.len) {
        var count: u32 = 0;
        if (win.ReadFile(handle, bytes[pos..].ptr, @intCast(bytes.len - pos), &count, null) == 0 or count == 0) return false;
        pos += count;
    }
    return true;
}

pub fn runIfRequested(args: []const []const u8) bool {
    if (args.len != 2 or !std.mem.eql(u8, args[1], "--console-snapshot")) return false;
    const source = win.GetStdHandle(@bitCast(@as(i32, -10)));
    const destination = win.GetStdHandle(win.STD_OUTPUT_HANDLE);
    var request: Request = undefined;
    while (readExact(source, std.mem.asBytes(&request))) {
        reply.header = .{ .request = request };
        acquire(request.pid, &reply);
        const bytes = std.mem.asBytes(&reply)[0 .. @sizeOf(Header) + reply.header.chars * @sizeOf(u16)];
        var pos: usize = 0;
        while (pos < bytes.len) {
            var count: u32 = 0;
            if (win.WriteFile(destination, bytes[pos..].ptr, @intCast(bytes.len - pos), &count, null) == 0 or count == 0) return true;
            pos += count;
        }
    }
    return true;
}

fn acquire(pid: u32, target: *Reply) void {
    _ = win.FreeConsole();
    if (pid == 0 or win.AttachConsole(pid) == 0) return;
    defer _ = win.FreeConsole();
    const handle = win.CreateFileW(W("CONOUT$"), win.GENERIC_READ, win.FILE_SHARE_READ | win.FILE_SHARE_WRITE, null, win.OPEN_EXISTING, 0, null);
    if (handle == null or handle == win.INVALID_HANDLE_VALUE_PTR) return;
    defer _ = win.CloseHandle(handle);
    var info: win.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (win.GetConsoleScreenBufferInfo(handle, &info) == 0 or info.dwSize.x <= 0 or info.dwSize.y <= 0) return;
    const width: usize = @intCast(info.dwSize.x);
    const end = @min(@as(i32, info.dwSize.y) - 1, @max(@as(i32, info.dwCursorPosition.y), @as(i32, info.srWindow.bottom)));
    const rows = @min(@min(70, target.raw.len / width), @as(usize, @intCast(end + 1)));
    if (rows == 0) return;
    var count: u32 = 0;
    const cells: u32 = @intCast(rows * width);
    if (win.ReadConsoleOutputCharacterW(handle, &target.raw, cells, .{ .x = 0, .y = @intCast(end - @as(i32, @intCast(rows)) + 1) }, &count) == 0 or count != cells) return;
    target.header.width = @intCast(width);
    target.header.rows = @intCast(rows);
    target.header.chars = count;
}

test "snapshot polling never waits for partial data and rejects a switched session" {
    var request_reader: win.HANDLE = null;
    try std.testing.expect(win.CreatePipe(&request_reader, &input, null, 0) != 0);
    defer _ = win.CloseHandle(request_reader);
    var reply_writer: win.HANDLE = null;
    try std.testing.expect(win.CreatePipe(&output, &reply_writer, null, 4096) != 0);
    defer _ = win.CloseHandle(reply_writer);
    defer {
        process = null;
        close();
    }
    process = win.GetCurrentProcess();
    try std.testing.expect(poll(12, 34) == null);
    var request: Request = undefined;
    try std.testing.expect(readExact(request_reader, std.mem.asBytes(&request)));
    try std.testing.expectEqual(@as(u32, 34), request.sid);
    const header = Header{ .request = request, .width = 2, .rows = 1, .chars = 2 };
    var count: u32 = 0;
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&header), @sizeOf(Header), &count, null) != 0);
    try std.testing.expect(poll(12, 34) == null);
    const text = [2]u16{ 'o', 'k' };
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&text), @sizeOf(@TypeOf(text)), &count, null) != 0);
    const snapshot = poll(12, 34).?;
    try std.testing.expectEqualSlices(u16, &text, snapshot.raw);
    try std.testing.expect(readExact(request_reader, std.mem.asBytes(&request)));
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&header), @sizeOf(Header), &count, null) != 0);
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&text), @sizeOf(@TypeOf(text)), &count, null) != 0);
    try std.testing.expect(poll(56, 78) == null);
    try std.testing.expect(readExact(request_reader, std.mem.asBytes(&request)));
    try std.testing.expectEqual(@as(u32, 56), request.pid);
    try std.testing.expectEqual(@as(u32, 78), request.sid);
    const current = Header{ .request = request, .width = 2, .rows = 1, .chars = 2 };
    invalidate();
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&current), @sizeOf(Header), &count, null) != 0);
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&text), @sizeOf(@TypeOf(text)), &count, null) != 0);
    try std.testing.expect(poll(56, 78) == null);
    try std.testing.expect(readExact(request_reader, std.mem.asBytes(&request)));
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&current), @sizeOf(Header), &count, null) != 0);
    try std.testing.expect(win.WriteFile(reply_writer, std.mem.asBytes(&text), @sizeOf(@TypeOf(text)), &count, null) != 0);
    try std.testing.expectEqualSlices(u16, &text, poll(56, 78).?.raw);
}
