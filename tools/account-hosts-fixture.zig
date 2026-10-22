const std = @import("std");
const account_hosts = @import("account_hosts.zig");
const session_layout = @import("session_layout.zig");
const account_layout = @import("account_layout.zig");
const allocator = std.heap.page_allocator;
const DWORD = u32;
const SSH_TARGET_DE = "remote-1";
const SSH_TARGET_UK = "remote-2";
const SSH_TARGET_INNE = "remote-3";
const AccountJob = struct { kind: enum { startup, login, pull, push }, base: ?[]u8 = null, edited: ?[]u8 = null };
const LayoutReply = struct { bytes: ?[]u8 = null, unauthorized: bool = false };
const initial_host = account_hosts.Host{ .slot = 0, .name = "Host 1", .hostname = "old.example", .port = 22, .user = "owner" };
const initial_config = "Host remote-1\r\n  HostName old.example\r\n  Port 22\r\n  User owner\r\n  IdentityFile ~/.ssh/local_key\r\n  ProxyCommand custom-proxy %h\r\n  ForwardAgent no\r\nHost other\r\n  HostName untouched.example\r\n";
var g_account_hosts_cache: struct {
    arena: ?std.heap.ArenaAllocator = null,
    hosts: []const account_hosts.Host = &.{},
    refreshed_at: ?u64 = null,
} = .{};
const Laptop = struct {
    config: []const u8 = initial_config,
    base: ?[]const u8 = null,
    cache: @TypeOf(g_account_hosts_cache) = .{},
    backup: ?[]const u8 = null,
    backup_path: ?[]const u8 = null,
    fail_resolve: bool = false,
    fail_backup: bool = false,
    fail_after_discovery: bool = false,
    resolves: usize = 0,
};
var laptop_under_test: *Laptop = undefined;
var server_host = initial_host;
var revision: u64 = 1;
var puts: usize = 0;
var conflicts: usize = 0;
var race_user = false;

fn GetTickCount64() u64 {
    return 1000;
}
fn debugLog(_: []const u8) void {
    conflicts += 1;
}
fn appendSshExe(buf: []u8, len: *usize) bool {
    const exe = "\"fixture\\ssh.exe\" ";
    @memcpy(buf[0..exe.len], exe);
    len.* = exe.len;
    return true;
}
fn GetEnvironmentVariableA(_: [*:0]const u8, buf: []u8, _: usize) DWORD {
    @memcpy(buf[0..7], "fixture");
    return 7;
}
fn win32MakeDir(_: []const u8) void {}
fn readFileAllocWin32(_: []const u8, _: usize) ?[]u8 {
    return allocator.dupe(u8, laptop_under_test.config) catch null;
}
fn readDpapiFile(_: []const u8, _: usize) ?[]u8 {
    return if (laptop_under_test.base) |base| allocator.dupe(u8, base) catch null else null;
}
fn writeDpapiFile(_: []const u8, bytes: []const u8) bool {
    laptop_under_test.base = allocator.dupe(u8, bytes) catch return false;
    return true;
}
fn win32WidePath(buf: []u16, path: []const u8) ?[:0]u16 {
    const n = std.unicode.utf8ToUtf16Le(buf[0 .. buf.len - 1], path) catch return null;
    buf[n] = 0;
    return buf[0..n :0];
}
fn GetSystemTimeAsFileTime(stamp: *[2]DWORD) void {
    stamp.* = .{ 123456789, 42 };
}
const FakeKernel = struct {
    fn CopyFileW(_: [*:0]const u16, target: [*:0]const u16, exclusive: i32) i32 {
        std.debug.assert(exclusive == 1);
        if (laptop_under_test.fail_backup) return 0;
        laptop_under_test.backup_path = std.unicode.utf16LeToUtf8Alloc(allocator, std.mem.span(target)) catch unreachable;
        laptop_under_test.backup = allocator.dupe(u8, laptop_under_test.config) catch unreachable;
        return 1;
    }
};
fn writeFileAtomicW(_: []const u8, bytes: []const u8) bool {
    std.debug.assert(laptop_under_test.backup != null);
    laptop_under_test.config = allocator.dupe(u8, bytes) catch return false;
    return true;
}
fn accountAppendSshFile(_: []const u8, _: []const u8) !void {
    return error.UnexpectedImport;
}
fn accountSshOutput(alloc: std.mem.Allocator, command: []const u8, _: u64) ![]const u8 {
    if (std.mem.indexOf(u8, command, " -F ") != null) return "";
    laptop_under_test.resolves += 1;
    if (laptop_under_test.fail_resolve or (laptop_under_test.fail_after_discovery and laptop_under_test.resolves > 3)) return error.Process;
    const space = std.mem.lastIndexOfScalar(u8, command, ' ') orelse return error.Process;
    const alias = command[space + 1 ..];
    var hostname: ?[]const u8 = null;
    var user: ?[]const u8 = null;
    var port: ?[]const u8 = null;
    var active = true;
    var lines = std.mem.splitScalar(u8, laptop_under_test.config, '\n');
    while (lines.next()) |line| {
        var fields = std.mem.tokenizeAny(u8, line, " \t\r=");
        const key = fields.next() orelse continue;
        const value = fields.next() orelse continue;
        if (std.ascii.eqlIgnoreCase(key, "Host")) {
            active = std.ascii.eqlIgnoreCase(value, alias) or std.mem.eql(u8, value, "*");
        } else if (active) {
            if (hostname == null and std.ascii.eqlIgnoreCase(key, "HostName")) hostname = value;
            if (user == null and std.ascii.eqlIgnoreCase(key, "User")) user = value;
            if (port == null and std.ascii.eqlIgnoreCase(key, "Port")) port = value;
        }
    }
    return std.fmt.allocPrint(alloc, "hostname {s}\nuser {s}\nport {s}\n", .{ hostname orelse alias, user orelse "owner", port orelse "22" });
}
fn accountReadLayout(alloc: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const parsed = try std.json.parseFromSlice(struct { layout: session_layout.Layout }, alloc, bytes, .{});
    defer parsed.deinit();
    return session_layout.encode(alloc, parsed.value.layout);
}
fn accountSyncDeviceKeys(_: []const u8, _: AccountJob, _: *LayoutReply) !void {}
fn accountDeviceKeyError(_: *LayoutReply, _: []const u8) void {
    @panic("unexpected device key error");
}
const account_client = struct {
    const Response = struct {
        status: u32,
        bytes: []u8,
        hosts_supported: bool = true,
        fn deinit(self: @This()) void {
            allocator.free(self.bytes);
        }
    };
    fn request(method: []const u8, path: []const u8, _: []const u8, body: []const u8) !Response {
        std.debug.assert(std.mem.eql(u8, path, "/v1/layout"));
        var status: u32 = 200;
        if (std.mem.eql(u8, method, "PUT")) {
            const parsed = try std.json.parseFromSlice(struct { base_revision: u64, layout: session_layout.Layout }, allocator, body, .{ .allocate = .alloc_always });
            defer parsed.deinit();
            if (race_user) {
                race_user = false;
                server_host.user = "remoteuser";
                revision += 1;
            }
            if (parsed.value.base_revision != revision) {
                status = 409;
            } else {
                const host = parsed.value.layout.hosts.?[0];
                server_host = host;
                server_host.hostname = try allocator.dupe(u8, host.hostname);
                server_host.user = try allocator.dupe(u8, host.user);
                revision += 1;
                puts += 1;
            }
        }
        const layout = session_layout.Layout{ .revision = revision, .hosts = &.{server_host}, .workspaces = &.{}, .tabs = &.{} };
        return .{ .status = status, .bytes = try std.json.Stringify.valueAlloc(allocator, .{ .layout = layout }, .{ .emit_null_optional_fields = false }) };
    }
};
fn sync(laptop: *Laptop, kind: @FieldType(AccountJob, "kind")) !void {
    laptop_under_test = laptop;
    g_account_hosts_cache = laptop.cache;
    defer laptop.cache = g_account_hosts_cache;
    var reply: LayoutReply = .{};
    defer if (reply.bytes) |bytes| allocator.free(bytes);
    try accountRequest(.{ .kind = kind }, &reply);
}
fn reset() void {
    g_account_hosts_cache = .{};
    server_host = initial_host;
    revision = 1;
    puts = 0;
    conflicts = 0;
    race_user = false;
}
fn pair(one: *Laptop, two: *Laptop) !void {
    reset();
    try sync(one, .startup);
    try sync(two, .startup);
}
fn edit(laptop: *Laptop, from: []const u8, to: []const u8) !void {
    laptop.config = try std.mem.replaceOwned(u8, allocator, laptop.config, from, to);
}
fn laptopAddress(laptop: *Laptop) !account_hosts.Resolved {
    laptop_under_test = laptop;
    const output = try accountSshOutput(allocator, "ssh -G remote-1", 5000);
    return account_hosts.parseSshConfig(output) orelse error.InvalidHosts;
}

test "ISSUE-252 remote hostname port and user changes reach laptop B" {
    var one: Laptop = .{};
    var two: Laptop = .{};
    try pair(&one, &two);
    try edit(&one, "old.example", "new.example");
    try edit(&one, "Port 22", "Port 2222");
    try edit(&one, "User owner", "User newuser");
    try sync(&one, .startup);
    try sync(&two, .pull);
    const result = try laptopAddress(&two);
    try std.testing.expectEqualStrings("new.example", result.hostname);
    try std.testing.expectEqual(@as(u16, 2222), result.port);
    try std.testing.expectEqualStrings("newuser", result.user);
    try std.testing.expectEqual(@as(usize, 1), puts);
}

test "ISSUE-252 local-only address change is pushed" {
    var one: Laptop = .{};
    var two: Laptop = .{};
    try pair(&one, &two);
    try edit(&two, "old.example", "local.example");
    try sync(&two, .startup);
    try std.testing.expectEqualStrings("local.example", server_host.hostname);
    try sync(&one, .pull);
    try std.testing.expectEqualStrings("local.example", (try laptopAddress(&one)).hostname);
    try std.testing.expect(two.backup == null);
}

test "ISSUE-252 both-changed keeps local and logs conflict while remote-only user merges" {
    var one: Laptop = .{};
    var two: Laptop = .{};
    try pair(&one, &two);
    try edit(&one, "old.example", "remote.example");
    try edit(&one, "User owner", "User remoteuser");
    try sync(&one, .startup);
    try edit(&two, "old.example", "local.example");
    try sync(&two, .pull);
    try std.testing.expectEqualStrings("local.example", server_host.hostname);
    try std.testing.expectEqualStrings("remoteuser", (try laptopAddress(&two)).user);
    try std.testing.expectEqual(@as(usize, 1), conflicts);
}

test "ISSUE-252 backup precedes rewrite and preserves private and unrelated lines" {
    var one: Laptop = .{};
    var two: Laptop = .{};
    try pair(&one, &two);
    try edit(&one, "old.example", "new.example");
    try sync(&one, .startup);
    try sync(&two, .pull);
    try std.testing.expectEqualStrings(initial_config, two.backup.?);
    try std.testing.expect(std.mem.endsWith(u8, two.backup_path.?, ".180512083221.bak"));
    for ([_][]const u8{ "  IdentityFile ~/.ssh/local_key\r\n", "  ProxyCommand custom-proxy %h\r\n", "  ForwardAgent no\r\n", "Host other\r\n  HostName untouched.example\r\n" }) |line| {
        try std.testing.expect(std.mem.indexOf(u8, two.config, line) != null);
    }
}

test "ISSUE-252 failed resolve changes neither laptop account nor merge base" {
    var one: Laptop = .{};
    var two: Laptop = .{};
    try pair(&one, &two);
    try edit(&one, "old.example", "remote.example");
    try sync(&one, .startup);
    const old_base = two.base.?;
    const old_revision = revision;
    two.fail_resolve = true;
    try sync(&two, .pull);
    try std.testing.expectEqualStrings(initial_config, two.config);
    try std.testing.expectEqualStrings(old_base, two.base.?);
    try std.testing.expectEqual(old_revision, revision);
    try std.testing.expect(two.backup == null);
}

test "ISSUE-252 failed backup and failed revalidation never rewrite config" {
    for ([_]bool{ false, true }) |resolve| {
        var one: Laptop = .{};
        var two: Laptop = .{};
        try pair(&one, &two);
        try edit(&one, "old.example", "remote.example");
        try sync(&one, .startup);
        const old_base = two.base.?;
        two.resolves = 0;
        two.fail_after_discovery = resolve;
        two.fail_backup = !resolve;
        if (resolve) try std.testing.expectError(error.Process, sync(&two, .pull)) else try std.testing.expectError(error.Storage, sync(&two, .pull));
        try std.testing.expectEqualStrings(initial_config, two.config);
        try std.testing.expectEqualStrings(old_base, two.base.?);
        try std.testing.expect(two.backup == null);
    }
}

test "ISSUE-252 conflict retry rebases latest remote fields and restart retains synced base" {
    var one: Laptop = .{};
    var two: Laptop = .{};
    try pair(&one, &two);
    try edit(&two, "old.example", "local.example");
    race_user = true;
    try sync(&two, .startup);
    try std.testing.expectEqualStrings("local.example", server_host.hostname);
    try std.testing.expectEqualStrings("remoteuser", server_host.user);
    try std.testing.expectEqualStrings("remoteuser", (try laptopAddress(&two)).user);
    one.cache = .{};
    try sync(&one, .startup);
    try std.testing.expectEqualStrings("local.example", (try laptopAddress(&one)).hostname);
}

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    const args = try init.minimal.args.toSlice(alloc);
    const Input = struct { local: account_hosts.Host, base: ?[]const account_hosts.Host = null, remote: account_hosts.Host, config: []const u8, fail_resolve: bool = false };
    const input = try std.json.parseFromSlice(Input, alloc, args[1], .{});
    var laptop: Laptop = .{ .config = input.value.config, .fail_resolve = input.value.fail_resolve };
    if (input.value.base) |base| laptop.base = try std.json.Stringify.valueAlloc(alloc, base, .{});
    reset();
    server_host = input.value.remote;
    try sync(&laptop, .startup);
    const result = try std.json.Stringify.valueAlloc(alloc, .{ .host = server_host, .config = laptop.config, .base = laptop.base, .backup = laptop.backup, .backup_path = laptop.backup_path, .conflicts = conflicts, .puts = puts }, .{ .emit_null_optional_fields = true });
    var buffer: [4096]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try output.interface.writeAll(result);
    try output.interface.flush();
}
