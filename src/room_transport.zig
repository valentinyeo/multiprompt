const std = @import("std");
const w = @import("win32.zig");
const console = @import("console.zig");
const app_state = @import("app_state.zig");
const L = std.unicode.utf8ToUtf16LeStringLiteral;
extern "kernel32" fn OpenThread(w.DWORD, w.BOOL, w.DWORD) callconv(w.WINAPI) w.HANDLE;
extern "kernel32" fn CancelSynchronousIo(w.HANDLE) callconv(w.WINAPI) w.BOOL;

const bootstrap = "import base64,sys,types,os;m=types.ModuleType('room_service');sys.modules[m.__name__]=m;exec(compile(base64.b64decode(sys.stdin.buffer.readline()),'room_service.py','exec'),m.__dict__);b=types.ModuleType('room_bridge');exec(compile(base64.b64decode(sys.stdin.buffer.readline()),'room_bridge.py','exec'),b.__dict__);b.serve(os.path.expanduser('~/.local/state/multiprompt/rooms'))";

pub const Job = struct {
    host: u8,
    request: []const u8,
    output: []u8,
    output_len: usize = 0,
    success: bool = false,
    finished: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn writeAll(handle: w.HANDLE, bytes: []const u8, expired: *std.atomic.Value(bool)) bool {
    var position: usize = 0;
    while (position < bytes.len) {
        if (expired.load(.acquire)) return false;
        var written: w.DWORD = 0;
        if (w.WriteFile(handle, bytes.ptr + position, @intCast(bytes.len - position), &written, null) == 0 or written == 0) return false;
        position += written;
    }
    return true;
}

fn writeSource(handle: w.HANDLE, source: []const u8, expired: *std.atomic.Value(bool)) bool {
    const allocator = std.heap.page_allocator;
    const buffer = allocator.alloc(u8, std.base64.standard.Encoder.calcSize(source.len) + 1) catch return false;
    defer allocator.free(buffer);
    _ = std.base64.standard.Encoder.encode(buffer[0 .. buffer.len - 1], source);
    buffer[buffer.len - 1] = '\n';
    return writeAll(handle, buffer, expired);
}

const Watchdog = struct {
    process: w.HANDLE,
    worker: w.HANDLE,
    expired: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    writes_finished: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn deadline(watchdog: *Watchdog) void {
    const wait = w.WaitForSingleObject(watchdog.process, 15000);
    if (wait != 0x00000102 and watchdog.writes_finished.load(.acquire)) return;
    watchdog.expired.store(true, .release);
    if (wait == 0x00000102) _ = w.TerminateProcess(watchdog.process, 1);
    while (!watchdog.writes_finished.load(.acquire)) {
        _ = CancelSynchronousIo(watchdog.worker);
        w.Sleep(10);
    }
}

pub fn start(job: *Job) bool {
    if (job.request.len == 0 or job.request.len > 131071 or job.output.len < 262145 or std.mem.indexOfScalar(u8, job.request, '\n') != null) return false;
    const thread = std.Thread.spawn(.{}, run, .{job}) catch return false;
    thread.detach();
    return true;
}

fn run(job: *Job) void {
    defer job.finished.store(true, .release);
    var cmd: [4096]u16 = undefined;
    var pos: usize = 0;
    if (!console.appendSshExe(&cmd, &pos) or
        !console.appendWideAscii(&cmd, &pos, "-T -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 ") or
        !console.appendWideAscii(&cmd, &pos, console.tmuxSshTarget(job.host)) or
        !console.appendWideAscii(&cmd, &pos, " python3 -u -c \"") or
        !console.appendWideAscii(&cmd, &pos, bootstrap) or
        !console.appendWideAscii(&cmd, &pos, "\"")) return;
    cmd[pos] = 0;
    var attributes = w.SECURITY_ATTRIBUTES{ .nLength = @sizeOf(w.SECURITY_ATTRIBUTES), .lpSecurityDescriptor = null, .bInheritHandle = 1 };
    var child_input: w.HANDLE = null;
    var input: w.HANDLE = null;
    if (w.CreatePipe(&child_input, &input, &attributes, 1 << 20) == 0) return;
    defer if (child_input != null) _ = w.CloseHandle(child_input);
    defer if (input != null) _ = w.CloseHandle(input);
    var output: w.HANDLE = null;
    var child_output: w.HANDLE = null;
    if (w.CreatePipe(&output, &child_output, &attributes, 1 << 20) == 0) return;
    defer _ = w.CloseHandle(output);
    defer if (child_output != null) _ = w.CloseHandle(child_output);
    if (w.SetHandleInformation(input, app_state.HANDLE_FLAG_INHERIT, 0) == 0 or w.SetHandleInformation(output, app_state.HANDLE_FLAG_INHERIT, 0) == 0) return;
    const stderr = w.CreateFileW(L("NUL"), w.GENERIC_WRITE, w.FILE_SHARE_READ | w.FILE_SHARE_WRITE, &attributes, w.OPEN_EXISTING, w.FILE_ATTRIBUTE_NORMAL, null);
    if (stderr == w.INVALID_HANDLE_VALUE_PTR) return;
    defer _ = w.CloseHandle(stderr);
    var startup = std.mem.zeroes(w.STARTUPINFOW);
    startup.cb = @sizeOf(w.STARTUPINFOW);
    startup.dwFlags = 0x00000100;
    startup.hStdInput = child_input;
    startup.hStdOutput = child_output;
    startup.hStdError = stderr;
    var process = std.mem.zeroes(w.PROCESS_INFORMATION);
    if (w.CreateProcessW(null, @ptrCast(&cmd), null, null, 1, 0x08000000, null, null, &startup, &process) == 0) return;
    _ = w.CloseHandle(process.hThread);
    defer _ = w.CloseHandle(process.hProcess);
    const worker_handle = OpenThread(0x0001, 0, w.GetCurrentThreadId()) orelse {
        _ = w.TerminateProcess(process.hProcess, 1);
        return;
    };
    defer _ = w.CloseHandle(worker_handle);
    var watch = Watchdog{ .process = process.hProcess, .worker = worker_handle };
    const watchdog = std.Thread.spawn(.{}, deadline, .{&watch}) catch {
        _ = w.TerminateProcess(process.hProcess, 1);
        return;
    };
    defer watchdog.join();
    defer watch.writes_finished.store(true, .release);
    defer _ = w.TerminateProcess(process.hProcess, 1);
    _ = w.CloseHandle(child_input);
    child_input = null;
    _ = w.CloseHandle(child_output);
    child_output = null;
    if (!writeSource(input, @embedFile("room_service.py"), &watch.expired) or !writeSource(input, @embedFile("room_bridge.py"), &watch.expired) or !writeAll(input, job.request, &watch.expired) or !writeAll(input, "\n", &watch.expired)) return;
    watch.writes_finished.store(true, .release);
    _ = w.CloseHandle(input);
    input = null;
    const expires_at = w.GetTickCount64() + 15000;
    while (w.GetTickCount64() < expires_at and !watch.expired.load(.acquire)) {
        var available: w.DWORD = 0;
        if (w.PeekNamedPipe(output, null, 0, null, &available, null) == 0) return;
        if (available == 0) {
            if (w.WaitForSingleObject(process.hProcess, 0) == 0) return;
            w.Sleep(10);
            continue;
        }
        if (job.output_len == job.output.len) return;
        var count: w.DWORD = 0;
        const limit: w.DWORD = @intCast(@min(@as(usize, available), job.output.len - job.output_len));
        if (w.ReadFile(output, job.output.ptr + job.output_len, limit, &count, null) == 0 or count == 0) return;
        const start_pos = job.output_len;
        job.output_len += count;
        if (std.mem.indexOfScalar(u8, job.output[start_pos..job.output_len], '\n')) |offset| {
            if (start_pos + offset + 1 != job.output_len) return;
            job.success = true;
            return;
        }
    }
}
