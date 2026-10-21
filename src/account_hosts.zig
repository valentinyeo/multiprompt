const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Host = struct {
    slot: u8,
    name: []const u8,
    hostname: []const u8,
    port: u16,
    user: []const u8,
    host_keys: ?[]const []const u8 = null,
};
pub const Resolved = struct { hostname: []const u8, port: u16, user: []const u8 };

pub fn validHostname(value: []const u8) bool {
    if (value.len == 0 or value.len > 253) return false;
    var dns = true;
    var ipv6 = value.len >= 2 and value.len <= 45;
    for (value) |c| {
        dns = dns and (std.ascii.isAlphanumeric(c) or c == '.' or c == '-');
        ipv6 = ipv6 and (std.ascii.isHex(c) or c == ':');
    }
    return dns or ipv6;
}

pub fn validUser(value: []const u8) bool {
    if (value.len == 0 or value.len > 32 or (!std.ascii.isAlphabetic(value[0]) and value[0] != '_')) return false;
    for (value) |c| if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '.' and c != '-') return false;
    return true;
}

pub fn validKey(value: []const u8) bool {
    if (value.len > 1024) return false;
    const space = std.mem.indexOfScalar(u8, value, ' ') orelse return false;
    var supported = false;
    for ([_][]const u8{ "ssh-ed25519", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521", "ssh-rsa" }) |kind| {
        if (std.mem.eql(u8, value[0..space], kind)) supported = true;
    }
    if (!supported or space + 1 == value.len) return false;
    var padding: usize = 0;
    var data: usize = 0;
    for (value[space + 1 ..]) |c| {
        if (c == '=') {
            padding += 1;
            if (padding > 2) return false;
        } else {
            if (padding != 0 or (!std.ascii.isAlphanumeric(c) and c != '+' and c != '/')) return false;
            data += 1;
        }
    }
    return data > 0;
}

pub fn validate(hosts: []const Host) !void {
    if (hosts.len > 3) return error.InvalidHosts;
    for (hosts, 0..) |host, i| {
        if (host.slot > 2 or host.name.len == 0 or std.mem.indexOf(u8, host.name, "PRIVATE KEY") != null or !std.unicode.utf8ValidateSlice(host.name) or !validHostname(host.hostname) or host.port == 0 or !validUser(host.user)) return error.InvalidHosts;
        var wide: [64]u16 = undefined;
        const n = std.unicode.utf8ToUtf16Le(&wide, host.name) catch return error.InvalidHosts;
        if (n > 32) return error.InvalidHosts;
        var codepoints = (try std.unicode.Utf8View.init(host.name)).iterator();
        while (codepoints.nextCodepoint()) |c| if (c < 32 or (c >= 127 and c <= 159)) return error.InvalidHosts;
        for (hosts[0..i]) |old| if (old.slot == host.slot) return error.InvalidHosts;
        if (host.host_keys) |keys| {
            if (keys.len > 4) return error.InvalidHosts;
            for (keys, 0..) |key, j| {
                if (!validKey(key)) return error.InvalidHosts;
                for (keys[0..j]) |old| if (std.mem.eql(u8, old, key)) return error.InvalidHosts;
            }
        }
    }
}

pub fn parseSshConfig(output: []const u8) ?Resolved {
    var hostname: ?[]const u8 = null;
    var user: ?[]const u8 = null;
    var port: ?u16 = null;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "PRIVATE KEY") != null) continue;
        var fields = std.mem.tokenizeAny(u8, line, " \t\r");
        const key = fields.next() orelse continue;
        const value = fields.next() orelse continue;
        if (std.ascii.eqlIgnoreCase(key, "hostname")) hostname = value;
        if (std.ascii.eqlIgnoreCase(key, "user")) user = value;
        if (std.ascii.eqlIgnoreCase(key, "port")) port = std.fmt.parseInt(u16, value, 10) catch return null;
    }
    const result = Resolved{ .hostname = hostname orelse return null, .user = user orelse return null, .port = port orelse return null };
    if (!validHostname(result.hostname) or !validUser(result.user) or result.port == 0) return null;
    return result;
}

pub fn shouldImport(alias: []const u8, resolved: Resolved) bool {
    return std.ascii.eqlIgnoreCase(alias, resolved.hostname);
}

pub fn knownHostName(a: Allocator, hostname: []const u8, port: u16) ![]const u8 {
    if (!validHostname(hostname) or port == 0) return error.InvalidHosts;
    return if (port == 22) try a.dupe(u8, hostname) else try std.fmt.allocPrint(a, "[{s}]:{d}", .{ hostname, port });
}

pub fn knownHostLine(a: Allocator, host: Host, key: []const u8) ![]const u8 {
    if (!validKey(key)) return error.InvalidHosts;
    const name = try knownHostName(a, host.hostname, host.port);
    defer a.free(name);
    return std.fmt.allocPrint(a, "{s} {s}\r\n", .{ name, key });
}

pub fn configBlock(a: Allocator, alias: []const u8, host: Host) ![]const u8 {
    try validate(&.{host});
    if (!validHostname(alias)) return error.InvalidHosts;
    return std.fmt.allocPrint(a, "\r\nHost {s}\r\n  HostName {s}\r\n  Port {d}\r\n  User {s}\r\n", .{ alias, host.hostname, host.port, host.user });
}

pub fn readKeys(a: Allocator, output: []const u8) ![]const []const u8 {
    var keys: std.ArrayList([]const u8) = .empty;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "PRIVATE KEY") != null) continue;
        var fields = std.mem.tokenizeAny(u8, line, " \t\r");
        const name = fields.next() orelse continue;
        if (name[0] == '#') continue;
        const kind = fields.next() orelse continue;
        const data = fields.next() orelse continue;
        const key = try std.fmt.allocPrint(a, "{s} {s}", .{ kind, data });
        var duplicate = false;
        for (keys.items) |old| if (std.mem.eql(u8, old, key)) {
            duplicate = true;
        };
        if (validKey(key) and !duplicate) {
            try keys.append(a, key);
        } else a.free(key);
    }
    return keys.toOwnedSlice(a);
}

pub fn shouldRefresh(now: u64, last_refresh: ?u64, immediate: bool, local: []const Host, remote: []const Host) bool {
    if (immediate) return true;
    const last = last_refresh orelse return true;
    if (now -| last >= 15 * 60 * 1000) return true;
    for (remote) |host| {
        var configured = false;
        for (local) |cached| if (cached.slot == host.slot) {
            configured = true;
            break;
        };
        if (!configured) return true;
    }
    return false;
}

pub fn needsPublish(local: []const Host, remote: []const Host) bool {
    for (local) |host| {
        var found = false;
        for (remote) |old| {
            if (old.slot != host.slot) continue;
            found = true;
            if (!std.mem.eql(u8, host.name, old.name) or !std.mem.eql(u8, host.hostname, old.hostname) or host.port != old.port or !std.mem.eql(u8, host.user, old.user)) return true;
            const keys = host.host_keys orelse &.{};
            const old_keys = old.host_keys orelse &.{};
            if (keys.len != old_keys.len) return true;
            for (keys) |key| {
                var present = false;
                for (old_keys) |old_key| if (std.mem.eql(u8, key, old_key)) {
                    present = true;
                };
                if (!present) return true;
            }
        }
        if (!found) return true;
    }
    return false;
}

const fixture = Host{ .slot = 0, .name = "Host 1", .hostname = "203.0.113.5", .port = 22, .user = "owner" };

test "hosts ssh -G parse ignores identity lines and rejects incomplete or unsafe output" {
    const parsed = parseSshConfig("host vps\r\nuser owner\r\nhostname 203.0.113.5\r\nport 2222\r\nidentityfile ~/.ssh/id_rsa\r\n").?;
    try std.testing.expectEqualStrings(fixture.hostname, parsed.hostname);
    try std.testing.expectEqualStrings(fixture.user, parsed.user);
    try std.testing.expectEqual(@as(u16, 2222), parsed.port);
    for ([_][]const u8{ "hostname vps\n", "hostname bad/host\nuser root\nport 22", "hostname vps\nuser root\nport 0", "hostname vps\nuser root\nport 65536" }) |bad| try std.testing.expect(parseSshConfig(bad) == null);
}

test "hosts config block is append only and never contains IdentityFile or private key material" {
    const block = try configBlock(std.testing.allocator, "vps", fixture);
    defer std.testing.allocator.free(block);
    try std.testing.expectEqualStrings("\r\nHost vps\r\n  HostName 203.0.113.5\r\n  Port 22\r\n  User owner\r\n", block);
    try std.testing.expect(std.mem.indexOf(u8, block, "IdentityFile") == null);
    try std.testing.expectError(error.InvalidHosts, configBlock(std.testing.allocator, "vps\nIdentityFile bad", fixture));
}

test "hosts known hosts lines use bracketed names only for nonstandard ports" {
    for ([_]u16{ 22, 2222 }) |port| {
        var host = fixture;
        host.port = port;
        const line = try knownHostLine(std.testing.allocator, host, "ssh-ed25519 AAAA==");
        defer std.testing.allocator.free(line);
        try std.testing.expectEqualStrings(if (port == 22) "203.0.113.5 ssh-ed25519 AAAA==\r\n" else "[203.0.113.5]:2222 ssh-ed25519 AAAA==\r\n", line);
    }
}

test "hosts skip configured alias including different local server" {
    try std.testing.expect(shouldImport("vps", parseSshConfig("hostname vps\nport 22\nuser root").?));
    try std.testing.expect(!shouldImport("vps", parseSshConfig("hostname different.example\nport 22\nuser root").?));
}

test "hosts key lookup accepts hashed names deduplicates and excludes secrets and markers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const keys = try readKeys(arena.allocator(), "# Host found\n|1|hashed ssh-ed25519 AAAA== comment\nserver ssh-ed25519 AAAA==\n@revoked server ssh-rsa BBBB\nserver ssh-rsa PRIVATE KEY\nserver ssh-rsa BBBB\n");
    try std.testing.expectEqual(@as(usize, 2), keys.len);
    try std.testing.expectEqualStrings("ssh-ed25519 AAAA==", keys[0]);
    try std.testing.expectEqualStrings("ssh-rsa BBBB", keys[1]);
}

test "hosts publishing is slot based and detects local changes without deleting unknown slots" {
    var other = fixture;
    other.slot = 1;
    try std.testing.expect(!needsPublish(&.{fixture}, &.{ other, fixture }));
    other = fixture;
    other.hostname = "local.example";
    try std.testing.expect(needsPublish(&.{other}, &.{fixture}));
    try std.testing.expect(needsPublish(&.{fixture}, &.{}));
    try std.testing.expect(!needsPublish(&.{}, &.{fixture}));
}

test "hosts refresh on first run even with no remote hosts" {
    try std.testing.expect(shouldRefresh(0, null, false, &.{}, &.{}));
}

test "hosts reuse local discovery inside fifteen minutes including empty results" {
    try std.testing.expect(!shouldRefresh(1000 + 15 * 60 * 1000 - 1, 1000, false, &.{fixture}, &.{fixture}));
    try std.testing.expect(!shouldRefresh(21000, 1000, false, &.{}, &.{}));
}

test "hosts refresh at and after fifteen minutes" {
    try std.testing.expect(shouldRefresh(1000 + 15 * 60 * 1000, 1000, false, &.{fixture}, &.{fixture}));
    try std.testing.expect(shouldRefresh(1000 + 15 * 60 * 1000 + 1, 1000, false, &.{fixture}, &.{fixture}));
}

test "hosts login and startup jobs refresh immediately" {
    try std.testing.expect(shouldRefresh(1000, 1000, true, &.{fixture}, &.{fixture}));
}

test "hosts remote slot missing locally refreshes immediately but configured slots do not" {
    var remote = fixture;
    remote.slot = 1;
    try std.testing.expect(shouldRefresh(1001, 1000, false, &.{fixture}, &.{remote}));
    try std.testing.expect(shouldRefresh(1001, 1000, false, &.{}, &.{fixture}));
    remote.slot = fixture.slot;
    remote.hostname = "remote.example";
    try std.testing.expect(!shouldRefresh(1001, 1000, false, &.{fixture}, &.{remote}));
}
