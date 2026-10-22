const std = @import("std");
const usage_telemetry_mode = @import("usage_telemetry_mode.zig");

pub const MARKER_PREFIX = "MPVERSION=";
pub const MAX_VERSION_LEN = 24;
pub const RELAUNCH_FLAG = "--relaunch-after";
pub const MAX_PIDS = 32;

pub fn isVersionChar(c: u8) bool {
    return (c >= '0' and c <= '9') or c == '.';
}

pub fn parseAfterPrefix(rest: []const u8) ?[]const u8 {
    var n: usize = 0;
    while (n < rest.len and n <= MAX_VERSION_LEN and isVersionChar(rest[n])) n += 1;
    if (n == 0 or n > MAX_VERSION_LEN or n >= rest.len or rest[n] != ';') return null;
    if (rest[0] == '.') return null;
    return rest[0..n];
}

pub fn findMarker(buf: []const u8) ?[]const u8 {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, buf, from, MARKER_PREFIX)) |at| {
        const start = at + MARKER_PREFIX.len;
        if (parseAfterPrefix(buf[start..])) |v| return v;
        from = at + 1;
    }
    return null;
}

pub fn versionDiffers(running: []const u8, installed: []const u8) bool {
    return installed.len > 0 and !std.mem.eql(u8, running, installed);
}

pub fn versionNewer(running: []const u8, candidate: []const u8) bool {
    var old = std.mem.splitScalar(u8, running, '.');
    var next = std.mem.splitScalar(u8, candidate, '.');
    var order: std.math.Order = .eq;
    for (0..3) |_| {
        const a = std.fmt.parseInt(u32, old.next() orelse return false, 10) catch return false;
        const b = std.fmt.parseInt(u32, next.next() orelse return false, 10) catch return false;
        if (order == .eq) order = std.math.order(b, a);
    }
    return old.next() == null and next.next() == null and order == .gt;
}

pub fn parsePidList(text: []const u8, out: []u32) usize {
    var count: usize = 0;
    var it = std.mem.tokenizeAny(u8, text, ", ");
    while (it.next()) |tok| {
        if (count >= out.len) break;
        const pid = std.fmt.parseInt(u32, tok, 10) catch continue;
        if (pid == 0) continue;
        out[count] = pid;
        count += 1;
    }
    return count;
}

pub fn startsWithNoCase(name: []const u8, prefix: []const u8) bool {
    if (name.len < prefix.len) return false;
    return std.ascii.eqlIgnoreCase(name[0..prefix.len], prefix);
}

pub fn isOldHelperName(name: []const u8) bool {
    return startsWithNoCase(name, "multiprompt-telemetry") or startsWithNoCase(name, "zigshell-bridge");
}

const win = struct {
    const HANDLE = ?*anyopaque;
    const WINAPI: std.builtin.CallingConvention = .winapi;
    const FILE_ATTRIBUTE_DATA = extern struct {
        attrs: u32,
        ctime_lo: u32,
        ctime_hi: u32,
        atime_lo: u32,
        atime_hi: u32,
        mtime_lo: u32,
        mtime_hi: u32,
        size_hi: u32,
        size_lo: u32,
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
    const PROCESSENTRY32W = extern struct {
        dwSize: u32,
        cntUsage: u32,
        th32ProcessID: u32,
        th32DefaultHeapID: usize,
        th32ModuleID: u32,
        cntThreads: u32,
        th32ParentProcessID: u32,
        pcPriClassBase: i32,
        dwFlags: u32,
        szExeFile: [260]u16,
    };
    extern "kernel32" fn GetFileAttributesExW([*:0]const u16, u32, *FILE_ATTRIBUTE_DATA) callconv(WINAPI) i32;
    extern "kernel32" fn CreateFileW([*:0]const u16, u32, u32, ?*anyopaque, u32, u32, HANDLE) callconv(WINAPI) HANDLE;
    extern "kernel32" fn ReadFile(HANDLE, [*]u8, u32, *u32, ?*anyopaque) callconv(WINAPI) i32;
    extern "kernel32" fn CloseHandle(HANDLE) callconv(WINAPI) i32;
    extern "kernel32" fn OpenProcess(u32, i32, u32) callconv(WINAPI) HANDLE;
    extern "kernel32" fn WaitForSingleObject(HANDLE, u32) callconv(WINAPI) u32;
    extern "kernel32" fn WaitForMultipleObjects(u32, [*]const HANDLE, i32, u32) callconv(WINAPI) u32;
    extern "kernel32" fn TerminateProcess(HANDLE, u32) callconv(WINAPI) i32;
    extern "kernel32" fn QueryFullProcessImageNameW(HANDLE, u32, [*]u16, *u32) callconv(WINAPI) i32;
    extern "kernel32" fn CreateToolhelp32Snapshot(u32, u32) callconv(WINAPI) HANDLE;
    extern "kernel32" fn Process32FirstW(HANDLE, *PROCESSENTRY32W) callconv(WINAPI) i32;
    extern "kernel32" fn Process32NextW(HANDLE, *PROCESSENTRY32W) callconv(WINAPI) i32;
    extern "kernel32" fn GetModuleFileNameW(HANDLE, [*]u16, u32) callconv(WINAPI) u32;
    extern "kernel32" fn GetCommandLineW() callconv(WINAPI) [*:0]const u16;
    extern "kernel32" fn CreateProcessW(?[*:0]const u16, ?[*:0]u16, ?*anyopaque, ?*anyopaque, i32, u32, ?*anyopaque, ?[*:0]const u16, *STARTUPINFOW, *PROCESS_INFORMATION) callconv(WINAPI) i32;
    extern "kernel32" fn GetCurrentProcessId() callconv(WINAPI) u32;
};

pub const Stamp = struct {
    size: u64,
    mtime: u64,
    pub fn eql(a: Stamp, b: Stamp) bool {
        return a.size == b.size and a.mtime == b.mtime;
    }
};

pub fn statFile(path: [*:0]const u16) ?Stamp {
    var data: win.FILE_ATTRIBUTE_DATA = undefined;
    if (win.GetFileAttributesExW(path, 0, &data) == 0) return null;
    return .{
        .size = (@as(u64, data.size_hi) << 32) | data.size_lo,
        .mtime = (@as(u64, data.mtime_hi) << 32) | data.mtime_lo,
    };
}

pub fn scanFileForVersion(path: [*:0]const u16, out: *[MAX_VERSION_LEN]u8) ?[]const u8 {
    const h = win.CreateFileW(path, 0x80000000, 7, null, 3, 0x80, null);
    if (h == null or @intFromPtr(h) == std.math.maxInt(usize)) return null;
    defer _ = win.CloseHandle(h);
    const chunk = 1 << 20;
    const overlap = MARKER_PREFIX.len + MAX_VERSION_LEN + 2;
    var buf: [chunk + overlap]u8 = undefined;
    var have: usize = 0;
    while (true) {
        var got: u32 = 0;
        if (win.ReadFile(h, buf[have..].ptr, chunk, &got, null) == 0) return null;
        if (got == 0) return null;
        const total = have + got;
        if (findMarker(buf[0..total])) |v| {
            @memcpy(out[0..v.len], v);
            return out[0..v.len];
        }
        have = @min(overlap, total);
        std.mem.copyForwards(u8, buf[0..have], buf[total - have .. total]);
    }
}

fn wideEqIgnoreCase(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        const lx: u16 = if (x >= 'A' and x <= 'Z') x + 32 else x;
        const ly: u16 = if (y >= 'A' and y <= 'Z') y + 32 else y;
        if (lx != ly) return false;
    }
    return true;
}

fn wideDirLen(path: []const u16) usize {
    var last: usize = 0;
    for (path, 0..) |c, i| {
        if (c == '\\' or c == '/') last = i;
    }
    return last;
}

fn stopOldHelpers(dir: []const u16) void {
    const snap = win.CreateToolhelp32Snapshot(0x2, 0);
    if (snap == null or @intFromPtr(snap) == std.math.maxInt(usize)) return;
    defer _ = win.CloseHandle(snap);
    var entry: win.PROCESSENTRY32W = undefined;
    entry.dwSize = @sizeOf(win.PROCESSENTRY32W);
    if (win.Process32FirstW(snap, &entry) == 0) return;
    const self_pid = win.GetCurrentProcessId();
    while (true) {
        var name8: [260]u8 = undefined;
        var n: usize = 0;
        while (n < 260 and entry.szExeFile[n] != 0) : (n += 1) {
            name8[n] = if (entry.szExeFile[n] < 128) @intCast(entry.szExeFile[n]) else '?';
        }
        if (entry.th32ProcessID != self_pid and isOldHelperName(name8[0..n])) {
            const ph = win.OpenProcess(0x0001 | 0x1000 | 0x00100000, 0, entry.th32ProcessID);
            if (ph != null) {
                var path: [520]u16 = undefined;
                var plen: u32 = 520;
                if (win.QueryFullProcessImageNameW(ph, 0, &path, &plen) != 0) {
                    const p = path[0..plen];
                    const dl = wideDirLen(p);
                    if (wideEqIgnoreCase(p[0..dl], dir) and win.TerminateProcess(ph, 0) != 0) {
                        _ = win.WaitForSingleObject(ph, 5000);
                    }
                }
                _ = win.CloseHandle(ph);
            }
        }
        if (win.Process32NextW(snap, &entry) == 0) break;
    }
}

pub fn stopForUpdate(path: []const u16) void {
    stopOldHelpers(path[0..wideDirLen(path)]);
    usage_telemetry_mode.stopForRelaunch();
}

fn wideContains(hay: []const u16, needle: []const u8) ?usize {
    if (hay.len < needle.len) return null;
    var i: usize = 0;
    while (i + needle.len <= hay.len) : (i += 1) {
        var ok = true;
        for (needle, 0..) |c, j| {
            if (hay[i + j] != c) {
                ok = false;
                break;
            }
        }
        if (ok) return i;
    }
    return null;
}

pub fn spawnRelaunchHelper(exe_path: []const u16, pids: []const u32) bool {
    var cmd: [1024]u16 = undefined;
    var p: usize = 0;
    if (exe_path.len + 64 + pids.len * 11 >= cmd.len) return false;
    cmd[p] = '"';
    p += 1;
    for (exe_path) |c| {
        cmd[p] = c;
        p += 1;
    }
    cmd[p] = '"';
    p += 1;
    for (" " ++ RELAUNCH_FLAG ++ " ") |c| {
        cmd[p] = c;
        p += 1;
    }
    for (pids, 0..) |pid, i| {
        if (i > 0) {
            cmd[p] = ',';
            p += 1;
        }
        var tmp: [12]u8 = undefined;
        const s = std.fmt.bufPrint(&tmp, "{d}", .{pid}) catch return false;
        for (s) |c| {
            cmd[p] = c;
            p += 1;
        }
    }
    cmd[p] = 0;
    var exe_z: [520:0]u16 = undefined;
    if (exe_path.len >= exe_z.len) return false;
    @memcpy(exe_z[0..exe_path.len], exe_path);
    exe_z[exe_path.len] = 0;
    var si = std.mem.zeroes(win.STARTUPINFOW);
    si.cb = @sizeOf(win.STARTUPINFOW);
    var pi = std.mem.zeroes(win.PROCESS_INFORMATION);
    const flags: u32 = 0x00000008 | 0x08000000;
    if (win.CreateProcessW(&exe_z, @ptrCast(&cmd), null, null, 0, flags, null, null, &si, &pi) == 0) return false;
    if (pi.hProcess != null) _ = win.CloseHandle(pi.hProcess);
    if (pi.hThread != null) _ = win.CloseHandle(pi.hThread);
    return true;
}

pub fn runRelaunchHelperIfRequested() bool {
    const cmdline = std.mem.span(win.GetCommandLineW());
    const at = wideContains(cmdline, RELAUNCH_FLAG) orelse return false;
    var rest = cmdline[at + RELAUNCH_FLAG.len ..];
    while (rest.len > 0 and rest[0] == ' ') rest = rest[1..];
    var end: usize = 0;
    while (end < rest.len and rest[end] != ' ') end += 1;
    var list8: [256]u8 = undefined;
    const ln = @min(end, list8.len);
    for (0..ln) |i| list8[i] = if (rest[i] < 128) @intCast(rest[i]) else ',';
    var pids: [MAX_PIDS]u32 = undefined;
    const npids = parsePidList(list8[0..ln], &pids);

    var handles: [MAX_PIDS]win.HANDLE = undefined;
    var nh: u32 = 0;
    for (pids[0..npids]) |pid| {
        const h = win.OpenProcess(0x00100000, 0, pid);
        if (h != null) {
            handles[nh] = h;
            nh += 1;
        }
    }
    if (nh > 0) {
        const wait_ms: u32 = if (wideContains(cmdline, "--after-crash") != null) 95_000 else 30_000;
        _ = win.WaitForMultipleObjects(nh, &handles, 1, wait_ms);
        for (handles[0..nh]) |h| _ = win.CloseHandle(h);
    }

    var exe: [520:0]u16 = undefined;
    const elen = win.GetModuleFileNameW(null, &exe, 520);
    if (elen == 0 or elen >= 520) return true;
    exe[elen] = 0;
    stopOldHelpers(exe[0..wideDirLen(exe[0..elen])]);
    usage_telemetry_mode.stopForRelaunch();

    var cmd: [524]u16 = undefined;
    cmd[0] = '"';
    @memcpy(cmd[1 .. 1 + elen], exe[0..elen]);
    cmd[1 + elen] = '"';
    cmd[2 + elen] = 0;
    var si = std.mem.zeroes(win.STARTUPINFOW);
    si.cb = @sizeOf(win.STARTUPINFOW);
    si.dwFlags = 0x1;
    si.wShowWindow = 3;
    var pi = std.mem.zeroes(win.PROCESS_INFORMATION);
    if (win.CreateProcessW(&exe, @ptrCast(&cmd), null, null, 0, 0, null, null, &si, &pi) != 0) {
        if (pi.hProcess != null) _ = win.CloseHandle(pi.hProcess);
        if (pi.hThread != null) _ = win.CloseHandle(pi.hThread);
    }
    return true;
}

test "findMarker reads the version after the prefix" {
    const blob = "junk\x00MPVERSION=0.28.687;tail";
    try std.testing.expectEqualStrings("0.28.687", findMarker(blob).?);
}

test "findMarker skips a bare needle and takes the later real marker" {
    const blob = "MPVERSION=" ++ "\x00\x00" ++ "MPVERSION=1.2.3;";
    try std.testing.expectEqualStrings("1.2.3", findMarker(blob).?);
}

test "findMarker rejects malformed markers" {
    try std.testing.expect(findMarker("MPVERSION=;") == null);
    try std.testing.expect(findMarker("MPVERSION=0.28.1") == null);
    try std.testing.expect(findMarker("MPVERSION=abc;") == null);
    try std.testing.expect(findMarker("MPVERSION=.5;") == null);
    try std.testing.expect(findMarker("nothing here") == null);
    try std.testing.expect(findMarker("MPVERSION=1111111111111111111111111111;") == null);
}

test "versionDiffers" {
    try std.testing.expect(versionDiffers("0.28.686", "0.28.687"));
    try std.testing.expect(!versionDiffers("0.28.686", "0.28.686"));
    try std.testing.expect(!versionDiffers("0.28.686", ""));
}

test "parsePidList" {
    var out: [4]u32 = undefined;
    try std.testing.expectEqual(@as(usize, 3), parsePidList("12,345,6789", &out));
    try std.testing.expectEqual(@as(u32, 345), out[1]);
    try std.testing.expectEqual(@as(usize, 2), parsePidList("7,x,0,8", &out));
    try std.testing.expectEqual(@as(usize, 4), parsePidList("1,2,3,4,5,6", &out));
}

test "old helper names" {
    try std.testing.expect(isOldHelperName("multiprompt-telemetry-old-20261010.exe"));
    try std.testing.expect(isOldHelperName("ZigShell-Bridge.exe"));
    try std.testing.expect(!isOldHelperName("multiprompt.exe"));
}

test "release versions compare numerically and reject downgrades" {
    try std.testing.expect(versionNewer("1.9.999", "1.10.0"));
    try std.testing.expect(versionNewer("1.99.99", "2.0.0"));
    try std.testing.expect(!versionNewer("2.0.0", "1.99.99"));
    try std.testing.expect(!versionNewer("1.2.3", "1.2.3"));
    try std.testing.expect(!versionNewer("1.2.3", "1.2.4-beta"));
    try std.testing.expect(!versionNewer("1.2.3", "1.2.4.1"));
}
