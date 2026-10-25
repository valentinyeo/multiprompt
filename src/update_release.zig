const std = @import("std");
const builtin = @import("builtin");
const win = @import("win32.zig");
const update_check = @import("update_check.zig");
const APP_VERSION = @import("main.zig").APP_VERSION;

pub const IGSH_246 = true;
const interval_ms = 5 * 60 * 1000;
pub const WM_RESPONSIVE = 0x85F4;
var launch_args: []const []const u8 = &.{};
var last_check: u64 = 0;
var checker: win.HANDLE = null;
var exe: [520:0]u16 = @splat(0);
var exe_len: usize = 0;
var script: [550:0]u16 = @splat(0);
var staged: [550:0]u16 = @splat(0);

fn enabled() bool {
    var value: [8]u16 = undefined;
    return IGSH_246 and !(win.GetEnvironmentVariableW(w("IGSH_246"), &value, value.len) == 1 and value[0] == '0');
}

fn w(comptime text: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(text);
}

fn initialize() bool {
    if (exe_len != 0) return true;
    const n = win.GetModuleFileNameW(null, &exe, exe.len);
    if (n == 0 or n >= exe.len) return false;
    exe_len = n;
    @memcpy(script[0..n], exe[0..n]);
    for (".updater.ps1", 0..) |c, i| script[n + i] = c;
    @memcpy(staged[0..n], exe[0..n]);
    for (".update\\ready.txt", 0..) |c, i| staged[n + i] = c;
    const file = win.CreateFileW(&script, 0x40000000, 1, null, 2, 0x80, null);
    if (file == null or file == win.INVALID_HANDLE_VALUE_PTR) {
        exe_len = 0;
        return false;
    }
    defer _ = win.CloseHandle(file);
    const source = @embedFile("update_release.ps1");
    var written: u32 = 0;
    if (win.WriteFile(file, source.ptr, source.len, &written, null) == 0 or written != source.len) {
        exe_len = 0;
        return false;
    }
    return true;
}

fn architecture() []const u8 {
    var process_machine: u16 = 0;
    var native_machine: u16 = 0;
    if (IsWow64Process2(GetCurrentProcess(), &process_machine, &native_machine) != 0 and native_machine == 0xaa64) return "arm64";
    return if (builtin.cpu.arch == .aarch64) "arm64" else "x64";
}

fn spawn(mode: []const u8, pids: []const u32, accepted: []const u8) win.HANDLE {
    if (!initialize()) return null;
    var system: [520:0]u16 = @splat(0);
    const n = win.GetEnvironmentVariableW(w("SystemRoot"), &system, system.len);
    if (n == 0 or n >= 400) return null;
    const suffix = "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
    for (suffix, 0..) |c, i| system[n + i] = c;
    var pid_buf: [400]u8 = undefined;
    var used: usize = 0;
    for (pids, 0..) |pid, i| {
        const part = std.fmt.bufPrint(pid_buf[used..], "{s}{d}", .{ if (i == 0) "" else ",", pid }) catch return null;
        used += part.len;
    }
    const a = std.heap.page_allocator;
    const script8 = std.unicode.utf16LeToUtf8Alloc(a, script[0 .. exe_len + ".updater.ps1".len]) catch return null;
    defer a.free(script8);
    const exe8 = std.unicode.utf16LeToUtf8Alloc(a, exe[0..exe_len]) catch return null;
    defer a.free(exe8);
    var arguments: std.Io.Writer.Allocating = .init(a);
    defer arguments.deinit();
    var skip = false;
    for (launch_args) |arg| {
        if (skip) {
            skip = false;
            continue;
        }
        if (std.mem.eql(u8, arg, "--update-ready")) {
            skip = true;
            continue;
        }
        arguments.writer.writeAll(" \"") catch return null;
        var slashes: usize = 0;
        for (arg) |c| {
            if (c == '\\') {
                slashes += 1;
                continue;
            }
            arguments.writer.splatByteAll('\\', if (c == '"') slashes * 2 + 1 else slashes) catch return null;
            arguments.writer.writeByte(c) catch return null;
            slashes = 0;
        }
        arguments.writer.splatByteAll('\\', slashes * 2) catch return null;
        arguments.writer.writeByte('"') catch return null;
    }
    const raw = arguments.written();
    const encoded = a.alloc(u8, std.base64.standard.Encoder.calcSize(raw.len)) catch return null;
    defer a.free(encoded);
    _ = std.base64.standard.Encoder.encode(encoded, raw);
    const text = std.fmt.allocPrint(a, "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"{s}\" -Mode {s} -Exe \"{s}\" -Current {s} -Arch {s} -WaitPids \"{s}\" -AcceptedEvent \"{s}\" -LaunchArguments \"{s}\"", .{ script8, mode, exe8, APP_VERSION, architecture(), pid_buf[0..used], accepted, encoded }) catch return null;
    defer a.free(text);
    const cmd = std.unicode.utf8ToUtf16LeAllocZ(a, text) catch return null;
    defer a.free(cmd);
    var si = std.mem.zeroes(win.STARTUPINFOW);
    si.cb = @sizeOf(win.STARTUPINFOW);
    var pi = std.mem.zeroes(win.PROCESS_INFORMATION);
    if (win.CreateProcessW(&system, cmd.ptr, null, null, 0, 0x08000000, null, null, &si, &pi) == 0) return null;
    _ = win.CloseHandle(pi.hThread);
    return pi.hProcess;
}

pub fn startup(args: []const []const u8) bool {
    launch_args = if (args.len > 1) args[1..] else &.{};
    if (!enabled() or win.FindWindowW(w("ZigShell"), null) != null) return false;
    for (launch_args) |arg| {
        if (std.mem.eql(u8, arg, "--update-ready")) return false;
    }
    return hasStaged() and restart(&.{win.GetCurrentProcessId()});
}

pub fn beginCheck() void {
    if (!enabled() or checker != null) return;
    last_check = win.GetTickCount64();
    checker = spawn("Check", &.{}, "");
}

pub fn checking() bool {
    const process = checker orelse return false;
    return win.WaitForSingleObject(process, 0) == 0x102;
}

pub fn poll() ?[]const u8 {
    if (!enabled() or !initialize()) return null;
    if (checker) |process| {
        if (win.WaitForSingleObject(process, 0) == 0) {
            _ = win.CloseHandle(process);
            checker = null;
        }
    }
    const now = win.GetTickCount64();
    if (checker == null and now -| last_check >= interval_ms) {
        last_check = now;
        checker = spawn("Check", &.{}, "");
    }
    const version = update_check.scanFileForVersion(&staged, &version_buf) orelse return null;
    return if (update_check.versionNewer(APP_VERSION, version)) version else null;
}

var version_buf: [update_check.MAX_VERSION_LEN]u8 = undefined;

pub fn cardNotes(offered: []const u8) @import("update_notes.zig").Notes {
    if (!initialize()) return .{};
    const a = std.heap.page_allocator;
    const exe8 = std.unicode.utf16LeToUtf8Alloc(a, exe[0..exe_len]) catch return .{};
    defer a.free(exe8);
    var path_buf: [600]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}.update\\release-notes.json", .{exe8}) catch return .{};
    const bytes = @import("file_io.zig").readFileAllocWin32(path, 1024 * 1024 + 1) orelse return .{};
    defer a.free(bytes);
    if (bytes.len > 1024 * 1024) return .{};
    const parsed = std.json.parseFromSlice(@import("update_notes.zig").Document, a, bytes, .{ .ignore_unknown_fields = true }) catch return .{};
    defer parsed.deinit();
    if (update_check.versionNewer(parsed.value.version, offered)) return .{};
    for (parsed.value.releases) |release| {
        if (std.mem.eql(u8, release.version, offered)) return @import("update_notes.zig").pick(parsed.value.releases, APP_VERSION, offered);
    }
    return .{};
}

pub fn hasStaged() bool {
    return initialize() and update_check.statFile(&staged) != null;
}

pub fn restart(pids: []const u32) bool {
    if (!enabled()) return false;
    var buf: [100]u8 = undefined;
    const name = std.fmt.bufPrint(&buf, "Local\\MultipromptApply-{d}-{d}", .{ win.GetCurrentProcessId(), win.GetTickCount64() }) catch return false;
    const wide = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, name) catch return false;
    defer std.heap.page_allocator.free(wide);
    const event = win.CreateEventW(null, 1, 0, wide.ptr) orelse return false;
    defer _ = win.CloseHandle(event);
    const process = spawn("Apply", pids, name) orelse return false;
    defer _ = win.CloseHandle(process);
    const handles = [_]win.HANDLE{ event, process };
    if (win.WaitForMultipleObjects(2, &handles, 0, 15_000) == 0) return true;
    _ = win.TerminateProcess(process, 1);
    return false;
}

pub fn runHelperIfRequested(args: []const []const u8) bool {
    if (args.len < 2) return false;
    if (std.mem.eql(u8, args[1], "--stop-update-helpers")) {
        var path: [520:0]u16 = @splat(0);
        const n = win.GetModuleFileNameW(null, &path, path.len);
        if (n == 0 or n >= path.len) std.process.exit(1);
        update_check.stopForUpdate(path[0..n]);
        return true;
    }
    if (!std.mem.eql(u8, args[1], "--verify-release-manifest")) return false;
    if (args.len != 4) std.process.exit(1);
    const manifest = @import("file_io.zig").readFileAllocWin32(args[2], 1024 * 1024 + 1) orelse std.process.exit(1);
    defer std.heap.page_allocator.free(manifest);
    if (manifest.len > 1024 * 1024) std.process.exit(1);
    const signature = @import("file_io.zig").readFileAllocWin32(args[3], 65) orelse std.process.exit(1);
    defer std.heap.page_allocator.free(signature);
    @import("release_signature.zig").verify(manifest, signature) catch std.process.exit(1);
    std.process.exit(0);
}

pub fn ready() void {
    const cmd = std.mem.span(GetCommandLineW());
    const flag = std.mem.span(w("--update-ready "));
    const at = std.mem.indexOf(u16, cmd, flag) orelse return;
    const rest = cmd[at + flag.len ..];
    const end = std.mem.indexOfScalar(u16, rest, ' ') orelse rest.len;
    if (end >= 128) return;
    var name: [128:0]u16 = @splat(0);
    @memcpy(name[0..end], rest[0..end]);
    const event = OpenEventW(2, 0, &name) orelse return;
    defer _ = win.CloseHandle(event);
    _ = win.SetEvent(event);
}

extern "kernel32" fn OpenEventW(u32, i32, [*:0]const u16) callconv(.winapi) win.HANDLE;

extern "kernel32" fn GetCommandLineW() callconv(.winapi) [*:0]const u16;

extern "kernel32" fn IsWow64Process2(win.HANDLE, *u16, *u16) callconv(.winapi) i32;

extern "kernel32" fn GetCurrentProcess() callconv(.winapi) win.HANDLE;

test "the update check runs every five minutes" {
    try std.testing.expectEqual(@as(u64, 5 * 60 * 1000), interval_ms);
}
