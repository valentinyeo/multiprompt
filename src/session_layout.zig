const std = @import("std");
const tmux_identity = @import("tmux_identity.zig");
const Allocator = std.mem.Allocator;

pub const max_bytes = 1024 * 1024;
pub const Host = @import("account_hosts.zig").Host;
pub const Workspace = struct { name: []const u8 };
pub const Tab = struct {
    kind: []const u8 = "tmux",
    name: []const u8,
    manual: bool = false,
    favorite: ?bool = null,
    used: ?u64 = null,
    input: ?u64 = null,
    visits: ?[]const u64 = null,
    tmux_session: []const u8,
    tmux_host: u8,
    workspace: []const u8,
};
pub const Settings = @import("frequent.zig").Settings;
pub const Layout = struct {
    settings: ?Settings = null,
    schema: u32 = 1,
    revision: u64 = 0,
    workspaces: []const Workspace,
    tabs: []const Tab,
    hosts: ?[]const Host = null,
};

pub fn sameTab(a: Tab, b: Tab) bool {
    return tmux_identity.same(a.tmux_host, a.tmux_session, b.tmux_host, b.tmux_session);
}

pub fn maxUsed(a: ?u64, b: ?u64) ?u64 {
    if (a == null) return b;
    if (b == null) return a;
    return @max(a.?, b.?);
}

pub fn mergeVisits(a: Allocator, left: ?[]const u64, right: ?[]const u64) !?[]const u64 {
    const merged = @import("frequent.zig").Visits.merge(left, right);
    return if (merged.optional()) |values| try a.dupe(u64, values) else null;
}

fn validText(text: []const u8, max_units: usize) bool {
    if (text.len == 0 or !std.unicode.utf8ValidateSlice(text)) return false;
    for (text) |c| if (c < 32 or c == 127) return false;
    var wide: [64]u16 = undefined;
    const n = std.unicode.utf8ToUtf16Le(&wide, text) catch return false;
    return n <= max_units;
}

pub fn validate(layout: Layout) !void {
    if (layout.schema != 1 or layout.workspaces.len > 64 or layout.tabs.len > 4096) return error.InvalidLayout;
    if (layout.hosts) |hosts| try @import("account_hosts.zig").validate(hosts);
    for (layout.workspaces, 0..) |ws, i| {
        if (ws.name.len > 32 or !validText(ws.name, 32)) return error.InvalidLayout;
        for (layout.workspaces[0..i]) |old| if (std.mem.eql(u8, old.name, ws.name)) return error.InvalidLayout;
    }
    for (layout.tabs, 0..) |tab, i| {
        if (!std.mem.eql(u8, tab.kind, "tmux") or tab.tmux_host > 2 or !validText(tab.name, 64) or
            tab.tmux_session.len == 0 or tab.tmux_session.len > 63) return error.InvalidLayout;
        if (tab.used) |used| if (used > 9_007_199_254_740_991) return error.InvalidLayout;
        if (tab.input) |input| if (input > 9_007_199_254_740_991) return error.InvalidLayout;
        if (tab.visits) |visits| {
            if (visits.len > 8) return error.InvalidLayout;
            for (visits, 0..) |v, j| if (v > 9_007_199_254_740_991 or (j > 0 and v <= visits[j - 1])) return error.InvalidLayout;
        }
        for (tab.tmux_session) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') return error.InvalidLayout;
        }
        var found = false;
        for (layout.workspaces) |ws| {
            if (std.mem.eql(u8, ws.name, tab.workspace)) found = true;
        }
        if (!found) return error.InvalidLayout;
        for (layout.tabs[0..i]) |old| if (sameTab(old, tab)) return error.InvalidLayout;
    }
}

pub fn parse(a: Allocator, json: []const u8) !std.json.Parsed(Layout) {
    if (json.len == 0 or json.len >= max_bytes) return error.InvalidLayout;
    const parsed = try std.json.parseFromSlice(Layout, a, json, .{ .allocate = .alloc_always });
    errdefer parsed.deinit();
    try validate(parsed.value);
    if (parsed.value.settings == null) {
        const value = try std.json.parseFromSlice(std.json.Value, a, json, .{});
        defer value.deinit();
        if (value.value.object.contains("settings")) return error.InvalidLayout;
    }
    return parsed;
}

pub fn encode(a: Allocator, layout: Layout) ![]u8 {
    try validate(layout);
    const json = try std.json.Stringify.valueAlloc(a, layout, .{ .emit_null_optional_fields = false });
    if (json.len >= max_bytes) {
        a.free(json);
        return error.InvalidLayout;
    }
    return json;
}

pub fn merge(a: Allocator, local: Layout, server: Layout, max_workspaces: usize, max_tabs: usize) !Layout {
    try validate(server);
    var workspaces: std.ArrayList(Workspace) = .empty;
    defer workspaces.deinit(a);
    var tabs: std.ArrayList(Tab) = .empty;
    defer tabs.deinit(a);
    try workspaces.appendSlice(a, local.workspaces);
    try tabs.appendSlice(a, local.tabs);
    for (server.workspaces) |ws| {
        var found = false;
        for (workspaces.items) |old| if (std.mem.eql(u8, old.name, ws.name)) {
            found = true;
            break;
        };
        if (!found) try workspaces.append(a, ws);
    }
    for (server.tabs) |tab| {
        var found = false;
        for (tabs.items) |*old| if (sameTab(old.*, tab)) {
            const favorite = old.favorite;
            const used = old.used;
            const input = old.input;
            const visits = old.visits;
            old.* = tab;
            if (tab.favorite == null) old.favorite = favorite;
            old.used = maxUsed(used, tab.used);
            old.input = maxUsed(input, tab.input);
            old.visits = try mergeVisits(a, visits, tab.visits);
            found = true;
            break;
        };
        if (!found) try tabs.append(a, tab);
    }
    if (workspaces.items.len > max_workspaces or tabs.items.len > max_tabs) return error.LayoutCapacity;
    const ws = try workspaces.toOwnedSlice(a);
    errdefer a.free(ws);
    return .{ .settings = server.settings, .revision = server.revision, .hosts = server.hosts, .workspaces = ws, .tabs = try tabs.toOwnedSlice(a) };
}

fn freeMerge(a: Allocator, layout: Layout) void {
    a.free(layout.workspaces);
    a.free(layout.tabs);
}

const test_ws = [_]Workspace{.{ .name = "Other" }};
const test_tab = Tab{ .name = "local name", .tmux_session = "session-1", .tmux_host = 0, .workspace = "Other" };

test "merge renames and moves by host plus session without removing local tabs" {
    const local = Layout{ .workspaces = &test_ws, .tabs = &.{ test_tab, .{ .kind = "cmd", .name = "CMD", .tmux_session = "", .tmux_host = 0, .workspace = "Other" } } };
    var renamed = test_tab;
    renamed.name = "Kraków 🚀";
    renamed.workspace = "Product";
    const server = Layout{ .revision = 7, .workspaces = &.{.{ .name = "Product" }}, .tabs = &.{renamed} };
    const result = try merge(std.testing.allocator, local, server, 9, 256);
    defer freeMerge(std.testing.allocator, result);
    try std.testing.expectEqual(@as(u64, 7), result.revision);
    try std.testing.expectEqualStrings("Kraków 🚀", result.tabs[0].name);
    try std.testing.expectEqualStrings("Product", result.tabs[0].workspace);
    try std.testing.expectEqualStrings("CMD", result.tabs[1].name);
    try std.testing.expectEqualStrings("Other", result.workspaces[0].name);
    try std.testing.expectEqualStrings("Product", result.workspaces[1].name);
    try std.testing.expectEqualStrings("local name", local.tabs[0].name);
}

test "merge appends missing tabs in server order and separates all three hosts" {
    var uk = test_tab;
    uk.tmux_host = 1;
    var secondary = test_tab;
    secondary.tmux_host = 2;
    const local = Layout{ .workspaces = &test_ws, .tabs = &.{test_tab} };
    const server = Layout{ .workspaces = &test_ws, .tabs = &.{ secondary, uk, test_tab } };
    const result = try merge(std.testing.allocator, local, server, 9, 256);
    defer freeMerge(std.testing.allocator, result);
    try std.testing.expectEqual(@as(usize, 3), result.tabs.len);
    try std.testing.expectEqual(@as(u8, 0), result.tabs[0].tmux_host);
    try std.testing.expectEqual(@as(u8, 2), result.tabs[1].tmux_host);
    try std.testing.expectEqual(@as(u8, 1), result.tabs[2].tmux_host);
}

test "merge is idempotent and keeps unrelated local remote tabs" {
    var other = test_tab;
    other.tmux_session = "session-2";
    const local = Layout{ .workspaces = &test_ws, .tabs = &.{ test_tab, other } };
    const server = Layout{ .workspaces = &test_ws, .tabs = &.{test_tab} };
    const once = try merge(std.testing.allocator, local, server, 9, 256);
    defer freeMerge(std.testing.allocator, once);
    const twice = try merge(std.testing.allocator, once, server, 9, 256);
    defer freeMerge(std.testing.allocator, twice);
    try std.testing.expectEqual(@as(usize, 2), twice.tabs.len);
    try std.testing.expectEqual(@as(usize, 1), twice.workspaces.len);
    try std.testing.expectEqualStrings("session-2", twice.tabs[1].tmux_session);
}

test "empty server preserves layout and empty server workspaces are imported" {
    const local = Layout{ .workspaces = &test_ws, .tabs = &.{test_tab} };
    const empty = try merge(std.testing.allocator, local, .{ .workspaces = &.{}, .tabs = &.{} }, 9, 256);
    defer freeMerge(std.testing.allocator, empty);
    try std.testing.expectEqual(@as(usize, 1), empty.tabs.len);
    const named = try merge(std.testing.allocator, local, .{ .workspaces = &.{.{ .name = "Empty" }}, .tabs = &.{} }, 9, 256);
    defer freeMerge(std.testing.allocator, named);
    try std.testing.expectEqual(@as(usize, 2), named.workspaces.len);
}

test "workspace name matching is exact not index based" {
    const local = Layout{ .workspaces = &.{ .{ .name = "Other" }, .{ .name = "other" } }, .tabs = &.{test_tab} };
    const server = Layout{ .workspaces = &test_ws, .tabs = &.{test_tab} };
    const result = try merge(std.testing.allocator, local, server, 9, 256);
    defer freeMerge(std.testing.allocator, result);
    try std.testing.expectEqual(@as(usize, 2), result.workspaces.len);
}

test "capacity failure is all or nothing" {
    const local = Layout{ .workspaces = &test_ws, .tabs = &.{test_tab} };
    var other = test_tab;
    other.tmux_host = 1;
    try std.testing.expectError(error.LayoutCapacity, merge(std.testing.allocator, local, .{ .workspaces = &test_ws, .tabs = &.{other} }, 9, 1));
    try std.testing.expectError(error.LayoutCapacity, merge(std.testing.allocator, local, .{ .workspaces = &.{.{ .name = "New" }}, .tabs = &.{} }, 1, 256));
    try std.testing.expectEqualStrings("local name", local.tabs[0].name);
}

test "parser rejects malformed schema identities and runtime fields" {
    for ([_][]const u8{
        "{}",                                          "{\"schema\":2,\"workspaces\":[],\"tabs\":[]}",
        "{\"workspaces\":[],\"tabs\":[],\"pid\":123}", "{\"workspaces\":[{\"name\":\"Other\"}],\"tabs\":[{\"name\":\"bad\",\"tmux_session\":\"x';touch pwn\",\"tmux_host\":0,\"workspace\":\"Other\"}]}",
    }) |json| {
        if (parse(std.testing.allocator, json)) |parsed| {
            parsed.deinit();
            return error.ExpectedRejection;
        } else |_| {}
    }
    var bad = test_tab;
    bad.tmux_host = 3;
    try std.testing.expectError(error.InvalidLayout, validate(.{ .workspaces = &test_ws, .tabs = &.{bad} }));
    bad = test_tab;
    bad.workspace = "Missing";
    try std.testing.expectError(error.InvalidLayout, validate(.{ .workspaces = &test_ws, .tabs = &.{bad} }));
    try std.testing.expectError(error.InvalidLayout, validate(.{ .workspaces = &test_ws, .tabs = &.{ test_tab, test_tab } }));
    try std.testing.expectError(error.InvalidLayout, validate(.{ .workspaces = &.{ test_ws[0], test_ws[0] }, .tabs = &.{} }));
}

test "portable JSON round trips Unicode with only allowlisted fields" {
    var tab = test_tab;
    tab.name = "quote \" slash \\ Kraków 🚀";
    const json = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{tab} });
    defer std.testing.allocator.free(json);
    const parsed = try parse(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings(tab.name, parsed.value.tabs[0].name);
    try std.testing.expect(std.mem.indexOf(u8, json, "pid") == null);
}

test "legacy names default automatic and explicit manual naming round trips" {
    const old = try parse(std.testing.allocator, "{\"workspaces\":[{\"name\":\"Other\"}],\"tabs\":[{\"name\":\"Agent\",\"tmux_session\":\"one\",\"tmux_host\":0,\"workspace\":\"Other\"}]}");
    defer old.deinit();
    try std.testing.expect(!old.value.tabs[0].manual);
    var tab = test_tab;
    tab.manual = true;
    const json = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{tab} });
    defer std.testing.allocator.free(json);
    const p = try parse(std.testing.allocator, json);
    defer p.deinit();
    try std.testing.expect(p.value.tabs[0].manual);
}

test "case variants identify the same tmux session but hosts remain distinct" {
    var upper = test_tab;
    upper.tmux_session = "SESSION-1";
    try std.testing.expect(sameTab(test_tab, upper));
    try std.testing.expectError(error.InvalidLayout, validate(.{ .workspaces = &test_ws, .tabs = &.{ test_tab, upper } }));
    upper.tmux_host = 1;
    try std.testing.expect(!sameTab(test_tab, upper));
}

test "favorite merge preserves unknown and applies explicit true and false" {
    var local = test_tab;
    local.favorite = true;
    for ([_]?bool{ null, true, false }) |favorite| {
        var remote = test_tab;
        remote.tmux_session = "SESSION-1";
        remote.favorite = favorite;
        const result = try merge(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{local} }, .{ .workspaces = &test_ws, .tabs = &.{remote} }, 9, 256);
        defer freeMerge(std.testing.allocator, result);
        try std.testing.expectEqual(favorite orelse true, result.tabs[0].favorite.?);
    }
    local.favorite = false;
    var remote = test_tab;
    remote.favorite = true;
    const starred = try merge(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{local} }, .{ .workspaces = &test_ws, .tabs = &.{remote} }, 9, 256);
    defer freeMerge(std.testing.allocator, starred);
    try std.testing.expectEqual(true, starred.tabs[0].favorite.?);
}

test "favorite encoding omits unknown and round trips explicit booleans" {
    for ([_]?bool{ null, true, false }) |favorite| {
        var tab = test_tab;
        tab.favorite = favorite;
        const json = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{tab} });
        defer std.testing.allocator.free(json);
        try std.testing.expectEqual(favorite != null, std.mem.indexOf(u8, json, "\"favorite\"") != null);
        const parsed = try parse(std.testing.allocator, json);
        defer parsed.deinit();
        try std.testing.expectEqual(favorite, parsed.value.tabs[0].favorite);
    }
    const legacy = try parse(std.testing.allocator, "{\"workspaces\":[{\"name\":\"Other\"}],\"tabs\":[{\"name\":\"One\",\"tmux_session\":\"one\",\"tmux_host\":0,\"workspace\":\"Other\"}]}");
    defer legacy.deinit();
    try std.testing.expectEqual(@as(?bool, null), legacy.value.tabs[0].favorite);
}

test "used merge never loses or lowers known time" {
    for ([_]?u64{ null, 0, 1000, 3000 }) |local_used| for ([_]?u64{ null, 0, 2000, 4000 }) |remote_used| {
        var local = test_tab;
        local.used = local_used;
        var remote = test_tab;
        remote.tmux_session = "SESSION-1";
        remote.used = remote_used;
        const result = try merge(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{local} }, .{ .workspaces = &test_ws, .tabs = &.{remote} }, 9, 256);
        defer freeMerge(std.testing.allocator, result);
        try std.testing.expectEqual(if (local_used == null and remote_used == null) @as(?u64, null) else @as(?u64, @max(local_used orelse 0, remote_used orelse 0)), result.tabs[0].used);
    };
}

test "used encoding omits unknown and round trips safe integers" {
    for ([_]?u64{ null, 0, 1, 9_007_199_254_740_991 }) |used| {
        var tab = test_tab;
        tab.used = used;
        const json = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{tab} });
        defer std.testing.allocator.free(json);
        try std.testing.expectEqual(used != null, std.mem.indexOf(u8, json, "\"used\"") != null);
        const parsed = try parse(std.testing.allocator, json);
        defer parsed.deinit();
        try std.testing.expectEqual(used, parsed.value.tabs[0].used);
    }
    var invalid = test_tab;
    invalid.used = 9_007_199_254_740_992;
    try std.testing.expectError(error.InvalidLayout, encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{invalid} }));
}

test "visits merge union dedupe cap eight never drops and encoding round trip" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]?[]const u64{ null, &.{}, &.{ 0, 1, 3 }, &.{ 1, 2, 3, 4, 5, 6, 7, 8 } }) |left| {
        for ([_]?[]const u64{ null, &.{}, &.{ 2, 3, 9 }, &.{ 3, 4, 5, 6, 7, 8, 9, 10 } }) |right| {
            var local = test_tab;
            local.visits = left;
            var remote = test_tab;
            remote.tmux_session = "SESSION-1";
            remote.visits = right;
            const merged = try merge(a, .{ .workspaces = &test_ws, .tabs = &.{local} }, .{ .workspaces = &test_ws, .tabs = &.{remote} }, 9, 256);
            var union_values: std.ArrayList(u64) = .empty;
            for (left orelse &.{}) |v| try union_values.append(a, v);
            for (right orelse &.{}) |v| {
                if (std.mem.indexOfScalar(u64, union_values.items, v) == null) try union_values.append(a, v);
            }
            std.mem.sort(u64, union_values.items, {}, std.sort.asc(u64));
            const expected = union_values.items[union_values.items.len -| 8..];
            try std.testing.expectEqualSlices(u64, expected, merged.tabs[0].visits orelse &.{});
            try std.testing.expectEqual(left != null or right != null, merged.tabs[0].visits != null);
            const json = try encode(a, merged);
            const parsed = try parse(a, json);
            defer parsed.deinit();
            try std.testing.expectEqualSlices(u64, expected, parsed.value.tabs[0].visits orelse &.{});
            const again = try merge(a, merged, .{ .workspaces = &test_ws, .tabs = &.{test_tab} }, 9, 256);
            try std.testing.expectEqualSlices(u64, expected, again.tabs[0].visits orelse &.{});
        }
    }
    for ([_][]const u64{ &.{ 2, 1 }, &.{ 1, 1 }, &.{9_007_199_254_740_992}, &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8 } }) |invalid| {
        var tab = test_tab;
        tab.visits = invalid;
        try std.testing.expectError(error.InvalidLayout, encode(a, .{ .workspaces = &test_ws, .tabs = &.{tab} }));
    }
}

test "v2 shared fixture input and watch-only order beta alpha gamma" {
    const frequent = @import("frequent.zig");
    const Fixture = struct { now: u64, layout: Layout, expected: []const []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, std.testing.allocator, @embedFile("fixtures/issue-415-frequent.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    try validate(fixture.layout);
    var rows: [6]Tab = undefined;
    var count: usize = 0;
    for (fixture.layout.tabs) |tab| {
        if (!frequent.inFrequent(tab.visits orelse &.{}, fixture.now, tab.input)) continue;
        rows[count] = tab;
        count += 1;
    }
    std.mem.sort(Tab, rows[0..count], {}, struct {
        fn less(_: void, a: Tab, b: Tab) bool {
            return frequent.bottomOrder(frequent.orderKey(a.visits orelse &.{}, 1_800_000_000_000, a.input), frequent.orderKey(b.visits orelse &.{}, 1_800_000_000_000, b.input));
        }
    }.less);
    try std.testing.expectEqual(fixture.expected.len, count);
    var bottom: []const u8 = "";
    for (rows[0..count], fixture.expected) |row, name| {
        try std.testing.expectEqualStrings(name, row.name);
        bottom = row.name;
    }
    try std.testing.expectEqualStrings("gamma", bottom);
}

test "input merge never loses or lowers known time" {
    for ([_]?u64{ null, 0, 1000, 3000 }) |local_input| for ([_]?u64{ null, 0, 2000, 4000 }) |remote_input| {
        var local = test_tab;
        local.input = local_input;
        var remote = test_tab;
        remote.tmux_session = "SESSION-1";
        remote.input = remote_input;
        const result = try merge(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{local} }, .{ .workspaces = &test_ws, .tabs = &.{remote} }, 9, 256);
        defer freeMerge(std.testing.allocator, result);
        try std.testing.expectEqual(if (local_input == null and remote_input == null) @as(?u64, null) else @as(?u64, @max(local_input orelse 0, remote_input orelse 0)), result.tabs[0].input);
    };
}

test "input encoding omits unknown and round trips safe integers" {
    for ([_]?u64{ null, 0, 1, 9_007_199_254_740_991 }) |input| {
        var tab = test_tab;
        tab.input = input;
        const json = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{tab} });
        defer std.testing.allocator.free(json);
        try std.testing.expectEqual(input != null, std.mem.indexOf(u8, json, "\"input\"") != null);
        const parsed = try parse(std.testing.allocator, json);
        defer parsed.deinit();
        try std.testing.expectEqual(input, parsed.value.tabs[0].input);
    }
    var invalid = test_tab;
    invalid.input = 9_007_199_254_740_992;
    try std.testing.expectError(error.InvalidLayout, encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{invalid} }));
}

test "hosts portable round trip validates hosts and rejects private fields" {
    const host = Host{ .slot = 0, .name = "Host 1", .hostname = "203.0.113.5", .port = 22, .user = "owner", .host_keys = &.{"ssh-ed25519 AAAA=="} };
    const json = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{test_tab}, .hosts = &.{host} });
    defer std.testing.allocator.free(json);
    const parsed = try parse(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings(host.hostname, parsed.value.hosts.?[0].hostname);
    try std.testing.expectEqualStrings(host.host_keys.?[0], parsed.value.hosts.?[0].host_keys.?[0]);
    const extra = "{\"workspaces\":[],\"tabs\":[],\"hosts\":[{\"slot\":0,\"name\":\"Server\",\"hostname\":\"example.com\",\"port\":22,\"user\":\"root\",\"identity_file\":\"id_rsa\"}]}";
    try std.testing.expectError(error.UnknownField, parse(std.testing.allocator, extra));
    var bad = host;
    bad.host_keys = &.{"ssh-rsa PRIVATE KEY"};
    try std.testing.expectError(error.InvalidHosts, encode(std.testing.allocator, .{ .workspaces = &.{}, .tabs = &.{}, .hosts = &.{bad} }));
}

test "null hosts are omitted from layout JSON while an empty slice is explicit" {
    const without_hosts = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{test_tab}, .hosts = null });
    defer std.testing.allocator.free(without_hosts);
    const absent = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, without_hosts, .{});
    defer absent.deinit();
    try std.testing.expect(!absent.value.object.contains("hosts"));
    const with_hosts = try encode(std.testing.allocator, .{ .workspaces = &test_ws, .tabs = &.{test_tab}, .hosts = &.{} });
    defer std.testing.allocator.free(with_hosts);
    const present = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, with_hosts, .{});
    defer present.deinit();
    try std.testing.expectEqual(@as(usize, 0), present.value.object.get("hosts").?.array.items.len);
}

test "ISSUE-423 real layout parser preserves hosts, hides Frequent and defaults missing flags to true" {
    const frequent = @import("frequent.zig");
    const parsed = try parse(std.testing.allocator, "{\"schema\":1,\"workspaces\":[],\"tabs\":[],\"settings\":{\"frequent\":false},\"hosts\":[{\"slot\":0,\"name\":\"Host 1\",\"hostname\":\"example.com\",\"port\":22,\"user\":\"owner\"}]}");
    defer parsed.deinit();
    const splits = frequent.builtinSplits(parsed.value.settings orelse .{});
    try std.testing.expectEqualSlices(u32, &.{ frequent.all_split, frequent.favorites_split }, splits.slice());
    const settings = parsed.value.settings.?;
    try std.testing.expect(!settings.frequent and settings.favorites and settings.all and settings.frequent_first);
    const json = try encode(std.testing.allocator, parsed.value);
    defer std.testing.allocator.free(json);
    const again = try parse(std.testing.allocator, json);
    defer again.deinit();
    try std.testing.expectEqualDeep(parsed.value.settings, again.value.settings);
    try std.testing.expectEqualStrings("example.com", again.value.hosts.?[0].hostname);
    const merged = try merge(std.testing.allocator, parsed.value, again.value, 9, 256);
    defer freeMerge(std.testing.allocator, merged);
    try std.testing.expectEqualDeep(again.value.settings, merged.settings);
    try std.testing.expectEqualDeep(again.value.hosts, merged.hosts);
    for ([_][]const u8{ "{\"workspaces\":[],\"tabs\":[]}", "{\"workspaces\":[],\"tabs\":[],\"settings\":{}}" }) |raw| {
        const defaults = try parse(std.testing.allocator, raw);
        defer defaults.deinit();
        const order = frequent.builtinSplits(defaults.value.settings orelse .{});
        try std.testing.expectEqualSlices(u32, &.{ frequent.frequent_split, frequent.all_split, frequent.favorites_split }, order.slice());
    }
}

test "ISSUE-423 settings reject unknown keys and every nonboolean value through real parse" {
    for ([_][]const u8{ "null", "[]", "false", "0", "\"settings\"", "{\"extra\":true}", "{\"frequent\":false,\"extra\":false}", "{\"frequent\":true,\"frequent\":false}" }) |settings| {
        const raw = try std.fmt.allocPrint(std.testing.allocator, "{{\"workspaces\":[],\"tabs\":[],\"settings\":{s}}}", .{settings});
        defer std.testing.allocator.free(raw);
        if (parse(std.testing.allocator, raw)) |parsed| {
            parsed.deinit();
            return error.ExpectedRejection;
        } else |_| {}
    }
    inline for (std.meta.fields(Settings)) |field| {
        for ([_][]const u8{ "null", "0", "1", "\"false\"", "[]", "{}" }) |value| {
            const raw = try std.fmt.allocPrint(std.testing.allocator, "{{\"workspaces\":[],\"tabs\":[],\"settings\":{{\"{s}\":{s}}}}}", .{ field.name, value });
            defer std.testing.allocator.free(raw);
            if (parse(std.testing.allocator, raw)) |parsed| {
                parsed.deinit();
                return error.ExpectedRejection;
            } else |_| {}
        }
    }
}
