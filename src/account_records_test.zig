const std = @import("std");
const records = @import("account_records.zig");
const layout = @import("session_layout.zig");
const Allocator = std.mem.Allocator;
const empty = layout.Layout{ .workspaces = &.{}, .tabs = &.{} };
const host = layout.Host{ .slot = 0, .name = "Host 1", .hostname = "one.example.com", .port = 22, .user = "owner" };
const tab = layout.Tab{ .name = "One", .tmux_session = "One", .tmux_host = 0, .workspace = "Work" };
const initial = layout.Layout{ .hosts = &.{host}, .workspaces = &.{.{ .name = "Work" }}, .tabs = &.{tab} };

const Server = struct {
    documents: []const records.Record = &.{},
    online: bool = true,
    bytes_sent: usize = 0,

    fn exchange(self: *Server, a: Allocator, incoming: []const records.Record) ![]const records.Record {
        if (!self.online) return error.Offline;
        const wire = try std.json.Stringify.valueAlloc(a, records.Documents{ .records = incoming }, .{ .emit_null_optional_fields = false });
        self.bytes_sent += wire.len;
        const parsed = try std.json.parseFromSlice(records.Documents, a, wire, .{ .allocate = .alloc_always });
        self.documents = try records.merge(a, self.documents, parsed.value.records);
        const readback = try std.json.Stringify.valueAlloc(a, records.Documents{ .records = self.documents }, .{ .emit_null_optional_fields = false });
        const get = try std.json.parseFromSlice(records.Documents, a, readback, .{ .allocate = .alloc_always });
        try records.roundTrip(a, incoming, get.value.records);
        return get.value.records;
    }
};
const Device = struct {
    id: []const u8,
    local: layout.Layout = empty,
    observed: layout.Layout = empty,
    documents: []const records.Record = &.{},
    secret: []const u8 = "device-only-password",
    window_x: i32 = 700,

    fn edit(self: *Device, a: Allocator, current: layout.Layout, now: u64) !void {
        self.documents = try records.edit(a, self.documents, self.observed, current, self.id, now);
        self.local = current;
        self.observed = current;
    }
    fn sync(self: *Device, a: Allocator, server: *Server) !void {
        const received = try server.exchange(a, self.documents);
        self.documents = try records.merge(a, self.documents, received);
        self.local = try records.materialize(a, self.documents);
        self.observed = self.local;
    }
};

test "ISSUE-252 two devices add edit delete workspace and session round trips" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var server: Server = .{};
    var first: Device = .{ .id = "a" };
    var second: Device = .{ .id = "b" };
    try first.edit(a, initial, 100);
    try first.sync(a, &server);
    try second.sync(a, &server);
    try std.testing.expectEqualStrings(host.hostname, second.local.hosts.?[0].hostname);
    try std.testing.expectEqualStrings("One", second.local.tabs[0].tmux_session);
    var changed = tab;
    changed.name = "Renamed";
    changed.favorite = true;
    try second.edit(a, .{ .hosts = initial.hosts, .workspaces = initial.workspaces, .tabs = &.{changed}, .settings = .{ .frequent = false } }, 200);
    try second.sync(a, &server);
    try first.sync(a, &server);
    try std.testing.expectEqualStrings("Renamed", first.local.tabs[0].name);
    try std.testing.expect(first.local.tabs[0].favorite.?);
    try std.testing.expect(!first.local.settings.?.frequent);
    try first.edit(a, empty, 300);
    try first.sync(a, &server);
    try second.sync(a, &server);
    try std.testing.expectEqual(@as(usize, 0), second.local.tabs.len);
    try std.testing.expectEqual(@as(usize, 0), second.local.workspaces.len);
    try std.testing.expectEqual(@as(usize, 0), second.local.hosts.?.len);
    for (server.documents) |doc| try std.testing.expect(doc.deleted);
}

test "ISSUE-252 both devices edit the same host LWW is per record and arrival independent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var server: Server = .{};
    var first: Device = .{ .id = "a" };
    var second: Device = .{ .id = "b" };
    try first.edit(a, initial, 100);
    try first.sync(a, &server);
    try second.sync(a, &server);
    var left = host;
    left.hostname = "left.example.com";
    var right = host;
    right.hostname = "right.example.com";
    try first.edit(a, .{ .hosts = &.{left}, .workspaces = initial.workspaces, .tabs = initial.tabs }, 200);
    var renamed = tab;
    renamed.name = "Independent edit";
    try second.edit(a, .{ .hosts = &.{right}, .workspaces = initial.workspaces, .tabs = &.{renamed} }, 200);
    const forward = try records.merge(a, first.documents, second.documents);
    const backward = try records.merge(a, second.documents, first.documents);
    const f = try std.json.Stringify.valueAlloc(a, forward, .{});
    const b = try std.json.Stringify.valueAlloc(a, backward, .{});
    try std.testing.expectEqualStrings(f, b);
    try first.sync(a, &server);
    try second.sync(a, &server);
    try first.sync(a, &server);
    try std.testing.expectEqualStrings("right.example.com", first.local.hosts.?[0].hostname);
    try std.testing.expectEqualStrings("Independent edit", first.local.tabs[0].name);
    const before = server.bytes_sent;
    try first.sync(a, &server);
    try std.testing.expect(server.bytes_sent > before);
    try std.testing.expectEqualStrings("right.example.com", first.local.hosts.?[0].hostname);
}

test "ISSUE-252 offline reconnect and process restart preserve edits and tombstones without resurrection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var server: Server = .{};
    var first: Device = .{ .id = "a" };
    var second: Device = .{ .id = "b" };
    try first.edit(a, initial, 100);
    try first.sync(a, &server);
    try second.sync(a, &server);
    server.online = false;
    var changed = host;
    changed.port = 2222;
    try first.edit(a, .{ .hosts = &.{changed}, .workspaces = initial.workspaces, .tabs = &.{} }, 200);
    const journal = try std.json.Stringify.valueAlloc(a, records.State{ .account = "account", .records = first.documents, .local = first.observed }, .{ .emit_null_optional_fields = false });
    try std.testing.expectError(error.Offline, first.sync(a, &server));
    try std.testing.expectEqual(@as(u16, 2222), first.local.hosts.?[0].port);
    const restored = try std.json.parseFromSlice(records.State, a, journal, .{ .allocate = .alloc_always });
    first.documents = restored.value.records;
    first.observed = restored.value.local;
    server.online = true;
    try first.sync(a, &server);
    try second.sync(a, &server);
    try std.testing.expectEqual(@as(u16, 2222), second.local.hosts.?[0].port);
    try std.testing.expectEqual(@as(usize, 0), second.local.tabs.len);
    const stale = try records.project(a, initial, "stale", 100);
    _ = try server.exchange(a, stale);
    try second.sync(a, &server);
    try std.testing.expectEqual(@as(usize, 0), second.local.tabs.len);
}

test "ISSUE-252 privacy allowlists reject secrets keys paths and window geometry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var keyed = host;
    keyed.host_keys = &.{"ssh-ed25519 AAAA=="};
    const projected = try records.project(a, .{ .hosts = &.{keyed}, .workspaces = initial.workspaces, .tabs = initial.tabs }, "device", 100);
    const wire = try std.json.Stringify.valueAlloc(a, records.Documents{ .records = projected }, .{ .emit_null_optional_fields = false });
    for ([_][]const u8{ "host_keys", "ssh-ed25519", "password", "IdentityFile", "window_x", "cwd" }) |secret| try std.testing.expect(std.mem.indexOf(u8, wire, secret) == null);
    const valid = "{\"kind\":\"host\",\"id\":\"0\",\"updated_at\":100,\"device_id\":\"a\",\"deleted\":false,\"host\":{\"slot\":0,\"name\":\"One\",\"hostname\":\"one.example.com\",\"port\":22,\"user\":\"owner\"}}";
    _ = try std.json.parseFromSlice(records.Record, a, valid, .{});
    for ([_][]const u8{ "password", "private_key", "host_keys", "IdentityFile", "cwd", "window_x", "window_y", "width", "height" }) |field| {
        const bad = try std.fmt.allocPrint(a, "{s},\"{s}\":\"device-only\"}}", .{ valid[0 .. valid.len - 1], field });
        try std.testing.expectError(error.UnknownField, std.json.parseFromSlice(records.Record, a, bad, .{}));
    }
    var server: Server = .{};
    var first: Device = .{ .id = "a", .secret = "first-secret", .window_x = 15 };
    var second: Device = .{ .id = "b", .secret = "second-secret", .window_x = 900 };
    try first.edit(a, initial, 100);
    try first.sync(a, &server);
    try second.sync(a, &server);
    try std.testing.expectEqualStrings("second-secret", second.secret);
    try std.testing.expectEqual(@as(i32, 900), second.window_x);
}

test "ISSUE-252 failed or altered readback cannot authorize local replacement" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sent = try records.project(a, initial, "a", 100);
    try std.testing.expectError(error.UnprovenRoundTrip, records.roundTrip(a, sent, &.{}));
    var altered = try a.dupe(records.Record, sent);
    altered[0].host.?.hostname = "altered.example.com";
    try std.testing.expectError(error.UnprovenRoundTrip, records.roundTrip(a, sent, altered));
    try records.roundTrip(a, sent, sent);
    const acknowledged = try records.edit(a, sent, empty, initial, "a", 200);
    for (acknowledged) |doc| try std.testing.expectEqual(@as(u64, 100), doc.updated_at);
}

test "ISSUE-252 host edits and deletes keep local identities passwords and unrelated SSH options" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const config = "Host remote-1\n HostName old.example.com\n User old\n Port 22\n IdentityFile device-key\n ProxyCommand device-proxy\nHost other\n HostName other.example.com\n";
    const next = try records.rewriteHost(a, config, "remote-1", .{ .slot = 0, .name = "Host 1", .hostname = "new.example.com", .port = 2222, .user = "owner" });
    try std.testing.expect(std.mem.indexOf(u8, next, "HostName new.example.com") != null);
    try std.testing.expect(std.mem.indexOf(u8, next, "HostName old.example.com") == null);
    for ([_][]const u8{ "IdentityFile device-key", "ProxyCommand device-proxy", "HostName other.example.com" }) |kept| try std.testing.expect(std.mem.indexOf(u8, next, kept) != null);
    const deleted = try records.rewriteHost(a, next, "remote-1", null);
    try std.testing.expect(std.mem.indexOf(u8, deleted, "HostName new.example.com") == null);
    try std.testing.expect(std.mem.indexOf(u8, deleted, "IdentityFile device-key") != null);
}

test "ISSUE-252 readback crash replay and idle polls do not restamp acknowledged remote changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const local = try records.project(a, initial, "a", 100);
    var changed = host;
    changed.hostname = "remote.example.com";
    const remote_layout = layout.Layout{ .hosts = &.{changed}, .workspaces = initial.workspaces, .tabs = initial.tabs };
    const remote = try records.edit(a, local, initial, remote_layout, "b", 200);
    const journal = records.State{ .account = "account", .local = initial, .records = remote };
    const replay = try records.edit(a, journal.records, journal.local, initial, "a", 300);
    try std.testing.expect(!try records.needsPush(a, replay, remote));
    const applied = try records.materialize(a, remote);
    const acknowledged = try records.edit(a, journal.records, journal.local, applied, "a", 400);
    try std.testing.expect(!try records.needsPush(a, acknowledged, remote));
    const materialized = try records.materialize(a, replay);
    try std.testing.expectEqualStrings("remote.example.com", materialized.hosts.?[0].hostname);
    try std.testing.expect(try records.needsPush(a, remote, local));
}

test "ISSUE-252 SSH rewrite overrides earlier wildcards without copying local options or growing empty blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const config = "IdentityFile device-key\nHost *\n Port 22\nHost remote-1\n HostName old.example.com\n User old\n ProxyCommand device-proxy\n";
    const remote = records.Host{ .slot = 0, .name = "Host 1", .hostname = "new.example.com", .port = 2222, .user = "owner" };
    const first = try records.rewriteHost(a, config, "remote-1", remote);
    try std.testing.expect(std.mem.startsWith(u8, first, "Host remote-1\n  HostName new.example.com\n  Port 2222\n  User owner\nHost *\nIdentityFile device-key"));
    const second = try records.rewriteHost(a, first, "remote-1", remote);
    try std.testing.expectEqualStrings(first, second);
    try std.testing.expect(std.mem.indexOf(u8, first, "ProxyCommand device-proxy") != null);
}
