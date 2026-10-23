const std = @import("std");
const windows = std.os.windows;

pub const FILE_NAME = "browser-own-profile.txt";
pub const TOKEN_LEN = 28;
const token_prefix = "own-";

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

pub fn token(buf: *[TOKEN_LEN]u8, workspace_id: []const u8) ![]const u8 {
    if (workspace_id.len == 0) return error.MissingWorkspaceId;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(workspace_id, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    @memcpy(buf[0..token_prefix.len], token_prefix);
    @memcpy(buf[token_prefix.len..], hex[0 .. TOKEN_LEN - token_prefix.len]);
    return buf;
}

pub fn isToken(value: []const u8) bool {
    if (value.len != TOKEN_LEN or !std.mem.startsWith(u8, value, token_prefix)) return false;
    for (value[token_prefix.len..]) |c| if (!std.ascii.isDigit(c) and (c < 'a' or c > 'f')) return false;
    return true;
}

pub fn listed(contents: []const u8, workspace_id: []const u8) bool {
    if (workspace_id.len == 0) return false;
    const body = if (std.mem.startsWith(u8, contents, "\xEF\xBB\xBF")) contents[3..] else contents;
    var lines = std.mem.splitScalar(u8, body, '\n');
    while (lines.next()) |line| {
        if (std.mem.eql(u8, std.mem.trim(u8, line, " \t\r"), workspace_id)) return true;
    }
    return false;
}

pub fn path(buf: []u8, local: []const u8, engine: []const u8, value: []const u8) ![]const u8 {
    if (!std.mem.eql(u8, engine, "edge") and !std.mem.eql(u8, engine, "chrome")) return error.InvalidEngine;
    if (!isToken(value)) return error.InvalidProfileToken;
    return std.fmt.bufPrint(buf, "{s}\\ZigShell\\BrowserWorkspaces\\{s}\\{s}", .{ local, engine, value });
}

pub fn command(buf: []u8, original: []const u8, value: []const u8) ![]const u8 {
    if (value.len == 0) return std.fmt.bufPrint(buf, "{s}", .{original});
    if (!isToken(value) or original.len == 0 or original[0] != '"') return error.InvalidProfileCommand;
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

pub fn tokenFromPath(buf: *[TOKEN_LEN]u8, local: []const u8, candidate: []const u8) !?[]const u8 {
    var base_buf: [1024]u8 = undefined;
    const base = try std.fmt.bufPrint(&base_buf, "{s}\\ZigShell\\BrowserWorkspaces\\", .{local});
    if (candidate.len < base.len or !std.ascii.eqlIgnoreCase(candidate[0..base.len], base)) return null;
    var rest = candidate[base.len..];
    while (rest.len > 0 and rest[rest.len - 1] == '\\') rest = rest[0 .. rest.len - 1];
    const split = std.mem.indexOfScalar(u8, rest, '\\') orelse return error.InvalidWorkspaceProfile;
    const engine = rest[0..split];
    if (!std.ascii.eqlIgnoreCase(engine, "edge") and !std.ascii.eqlIgnoreCase(engine, "chrome")) return error.InvalidWorkspaceProfile;
    const leaf = rest[split + 1 ..];
    if (!isToken(leaf)) return error.InvalidWorkspaceProfile;
    @memcpy(buf, leaf);
    return buf;
}

pub fn nativeParentToken(allocator: std.mem.Allocator, buf: *[TOKEN_LEN]u8) !?[]const u8 {
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
                    return tokenFromPath(buf, local_buf[0..n], profile);
                }
                return null;
            }
        }
        if (basic.parent == 0 or basic.parent > std.math.maxInt(u32)) return null;
        pid = @intCast(basic.parent);
    }
    return null;
}

test "IGSH-672 own profile tokens are stable, distinct and pipe safe" {
    var first: [TOKEN_LEN]u8 = undefined;
    var again: [TOKEN_LEN]u8 = undefined;
    var other: [TOKEN_LEN]u8 = undefined;
    try std.testing.expectEqualStrings("own-9fcaf773c928d505d4457afd", try token(&first, "ws-inne-test"));
    _ = try token(&again, "ws-inne-test");
    _ = try token(&other, "ws-other-test");
    try std.testing.expectEqualStrings(&first, &again);
    try std.testing.expect(!std.mem.eql(u8, &first, &other));
    try std.testing.expect(isToken(&first));
    try std.testing.expect(!isToken("9fcaf773c928d505d4457afd0123"));
    try std.testing.expect(!isToken("own-9FCAF773C928D505D4457AFD"));
    try std.testing.expectError(error.MissingWorkspaceId, token(&again, ""));
}

test "IGSH-672 opt-in file lists exact workspace ids one per line" {
    try std.testing.expect(listed("ws-inne-test\n", "ws-inne-test"));
    try std.testing.expect(listed("\xEF\xBB\xBFws-a\r\n  ws-inne-test  \r\n", "ws-inne-test"));
    try std.testing.expect(!listed("ws-inne-test-2\n", "ws-inne-test"));
    try std.testing.expect(!listed("", "ws-inne-test"));
    try std.testing.expect(!listed("ws-inne-test\n", ""));
}

test "IGSH-672 own profile folders never name the shared profile or old hash folders" {
    var value: [TOKEN_LEN]u8 = undefined;
    _ = try token(&value, "ws-inne-test");
    var buf: [256]u8 = undefined;
    const root = try path(&buf, "C:\\Local", "chrome", &value);
    try std.testing.expectEqualStrings("C:\\Local\\ZigShell\\BrowserWorkspaces\\chrome\\own-9fcaf773c928d505d4457afd", root);
    var found: [TOKEN_LEN]u8 = undefined;
    try std.testing.expectEqualStrings(&value, (try tokenFromPath(&found, "C:\\Local", root)).?);
    try std.testing.expectEqual(@as(?[]const u8, null), try tokenFromPath(&found, "C:\\Local", "C:\\Local\\ZigShell\\ChromeUserData"));
    try std.testing.expectError(error.InvalidWorkspaceProfile, tokenFromPath(&found, "C:\\Local", "C:\\Local\\ZigShell\\BrowserWorkspaces\\chrome\\0123456789abcdef0123456789abcd"));
    try std.testing.expectError(error.InvalidEngine, path(&buf, "C:\\Local", "firefox", &value));
}

test "IGSH-672 commands gain a profile only for an own profile" {
    var value: [TOKEN_LEN]u8 = undefined;
    _ = try token(&value, "ws-inne-test");
    var buf: [256]u8 = undefined;
    const original = "\"C:\\Program Files\\bridge.exe\" --window 42 tabs";
    try std.testing.expectEqualStrings(original, try command(&buf, original, ""));
    const qualified = try command(&buf, original, &value);
    try std.testing.expectEqualStrings("\"C:\\Program Files\\bridge.exe\" --profile own-9fcaf773c928d505d4457afd --window 42 tabs", qualified);
    try std.testing.expectError(error.InvalidProfileCommand, command(&buf, "bridge.exe tabs", &value));
    const profile = (try userDataArgument(std.testing.allocator, "chrome.exe --user-data-dir=\"C:\\Local Space\\profile\" --app=about:blank")).?;
    defer std.testing.allocator.free(profile);
    try std.testing.expectEqualStrings("C:\\Local Space\\profile", profile);
}

test "IGSH-672 module declarations compile" {
    std.testing.refAllDecls(@This());
}
