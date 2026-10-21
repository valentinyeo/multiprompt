const std = @import("std");
const windows = std.os.windows;
const clone_profile = @import("browser_profile_clone.zig");

pub const IGSH_224 = true;

extern "kernel32" fn OpenProcess(u32, i32, u32) callconv(.winapi) ?windows.HANDLE;
extern "kernel32" fn CloseHandle(windows.HANDLE) callconv(.winapi) i32;
extern "kernel32" fn QueryFullProcessImageNameW(windows.HANDLE, u32, [*]u16, *u32) callconv(.winapi) i32;
extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) u32;
extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
extern "ntdll" fn NtQueryInformationProcess(windows.HANDLE, u32, *anyopaque, u32, ?*u32) callconv(.winapi) i32;

const BasicInfo = extern struct {
    exit_status: usize,
    peb: usize,
    affinity: usize,
    priority: usize,
    pid: usize,
    parent: usize,
};
const UnicodeString = extern struct { length: u16, maximum: u16, buffer: [*]const u16 };

pub fn token(buf: *[32]u8, engine: []const u8, workspace_id: []const u8) ![]const u8 {
    if (workspace_id.len == 0) return error.MissingWorkspaceId;
    if (!std.mem.eql(u8, engine, "edge") and !std.mem.eql(u8, engine, "chrome")) return error.InvalidEngine;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(workspace_id, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    buf[0] = engine[0];
    buf[1] = '-';
    @memcpy(buf[2..], hex[0..30]);
    return buf;
}

pub fn isWorkspaceToken(value: []const u8) bool {
    if (value.len != 32 or (value[0] != 'e' and value[0] != 'c') or value[1] != '-') return false;
    for (value[2..]) |c| if (!std.ascii.isDigit(c) and (c < 'a' or c > 'f')) return false;
    return true;
}

pub fn path(buf: []u8, local: []const u8, engine: []const u8, value: []const u8) ![]const u8 {
    if (!isWorkspaceToken(value) or value[0] != engine[0]) return error.InvalidProfileToken;
    return std.fmt.bufPrint(buf, "{s}\\ZigShell\\BrowserWorkspaces\\{s}\\{s}", .{ local, engine, value[2..] });
}

pub fn command(buf: []u8, original: []const u8, value: []const u8) ![]const u8 {
    if (value.len == 0) return std.fmt.bufPrint(buf, "{s}", .{original});
    if (!isWorkspaceToken(value) or original.len == 0 or original[0] != '"') return error.InvalidProfileCommand;
    const end = (std.mem.indexOfScalarPos(u8, original, 1, '"') orelse return error.InvalidProfileCommand) + 1;
    return std.fmt.bufPrint(buf, "{s} --profile {s}{s}", .{ original[0..end], value, original[end..] });
}

pub fn processCommandLine(allocator: std.mem.Allocator, process: windows.HANDLE) ![]u8 {
    var required: u32 = 0;
    _ = NtQueryInformationProcess(process, 60, &required, 0, &required);
    if (required < @sizeOf(UnicodeString) or required > 256 * 1024) return error.ProcessCommandLineUnavailable;
    const memory = try allocator.alignedAlloc(u8, std.mem.Alignment.of(UnicodeString), required);
    defer allocator.free(memory);
    if (NtQueryInformationProcess(process, 60, memory.ptr, required, null) < 0) return error.ProcessCommandLineUnavailable;
    const text: *const UnicodeString = @ptrCast(@alignCast(memory.ptr));
    const start = @intFromPtr(text.buffer);
    const base = @intFromPtr(memory.ptr);
    if (text.length % 2 != 0 or start < base or start > base + memory.len or text.length > base + memory.len - start) return error.ProcessCommandLineUnavailable;
    return std.unicode.utf16LeToUtf8Alloc(allocator, text.buffer[0 .. text.length / 2]);
}

pub fn userDataArgument(allocator: std.mem.Allocator, line: []const u8) !?[]u8 {
    const wide = try std.unicode.utf8ToUtf16LeAlloc(allocator, line);
    defer allocator.free(wide);
    var args = try std.process.Args.Iterator.Windows.init(allocator, wide);
    defer args.deinit();
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--user-data-dir=")) return try allocator.dupe(u8, arg[16..]);
        if (std.mem.eql(u8, arg, "--user-data-dir")) return try allocator.dupe(u8, args.next() orelse return error.MissingProfilePath);
    }
    return null;
}

pub fn tokenFromPath(buf: *[32]u8, local: []const u8, candidate: []const u8) !?[]const u8 {
    var expected_buf: [1024]u8 = undefined;
    const base = try std.fmt.bufPrint(&expected_buf, "{s}\\ZigShell\\BrowserWorkspaces\\", .{local});
    if (candidate.len < base.len or !std.ascii.eqlIgnoreCase(candidate[0..base.len], base)) return null;
    const rest = candidate[base.len..];
    const split = std.mem.indexOfScalar(u8, rest, '\\') orelse return error.InvalidWorkspaceProfile;
    const engine = rest[0..split];
    if (!std.mem.eql(u8, engine, "edge") and !std.mem.eql(u8, engine, "chrome")) return error.InvalidWorkspaceProfile;
    if (rest.len - split - 1 != 30) return error.InvalidWorkspaceProfile;
    buf[0] = engine[0];
    buf[1] = '-';
    @memcpy(buf[2..], rest[split + 1 ..]);
    if (!isWorkspaceToken(buf)) return error.InvalidWorkspaceProfile;
    return buf;
}

pub fn nativeParentToken(allocator: std.mem.Allocator, buf: *[32]u8) !struct { chromium: bool = false, token: ?[]const u8 = null } {
    if (!IGSH_224) return .{};
    var local_buf: [1024]u8 = undefined;
    const n = GetEnvironmentVariableA("LOCALAPPDATA", &local_buf, local_buf.len);
    if (n == 0 or n >= local_buf.len) return error.LocalAppDataUnavailable;
    var pid = GetCurrentProcessId();
    for (0..4) |_| {
        const process = OpenProcess(0x1000, 0, pid) orelse return error.ParentProcessUnavailable;
        defer _ = CloseHandle(process);
        var basic: BasicInfo = undefined;
        if (NtQueryInformationProcess(process, 0, &basic, @sizeOf(BasicInfo), null) < 0) return error.ParentProcessUnavailable;
        if (pid != GetCurrentProcessId()) {
            var image: [32768]u16 = undefined;
            var image_len: u32 = image.len;
            if (QueryFullProcessImageNameW(process, 0, &image, &image_len) == 0) return error.ParentProcessUnavailable;
            const image_text = try std.unicode.utf16LeToUtf8Alloc(allocator, image[0..image_len]);
            defer allocator.free(image_text);
            const start = if (std.mem.lastIndexOfScalar(u8, image_text, '\\')) |at| at + 1 else 0;
            const name = image_text[start..];
            if (std.ascii.eqlIgnoreCase(name, "msedge.exe") or std.ascii.eqlIgnoreCase(name, "chrome.exe")) {
                const line = try processCommandLine(allocator, process);
                defer allocator.free(line);
                if (try userDataArgument(allocator, line)) |profile| {
                    defer allocator.free(profile);
                    return .{ .chromium = true, .token = try tokenFromPath(buf, local_buf[0..n], profile) };
                }
                return .{ .chromium = true };
            }
        }
        if (basic.parent == 0 or basic.parent > std.math.maxInt(u32)) return .{};
        pid = @intCast(basic.parent);
    }
    return .{};
}

const ProcessEntry = extern struct {
    size: u32,
    usage: u32,
    pid: u32,
    heap: usize,
    module: u32,
    threads: u32,
    parent: u32,
    priority: i32,
    flags: u32,
    name: [260]u16,
};
extern "kernel32" fn CreateToolhelp32Snapshot(u32, u32) callconv(.winapi) windows.HANDLE;
extern "kernel32" fn Process32FirstW(windows.HANDLE, *ProcessEntry) callconv(.winapi) i32;
extern "kernel32" fn Process32NextW(windows.HANDLE, *ProcessEntry) callconv(.winapi) i32;

pub fn requireSourceClosed(allocator: std.mem.Allocator, seed: []const u8) !void {
    const snapshot = CreateToolhelp32Snapshot(2, 0);
    if (snapshot == @as(windows.HANDLE, @ptrFromInt(std.math.maxInt(usize)))) return error.ProcessSnapshotUnavailable;
    defer _ = CloseHandle(snapshot);
    var entry: ProcessEntry = undefined;
    entry.size = @sizeOf(ProcessEntry);
    if (Process32FirstW(snapshot, &entry) == 0) return error.ProcessSnapshotUnavailable;
    while (true) {
        const name = try std.unicode.utf16LeToUtf8Alloc(allocator, std.mem.sliceTo(&entry.name, 0));
        defer allocator.free(name);
        if (std.ascii.eqlIgnoreCase(name, "msedge.exe") or std.ascii.eqlIgnoreCase(name, "chrome.exe")) {
            const process = OpenProcess(0x1000, 0, entry.pid) orelse return error.Browser_running;
            defer _ = CloseHandle(process);
            const line = processCommandLine(allocator, process) catch return error.Browser_running;
            defer allocator.free(line);
            if (try userDataArgument(allocator, line)) |profile| {
                defer allocator.free(profile);
                const normalized = if (std.mem.startsWith(u8, seed, "\\\\?\\")) seed[4..] else seed;
                if (std.ascii.eqlIgnoreCase(profile, normalized)) return error.Browser_running;
            }
        }
        if (Process32NextW(snapshot, &entry) == 0) break;
    }
}

pub fn ensureWorkspaceProfile(allocator: std.mem.Allocator, seed: []const u8, destination: []const u8) !void {
    try clone_profile.ensureWorkspaceProfile(allocator, seed, destination);
}

test "IGSH-224 stable workspace profile identities survive names and slots and separate engines" {
    var first: [32]u8 = undefined;
    var again: [32]u8 = undefined;
    var other: [32]u8 = undefined;
    _ = try token(&first, "edge", "stable-workspace-id");
    _ = try token(&again, "edge", "stable-workspace-id");
    _ = try token(&other, "edge", "other-workspace-id");
    try std.testing.expectEqualStrings(&first, &again);
    try std.testing.expect(!std.mem.eql(u8, &first, &other));
    _ = try token(&other, "chrome", "stable-workspace-id");
    try std.testing.expect(!std.mem.eql(u8, &first, &other));
    var p: [256]u8 = undefined;
    const root = try path(&p, "C:\\Local", "chrome", &other);
    try std.testing.expectEqualStrings(&other, (try tokenFromPath(&again, "C:\\Local", root)).?);
    try std.testing.expectEqual(@as(?[]const u8, null), try tokenFromPath(&again, "C:\\Local", "C:\\Local\\ZigShell\\ChromeUserData"));
    try std.testing.expectError(error.MissingWorkspaceId, token(&again, "edge", ""));
}

test "IGSH-224 profile routing qualifies commands without changing Windows quoting" {
    var value: [32]u8 = undefined;
    _ = try token(&value, "edge", "workspace");
    var buf: [256]u8 = undefined;
    const qualified = try command(&buf, "\"C:\\Program Files\\bridge.exe\" --window 42 text", &value);
    try std.testing.expect(std.mem.indexOf(u8, qualified, " --profile e-") != null);
    try std.testing.expect(std.mem.endsWith(u8, qualified, " --window 42 text"));
    const profile = (try userDataArgument(std.testing.allocator, "edge.exe --user-data-dir=\"C:\\Local Space\\profile\" --app=about:blank")).?;
    defer std.testing.allocator.free(profile);
    try std.testing.expectEqualStrings("C:\\Local Space\\profile", profile);
}
