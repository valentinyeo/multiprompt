const std = @import("std");
const hosts = @import("account_hosts.zig");
const keys = @import("account_keys.zig");
const Allocator = std.mem.Allocator;

pub const slot_count = 3;
pub const retry_seconds: u64 = 6 * 60 * 60;

pub const Status = enum { empty, needs_setup, connected, failed, removed };

pub const Text = struct {
    buf: [256]u8 = undefined,
    len: usize = 0,

    pub fn get(self: *const Text) []const u8 {
        return self.buf[0..self.len];
    }

    pub fn set(self: *Text, value: []const u8) void {
        self.len = 0;
        for (value) |c| {
            if (self.len == self.buf.len) break;
            self.buf[self.len] = if (c < 0x20 or c == 0x7f) ' ' else c;
            self.len += 1;
        }
    }
};

pub const Slot = struct {
    status: Status = .empty,
    owned: bool = false,
    port: u16 = 22,
    tried: u64 = 0,
    name: Text = .{},
    hostname: Text = .{},
    user: Text = .{},
    reason: Text = .{},
};

pub const Table = [slot_count]Slot;

pub fn listed(slot: Slot) bool {
    return slot.status != .empty and slot.status != .removed;
}

pub fn forced(slot: Slot) bool {
    return slot.status == .connected or (slot.owned and listed(slot));
}

pub fn needsMigration(slot: Slot, now: u64) bool {
    if (slot.owned) return false;
    return slot.status == .needs_setup or (slot.status == .failed and now >= slot.tried + retry_seconds);
}

pub fn freeSlot(table: *const Table) ?usize {
    for (table, 0..) |slot, i| if (!listed(slot)) return i;
    return null;
}

pub fn encode(a: Allocator, table: *const Table) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    try out.appendSlice(a, "v1\n");
    for (table) |slot| {
        const line = try std.fmt.allocPrint(a, "{s}\t{d}\t{d}\t{d}\t{s}\t{s}\t{s}\t{s}\n", .{ @tagName(slot.status), @intFromBool(slot.owned), slot.port, slot.tried, slot.hostname.get(), slot.user.get(), slot.name.get(), slot.reason.get() });
        defer a.free(line);
        try out.appendSlice(a, line);
    }
    return out.toOwnedSlice(a);
}

pub fn decode(bytes: []const u8) Table {
    var table: Table = @splat(.{});
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    if (!std.mem.eql(u8, std.mem.trimEnd(u8, lines.next() orelse return table, "\r"), "v1")) return table;
    for (&table) |*slot| {
        const line = std.mem.trimEnd(u8, lines.next() orelse break, "\r");
        slot.* = parseSlot(line) orelse .{};
    }
    return table;
}

fn parseSlot(line: []const u8) ?Slot {
    var fields = std.mem.splitScalar(u8, line, '\t');
    var slot: Slot = .{};
    slot.status = std.meta.stringToEnum(Status, fields.next() orelse return null) orelse return null;
    const owned = fields.next() orelse return null;
    if (!std.mem.eql(u8, owned, "0") and !std.mem.eql(u8, owned, "1")) return null;
    slot.owned = owned[0] == '1';
    slot.port = std.fmt.parseInt(u16, fields.next() orelse return null, 10) catch return null;
    slot.tried = std.fmt.parseInt(u64, fields.next() orelse return null, 10) catch return null;
    slot.hostname.set(fields.next() orelse return null);
    slot.user.set(fields.next() orelse return null);
    slot.name.set(fields.next() orelse return null);
    slot.reason.set(fields.next() orelse "");
    if (slot.port == 0) return null;
    if (slot.owned and listed(slot) and (!hosts.validHostname(slot.hostname.get()) or !hosts.validUser(slot.user.get()))) return null;
    return slot;
}

pub fn configPath(a: Allocator, path: []const u8) ![]u8 {
    if (path.len == 0 or std.mem.indexOfAny(u8, path, "\"%\r\n\t") != null) return error.InvalidPath;
    const out = try a.dupe(u8, path);
    std.mem.replaceScalar(u8, out, '\\', '/');
    return out;
}

pub fn renderConfig(a: Allocator, key_path: []const u8, user_config: []const u8, system_config: []const u8, aliases: []const []const u8, table: *const Table) ![]u8 {
    const key = try configPath(a, key_path);
    defer a.free(key);
    const user = try configPath(a, user_config);
    defer a.free(user);
    const system = try configPath(a, system_config);
    defer a.free(system);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    for (table, aliases) |slot, alias| {
        if (!forced(slot)) continue;
        if (!hosts.validHostname(alias)) return error.InvalidHosts;
        const head = try std.fmt.allocPrint(a, "Host {s}\r\n", .{alias});
        defer a.free(head);
        try out.appendSlice(a, head);
        if (!hosts.validHostname(slot.hostname.get()) or !hosts.validUser(slot.user.get()) or slot.port == 0) return error.InvalidHosts;
        const address = try std.fmt.allocPrint(a, "  HostName {s}\r\n  User {s}\r\n  Port {d}\r\n", .{ slot.hostname.get(), slot.user.get(), slot.port });
        defer a.free(address);
        try out.appendSlice(a, address);
        const identity = try std.fmt.allocPrint(a, "  IdentityFile \"{s}\"\r\n  IdentitiesOnly yes\r\n  IdentityAgent none\r\n", .{key});
        defer a.free(identity);
        try out.appendSlice(a, identity);
    }
    for ([_][]const u8{ user, system }) |config| {
        try out.appendSlice(a, "Host *");
        for (table, aliases) |slot, alias| {
            if (!forced(slot)) continue;
            const exclusion = try std.fmt.allocPrint(a, " !{s}", .{alias});
            defer a.free(exclusion);
            try out.appendSlice(a, exclusion);
        }
        const include = try std.fmt.allocPrint(a, "\r\n  Include \"{s}\"\r\n", .{config});
        defer a.free(include);
        try out.appendSlice(a, include);
    }
    return out.toOwnedSlice(a);
}

pub fn proofArgs(a: Allocator, key_path: []const u8, user: []const u8, hostname: []const u8, port: u16) ![]u8 {
    if (!hosts.validHostname(hostname) or !hosts.validUser(user) or port == 0) return error.InvalidHosts;
    if (std.mem.indexOfScalar(u8, key_path, '"') != null) return error.InvalidPath;
    return std.fmt.allocPrint(a, "-F none -n -i \"{s}\" -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -p {d} {s}@{s} true", .{ key_path, port, user, hostname });
}

pub fn pasteLine(a: Allocator, public_key: []const u8) ![]const u8 {
    return keys.addCommand(a, public_key);
}

pub fn failureReason(output: []const u8) []const u8 {
    const table = [_]struct { []const u8, []const u8 }{
        .{ "Permission denied", "the key is not on the server yet" },
        .{ "Host key verification failed", "the server identity changed" },
        .{ "REMOTE HOST IDENTIFICATION HAS CHANGED", "the server identity changed" },
        .{ "Could not resolve hostname", "address not found" },
        .{ "Connection refused", "the server refused, check the port" },
        .{ "timed out", "server not reachable" },
        .{ "No route to host", "server not reachable" },
        .{ "Network is unreachable", "no network" },
    };
    for (table) |entry| if (std.mem.indexOf(u8, output, entry[0]) != null) return entry[1];
    return "could not sign in";
}

pub fn statusText(buf: []u8, slot: Slot, checking: bool) []const u8 {
    if (checking) return "Checking...";
    return switch (slot.status) {
        .connected => "Connected",
        .needs_setup => "Needs setup",
        .failed => std.fmt.bufPrint(buf, "Failed: {s}", .{if (slot.reason.len == 0) "could not sign in" else slot.reason.get()}) catch "Failed",
        .empty, .removed => "",
    };
}

pub const Draft = struct { hostname: []const u8, user: []const u8, port: u16 };

pub fn parseDraft(address: []const u8, user: []const u8, port_text: []const u8) ?Draft {
    const host = std.mem.trim(u8, address, " \t");
    const name = std.mem.trim(u8, user, " \t");
    const port_value = std.mem.trim(u8, port_text, " \t");
    const port = if (port_value.len == 0) 22 else std.fmt.parseInt(u16, port_value, 10) catch return null;
    if (port == 0 or !hosts.validHostname(host) or !hosts.validUser(name)) return null;
    return .{ .hostname = host, .user = name, .port = port };
}

const fake_key = "ssh-ed25519 AAAA";
const test_aliases = [_][]const u8{ "remote-1", "remote-2", "remote-3" };

test "IGSH-1928 config forces the app key only on proven or app-owned servers" {
    const a = std.testing.allocator;
    var table: Table = @splat(.{});
    table[0].status = .connected;
    table[0].hostname.set("one.example.invalid");
    table[0].user.set("deploy");
    table[1].status = .needs_setup;
    table[2].status = .needs_setup;
    table[2].owned = true;
    table[2].hostname.set("example.invalid");
    table[2].user.set("deploy");
    table[2].port = 2222;
    const config = try renderConfig(a, "C:\\Users\\Example User\\AppData\\Roaming\\ZigShell\\ssh-key\\multibot_ed25519", "~/.ssh/config", "C:\\ProgramData\\ssh\\ssh_config", &test_aliases, &table);
    defer a.free(config);
    try std.testing.expectEqualStrings(
        "Host remote-1\r\n  HostName one.example.invalid\r\n  User deploy\r\n  Port 22\r\n" ++
            "  IdentityFile \"C:/Users/Example User/AppData/Roaming/ZigShell/ssh-key/multibot_ed25519\"\r\n  IdentitiesOnly yes\r\n  IdentityAgent none\r\n" ++
            "Host remote-3\r\n  HostName example.invalid\r\n  User deploy\r\n  Port 2222\r\n" ++
            "  IdentityFile \"C:/Users/Example User/AppData/Roaming/ZigShell/ssh-key/multibot_ed25519\"\r\n  IdentitiesOnly yes\r\n  IdentityAgent none\r\n" ++
            "Host * !remote-1 !remote-3\r\n  Include \"~/.ssh/config\"\r\n" ++
            "Host * !remote-1 !remote-3\r\n  Include \"C:/ProgramData/ssh/ssh_config\"\r\n",
        config,
    );
    try std.testing.expect(std.mem.indexOf(u8, config, "Host remote-2") == null);
}

test "IGSH-1928 real OpenSSH isolates proven keys while preserving unproven fallback" {
    const a = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(io, ".", a);
    defer a.free(base);
    const user_config = try std.fmt.allocPrint(a, "{s}/user.conf", .{base});
    defer a.free(user_config);
    const system_config = try std.fmt.allocPrint(a, "{s}/system.conf", .{base});
    defer a.free(system_config);
    const app_config = try std.fmt.allocPrint(a, "{s}/app.conf", .{base});
    defer a.free(app_config);
    try tmp.dir.writeFile(io, .{ .sub_path = "user.conf", .data = "Host remote-1\n  HostName old.example.invalid\n  IdentityFile legacy-host-key\n" ++
        "Host *\n  IdentityFile legacy-wildcard-key\n  IdentityAgent legacy-agent\n" });
    try tmp.dir.writeFile(io, .{ .sub_path = "system.conf", .data = "Host *\n  IdentityFile legacy-system-key\n" });
    var table: Table = @splat(.{});
    table[0].hostname.set("example.invalid");
    table[0].user.set("deploy");
    table[0].port = 2222;
    for ([_]bool{ false, true }) |owned| {
        table[0].owned = owned;
        for ([_]Status{ .connected, .failed, .needs_setup, .removed, .empty }) |status| {
            table[0].status = status;
            const config = try renderConfig(a, "multibot-test-key", user_config, system_config, &test_aliases, &table);
            defer a.free(config);
            try tmp.dir.writeFile(io, .{ .sub_path = "app.conf", .data = config });
            const result = try std.process.run(a, io, .{ .argv = &.{ "ssh", "-F", app_config, "-G", "remote-1" } });
            defer a.free(result.stdout);
            defer a.free(result.stderr);
            if (result.term != .exited or result.term.exited != 0) std.debug.print("{s}", .{result.stderr});
            try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
            if (!forced(table[0])) {
                try std.testing.expect(std.mem.indexOf(u8, result.stdout, "identityfile legacy-host-key") != null);
                try std.testing.expect(std.mem.indexOf(u8, result.stdout, "identityfile legacy-system-key") != null);
                try std.testing.expect(std.mem.indexOf(u8, result.stdout, "identityagent legacy-agent") != null);
                try std.testing.expect(std.mem.indexOf(u8, result.stdout, "multibot-test-key") == null);
                continue;
            }
            try std.testing.expect(std.mem.indexOf(u8, result.stdout, "identitiesonly yes") != null);
            try std.testing.expect(std.mem.indexOf(u8, result.stdout, "identityagent none") != null);
            try std.testing.expect(std.mem.indexOf(u8, result.stdout, "legacy-") == null);
            var lines = std.mem.tokenizeAny(u8, result.stdout, "\r\n");
            var identities: usize = 0;
            while (lines.next()) |line| {
                if (!std.mem.startsWith(u8, line, "identityfile ")) continue;
                identities += 1;
                try std.testing.expectEqualStrings("identityfile multibot-test-key", line);
            }
            try std.testing.expectEqual(@as(usize, 1), identities);
            if (listed(table[0])) {
                try std.testing.expect(std.mem.indexOf(u8, result.stdout, "hostname example.invalid") != null);
                try std.testing.expect(std.mem.indexOf(u8, result.stdout, "user deploy") != null);
                try std.testing.expect(std.mem.indexOf(u8, result.stdout, "port 2222") != null);
            }
        }
    }
    const control = try std.process.run(a, io, .{ .argv = &.{ "ssh", "-F", app_config, "-G", "unrelated.example.invalid" } });
    defer a.free(control.stdout);
    defer a.free(control.stderr);
    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, control.term);
    try std.testing.expect(std.mem.indexOf(u8, control.stdout, "identityfile legacy-wildcard-key") != null);
    try std.testing.expect(std.mem.indexOf(u8, control.stdout, "identityfile legacy-system-key") != null);
    try std.testing.expect(std.mem.indexOf(u8, control.stdout, "identityagent legacy-agent") != null);
    try std.testing.expect(std.mem.indexOf(u8, control.stdout, "multibot-test-key") == null);
}

test "IGSH-1928 config refuses paths ssh would misread" {
    const a = std.testing.allocator;
    const table: Table = @splat(.{});
    try std.testing.expectError(error.InvalidPath, renderConfig(a, "C:\\a\"b", "C:\\c", "C:\\d", &test_aliases, &table));
    try std.testing.expectError(error.InvalidPath, renderConfig(a, "C:\\%d\\key", "C:\\c", "C:\\d", &test_aliases, &table));
}

test "IGSH-1928 server table survives a save and reload" {
    const a = std.testing.allocator;
    var table: Table = @splat(.{});
    table[0].status = .failed;
    table[0].tried = 1700000000;
    table[0].hostname.set("one.example.invalid");
    table[0].user.set("root");
    table[0].name.set("Server 1");
    table[0].reason.set("server not reachable");
    table[1].status = .removed;
    table[2].status = .connected;
    table[2].owned = true;
    table[2].port = 2200;
    table[2].hostname.set("three.example.invalid");
    table[2].user.set("deploy");
    table[2].name.set("Build box");
    const bytes = try encode(a, &table);
    defer a.free(bytes);
    const back = decode(bytes);
    for (table, back) |want, got| {
        try std.testing.expectEqual(want.status, got.status);
        try std.testing.expectEqual(want.owned, got.owned);
        try std.testing.expectEqual(want.port, got.port);
        try std.testing.expectEqual(want.tried, got.tried);
        try std.testing.expectEqualStrings(want.hostname.get(), got.hostname.get());
        try std.testing.expectEqualStrings(want.user.get(), got.user.get());
        try std.testing.expectEqualStrings(want.name.get(), got.name.get());
        try std.testing.expectEqualStrings(want.reason.get(), got.reason.get());
    }
    const broken = decode("v1\nconnected\t1\t22\t0\tbad host\troot\tx\t\n");
    try std.testing.expectEqual(Status.empty, broken[0].status);
    try std.testing.expectEqual(Status.empty, decode("v2\n")[0].status);
}

test "IGSH-1928 migration retries failed servers only after a pause and never touches app-owned ones" {
    var slot: Slot = .{ .status = .failed, .tried = 1000 };
    try std.testing.expect(!needsMigration(slot, 1000 + retry_seconds - 1));
    try std.testing.expect(needsMigration(slot, 1000 + retry_seconds));
    slot.status = .needs_setup;
    try std.testing.expect(needsMigration(slot, 0));
    slot.owned = true;
    try std.testing.expect(!needsMigration(slot, 0));
    try std.testing.expect(!needsMigration(.{ .status = .connected }, 0));
}

test "IGSH-1928 proof signs in with the app key alone" {
    const a = std.testing.allocator;
    const args = try proofArgs(a, "C:\\k\\multibot_ed25519", "deploy", "example.invalid", 2222);
    defer a.free(args);
    try std.testing.expectEqualStrings("-F none -n -i \"C:\\k\\multibot_ed25519\" -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -p 2222 deploy@example.invalid true", args);
    try std.testing.expectError(error.InvalidHosts, proofArgs(a, "C:\\k", "deploy", "bad host", 22));
}

test "IGSH-1928 add form, failure words and paste line" {
    const draft = parseDraft(" example.invalid ", "deploy", "") orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u16, 22), draft.port);
    try std.testing.expect(parseDraft("example.invalid", "deploy", "0") == null);
    try std.testing.expect(parseDraft("example.invalid", "", "22") == null);
    try std.testing.expect(parseDraft("bad host", "deploy", "22") == null);
    try std.testing.expectEqualStrings("the key is not on the server yet", failureReason("deploy@example.invalid: Permission denied (publickey)."));
    try std.testing.expectEqualStrings("server not reachable", failureReason("ssh: connect to host example.invalid port 22: Connection timed out"));
    try std.testing.expectEqualStrings("could not sign in", failureReason(""));
    const a = std.testing.allocator;
    const line = try pasteLine(a, fake_key);
    defer a.free(line);
    try std.testing.expect(std.mem.indexOf(u8, line, fake_key) != null);
    try std.testing.expect(std.mem.indexOf(u8, line, "authorized_keys") != null);
    var buf: [128]u8 = undefined;
    var failed: Slot = .{ .status = .failed };
    failed.reason.set("address not found");
    try std.testing.expectEqualStrings("Failed: address not found", statusText(&buf, failed, false));
    try std.testing.expectEqualStrings("Needs setup", statusText(&buf, .{ .status = .needs_setup }, false));
    try std.testing.expectEqualStrings("Connected", statusText(&buf, .{ .status = .connected }, false));
}

test "IGSH-1928 free slot skips listed servers" {
    var table: Table = @splat(.{});
    table[0].status = .connected;
    table[1].status = .removed;
    try std.testing.expectEqual(@as(?usize, 1), freeSlot(&table));
    table[1].status = .needs_setup;
    table[2].status = .failed;
    try std.testing.expectEqual(@as(?usize, null), freeSlot(&table));
}
