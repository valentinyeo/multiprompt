const std = @import("std");
const tmux_identity = @import("tmux_identity.zig");
const Allocator = std.mem.Allocator;

pub const max_bytes = 1024 * 1024;
pub const Workspace = struct { name: []const u8 };
pub const Tab = struct {
    kind: []const u8 = "tmux",
    name: []const u8,
    manual: bool = false,
    tmux_session: []const u8,
    tmux_host: u8,
    workspace: []const u8,
};
pub const Layout = struct {
    schema: u32 = 1,
    revision: u64 = 0,
    workspaces: []const Workspace,
    tabs: []const Tab,
};

pub fn sameTab(a: Tab, b: Tab) bool {
    return tmux_identity.same(a.tmux_host, a.tmux_session, b.tmux_host, b.tmux_session);
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
    for (layout.workspaces, 0..) |ws, i| {
        if (ws.name.len > 32 or !validText(ws.name, 32)) return error.InvalidLayout;
        for (layout.workspaces[0..i]) |old| if (std.mem.eql(u8, old.name, ws.name)) return error.InvalidLayout;
    }
    for (layout.tabs, 0..) |tab, i| {
        if (!std.mem.eql(u8, tab.kind, "tmux") or tab.tmux_host > 2 or !validText(tab.name, 64) or
            tab.tmux_session.len == 0 or tab.tmux_session.len > 63) return error.InvalidLayout;
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
    return parsed;
}

pub fn encode(a: Allocator, layout: Layout) ![]u8 {
    try validate(layout);
    const json = try std.json.Stringify.valueAlloc(a, layout, .{});
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
            old.* = tab;
            found = true;
            break;
        };
        if (!found) try tabs.append(a, tab);
    }
    if (workspaces.items.len > max_workspaces or tabs.items.len > max_tabs) return error.LayoutCapacity;
    const ws = try workspaces.toOwnedSlice(a);
    errdefer a.free(ws);
    return .{ .revision = server.revision, .workspaces = ws, .tabs = try tabs.toOwnedSlice(a) };
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
