const std = @import("std");
const update_check = @import("update_check.zig");

pub const CURRENT_NAME = "multibot.exe";
pub const LEGACY_NAME = "multiprompt.exe";
const UPDATE_READY_FLAG = "--update-ready";
const HANDOFF_DELAY_MS: u64 = 20_000;

const win = struct {
    const HANDLE = ?*anyopaque;
    const WINAPI: std.builtin.CallingConvention = .winapi;
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
    extern "kernel32" fn GetModuleFileNameW(HANDLE, [*]u16, u32) callconv(WINAPI) u32;
    extern "kernel32" fn GetCommandLineW() callconv(WINAPI) [*:0]const u16;
    extern "kernel32" fn CreateProcessW(?[*:0]const u16, ?[*:0]u16, ?*anyopaque, ?*anyopaque, i32, u32, ?*anyopaque, ?[*:0]const u16, *STARTUPINFOW, *PROCESS_INFORMATION) callconv(WINAPI) i32;
    extern "kernel32" fn CloseHandle(HANDLE) callconv(WINAPI) i32;
    extern "kernel32" fn CopyFileW([*:0]const u16, [*:0]const u16, i32) callconv(WINAPI) i32;
    extern "kernel32" fn MoveFileExW([*:0]const u16, [*:0]const u16, u32) callconv(WINAPI) i32;
    extern "kernel32" fn DeleteFileW([*:0]const u16) callconv(WINAPI) i32;
    extern "kernel32" fn GetTickCount64() callconv(WINAPI) u64;
};

var handoff_pending = false;
var started_at: u64 = 0;

fn lower(c: u16) u16 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

pub fn eqlIgnoreCase(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (lower(x) != lower(y)) return false;
    }
    return true;
}

fn baseStart(path: []const u16) usize {
    var at: usize = 0;
    for (path, 0..) |c, i| {
        if (c == '\\' or c == '/') at = i + 1;
    }
    return at;
}

fn nameIs(name: []const u16, comptime want: []const u8) bool {
    if (name.len != want.len) return false;
    for (name, 0..) |c, i| {
        if (lower(c) != want[i]) return false;
    }
    return true;
}

pub fn isLegacyPath(path: []const u16) bool {
    return nameIs(path[baseStart(path)..], LEGACY_NAME);
}

pub fn siblingPath(path: []const u16, name: []const u8, out: []u16) ?usize {
    const dir = baseStart(path);
    const total = dir + name.len;
    if (total >= out.len) return null;
    @memcpy(out[0..dir], path[0..dir]);
    for (name, 0..) |c, i| out[dir + i] = c;
    out[total] = 0;
    return total;
}

pub fn restOfCommandLine(cmd: []const u16) []const u16 {
    var i: usize = 0;
    while (i < cmd.len and (cmd[i] == ' ' or cmd[i] == '\t')) i += 1;
    if (i < cmd.len and cmd[i] == '"') {
        i += 1;
        while (i < cmd.len and cmd[i] != '"') i += 1;
        if (i < cmd.len) i += 1;
    } else {
        while (i < cmd.len and cmd[i] != ' ' and cmd[i] != '\t') i += 1;
    }
    return cmd[i..];
}

fn containsAscii(hay: []const u16, needle: []const u8) bool {
    if (hay.len < needle.len) return false;
    var i: usize = 0;
    while (i + needle.len <= hay.len) : (i += 1) {
        var ok = true;
        for (needle, 0..) |c, j| {
            if (hay[i + j] != c) {
                ok = false;
                break;
            }
        }
        if (ok) return true;
    }
    return false;
}

pub fn buildForwardCommand(out: []u16, target: []const u16, rest: []const u16) ?usize {
    const total = target.len + 2 + rest.len;
    if (total >= out.len) return null;
    out[0] = '"';
    @memcpy(out[1 .. 1 + target.len], target);
    out[1 + target.len] = '"';
    @memcpy(out[2 + target.len .. total], rest);
    out[total] = 0;
    return total;
}

fn appendAscii(out: []u16, at: usize, text: []const u8) ?usize {
    if (at + text.len >= out.len) return null;
    for (text, 0..) |c, i| out[at + i] = c;
    out[at + text.len] = 0;
    return at + text.len;
}

fn targetIsCurrent(target: [*:0]const u16, version: []const u8) bool {
    var buf: [update_check.MAX_VERSION_LEN]u8 = undefined;
    const found = update_check.scanFileForVersion(target, &buf) orelse return false;
    return !update_check.versionNewer(found, version);
}

fn ensureTarget(source: [*:0]const u16, target: []u16, target_len: usize, version: []const u8) bool {
    const target_z: [*:0]const u16 = @ptrCast(target.ptr);
    if (update_check.statFile(target_z) != null) {
        if (targetIsCurrent(target_z, version)) return true;
    }
    var temp: [530]u16 = undefined;
    @memcpy(temp[0..target_len], target[0..target_len]);
    const temp_len = appendAscii(&temp, target_len, ".new") orelse return false;
    _ = temp_len;
    const temp_z: [*:0]const u16 = @ptrCast(&temp);
    if (win.CopyFileW(source, temp_z, 0) == 0) return false;
    if (win.MoveFileExW(temp_z, target_z, 1) == 0) {
        _ = win.DeleteFileW(temp_z);
        return false;
    }
    return true;
}

fn launch(target: [*:0]const u16, rest: []const u16, target_len: usize) bool {
    const a = std.heap.page_allocator;
    const cmd = a.alloc(u16, target_len + 2 + rest.len + 1) catch return false;
    defer a.free(cmd);
    const target_slice = std.mem.span(target);
    if (buildForwardCommand(cmd, target_slice, rest) == null) return false;
    var si = std.mem.zeroes(win.STARTUPINFOW);
    si.cb = @sizeOf(win.STARTUPINFOW);
    var pi = std.mem.zeroes(win.PROCESS_INFORMATION);
    if (win.CreateProcessW(target, @ptrCast(cmd.ptr), null, null, 0, 0, null, null, &si, &pi) == 0) return false;
    if (pi.hProcess != null) _ = win.CloseHandle(pi.hProcess);
    if (pi.hThread != null) _ = win.CloseHandle(pi.hThread);
    return true;
}

pub fn forwardIfLegacy(version: []const u8) bool {
    var exe: [520:0]u16 = undefined;
    const n = win.GetModuleFileNameW(null, &exe, exe.len);
    if (n == 0 or n >= exe.len) return false;
    if (!isLegacyPath(exe[0..n])) return false;
    const cmd = std.mem.span(win.GetCommandLineW());
    if (containsAscii(cmd, UPDATE_READY_FLAG)) {
        handoff_pending = true;
        started_at = win.GetTickCount64();
        return false;
    }
    var target: [520:0]u16 = undefined;
    const tn = siblingPath(exe[0..n], CURRENT_NAME, &target) orelse return false;
    if (!ensureTarget(&exe, &target, tn, version)) return false;
    return launch(&target, restOfCommandLine(cmd), tn);
}

pub fn handoffDue() bool {
    return handoff_pending and win.GetTickCount64() -% started_at >= HANDOFF_DELAY_MS;
}

pub fn prepareHandoff(version: []const u8, out: *[520:0]u16) ?usize {
    handoff_pending = false;
    var exe: [520:0]u16 = undefined;
    const n = win.GetModuleFileNameW(null, &exe, exe.len);
    if (n == 0 or n >= exe.len) return null;
    if (!isLegacyPath(exe[0..n])) return null;
    const tn = siblingPath(exe[0..n], CURRENT_NAME, out) orelse return null;
    if (!ensureTarget(&exe, out, tn, version)) return null;
    return tn;
}

fn wide(comptime text: []const u8) []const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text)[0..text.len];
}

test "legacy path detection" {
    try std.testing.expect(isLegacyPath(wide("C:\\Apps\\Multi\\multiprompt.exe")));
    try std.testing.expect(isLegacyPath(wide("C:\\Apps\\Multi\\MultiPrompt.EXE")));
    try std.testing.expect(isLegacyPath(wide("multiprompt.exe")));
    try std.testing.expect(!isLegacyPath(wide("C:\\Apps\\Multi\\multibot.exe")));
    try std.testing.expect(!isLegacyPath(wide("C:\\Apps\\Multi\\multiprompt-dev.exe")));
    try std.testing.expect(!isLegacyPath(wide("C:\\multiprompt.exe\\multibot.exe")));
}

test "sibling path swaps the file name" {
    var out: [64]u16 = undefined;
    const n = siblingPath(wide("C:\\Apps\\Multi\\multiprompt.exe"), CURRENT_NAME, &out).?;
    try std.testing.expect(eqlIgnoreCase(out[0..n], wide("C:\\Apps\\Multi\\multibot.exe")));
    try std.testing.expectEqual(@as(u16, 0), out[n]);
    var tiny: [8]u16 = undefined;
    try std.testing.expect(siblingPath(wide("C:\\Apps\\Multi\\multiprompt.exe"), CURRENT_NAME, &tiny) == null);
}

test "rest of command line skips the program token" {
    try std.testing.expect(eqlIgnoreCase(restOfCommandLine(wide("\"C:\\A B\\multiprompt.exe\" --x \"y z\"")), wide(" --x \"y z\"")));
    try std.testing.expect(eqlIgnoreCase(restOfCommandLine(wide("C:\\A\\multiprompt.exe --x")), wide(" --x")));
    try std.testing.expectEqual(@as(usize, 0), restOfCommandLine(wide("multiprompt.exe")).len);
    try std.testing.expectEqual(@as(usize, 0), restOfCommandLine(wide("")).len);
}

test "forward command quotes the target and keeps the arguments" {
    var out: [128]u16 = undefined;
    const n = buildForwardCommand(&out, wide("C:\\A B\\multibot.exe"), wide(" multiprompt://auth/cb")).?;
    try std.testing.expect(eqlIgnoreCase(out[0..n], wide("\"C:\\A B\\multibot.exe\" multiprompt://auth/cb")));
    var tiny: [8]u16 = undefined;
    try std.testing.expect(buildForwardCommand(&tiny, wide("C:\\A B\\multibot.exe"), wide(" x")) == null);
}

test "update ready flag is found anywhere in the command line" {
    try std.testing.expect(containsAscii(wide("\"C:\\a\\multiprompt.exe\" --update-ready Local\\x"), UPDATE_READY_FLAG));
    try std.testing.expect(!containsAscii(wide("\"C:\\a\\multiprompt.exe\" --relaunch-after 4"), UPDATE_READY_FLAG));
}
