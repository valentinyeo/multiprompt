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

pub fn seed(contents: []const u8, workspace_id: []const u8, workspace_name: []const u8) ?[]const u8 {
    if (workspace_id.len == 0 and workspace_name.len == 0) return null;
    const body = if (std.mem.startsWith(u8, contents, "\xEF\xBB\xBF")) contents[3..] else contents;
    var named: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, body, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        const split = std.mem.lastIndexOfScalar(u8, line, '=');
        const key = std.mem.trim(u8, if (split) |at| line[0..at] else line, " \t");
        const pinned = if (split) |at| std.mem.trim(u8, line[at + 1 ..], " \t") else "";
        const chosen = if (pinned.len > 0) pinned else key;
        if (chosen.len == 0) continue;
        if (workspace_id.len > 0 and std.mem.eql(u8, key, workspace_id)) return chosen;
        if (named == null and workspace_name.len > 0 and std.mem.eql(u8, key, workspace_name)) named = chosen;
    }
    return named;
}

pub fn path(buf: []u8, local: []const u8, engine: []const u8, value: []const u8) ![]const u8 {
    if (!std.mem.eql(u8, engine, "edge") and !std.mem.eql(u8, engine, "chrome")) return error.InvalidEngine;
    if (!isToken(value)) return error.InvalidProfileToken;
    return std.fmt.bufPrint(buf, "{s}\\ZigShell\\BrowserWorkspaces\\{s}\\{s}", .{ local, engine, value });
}

pub fn command(buf: []u8, original: []const u8, value: []const u8) ![]const u8 {
    if ((value.len > 0 and !isToken(value)) or original.len == 0 or original[0] != '"') return error.InvalidProfileCommand;
    const end = (std.mem.indexOfScalarPos(u8, original, 1, '"') orelse return error.InvalidProfileCommand) + 1;
    return std.fmt.bufPrint(buf, "{s} --profile {s}{s}", .{ original[0..end], if (value.len == 0) "\"\"" else value, original[end..] });
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
    try std.testing.expectEqualStrings("own-adee37bbc9fa6013ec24ccfd", try token(&first, "ws-own-test"));
    _ = try token(&again, "ws-own-test");
    _ = try token(&other, "ws-other-test");
    try std.testing.expectEqualStrings(&first, &again);
    try std.testing.expect(!std.mem.eql(u8, &first, &other));
    try std.testing.expect(isToken(&first));
    try std.testing.expect(!isToken("adee37bbc9fa6013ec24ccfd0123"));
    try std.testing.expect(!isToken("own-ADEE37BBC9FA6013EC24CCFD"));
    try std.testing.expectError(error.MissingWorkspaceId, token(&again, ""));
}

test "IGSH-672 opt-in file lists exact workspace ids one per line" {
    try std.testing.expectEqualStrings("ws-own-test", seed("ws-own-test\n", "ws-own-test", "").?);
    try std.testing.expectEqualStrings("ws-own-test", seed("\xEF\xBB\xBFws-a\r\n  ws-own-test  \r\n", "ws-own-test", "").?);
    try std.testing.expect(seed("ws-own-test-2\n", "ws-own-test", "") == null);
    try std.testing.expect(seed("", "ws-own-test", "") == null);
    try std.testing.expect(seed("ws-own-test\n", "", "") == null);
}

test "IGSH-989 opt-in by workspace name survives a regenerated workspace id" {
    const listing = "inne=ws-before-sync\n";
    try std.testing.expectEqualStrings("ws-before-sync", seed(listing, "ws-after-sync", "inne").?);
    try std.testing.expectEqualStrings("ws-before-sync", seed(listing, "ws-before-sync", "inne").?);
    try std.testing.expect(seed(listing, "ws-after-sync-two", "Yeo UX") == null);
    try std.testing.expect(seed(listing, "ws-after-sync", "inne chat") == null);
    try std.testing.expect(seed(listing, "", "") == null);
    try std.testing.expectEqualStrings("inne", seed("inne\n", "ws-new", "inne").?);
    var first: [TOKEN_LEN]u8 = undefined;
    var second: [TOKEN_LEN]u8 = undefined;
    _ = try token(&first, seed(listing, "ws-after-sync", "inne").?);
    _ = try token(&second, "ws-before-sync");
    try std.testing.expectEqualStrings(&second, &first);
}

test "IGSH-989 an id line beats a name line for the same workspace" {
    const listing = "inne=ws-name-seed\nws-current=ws-id-seed\n";
    try std.testing.expectEqualStrings("ws-id-seed", seed(listing, "ws-current", "inne").?);
}

test "IGSH-672 own profile folders never name the shared profile or old hash folders" {
    var value: [TOKEN_LEN]u8 = undefined;
    _ = try token(&value, "ws-own-test");
    var buf: [256]u8 = undefined;
    const root = try path(&buf, "C:\\Local", "chrome", &value);
    try std.testing.expectEqualStrings("C:\\Local\\ZigShell\\BrowserWorkspaces\\chrome\\own-adee37bbc9fa6013ec24ccfd", root);
    var found: [TOKEN_LEN]u8 = undefined;
    try std.testing.expectEqualStrings(&value, (try tokenFromPath(&found, "C:\\Local", root)).?);
    try std.testing.expectEqual(@as(?[]const u8, null), try tokenFromPath(&found, "C:\\Local", "C:\\Local\\ZigShell\\ChromeUserData"));
    try std.testing.expectError(error.InvalidWorkspaceProfile, tokenFromPath(&found, "C:\\Local", "C:\\Local\\ZigShell\\BrowserWorkspaces\\chrome\\0123456789abcdef0123456789abcd"));
    try std.testing.expectError(error.InvalidEngine, path(&buf, "C:\\Local", "firefox", &value));
}

test "IGSH-726 commands explicitly select shared and own profiles" {
    var value: [TOKEN_LEN]u8 = undefined;
    _ = try token(&value, "ws-own-test");
    var buf: [256]u8 = undefined;
    const original = "\"C:\\Program Files\\bridge.exe\" --window 42 tabs";
    try std.testing.expectEqualStrings("\"C:\\Program Files\\bridge.exe\" --profile \"\" --window 42 tabs", try command(&buf, original, ""));
    const qualified = try command(&buf, original, &value);
    try std.testing.expectEqualStrings("\"C:\\Program Files\\bridge.exe\" --profile own-adee37bbc9fa6013ec24ccfd --window 42 tabs", qualified);
    try std.testing.expectError(error.InvalidProfileCommand, command(&buf, "bridge.exe tabs", &value));
    const profile = (try userDataArgument(std.testing.allocator, "chrome.exe --user-data-dir=\"C:\\Local Space\\profile\" --app=about:blank")).?;
    defer std.testing.allocator.free(profile);
    try std.testing.expectEqualStrings("C:\\Local Space\\profile", profile);
}

test "IGSH-672 module declarations compile" {
    std.testing.refAllDecls(@This());
}
