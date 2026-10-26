const std = @import("std");
const builtin = @import("builtin");

pub const MAX_CRASH_FILES: usize = 10;
pub const LOOP_MAX_CRASHES: usize = 4;
pub const LOOP_WINDOW_SECS: i64 = 900;
pub const NOTICE_MAX_AGE_SECS: i64 = 600;
pub const LOG_TAIL_LINES: usize = 200;
pub const NOTICE_TEXT = "multiprompt restarted after a crash (details saved)";
pub const CRASH_NAME_LEN: usize = 25;

pub const Snapshot = struct {
    tab_count: u32,
    chat_view: bool,
    debug_log_on: bool,
    instance: []const u8,
};
pub const SnapshotFn = *const fn () Snapshot;

pub fn formatCrashName(buf: []u8, year: u16, month: u16, day: u16, hour: u16, minute: u16, second: u16, ext: []const u8) ?[]u8 {
    return std.fmt.bufPrint(buf, "crash-{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}{d:0>2}{s}", .{ year, month, day, hour, minute, second, ext }) catch null;
}

pub fn isCrashTxtName(name: []const u8) bool {
    return name.len == CRASH_NAME_LEN and std.mem.startsWith(u8, name, "crash-") and std.mem.endsWith(u8, name, ".txt");
}

pub fn filesToDelete(existing: usize) usize {
    return if (existing + 1 > MAX_CRASH_FILES) existing + 1 - MAX_CRASH_FILES else 0;
}

pub fn recentCrashCount(stamps: []const i64, now: i64) usize {
    var n: usize = 0;
    for (stamps) |s| {
        const age = now - s;
        if (age >= 0 and age <= LOOP_WINDOW_SECS) n += 1;
    }
    return n;
}

pub fn reopenAllowed(stamps: []const i64, now: i64) bool {
    return recentCrashCount(stamps, now) < LOOP_MAX_CRASHES;
}

pub fn reopenDelaySecs(stamps: []const i64, now: i64) u32 {
    return switch (recentCrashCount(stamps, now)) {
        0, 1 => 0,
        2 => 5,
        else => 30,
    };
}

pub fn parseStamps(text: []const u8, out: []i64) usize {
    var n: usize = 0;
    var it = std.mem.tokenizeAny(u8, text, "\r\n");
    while (it.next()) |line| {
        const v = std.fmt.parseInt(i64, std.mem.trim(u8, line, " \t"), 10) catch continue;
        if (n == out.len) {
            std.mem.copyForwards(i64, out[0 .. out.len - 1], out[1..]);
            n -= 1;
        }
        out[n] = v;
        n += 1;
    }
    return n;
}

pub fn formatStamps(buf: []u8, stamps: []const i64) []const u8 {
    var len: usize = 0;
    for (stamps) |s| {
        const piece = std.fmt.bufPrint(buf[len..], "{d}\n", .{s}) catch break;
        len += piece.len;
    }
    return buf[0..len];
}

pub fn tailLines(text: []const u8, n: usize) []const u8 {
    if (n == 0) return text[text.len..];
    var end = text.len;
    if (end > 0 and text[end - 1] == '\n') end -= 1;
    var count: usize = 0;
    var i = end;
    while (i > 0) {
        i -= 1;
        if (text[i] == '\n') {
            count += 1;
            if (count == n) return text[i + 1 ..];
        }
    }
    return text;
}

pub fn fileTimeToUnixSecs(ft: u64) i64 {
    const secs: i64 = @intCast(ft / 10_000_000);
    return secs - 11_644_473_600;
}

pub fn noticeIsFresh(marker_secs: i64, now: i64) bool {
    const age = now - marker_secs;
    return age >= 0 and age <= NOTICE_MAX_AGE_SECS;
}

pub fn isCrashCode(code: u32) bool {
    return code >= 0x8000_0000;
}

pub fn exceptionName(code: u32) []const u8 {
    return switch (code) {
        0xC0000005 => "ACCESS_VIOLATION",
        0xC00000FD => "STACK_OVERFLOW",
        0xC0000094 => "INT_DIVIDE_BY_ZERO",
        0xC000001D => "ILLEGAL_INSTRUCTION",
        0xC0000409 => "STACK_BUFFER_OVERRUN",
        0xC0000374 => "HEAP_CORRUPTION",
        0xC0000096 => "PRIVILEGED_INSTRUCTION",
        0xC0000006 => "IN_PAGE_ERROR",
        0xC000008C => "ARRAY_BOUNDS_EXCEEDED",
        0x80000003 => "BREAKPOINT",
        0x80000002 => "DATATYPE_MISALIGNMENT",
        else => "UNKNOWN",
    };
}

pub const Buf = struct {
    data: []u8,
    len: usize = 0,

    pub fn add(self: *Buf, s: []const u8) void {
        const n = @min(s.len, self.data.len - self.len);
        @memcpy(self.data[self.len..][0..n], s[0..n]);
        self.len += n;
    }

    pub fn print(self: *Buf, comptime fmt: []const u8, args: anytype) void {
        const piece = std.fmt.bufPrint(self.data[self.len..], fmt, args) catch {
            self.len = self.data.len;
            return;
        };
        self.len += piece.len;
    }

    pub fn slice(self: *const Buf) []const u8 {
        return self.data[0..self.len];
    }
};

pub const ReportInput = struct {
    version: []const u8,
    is_dev: bool,
    when: []const u8,
    kind: []const u8,
    message: []const u8,
    code: u32,
    address: usize,
    access_kind: ?usize,
    access_addr: usize,
    module: []const u8,
    module_base: usize,
    exe_base: usize,
    thread_id: u32,
    snap: Snapshot,
    log_tail: ?[]const u8,
    stack_rvas: []const usize,
    dump_name: ?[]const u8,
    reopen: bool,
};

pub fn buildReport(b: *Buf, in: ReportInput) void {
    b.print("multiprompt crash report\nversion: {s}\nbuild: {s}\ntime: {s} (local)\nkind: {s}\n", .{
        in.version, if (in.is_dev) "dev" else "stable", in.when, in.kind,
    });
    if (in.message.len > 0) b.print("message: {s}\n", .{in.message});
    b.print("exception_code: 0x{X:0>8} ({s})\nexception_address: 0x{X:0>16}\n", .{ in.code, exceptionName(in.code), in.address });
    if (in.access_kind) |k| {
        const what = switch (k) {
            0 => "read",
            1 => "write",
            8 => "execute",
            else => "access",
        };
        b.print("access: {s} at 0x{X:0>16}\n", .{ what, in.access_addr });
    }
    b.print("module: {s}\nmodule_base: 0x{X:0>16}\nmodule_offset: 0x{X}\n", .{ in.module, in.module_base, in.address -% in.module_base });
    b.print("exe_base: 0x{X:0>16}\n", .{in.exe_base});
    if (in.address >= in.exe_base and in.address - in.exe_base < 0x4000_0000) {
        b.print("exe_offset: 0x{X} (address minus exe base; match with the .pdb)\n", .{in.address - in.exe_base});
    } else {
        b.add("exe_offset: n/a (address is outside multiprompt.exe)\n");
    }
    b.print("thread_id: {d}\ntabs: {d}\nchat_view: {s}\ninstance: {s}\n", .{
        in.thread_id, in.snap.tab_count, if (in.snap.chat_view) "on" else "off", in.snap.instance,
    });
    b.print("minidump: {s}\nreopen: {s}\n", .{
        in.dump_name orelse "not written",
        if (in.reopen) "yes" else "no (4 crashes within 15 minutes, or recent.txt not writable)",
    });
    b.add("stack_rvas (exe offsets found on the stack, nearest first):\n");
    for (in.stack_rvas) |rva| b.print("  0x{X}\n", .{rva});
    if (in.log_tail) |tail| {
        b.print("debug_log_tail (last {d} lines):\n", .{LOG_TAIL_LINES});
        b.add(tail);
        if (tail.len > 0 and tail[tail.len - 1] != '\n') b.add("\n");
    } else {
        b.add("debug_log_tail: debug log off\n");
    }
}

const win = struct {
    const HANDLE = ?*anyopaque;
    const WINAPI: std.builtin.CallingConvention = .winapi;
    const INVALID_HANDLE: usize = std.math.maxInt(usize);

    const EXCEPTION_RECORD = extern struct {
        code: u32,
        flags: u32,
        next: ?*EXCEPTION_RECORD,
        address: ?*anyopaque,
        num_params: u32,
        info: [15]usize,
    };
    const EXCEPTION_POINTERS = extern struct {
        record: *EXCEPTION_RECORD,
        context: ?*anyopaque,
    };
    const FILETIME = extern struct { lo: u32, hi: u32 };
    const SYSTEMTIME = extern struct {
        year: u16,
        month: u16,
        day_of_week: u16,
        day: u16,
        hour: u16,
        minute: u16,
        second: u16,
        milliseconds: u16,
    };
    const WIN32_FIND_DATAW = extern struct {
        attrs: u32,
        ctime: FILETIME,
        atime: FILETIME,
        mtime: FILETIME,
        size_hi: u32,
        size_lo: u32,
        reserved0: u32,
        reserved1: u32,
        file_name: [260]u16,
        alt_name: [14]u16,
    };
    const STARTUPINFOW = extern struct {
        cb: u32,
        lpReserved: ?[*:0]u16,
        lpDesktop: ?[*:0]u16,
        lpTitle: ?[*:0]u16,
        dwX: u32,
        dwY: u32,
        dwXSize: u32,
        dwYSize: u32,
        dwXCountChars: u32,
        dwYCountChars: u32,
        dwFillAttribute: u32,
        dwFlags: u32,
        wShowWindow: u16,
        cbReserved2: u16,
        lpReserved2: ?*u8,
        hStdInput: HANDLE,
        hStdOutput: HANDLE,
        hStdError: HANDLE,
    };
    const PROCESS_INFORMATION = extern struct {
        hProcess: HANDLE,
        hThread: HANDLE,
        dwProcessId: u32,
        dwThreadId: u32,
    };
    const FilterFn = *const fn (*EXCEPTION_POINTERS) callconv(WINAPI) i32;
    const ThreadFn = *const fn (?*anyopaque) callconv(WINAPI) u32;

    extern "kernel32" fn SetUnhandledExceptionFilter(?FilterFn) callconv(WINAPI) ?FilterFn;
    extern "kernel32" fn SetThreadStackGuarantee(*u32) callconv(WINAPI) i32;
    extern "kernel32" fn CreateThread(?*anyopaque, usize, ThreadFn, ?*anyopaque, u32, ?*u32) callconv(WINAPI) HANDLE;
    extern "kernel32" fn Sleep(u32) callconv(WINAPI) void;
    extern "kernel32" fn WaitForSingleObject(HANDLE, u32) callconv(WINAPI) u32;
    extern "kernel32" fn CloseHandle(HANDLE) callconv(WINAPI) i32;
    extern "kernel32" fn GetCurrentThreadId() callconv(WINAPI) u32;
    extern "kernel32" fn GetCurrentProcessId() callconv(WINAPI) u32;
    extern "kernel32" fn GetCurrentProcess() callconv(WINAPI) HANDLE;
    extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(WINAPI) HANDLE;
    extern "kernel32" fn GetModuleHandleExW(u32, usize, *HANDLE) callconv(WINAPI) i32;
    extern "kernel32" fn GetModuleFileNameW(HANDLE, [*]u16, u32) callconv(WINAPI) u32;
    extern "kernel32" fn GetEnvironmentVariableW([*:0]const u16, ?[*]u16, u32) callconv(WINAPI) u32;
    extern "kernel32" fn CreateDirectoryW([*:0]const u16, ?*anyopaque) callconv(WINAPI) i32;
    extern "kernel32" fn CreateFileW([*:0]const u16, u32, u32, ?*anyopaque, u32, u32, HANDLE) callconv(WINAPI) HANDLE;
    extern "kernel32" fn ReadFile(HANDLE, [*]u8, u32, *u32, ?*anyopaque) callconv(WINAPI) i32;
    extern "kernel32" fn WriteFile(HANDLE, [*]const u8, u32, *u32, ?*anyopaque) callconv(WINAPI) i32;
    extern "kernel32" fn SetFilePointerEx(HANDLE, i64, ?*i64, u32) callconv(WINAPI) i32;
    extern "kernel32" fn DeleteFileW([*:0]const u16) callconv(WINAPI) i32;
    extern "kernel32" fn FindFirstFileW([*:0]const u16, *WIN32_FIND_DATAW) callconv(WINAPI) HANDLE;
    extern "kernel32" fn FindNextFileW(HANDLE, *WIN32_FIND_DATAW) callconv(WINAPI) i32;
    extern "kernel32" fn FindClose(HANDLE) callconv(WINAPI) i32;
    extern "kernel32" fn GetLocalTime(*SYSTEMTIME) callconv(WINAPI) void;
    extern "kernel32" fn GetSystemTimeAsFileTime(*FILETIME) callconv(WINAPI) void;
    extern "kernel32" fn ReadProcessMemory(HANDLE, usize, [*]u8, usize, ?*usize) callconv(WINAPI) i32;
    extern "kernel32" fn LoadLibraryA([*:0]const u8) callconv(WINAPI) HANDLE;
    extern "kernel32" fn GetProcAddress(HANDLE, [*:0]const u8) callconv(WINAPI) ?*anyopaque;
    extern "kernel32" fn CreateProcessW(?[*:0]const u16, ?[*:0]u16, ?*anyopaque, ?*anyopaque, i32, u32, ?*anyopaque, ?[*:0]const u16, *STARTUPINFOW, *PROCESS_INFORMATION) callconv(WINAPI) i32;
    extern "shell32" fn ShellExecuteW(HANDLE, ?[*:0]const u16, [*:0]const u16, ?[*:0]const u16, ?[*:0]const u16, i32) callconv(WINAPI) HANDLE;
};

const MiniDumpFn = *const fn (win.HANDLE, u32, win.HANDLE, u32, ?*const anyopaque, ?*const anyopaque, ?*const anyopaque) callconv(win.WINAPI) i32;

const GENERIC_READ: u32 = 0x80000000;
const GENERIC_WRITE: u32 = 0x40000000;
const CREATE_ALWAYS: u32 = 2;
const OPEN_EXISTING: u32 = 3;
const FILE_ATTRIBUTE_NORMAL: u32 = 0x80;
const SUBDIR = "\\ZigShell\\crashes";
const CAPTURE_CAP: usize = 64 * 1024;

var g_snapshot_fn: ?SnapshotFn = null;
var g_dump_fn: ?MiniDumpFn = null;
var g_version: []const u8 = "";
var g_is_dev: bool = false;
var g_in_crash: bool = false;
var g_info: ?*win.EXCEPTION_POINTERS = null;
var g_crash_tid: u32 = 0;
var g_panic_msg: []const u8 = "";
var g_panic_addr: usize = 0;
var g_dir: [300]u16 = undefined;
var g_dir_len: usize = 0;
var g_log_path: [300]u16 = undefined;
var g_log_path_len: usize = 0;
var g_exe: [520]u16 = undefined;
var g_exe_len: usize = 0;
var g_report_mem: [48 * 1024]u8 = undefined;
var g_tail_mem: [CAPTURE_CAP]u8 = undefined;

fn wideAppendAscii(out: []u16, pos: *usize, s: []const u8) void {
    for (s) |c| {
        if (pos.* + 1 >= out.len) return;
        out[pos.*] = c;
        pos.* += 1;
    }
}

fn joinWide(out: []u16, name: []const u8) ?[:0]const u16 {
    if (g_dir_len + 1 + name.len + 1 > out.len) return null;
    @memcpy(out[0..g_dir_len], g_dir[0..g_dir_len]);
    var pos: usize = g_dir_len;
    wideAppendAscii(out, &pos, "\\");
    wideAppendAscii(out, &pos, name);
    out[pos] = 0;
    return out[0..pos :0];
}

fn initPaths() void {
    var pos: usize = 0;
    const got = win.GetEnvironmentVariableW(std.unicode.utf8ToUtf16LeStringLiteral("APPDATA"), &g_dir, g_dir.len - 40);
    if (got == 0 or got >= g_dir.len - 40) return;
    pos = got;
    @memcpy(g_log_path[0..pos], g_dir[0..pos]);
    var lp: usize = pos;
    wideAppendAscii(&g_log_path, &lp, "\\ZigShell\\debug.log");
    g_log_path[lp] = 0;
    g_log_path_len = lp;
    wideAppendAscii(&g_dir, &pos, "\\ZigShell");
    g_dir[pos] = 0;
    _ = win.CreateDirectoryW(@ptrCast(&g_dir), null);
    wideAppendAscii(&g_dir, &pos, "\\crashes");
    g_dir[pos] = 0;
    _ = win.CreateDirectoryW(@ptrCast(&g_dir), null);
    g_dir_len = pos;
    const n = win.GetModuleFileNameW(null, &g_exe, g_exe.len - 1);
    if (n > 0 and n < g_exe.len - 1) {
        g_exe[n] = 0;
        g_exe_len = n;
    }
}

fn writeWholeFile(path: [:0]const u16, bytes: []const u8) bool {
    const h = win.CreateFileW(path.ptr, GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (@intFromPtr(h) == win.INVALID_HANDLE or h == null) return false;
    defer _ = win.CloseHandle(h);
    var total: usize = 0;
    while (total < bytes.len) {
        var written: u32 = 0;
        const chunk: u32 = @intCast(@min(bytes.len - total, 1 << 20));
        if (win.WriteFile(h, bytes[total..].ptr, chunk, &written, null) == 0 or written == 0) return false;
        total += written;
    }
    return true;
}

fn readFileTail(path: [:0]const u16, buf: []u8) usize {
    const h = win.CreateFileW(path.ptr, GENERIC_READ, 3, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (@intFromPtr(h) == win.INVALID_HANDLE or h == null) return 0;
    defer _ = win.CloseHandle(h);
    var size: i64 = 0;
    if (win.SetFilePointerEx(h, 0, &size, 2) == 0) return 0;
    const want: i64 = @intCast(buf.len);
    const start: i64 = if (size > want) size - want else 0;
    if (win.SetFilePointerEx(h, start, null, 0) == 0) return 0;
    var total: usize = 0;
    while (total < buf.len) {
        var got: u32 = 0;
        if (win.ReadFile(h, buf[total..].ptr, @intCast(buf.len - total), &got, null) == 0 or got == 0) break;
        total += got;
    }
    return total;
}

fn deleteCrashFile(name: []const u8) void {
    var wbuf: [340]u16 = undefined;
    if (joinWide(&wbuf, name)) |p| _ = win.DeleteFileW(p.ptr);
}

fn pruneOldCrashFiles() void {
    var pat: [340]u16 = undefined;
    const pattern = joinWide(&pat, "crash-*.txt") orelse return;
    var names: [64][CRASH_NAME_LEN]u8 = undefined;
    var n: usize = 0;
    var fd: win.WIN32_FIND_DATAW = undefined;
    const fh = win.FindFirstFileW(pattern.ptr, &fd);
    if (@intFromPtr(fh) == win.INVALID_HANDLE or fh == null) return;
    while (true) {
        var name8: [64]u8 = undefined;
        var wl: usize = 0;
        while (wl < fd.file_name.len and fd.file_name[wl] != 0) wl += 1;
        if (wl == CRASH_NAME_LEN) {
            var ok = true;
            for (fd.file_name[0..wl], 0..) |c, i| {
                if (c > 127) {
                    ok = false;
                    break;
                }
                name8[i] = @intCast(c);
            }
            if (ok and isCrashTxtName(name8[0..wl]) and n < names.len) {
                @memcpy(&names[n], name8[0..CRASH_NAME_LEN]);
                n += 1;
            }
        }
        if (win.FindNextFileW(fh, &fd) == 0) break;
    }
    _ = win.FindClose(fh);
    std.mem.sort([CRASH_NAME_LEN]u8, names[0..n], {}, struct {
        fn lessThan(_: void, a: [CRASH_NAME_LEN]u8, b: [CRASH_NAME_LEN]u8) bool {
            return std.mem.lessThan(u8, &a, &b);
        }
    }.lessThan);
    const del = @min(filesToDelete(n), n);
    for (names[0..del]) |nm| {
        deleteCrashFile(&nm);
        var dmp: [CRASH_NAME_LEN]u8 = nm;
        @memcpy(dmp[CRASH_NAME_LEN - 4 ..], ".dmp");
        deleteCrashFile(&dmp);
    }
}

fn writeMiniDump(path: [:0]const u16, info: ?*win.EXCEPTION_POINTERS, tid: u32) bool {
    const dump_fn = g_dump_fn orelse return false;
    const h = win.CreateFileW(path.ptr, GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    if (@intFromPtr(h) == win.INVALID_HANDLE or h == null) return false;
    var exc: [16]u8 align(8) = std.mem.zeroes([16]u8);
    if (info) |p| {
        std.mem.writeInt(u32, exc[0..4], tid, .little);
        std.mem.writeInt(u64, exc[4..12], @intFromPtr(p), .little);
        std.mem.writeInt(i32, exc[12..16], 1, .little);
    }
    const dump_type: u32 = 0x20 | 0x40 | 0x1000;
    const ok = dump_fn(win.GetCurrentProcess(), win.GetCurrentProcessId(), h, dump_type, if (info != null) @ptrCast(&exc) else null, null, null) != 0;
    _ = win.CloseHandle(h);
    if (!ok) _ = win.DeleteFileW(path.ptr);
    return ok;
}

fn scanStackForExeAddresses(ctx: ?*anyopaque, exe_base: usize, out: []usize) usize {
    if (builtin.cpu.arch != .x86_64) return 0;
    const c = ctx orelse return 0;
    if (exe_base == 0) return 0;
    const cp: [*]const u8 = @ptrCast(c);
    const rsp = std.mem.readInt(u64, cp[0x98..][0..8], .little);
    const base_p: [*]const u8 = @ptrFromInt(exe_base);
    const nt = std.mem.readInt(u32, base_p[0x3C..][0..4], .little);
    const image_size = std.mem.readInt(u32, base_p[nt + 24 + 56 ..][0..4], .little);
    var stack: [1024]u8 = undefined;
    var got: usize = 0;
    if (win.ReadProcessMemory(win.GetCurrentProcess(), @intCast(rsp), &stack, stack.len, &got) == 0) return 0;
    var n: usize = 0;
    var off: usize = 0;
    while (off + 8 <= got and n < out.len) : (off += 8) {
        const v = std.mem.readInt(u64, stack[off..][0..8], .little);
        if (v >= exe_base and v - exe_base < image_size) {
            out[n] = @intCast(v - exe_base);
            n += 1;
        }
    }
    return n;
}

fn spawnReopen() void {
    if (g_exe_len == 0) return;
    var cmd: [1100]u16 = undefined;
    var p: usize = 0;
    wideAppendAscii(&cmd, &p, "\"");
    for (g_exe[0..g_exe_len]) |c| {
        if (p + 80 >= cmd.len) return;
        cmd[p] = c;
        p += 1;
    }
    wideAppendAscii(&cmd, &p, "\" --after-crash --relaunch-after ");
    var pid_buf: [16]u8 = undefined;
    const pid_s = std.fmt.bufPrint(&pid_buf, "{d}", .{win.GetCurrentProcessId()}) catch return;
    wideAppendAscii(&cmd, &p, pid_s);
    cmd[p] = 0;
    var si = std.mem.zeroes(win.STARTUPINFOW);
    si.cb = @sizeOf(win.STARTUPINFOW);
    si.dwFlags = 0x1;
    si.wShowWindow = 3;
    var pi = std.mem.zeroes(win.PROCESS_INFORMATION);
    if (win.CreateProcessW(@ptrCast(&g_exe), @ptrCast(&cmd), null, null, 0, 0x00000008 | 0x08000000, null, null, &si, &pi) == 0) return;
    if (pi.hProcess != null) _ = win.CloseHandle(pi.hProcess);
    if (pi.hThread != null) _ = win.CloseHandle(pi.hThread);
}

fn unixNow() i64 {
    var ft: win.FILETIME = undefined;
    win.GetSystemTimeAsFileTime(&ft);
    return fileTimeToUnixSecs((@as(u64, ft.hi) << 32) | ft.lo);
}

fn basenameUtf8(wide: []const u16, out: []u8) []const u8 {
    var start: usize = 0;
    for (wide, 0..) |c, i| {
        if (c == '\\' or c == '/') start = i + 1;
    }
    const n = std.unicode.utf16LeToUtf8(out, wide[start..]) catch return "?";
    return out[0..n];
}

fn recordCrash() void {
    if (g_dir_len == 0) return;
    const now = unixNow();
    var st: win.SYSTEMTIME = undefined;
    win.GetLocalTime(&st);
    var name_buf: [48]u8 = undefined;
    const txt_name = formatCrashName(&name_buf, st.year, st.month, st.day, st.hour, st.minute, st.second, ".txt") orelse return;
    var dmp_buf: [48]u8 = undefined;
    const dmp_name = formatCrashName(&dmp_buf, st.year, st.month, st.day, st.hour, st.minute, st.second, ".dmp") orelse return;
    var when_buf: [32]u8 = undefined;
    const when = std.fmt.bufPrint(&when_buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{ st.year, st.month, st.day, st.hour, st.minute, st.second }) catch "?";

    pruneOldCrashFiles();

    var recent_wide: [340]u16 = undefined;
    var stamps: [8]i64 = undefined;
    var n_stamps: usize = 0;
    var recent_ok = false;
    if (joinWide(&recent_wide, "recent.txt")) |p| {
        var text: [512]u8 = undefined;
        const got = readFileTail(p, &text);
        n_stamps = parseStamps(text[0..got], stamps[0 .. stamps.len - 1]);
        stamps[n_stamps] = now;
        n_stamps += 1;
        var out: [256]u8 = undefined;
        recent_ok = writeWholeFile(p, formatStamps(&out, stamps[0..n_stamps]));
    } else {
        stamps[0] = now;
        n_stamps = 1;
    }
    const reopen = recent_ok and reopenAllowed(stamps[0..n_stamps], now);
    const reopen_delay = reopenDelaySecs(stamps[0..n_stamps], now);

    var snap: Snapshot = .{ .tab_count = 0, .chat_view = false, .debug_log_on = false, .instance = "?" };
    if (g_snapshot_fn) |f| snap = f();

    var log_tail: ?[]const u8 = null;
    if (snap.debug_log_on and g_log_path_len > 0) {
        const got = readFileTail(g_log_path[0..g_log_path_len :0], &g_tail_mem);
        log_tail = tailLines(g_tail_mem[0..got], LOG_TAIL_LINES);
    }

    const exe_base = @intFromPtr(win.GetModuleHandleW(null));
    var code: u32 = 0;
    var address: usize = g_panic_addr;
    var access_kind: ?usize = null;
    var access_addr: usize = 0;
    var ctx: ?*anyopaque = null;
    if (g_info) |info| {
        code = info.record.code;
        address = @intFromPtr(info.record.address);
        ctx = info.context;
        if (code == 0xC0000005 and info.record.num_params >= 2) {
            access_kind = info.record.info[0];
            access_addr = info.record.info[1];
        }
    }
    var hmod: win.HANDLE = null;
    var mod_name_buf: [96]u8 = undefined;
    var module: []const u8 = "?";
    var module_base: usize = exe_base;
    if (address != 0 and win.GetModuleHandleExW(0x4 | 0x2, address, &hmod) != 0 and hmod != null) {
        module_base = @intFromPtr(hmod);
        var wname: [260]u16 = undefined;
        const wl = win.GetModuleFileNameW(hmod, &wname, wname.len);
        if (wl > 0 and wl < wname.len) module = basenameUtf8(wname[0..wl], &mod_name_buf);
    } else {
        module = "multiprompt.exe";
    }

    var rvas: [24]usize = undefined;
    const n_rvas = scanStackForExeAddresses(ctx, exe_base, &rvas);

    var b = Buf{ .data = &g_report_mem };
    buildReport(&b, .{
        .version = g_version,
        .is_dev = g_is_dev,
        .when = when,
        .kind = if (g_info == null) "panic" else "exception",
        .message = g_panic_msg,
        .code = code,
        .address = address,
        .access_kind = access_kind,
        .access_addr = access_addr,
        .module = module,
        .module_base = module_base,
        .exe_base = exe_base,
        .thread_id = g_crash_tid,
        .snap = snap,
        .log_tail = log_tail,
        .stack_rvas = rvas[0..n_rvas],
        .dump_name = if (g_dump_fn != null) dmp_name else null,
        .reopen = reopen,
    });
    var txt_wide: [340]u16 = undefined;
    if (joinWide(&txt_wide, txt_name)) |p| _ = writeWholeFile(p, b.slice());

    if (reopen) {
        var marker_wide: [340]u16 = undefined;
        if (joinWide(&marker_wide, "restarted.marker")) |p| {
            var mb: [24]u8 = undefined;
            const ms = std.fmt.bufPrint(&mb, "{d}\n", .{now}) catch "";
            _ = writeWholeFile(p, ms);
        }
        if (reopen_delay > 0) win.Sleep(reopen_delay * 1000);
        spawnReopen();
    }

    var dmp_wide: [340]u16 = undefined;
    if (joinWide(&dmp_wide, dmp_name)) |p| _ = writeMiniDump(p, g_info, g_crash_tid);
}

fn workerEntry(_: ?*anyopaque) callconv(win.WINAPI) u32 {
    recordCrash();
    return 0;
}

fn unhandledFilter(info: *win.EXCEPTION_POINTERS) callconv(win.WINAPI) i32 {
    if (!isCrashCode(info.record.code)) return 0;
    if (g_in_crash) return 1;
    g_in_crash = true;
    g_info = info;
    g_crash_tid = win.GetCurrentThreadId();
    var tid: u32 = 0;
    const th = win.CreateThread(null, 1 << 20, workerEntry, null, 0, &tid);
    if (th != null) {
        _ = win.WaitForSingleObject(th, 55_000);
        _ = win.CloseHandle(th);
    } else {
        recordCrash();
    }
    return 1;
}

pub fn install(snapshot_fn: SnapshotFn, version: []const u8, is_dev: bool) void {
    g_snapshot_fn = snapshot_fn;
    g_version = version;
    g_is_dev = is_dev;
    initPaths();
    if (win.LoadLibraryA("dbghelp.dll")) |lib| {
        if (win.GetProcAddress(lib, "MiniDumpWriteDump")) |raw| g_dump_fn = @ptrCast(@alignCast(raw));
    }
    var guarantee: u32 = 64 * 1024;
    _ = win.SetThreadStackGuarantee(&guarantee);
    _ = win.SetUnhandledExceptionFilter(unhandledFilter);
}

pub fn guardThread() void {
    var guarantee: u32 = 64 * 1024;
    _ = win.SetThreadStackGuarantee(&guarantee);
}

pub fn recordPanic(msg: []const u8, first_trace_addr: ?usize) void {
    if (g_in_crash) return;
    g_in_crash = true;
    g_info = null;
    g_crash_tid = win.GetCurrentThreadId();
    g_panic_msg = msg[0..@min(msg.len, 300)];
    g_panic_addr = first_trace_addr orelse 0;
    recordCrash();
}

pub fn takeRestartNotice() bool {
    if (g_dir_len == 0) return false;
    var wbuf: [340]u16 = undefined;
    const p = joinWide(&wbuf, "restarted.marker") orelse return false;
    var text: [32]u8 = undefined;
    const got = readFileTail(p, &text);
    if (got == 0) return false;
    _ = win.DeleteFileW(p.ptr);
    const secs = std.fmt.parseInt(i64, std.mem.trim(u8, text[0..got], " \r\n\t"), 10) catch return false;
    return noticeIsFresh(secs, unixNow());
}

pub fn writeFreezeReport(name: []const u8, bytes: []const u8) void {
    if (g_dir_len == 0) return;
    var path: [400]u16 = undefined;
    const report = joinWide(&path, name) orelse return;
    if (!writeWholeFile(report, bytes)) return;
    if (joinWide(&path, "freeze.marker")) |marker| _ = writeWholeFile(marker, "saved\n");
}

pub fn takeFreezeNotice() bool {
    if (g_dir_len == 0) return false;
    var path: [340]u16 = undefined;
    const marker = joinWide(&path, "freeze.marker") orelse return false;
    var text: [8]u8 = undefined;
    if (readFileTail(marker, &text) == 0) return false;
    return win.DeleteFileW(marker.ptr) != 0;
}

pub fn openFolder() void {
    if (g_dir_len == 0) return;
    _ = win.ShellExecuteW(null, std.unicode.utf8ToUtf16LeStringLiteral("open"), @ptrCast(&g_dir), null, null, 1);
}

pub fn crashNow() void {
    const p: *allowzero volatile u8 = @ptrFromInt(0);
    p.* = 1;
}

test "formatCrashName pads every field" {
    var buf: [48]u8 = undefined;
    try std.testing.expectEqualStrings("crash-20261011-090507.txt", formatCrashName(&buf, 2026, 10, 11, 9, 5, 7, ".txt").?);
    try std.testing.expectEqualStrings("crash-20261231-235959.dmp", formatCrashName(&buf, 2026, 12, 31, 23, 59, 59, ".dmp").?);
    var tiny: [4]u8 = undefined;
    try std.testing.expect(formatCrashName(&tiny, 2026, 1, 1, 1, 1, 1, ".txt") == null);
}

test "isCrashTxtName accepts only crash txt files" {
    try std.testing.expect(isCrashTxtName("crash-20261011-090507.txt"));
    try std.testing.expect(!isCrashTxtName("crash-20261011-090507.dmp"));
    try std.testing.expect(!isCrashTxtName("recent.txt"));
    try std.testing.expect(!isCrashTxtName("crash-1.txt"));
}

test "filesToDelete keeps room for one more under the cap of 10" {
    try std.testing.expectEqual(@as(usize, 0), filesToDelete(0));
    try std.testing.expectEqual(@as(usize, 0), filesToDelete(9));
    try std.testing.expectEqual(@as(usize, 1), filesToDelete(10));
    try std.testing.expectEqual(@as(usize, 6), filesToDelete(15));
}

test "crash loop guard: fourth crash within fifteen minutes blocks the reopen" {
    const now: i64 = 1_000_000;
    try std.testing.expect(reopenAllowed(&.{now}, now));
    try std.testing.expect(reopenAllowed(&.{ now - 30, now }, now));
    try std.testing.expect(reopenAllowed(&.{ now - 60, now - 30, now }, now));
    try std.testing.expect(!reopenAllowed(&.{ now - 90, now - 60, now - 30, now }, now));
    try std.testing.expect(!reopenAllowed(&.{ now - 800, now - 500, now - 200, now }, now));
    try std.testing.expect(reopenAllowed(&.{ now - 1200, now - 1000, now - 300, now }, now));
    try std.testing.expect(reopenAllowed(&.{ now - 901, now - 600, now - 300, now }, now));
}

test "reopen delay grows with recent crashes: 0, 5, 30 seconds" {
    const now: i64 = 1_000_000;
    try std.testing.expectEqual(@as(u32, 0), reopenDelaySecs(&.{now}, now));
    try std.testing.expectEqual(@as(u32, 5), reopenDelaySecs(&.{ now - 100, now }, now));
    try std.testing.expectEqual(@as(u32, 30), reopenDelaySecs(&.{ now - 200, now - 100, now }, now));
    try std.testing.expectEqual(@as(u32, 0), reopenDelaySecs(&.{ now - 5000, now }, now));
}

test "parseStamps and formatStamps round trip, ignoring junk and keeping the newest" {
    var out: [3]i64 = undefined;
    const n = parseStamps("10\nbad\n20\r\n30\n40\n", &out);
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqualSlices(i64, &.{ 20, 30, 40 }, out[0..n]);
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("20\n30\n40\n", formatStamps(&buf, out[0..n]));
}

test "tailLines returns the last n lines" {
    try std.testing.expectEqualStrings("b\nc\n", tailLines("a\nb\nc\n", 2));
    try std.testing.expectEqualStrings("b\nc", tailLines("a\nb\nc", 2));
    try std.testing.expectEqualStrings("a\nb\n", tailLines("a\nb\n", 5));
    try std.testing.expectEqualStrings("", tailLines("a\nb\n", 0));
    try std.testing.expectEqualStrings("", tailLines("", 3));
}

test "fileTimeToUnixSecs and noticeIsFresh" {
    try std.testing.expectEqual(@as(i64, 0), fileTimeToUnixSecs(116_444_736_000_000_000));
    try std.testing.expect(noticeIsFresh(1000, 1100));
    try std.testing.expect(!noticeIsFresh(1000, 1000 + NOTICE_MAX_AGE_SECS + 1));
    try std.testing.expect(!noticeIsFresh(1100, 1000));
}

test "isCrashCode ignores informational exceptions" {
    try std.testing.expect(isCrashCode(0xC0000005));
    try std.testing.expect(isCrashCode(0x80000003));
    try std.testing.expect(!isCrashCode(0x40010006));
    try std.testing.expect(!isCrashCode(0x406D1388));
}

test "buildReport has the fields tools/crash-report.js reads" {
    var mem: [4096]u8 = undefined;
    var b = Buf{ .data = &mem };
    buildReport(&b, .{
        .version = "0.28.693",
        .is_dev = false,
        .when = "2026-10-11 13:45:01",
        .kind = "exception",
        .message = "",
        .code = 0xC0000005,
        .address = 0x140001234,
        .access_kind = 1,
        .access_addr = 0,
        .module = "multiprompt.exe",
        .module_base = 0x140000000,
        .exe_base = 0x140000000,
        .thread_id = 77,
        .snap = .{ .tab_count = 12, .chat_view = true, .debug_log_on = false, .instance = "default" },
        .log_tail = null,
        .stack_rvas = &.{ 0x2000, 0x3000 },
        .dump_name = "crash-x.dmp",
        .reopen = true,
    });
    const s = b.slice();
    try std.testing.expect(std.mem.indexOf(u8, s, "version: 0.28.693\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "exception_code: 0xC0000005 (ACCESS_VIOLATION)\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "access: write at 0x0000000000000000\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "exe_offset: 0x1234 ") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "tabs: 12\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "chat_view: on\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "reopen: yes\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "  0x2000\n  0x3000\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, s, "debug_log_tail: debug log off\n") != null);
}

test "Buf truncates instead of overflowing" {
    var mem: [8]u8 = undefined;
    var b = Buf{ .data = &mem };
    b.add("abcdef");
    b.add("ghijkl");
    b.print("{s}", .{"more"});
    try std.testing.expectEqualStrings("abcdefgh", b.slice());
}
