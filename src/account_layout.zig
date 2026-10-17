const std = @import("std");
const layout = @import("session_layout.zig");
pub const Layout = layout.Layout;
pub const Tab = layout.Tab;
const Allocator = std.mem.Allocator;
const eq = std.mem.eql;

pub fn find(tabs: []const Tab, tab: Tab) ?usize {
    for (tabs, 0..) |old, i| if (layout.sameTab(old, tab)) return i;
    return null;
}
fn workspaceIndex(workspaces: []const layout.Workspace, name: []const u8) ?usize {
    for (workspaces, 0..) |ws, i| if (eq(u8, ws.name, name)) return i;
    return null;
}
pub fn equal(a: Layout, b: Layout) bool {
    if (a.workspaces.len != b.workspaces.len or a.tabs.len != b.tabs.len) return false;
    for (a.workspaces, b.workspaces) |x, y| if (!eq(u8, x.name, y.name)) return false;
    for (a.tabs, b.tabs) |x, y| if (!layout.sameTab(x, y) or !eq(u8, x.name, y.name) or x.manual != y.manual or !eq(u8, x.workspace, y.workspace)) return false;
    return true;
}

pub fn apply(a: Allocator, local: Layout, owned: []const bool, remote: Layout, max_ws: usize, max_tabs: usize) !Layout {
    try layout.validate(remote);
    if (owned.len != local.tabs.len) return error.InvalidLayout;
    var ws: std.ArrayList(layout.Workspace) = .empty;
    var tabs: std.ArrayList(Tab) = .empty;
    try ws.appendSlice(a, remote.workspaces);
    try tabs.appendSlice(a, remote.tabs);
    for (local.tabs, owned) |tab, synced| {
        if (find(remote.tabs, tab) != null or (synced and tab.tmux_session.len > 0)) continue;
        if (workspaceIndex(ws.items, tab.workspace) == null) try ws.append(a, .{ .name = tab.workspace });
        try tabs.append(a, tab);
    }
    if (ws.items.len > max_ws or tabs.items.len > max_tabs) return error.LayoutCapacity;
    return .{ .revision = remote.revision, .workspaces = try ws.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a) };
}

pub fn keepHeld(a: Allocator, base: Layout, edited: Layout, closed: []const Tab) !Layout {
    var tabs: std.ArrayList(Tab) = .empty;
    try tabs.appendSlice(a, edited.tabs);
    var ws: std.ArrayList(layout.Workspace) = .empty;
    try ws.appendSlice(a, edited.workspaces);
    for (base.tabs, 0..) |t, i| {
        if (t.tmux_session.len == 0 or find(edited.tabs, t) != null or find(closed, t) != null) continue;
        try tabs.insert(a, @min(i, tabs.items.len), t);
        if (workspaceIndex(ws.items, t.workspace) == null) try ws.append(a, .{ .name = t.workspace });
    }
    return .{ .revision = edited.revision, .workspaces = try ws.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a) };
}

pub fn rebase(a: Allocator, base: Layout, edited: Layout, remote: Layout) !Layout {
    try layout.validate(base);
    try layout.validate(edited);
    try layout.validate(remote);
    var tabs: std.ArrayList(Tab) = .empty;
    var ws: std.ArrayList(layout.Workspace) = .empty;
    for (remote.workspaces) |w| {
        if (workspaceIndex(base.workspaces, w.name) != null and workspaceIndex(edited.workspaces, w.name) == null) continue;
        try ws.append(a, w);
    }
    for (edited.workspaces) |w| {
        if (workspaceIndex(base.workspaces, w.name) == null and workspaceIndex(ws.items, w.name) == null) try ws.append(a, w);
    }
    for (remote.tabs) |r| {
        var t = r;
        if (find(base.tabs, r)) |bi| {
            const ei = find(edited.tabs, r) orelse continue;
            if (!eq(u8, edited.tabs[ei].name, base.tabs[bi].name) or edited.tabs[ei].manual != base.tabs[bi].manual) {
                t.name = edited.tabs[ei].name;
                t.manual = edited.tabs[ei].manual;
            }
            if (!eq(u8, edited.tabs[ei].workspace, base.tabs[bi].workspace)) t.workspace = edited.tabs[ei].workspace;
        }
        try tabs.append(a, t);
    }
    for (edited.tabs) |t| {
        if (find(base.tabs, t) == null and find(tabs.items, t) == null) try tabs.append(a, t);
    }
    for (tabs.items) |t| if (workspaceIndex(ws.items, t.workspace) == null) try ws.append(a, .{ .name = t.workspace });
    var order_changed = base.tabs.len != edited.tabs.len;
    if (!order_changed) {
        order_changed = false;
        for (base.tabs, edited.tabs) |x, y| if (!layout.sameTab(x, y)) {
            order_changed = true;
            break;
        };
    }
    if (order_changed) {
        var dest: usize = 0;
        for (edited.tabs) |t| if (find(tabs.items, t)) |i| {
            std.mem.swap(Tab, &tabs.items[dest], &tabs.items[i]);
            dest += 1;
        };
    }
    var ws_order_changed = base.workspaces.len != edited.workspaces.len;
    if (!ws_order_changed) {
        ws_order_changed = false;
        for (base.workspaces, edited.workspaces) |x, y| if (!eq(u8, x.name, y.name)) {
            ws_order_changed = true;
            break;
        };
    }
    if (ws_order_changed) {
        var dest: usize = 0;
        for (edited.workspaces) |w| if (workspaceIndex(ws.items, w.name)) |i| {
            std.mem.swap(layout.Workspace, &ws.items[dest], &ws.items[i]);
            dest += 1;
        };
    }
    const result = Layout{ .revision = remote.revision, .workspaces = try ws.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a) };
    try layout.validate(result);
    return result;
}

pub fn prepareCache(a: Allocator, cache: []const u8, remote: Layout) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, a, cache, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    var root = parsed.value;
    if (root != .object) return error.InvalidLayout;
    const old = root.object.get("tabs") orelse std.json.Value{ .array = .init(a) };
    if (old != .array) return error.InvalidLayout;
    var ws: std.ArrayList(layout.Workspace) = .empty;
    try ws.appendSlice(a, remote.workspaces);
    var records: std.array_list.Managed(std.json.Value) = .init(a);
    const old_ws = root.object.get("workspaces");
    for (remote.tabs) |t| {
        var record: std.json.Value = .{ .object = .empty };
        for (old.array.items) |r| {
            if (r != .object) continue;
            const session = r.object.get("tmux_session") orelse continue;
            const host = r.object.get("tmux_host") orelse std.json.Value{ .integer = 0 };
            if (session == .string and host == .integer and host.integer == t.tmux_host and std.ascii.eqlIgnoreCase(session.string, t.tmux_session)) {
                record = r;
                break;
            }
        }
        var normalized: std.json.Value = .{ .object = .empty };
        try normalized.object.put(a, "kind", .{ .string = "tmux" });
        try normalized.object.put(a, "name", .{ .string = t.name });
        var iter = record.object.iterator();
        while (iter.next()) |field| {
            if (eq(u8, field.key_ptr.*, "kind") or eq(u8, field.key_ptr.*, "name")) continue;
            try normalized.object.put(a, field.key_ptr.*, field.value_ptr.*);
        }
        try normalized.object.put(a, "tmux_session", .{ .string = t.tmux_session });
        try normalized.object.put(a, "tmux_host", .{ .integer = t.tmux_host });
        try normalized.object.put(a, "workspace", .{ .integer = @intCast(workspaceIndex(ws.items, t.workspace).?) });
        try normalized.object.put(a, "manual", .{ .bool = t.manual });
        try normalized.object.put(a, "sync_owned", .{ .bool = true });
        try records.append(normalized);
    }
    for (old.array.items) |r| {
        if (r != .object) return error.InvalidLayout;
        const session = r.object.get("tmux_session");
        const host = r.object.get("tmux_host") orelse std.json.Value{ .integer = 0 };
        const owned = r.object.get("sync_owned");
        if (session) |s| {
            if (s == .string and s.string.len > 0) {
                var found = false;
                for (remote.tabs) |t| if (host == .integer and host.integer == t.tmux_host and std.ascii.eqlIgnoreCase(t.tmux_session, s.string)) {
                    found = true;
                    break;
                };
                if (found or (owned != null and owned.? == .bool and owned.?.bool)) continue;
            }
        }
        var local = r;
        var name: []const u8 = "Other";
        if (r.object.get("workspace")) |index| {
            if (index == .integer and index.integer >= 0) {
                if (old_ws) |workspaces| {
                    if (workspaces == .array and index.integer < workspaces.array.items.len) {
                        const w = workspaces.array.items[@intCast(index.integer)];
                        if (w == .object) if (w.object.get("name")) |n| {
                            if (n == .string) name = n.string;
                        };
                    }
                }
            }
        }
        if (workspaceIndex(ws.items, name) == null) try ws.append(a, .{ .name = name });
        try local.object.put(a, "workspace", .{ .integer = @intCast(workspaceIndex(ws.items, name).?) });
        try records.append(local);
    }
    if (ws.items.len > 9 or records.items.len > 256) return error.LayoutCapacity;
    var workspaces: std.array_list.Managed(std.json.Value) = .init(a);
    for (ws.items) |w| {
        var value: std.json.Value = .{ .object = .empty };
        if (old_ws) |previous| {
            if (previous == .array) for (previous.array.items) |old_workspace| {
                if (old_workspace != .object) continue;
                const old_name = old_workspace.object.get("name") orelse continue;
                if (old_name == .string and eq(u8, old_name.string, w.name)) {
                    value = old_workspace;
                    break;
                }
            };
        }
        try value.object.put(a, "name", .{ .string = w.name });
        try workspaces.append(value);
    }
    try root.object.put(a, "tabs", .{ .array = records });
    try root.object.put(a, "workspaces", .{ .array = workspaces });
    try root.object.put(a, "workspace_count", .{ .integer = @intCast(ws.items.len) });
    try root.object.put(a, "single_window", .{ .bool = true });
    try root.object.put(a, "active_workspace", .{ .integer = 0 });
    return std.json.Stringify.valueAlloc(a, root, .{ .emit_null_optional_fields = false });
}

pub fn restoreCache(a: Allocator, cache: ?[]const u8, remote: Layout) !?[]u8 {
    const empty = "{\"tabs\":[],\"hide_pills\":false}";
    return prepareCache(a, cache orelse empty, remote) catch |err| switch (err) {
        error.LayoutCapacity => null,
        error.OutOfMemory => error.OutOfMemory,
        else => try prepareCache(a, empty, remote),
    };
}

const test_ws = [_]layout.Workspace{.{ .name = "Other" }};
const one = Tab{ .name = "One", .tmux_host = 0, .tmux_session = "one", .workspace = "Other" };
const two = Tab{ .name = "Two", .tmux_host = 1, .tmux_session = "two", .workspace = "Other" };
const initial = Layout{ .workspaces = &test_ws, .tabs = &.{ one, two } };

test "apply removes only sync-owned tmux and keeps local CMD and unsynced attachments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const cmd = Tab{ .kind = "cmd", .name = "CMD", .tmux_host = 0, .tmux_session = "", .workspace = "Local" };
    const result = try apply(arena.allocator(), .{ .workspaces = &test_ws, .tabs = &.{ one, two, cmd } }, &.{ true, false, true }, .{ .workspaces = &test_ws, .tabs = &.{} }, 9, 256);
    try std.testing.expectEqual(@as(usize, 2), result.tabs.len);
    try std.testing.expectEqualStrings("two", result.tabs[0].tmux_session);
    try std.testing.expectEqualStrings("cmd", result.tabs[1].kind);
    try std.testing.expectError(error.LayoutCapacity, apply(arena.allocator(), initial, &.{ false, false }, .{ .workspaces = &test_ws, .tabs = &.{} }, 9, 1));
}
test "apply uses server ordering names and membership without mutating local" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var renamed = one;
    renamed.name = "Kraków 🚀";
    renamed.workspace = "Product";
    const result = try apply(arena.allocator(), initial, &.{ true, true }, .{ .workspaces = &.{ test_ws[0], .{ .name = "Product" } }, .tabs = &.{ two, renamed } }, 9, 256);
    try std.testing.expectEqualStrings("two", result.tabs[0].tmux_session);
    try std.testing.expectEqualStrings(renamed.name, result.tabs[1].name);
    try std.testing.expectEqualStrings("Product", result.tabs[1].workspace);
    try std.testing.expectEqualStrings("One", initial.tabs[0].name);
}
test "conflict rebases only changed fields and preserves unrelated remote tab and workspace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var local = one;
    local.name = "Renamed";
    var remote = one;
    remote.workspace = "Remote";
    var added = two;
    added.tmux_session = "three";
    const result = try rebase(arena.allocator(), initial, .{ .workspaces = &test_ws, .tabs = &.{ local, two } }, .{ .revision = 7, .workspaces = &.{ test_ws[0], .{ .name = "Remote" } }, .tabs = &.{ remote, two, added } });
    try std.testing.expectEqual(@as(u64, 7), result.revision);
    try std.testing.expectEqualStrings("Renamed", result.tabs[0].name);
    try std.testing.expectEqualStrings("Remote", result.tabs[0].workspace);
    try std.testing.expectEqual(@as(usize, 3), result.tabs.len);
}
test "stale rename cannot resurrect remote deletion; local deletion survives conflict" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var renamed = one;
    renamed.name = "Stale";
    const deleted = try rebase(arena.allocator(), initial, .{ .workspaces = &test_ws, .tabs = &.{ renamed, two } }, .{ .workspaces = &test_ws, .tabs = &.{two} });
    try std.testing.expectEqual(@as(usize, 1), deleted.tabs.len);
    const closed = try rebase(arena.allocator(), initial, .{ .workspaces = &test_ws, .tabs = &.{two} }, initial);
    try std.testing.expectEqual(@as(usize, 1), closed.tabs.len);
}
test "cache reconciliation runs before spawn and retains local runtime fields only on matches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const cache = "{\"tabs\":[{\"kind\":\"tmux\",\"name\":\"stale\",\"tmux_session\":\"gone\",\"sync_owned\":true},{\"kind\":\"cmd\",\"name\":\"Local\",\"pid\":123},{\"kind\":\"tmux\",\"name\":\"old\",\"tmux_session\":\"one\",\"pid\":456}],\"theme\":\"dark\"}";
    const bytes = try prepareCache(arena.allocator(), cache, .{ .workspaces = &test_ws, .tabs = &.{one} });
    const p = try std.json.parseFromSlice(std.json.Value, arena.allocator(), bytes, .{});
    defer p.deinit();
    const tabs = p.value.object.get("tabs").?.array.items;
    try std.testing.expectEqual(@as(usize, 2), tabs.len);
    try std.testing.expectEqual(@as(i64, 456), tabs[0].object.get("pid").?.integer);
    try std.testing.expect(tabs[0].object.get("sync_owned").?.bool);
    try std.testing.expectEqual(@as(i64, 123), tabs[1].object.get("pid").?.integer);
    try std.testing.expectEqualStrings("dark", p.value.object.get("theme").?.string);
}
test "unchanged revision and runtime do not create a portable write" {
    var later = initial;
    later.revision = 99;
    try std.testing.expect(equal(initial, later));
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const rebased = try rebase(arena.allocator(), initial, initial, later);
    try std.testing.expect(equal(later, rebased));
}

test "in-flight close and rename rebase after acknowledgement while new server tabs survive" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var renamed = one;
    renamed.name = "Typed while uploading";
    var added = two;
    added.tmux_session = "three";
    const result = try rebase(arena.allocator(), initial, .{ .workspaces = &test_ws, .tabs = &.{renamed} }, .{ .revision = 9, .workspaces = &test_ws, .tabs = &.{ one, two, added } });
    try std.testing.expectEqual(@as(usize, 2), result.tabs.len);
    try std.testing.expectEqualStrings(renamed.name, result.tabs[0].name);
    try std.testing.expectEqualStrings("three", result.tabs[1].tmux_session);
}
test "add and reorder together preserve intended order and existing workspace ids" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var added = one;
    added.tmux_session = "three";
    const result = try rebase(arena.allocator(), initial, .{ .workspaces = &test_ws, .tabs = &.{ two, added, one } }, initial);
    try std.testing.expectEqualStrings("two", result.tabs[0].tmux_session);
    try std.testing.expectEqualStrings("three", result.tabs[1].tmux_session);
    const bytes = try prepareCache(arena.allocator(), "{\"tabs\":[],\"workspaces\":[{\"name\":\"Other\",\"wid\":\"existing-id\"}]}", initial);
    const p = try std.json.parseFromSlice(std.json.Value, arena.allocator(), bytes, .{});
    defer p.deinit();
    try std.testing.expectEqualStrings("existing-id", p.value.object.get("workspaces").?.array.items[0].object.get("wid").?.string);
}

test "restore corruption falls back to server-only and capacity keeps untouched local cache" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]?[]const u8{ null, "broken JSON", "{\"tabs\":{}}" }) |bad| {
        const bytes = (try restoreCache(a, bad, initial)).?;
        const p = try std.json.parseFromSlice(std.json.Value, a, bytes, .{});
        defer p.deinit();
        try std.testing.expectEqual(@as(usize, 2), p.value.object.get("tabs").?.array.items.len);
    }
    var ws: [9]layout.Workspace = undefined;
    for (&ws, 0..) |*w, i| w.* = .{ .name = try std.fmt.allocPrint(a, "Cloud{d}", .{i}) };
    const local = "{\"tabs\":[{\"kind\":\"cmd\",\"name\":\"Keep me\",\"pid\":123}],\"workspaces\":[{\"name\":\"Local\"}]}";
    try std.testing.expectEqual(@as(?[]u8, null), try restoreCache(a, local, .{ .workspaces = &ws, .tabs = &.{} }));
    var tabs: [256]Tab = undefined;
    for (&tabs, 0..) |*tab, i| tab.* = .{ .name = "Tab", .tmux_host = 0, .tmux_session = try std.fmt.allocPrint(a, "session-{d}", .{i}), .workspace = "Other" };
    try std.testing.expectEqual(@as(?[]u8, null), try restoreCache(a, local, .{ .workspaces = &test_ws, .tabs = &tabs }));
    try std.testing.expect(std.mem.indexOf(u8, local, "123") != null);
}

test "automatic synced titles stay automatic and manual rename flag rebases even without name change" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var manual = one;
    manual.manual = true;
    try std.testing.expect(!equal(initial, .{ .workspaces = &test_ws, .tabs = &.{ manual, two } }));
    const result = try rebase(arena.allocator(), initial, .{ .workspaces = &test_ws, .tabs = &.{ manual, two } }, initial);
    try std.testing.expect(result.tabs[0].manual);
    const bytes = try prepareCache(arena.allocator(), "{\"tabs\":[]}", .{ .workspaces = &test_ws, .tabs = &.{ one, manualWithIdentity } });
    const p = try std.json.parseFromSlice(std.json.Value, arena.allocator(), bytes, .{});
    defer p.deinit();
    const tabs = p.value.object.get("tabs").?.array.items;
    try std.testing.expect(!tabs[0].object.get("manual").?.bool);
    try std.testing.expect(tabs[1].object.get("manual").?.bool);
}
const manualWithIdentity = Tab{ .name = "Manual", .manual = true, .tmux_host = 0, .tmux_session = "manual", .workspace = "Other" };

test "case-insensitive cloud matching reuses cached PID and never appends a placeholder duplicate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var upper = one;
    upper.tmux_session = "ONE";
    const desired = try apply(arena.allocator(), .{ .workspaces = &test_ws, .tabs = &.{upper} }, &.{false}, .{ .workspaces = &test_ws, .tabs = &.{one} }, 9, 256);
    try std.testing.expectEqual(@as(usize, 1), desired.tabs.len);
    const bytes = try prepareCache(arena.allocator(), "{\"tabs\":[{\"kind\":\"tmux\",\"name\":\"Upper\",\"tmux_session\":\"ONE\",\"pid\":456}]}", .{ .workspaces = &test_ws, .tabs = &.{one} });
    const p = try std.json.parseFromSlice(std.json.Value, arena.allocator(), bytes, .{});
    defer p.deinit();
    const tabs = p.value.object.get("tabs").?.array.items;
    try std.testing.expectEqual(@as(usize, 1), tabs.len);
    try std.testing.expectEqual(@as(i64, 456), tabs[0].object.get("pid").?.integer);
}

test "issue: secondary tab on host 0 that this device never closed survives a push" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const ws = [_]layout.Workspace{ .{ .name = "Example Product" }, .{ .name = "secondary" } };
    const runner = Tab{ .name = "Session 5", .tmux_host = 1, .tmux_session = "project-2", .workspace = "Example Product" };
    const secondary = Tab{ .name = "Meta Klaviyo Connection", .tmux_host = 0, .tmux_session = "remote-3", .workspace = "secondary" };
    const growth = Tab{ .name = "secondary Growth Bot MCP Setup", .tmux_host = 0, .tmux_session = "term-18e02d6b", .workspace = "secondary" };
    const base = Layout{ .workspaces = &ws, .tabs = &.{ runner, secondary, growth } };
    const missing = Layout{ .workspaces = &ws, .tabs = &.{ runner, growth } };
    const kept = try keepHeld(a, base, missing, &.{});
    try std.testing.expectEqual(@as(usize, 3), kept.tabs.len);
    try std.testing.expectEqualStrings("remote-3", kept.tabs[1].tmux_session);
    const pushed = try rebase(a, base, kept, base);
    try std.testing.expect(find(pushed.tabs, secondary) != null);
    const closed = try keepHeld(a, base, missing, &.{secondary});
    try std.testing.expect(find((try rebase(a, base, closed, base)).tabs, secondary) == null);
    var other_host = secondary;
    other_host.tmux_host = 2;
    try std.testing.expect(find(base.tabs, other_host) == null);
}
