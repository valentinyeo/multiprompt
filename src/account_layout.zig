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
    return equalWithin(a, b, 0);
}

pub fn publishNeeded(local: Layout, base: Layout, synced: Layout) bool {
    if (!equalWithin(local, base, std.math.maxInt(u64))) return true;
    for (local.tabs) |tab| {
        const known = if (find(synced.tabs, tab)) |i| synced.tabs[i].visits else null;
        if (!eq(u64, tab.visits orelse &.{}, known orelse &.{})) return true;
        const input = tab.input orelse 0;
        const synced_input = if (find(synced.tabs, tab)) |i| synced.tabs[i].input orelse 0 else 0;
        if (input > synced_input and (synced_input == 0 or input - synced_input > 60 * 1000)) return true;
        const used = tab.used orelse 0;
        const previous = if (find(synced.tabs, tab)) |i| synced.tabs[i].used orelse 0 else 0;
        if (used > previous and used - previous > 10 * 60 * 1000) return true;
    }
    return false;
}

fn equalWithin(a: Layout, b: Layout, used_slack: u64) bool {
    if (!std.meta.eql(a.settings orelse layout.Settings{}, b.settings orelse layout.Settings{})) return false;
    if (a.workspaces.len != b.workspaces.len or a.tabs.len != b.tabs.len) return false;
    for (a.workspaces, b.workspaces) |x, y| if (!eq(u8, x.name, y.name)) return false;
    for (a.tabs, b.tabs) |x, y| if (!layout.sameTab(x, y) or !eq(u8, x.name, y.name) or x.manual != y.manual or (x.favorite orelse false) != (y.favorite orelse false) or @max(x.used orelse 0, y.used orelse 0) - @min(x.used orelse 0, y.used orelse 0) > used_slack or @max(x.input orelse 0, y.input orelse 0) - @min(x.input orelse 0, y.input orelse 0) > used_slack or !eq(u64, x.visits orelse &.{}, y.visits orelse &.{}) or !eq(u8, x.workspace, y.workspace)) return false;
    return true;
}

pub fn apply(a: Allocator, local: Layout, owned: []const bool, remote: Layout, max_ws: usize, max_tabs: usize) !Layout {
    try layout.validate(remote);
    if (owned.len != local.tabs.len) return error.InvalidLayout;
    var ws: std.ArrayList(layout.Workspace) = .empty;
    var tabs: std.ArrayList(Tab) = .empty;
    try ws.appendSlice(a, remote.workspaces);
    try tabs.appendSlice(a, remote.tabs);
    for (tabs.items) |*tab| {
        if (find(local.tabs, tab.*)) |i| {
            if (tab.favorite == null) tab.favorite = local.tabs[i].favorite;
            tab.used = layout.maxUsed(tab.used, local.tabs[i].used);
            tab.input = layout.maxUsed(tab.input, local.tabs[i].input);
            tab.visits = try layout.mergeVisits(a, tab.visits, local.tabs[i].visits);
        }
    }
    for (local.tabs, owned) |tab, synced| {
        if (find(remote.tabs, tab) != null or (synced and tab.tmux_session.len > 0)) continue;
        if (workspaceIndex(ws.items, tab.workspace) == null) try ws.append(a, .{ .name = tab.workspace });
        try tabs.append(a, tab);
    }
    if (ws.items.len > max_ws or tabs.items.len > max_tabs) return error.LayoutCapacity;
    return .{ .settings = remote.settings, .revision = remote.revision, .hosts = remote.hosts, .workspaces = try ws.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a) };
}

pub fn keepHeld(a: Allocator, base: Layout, edited: Layout, closed: []const Tab) !Layout {
    var tabs: std.ArrayList(Tab) = .empty;
    try tabs.appendSlice(a, edited.tabs);
    for (tabs.items) |*tab| {
        if (find(base.tabs, tab.*)) |i| {
            if (tab.favorite == null) tab.favorite = base.tabs[i].favorite;
            tab.used = layout.maxUsed(tab.used, base.tabs[i].used);
            tab.input = layout.maxUsed(tab.input, base.tabs[i].input);
            tab.visits = try layout.mergeVisits(a, tab.visits, base.tabs[i].visits);
        }
    }
    var ws: std.ArrayList(layout.Workspace) = .empty;
    try ws.appendSlice(a, edited.workspaces);
    for (base.tabs, 0..) |t, i| {
        if (t.tmux_session.len == 0 or find(edited.tabs, t) != null or find(closed, t) != null) continue;
        try tabs.insert(a, @min(i, tabs.items.len), t);
        if (workspaceIndex(ws.items, t.workspace) == null) try ws.append(a, .{ .name = t.workspace });
    }
    return .{ .settings = edited.settings, .revision = edited.revision, .hosts = edited.hosts, .workspaces = try ws.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a) };
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
        if (find(edited.tabs, r)) |ei| {
            t.used = layout.maxUsed(t.used, edited.tabs[ei].used);
            t.input = layout.maxUsed(t.input, edited.tabs[ei].input);
            t.visits = try layout.mergeVisits(a, t.visits, edited.tabs[ei].visits);
        }
        if (t.favorite == null) {
            if (find(edited.tabs, r)) |ei| t.favorite = edited.tabs[ei].favorite;
        }
        if (find(base.tabs, r)) |bi| {
            const ei = find(edited.tabs, r) orelse continue;
            t.used = layout.maxUsed(t.used, base.tabs[bi].used);
            t.input = layout.maxUsed(t.input, base.tabs[bi].input);
            t.visits = try layout.mergeVisits(a, t.visits, base.tabs[bi].visits);
            if (r.favorite == null and t.favorite == null) t.favorite = base.tabs[bi].favorite;
            if (edited.tabs[ei].favorite) |favorite| {
                if (favorite != (base.tabs[bi].favorite orelse false)) t.favorite = favorite;
            }
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
    var settings = remote.settings;
    inline for (std.meta.fields(layout.Settings)) |field| {
        const value = @field(edited.settings orelse layout.Settings{}, field.name);
        if (value != @field(base.settings orelse layout.Settings{}, field.name)) {
            if (settings == null) settings = .{};
            @field(settings.?, field.name) = value;
        }
    }
    const result = Layout{ .settings = settings, .revision = remote.revision, .hosts = remote.hosts, .workspaces = try ws.toOwnedSlice(a), .tabs = try tabs.toOwnedSlice(a) };
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
        if (t.favorite) |favorite| try normalized.object.put(a, "favorite", .{ .bool = favorite });
        const cached_used = record.object.get("used");
        const used = layout.maxUsed(t.used, if (cached_used != null and cached_used.? == .integer and cached_used.?.integer >= 0) @import("json_reader.zig").uint(record, "used") else null);
        if (used) |value| {
            try normalized.object.put(a, "used", .{ .integer = @intCast(value) });
            try normalized.object.put(a, "used_unix", .{ .bool = true });
        }
        const cached_input = record.object.get("input");
        if (layout.maxUsed(t.input, if (cached_input != null and cached_input.? == .integer and cached_input.?.integer >= 0) @as(u64, @intCast(cached_input.?.integer)) else null)) |value| try normalized.object.put(a, "input", .{ .integer = @intCast(value) });
        const cached_visits = @import("json_reader.zig").visits(record);
        if (try layout.mergeVisits(a, t.visits, cached_visits.optional())) |values| {
            var list: std.json.Array = .init(a);
            for (values) |v| try list.append(.{ .integer = @intCast(v) });
            try normalized.object.put(a, "visits", .{ .array = list });
        }
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
    if (remote.settings) |settings| {
        var value: std.json.Value = .{ .object = .empty };
        inline for (std.meta.fields(layout.Settings)) |field| try value.object.put(a, field.name, .{ .bool = @field(settings, field.name) });
        try root.object.put(a, "settings", value);
    } else {
        _ = root.object.swapRemove("settings");
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

test "favorite apply and held edits preserve unknown and accept explicit booleans" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]bool{ false, true }) |favorite| {
        var local = one;
        local.favorite = favorite;
        const base = Layout{ .workspaces = &test_ws, .tabs = &.{local} };
        for ([_]?bool{ null, true, false }) |incoming| {
            var remote = one;
            remote.tmux_session = "ONE";
            remote.favorite = incoming;
            const server = Layout{ .workspaces = &test_ws, .tabs = &.{remote} };
            const applied = try apply(a, base, &.{true}, server, 9, 256);
            try std.testing.expectEqual(incoming orelse favorite, applied.tabs[0].favorite.?);
            const held = try keepHeld(a, base, server, &.{});
            try std.testing.expectEqual(incoming orelse favorite, held.tabs[0].favorite.?);
        }
    }
}

test "favorite rebase preserves unknown server fields and applies remote changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]bool{ false, true }) |favorite| {
        var local = one;
        local.favorite = favorite;
        const base = Layout{ .workspaces = &test_ws, .tabs = &.{local} };
        for ([_]?bool{ null, true, false }) |incoming| {
            var remote = one;
            remote.favorite = incoming;
            const server = Layout{ .workspaces = &test_ws, .tabs = &.{remote} };
            const result = try rebase(a, base, base, server);
            try std.testing.expectEqual(incoming orelse favorite, result.tabs[0].favorite.?);
            const unknown_edit = Layout{ .workspaces = &test_ws, .tabs = &.{one} };
            const unchanged = try rebase(a, base, unknown_edit, server);
            try std.testing.expectEqual(incoming orelse favorite, unchanged.tabs[0].favorite.?);
        }
        var edited = local;
        edited.favorite = !favorite;
        var remote = one;
        remote.name = "Remote rename";
        const rebased = try rebase(a, base, .{ .workspaces = &test_ws, .tabs = &.{edited} }, .{ .workspaces = &test_ws, .tabs = &.{remote} });
        try std.testing.expectEqual(!favorite, rebased.tabs[0].favorite.?);
        try std.testing.expectEqualStrings(remote.name, rebased.tabs[0].name);
        const both_added = try rebase(a, .{ .workspaces = &test_ws, .tabs = &.{} }, base, .{ .workspaces = &test_ws, .tabs = &.{one} });
        try std.testing.expectEqual(favorite, both_added.tabs[0].favorite.?);
    }
}

test "favorite two laptop unstar applies rebases and pushes explicit false" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var starred = one;
    starred.favorite = true;
    const laptop_b = Layout{ .workspaces = &test_ws, .tabs = &.{starred} };
    var unstarred = one;
    unstarred.tmux_session = "ONE";
    unstarred.favorite = false;
    const server = Layout{ .workspaces = &test_ws, .tabs = &.{unstarred} };
    const applied = try apply(a, laptop_b, &.{true}, server, 9, 256);
    try std.testing.expectEqual(false, applied.tabs[0].favorite.?);
    const rebased = try rebase(a, laptop_b, laptop_b, server);
    try std.testing.expectEqual(false, rebased.tabs[0].favorite.?);
    const push = try layout.encode(a, rebased);
    try std.testing.expect(std.mem.indexOf(u8, push, "\"favorite\":false") != null);
    const parsed = try layout.parse(a, push);
    defer parsed.deinit();
    try std.testing.expectEqual(false, parsed.value.tabs[0].favorite.?);
}

test "favorite cache restore preserves legacy stars and applies explicit values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const cache = "{\"workspaces\":[{\"name\":\"Other\"}],\"tabs\":[{\"kind\":\"tmux\",\"name\":\"One\",\"tmux_session\":\"ONE\",\"tmux_host\":0,\"workspace\":0,\"pid\":42,\"favorite\":true}]}";
    for ([_]?bool{ null, true, false }) |favorite| {
        var remote = one;
        remote.favorite = favorite;
        const server = Layout{ .workspaces = &test_ws, .tabs = &.{remote} };
        const prepared = try prepareCache(a, cache, server);
        const restored = (try restoreCache(a, cache, server)).?;
        for ([_][]const u8{ prepared, restored }) |json| {
            const parsed = try std.json.parseFromSlice(std.json.Value, a, json, .{});
            defer parsed.deinit();
            const tab = parsed.value.object.get("tabs").?.array.items[0];
            try std.testing.expectEqual(favorite orelse true, tab.object.get("favorite").?.bool);
            try std.testing.expectEqual(@as(i64, 42), tab.object.get("pid").?.integer);
        }
        const fresh = (try restoreCache(a, null, server)).?;
        const parsed = try std.json.parseFromSlice(std.json.Value, a, fresh, .{});
        defer parsed.deinit();
        const field = parsed.value.object.get("tabs").?.array.items[0].object.get("favorite");
        if (favorite) |value| {
            try std.testing.expectEqual(value, field.?.bool);
        } else try std.testing.expect(field == null);
    }
}

test "favorite equality detects toggles without looping on canonical absent false" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var unstarred = one;
    unstarred.favorite = false;
    var starred = one;
    starred.favorite = true;
    const unknown = Layout{ .workspaces = &test_ws, .tabs = &.{one} };
    const off = Layout{ .workspaces = &test_ws, .tabs = &.{unstarred} };
    const on = Layout{ .workspaces = &test_ws, .tabs = &.{starred} };
    try std.testing.expect(equal(unknown, off));
    try std.testing.expect(equal(off, unknown));
    try std.testing.expect(!equal(on, off));
    try std.testing.expect(!equal(off, on));
    try std.testing.expect(!equal(unknown, on));
    const pushed = try rebase(a, on, off, on);
    try std.testing.expectEqual(false, pushed.tabs[0].favorite.?);
    try std.testing.expect(equal(pushed, unknown));
    const acknowledged = try apply(a, pushed, &.{true}, unknown, 9, 256);
    try std.testing.expect(equal(acknowledged, off));
    const repeated = try rebase(a, off, acknowledged, unknown);
    try std.testing.expect(equal(repeated, unknown));
}

test "used apply held and rebase merge all known times by maximum" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]?u64{ null, 0, 1000, 4000 }) |old| for ([_]?u64{ null, 0, 2000, 5000 }) |edit| for ([_]?u64{ null, 0, 3000, 6000 }) |incoming| {
        var b = one;
        b.used = old;
        var e = one;
        e.used = edit;
        var r = one;
        r.tmux_session = "ONE";
        r.used = incoming;
        const base = Layout{ .workspaces = &test_ws, .tabs = &.{b} };
        const edited = Layout{ .workspaces = &test_ws, .tabs = &.{e} };
        const remote = Layout{ .workspaces = &test_ws, .tabs = &.{r} };
        const applied = try apply(a, edited, &.{true}, remote, 9, 256);
        try std.testing.expectEqual(if (edit == null and incoming == null) @as(?u64, null) else @as(?u64, @max(edit orelse 0, incoming orelse 0)), applied.tabs[0].used);
        const held = try keepHeld(a, base, edited, &.{});
        try std.testing.expectEqual(if (old == null and edit == null) @as(?u64, null) else @as(?u64, @max(old orelse 0, edit orelse 0)), held.tabs[0].used);
        const rebased = try rebase(a, base, edited, remote);
        try std.testing.expectEqual(if (old == null and edit == null and incoming == null) @as(?u64, null) else @as(?u64, @max(old orelse 0, edit orelse 0, incoming orelse 0)), rebased.tabs[0].used);
        const added = try rebase(a, .{ .workspaces = &test_ws, .tabs = &.{} }, edited, remote);
        try std.testing.expectEqual(if (edit == null and incoming == null) @as(?u64, null) else @as(?u64, @max(edit orelse 0, incoming orelse 0)), added.tabs[0].used);
    };
}

test "used equality canonicalizes absent zero and detects newer or older times" {
    for ([_]?u64{ null, 0, 1000, 2000 }) |left| for ([_]?u64{ null, 0, 1000, 2000 }) |right| {
        var x = one;
        x.used = left;
        var y = one;
        y.used = right;
        try std.testing.expectEqual((left orelse 0) == (right orelse 0), equal(.{ .workspaces = &test_ws, .tabs = &.{x} }, .{ .workspaces = &test_ws, .tabs = &.{y} }));
    };
}

test "used cache restore keeps maximum and migrates Windows epoch without changing known Unix future times" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]?u64{ null, 0, 1000, 3000, 9_007_199_254_740_991 }) |incoming| {
        var remote = one;
        remote.used = incoming;
        const server = Layout{ .workspaces = &test_ws, .tabs = &.{remote} };
        for ([_][]const u8{
            "{\"tabs\":[{\"tmux_session\":\"ONE\",\"tmux_host\":0,\"pid\":42,\"used\":2000}]}",
            "{\"tabs\":[{\"tmux_session\":\"ONE\",\"tmux_host\":0,\"pid\":42,\"used\":11644473602000}]}",
        }) |cache| {
            const prepared = try prepareCache(a, cache, server);
            const restored = (try restoreCache(a, cache, server)).?;
            for ([_][]const u8{ prepared, restored, (try restoreCache(a, prepared, server)).? }) |json| {
                const parsed = try std.json.parseFromSlice(std.json.Value, a, json, .{});
                defer parsed.deinit();
                const tab = parsed.value.object.get("tabs").?.array.items[0];
                try std.testing.expectEqual(@max(@as(u64, 2000), incoming orelse 0), @import("json_reader.zig").uint(tab, "used"));
                try std.testing.expectEqual(@as(i64, 42), tab.object.get("pid").?.integer);
            }
        }
        const fresh = (try restoreCache(a, null, server)).?;
        const parsed = try std.json.parseFromSlice(std.json.Value, a, fresh, .{});
        defer parsed.deinit();
        const field = parsed.value.object.get("tabs").?.array.items[0].object.get("used");
        if (incoming) |used| try std.testing.expectEqual(used, @as(u64, @intCast(field.?.integer))) else try std.testing.expect(field == null);
    }
}

test "used publish throttle is strictly over ten minutes since synced not last local stamp" {
    var synced = one;
    synced.used = 1000;
    var base = one;
    base.used = 500_000;
    for ([_]u64{ 0, 999, 1000, 600_999, 601_000, 601_001, 602_000 }) |used| {
        var local = one;
        local.used = used;
        const current = Layout{ .workspaces = &test_ws, .tabs = &.{local} };
        const held = Layout{ .workspaces = &test_ws, .tabs = &.{base} };
        const server = Layout{ .workspaces = &test_ws, .tabs = &.{synced} };
        try std.testing.expectEqual(used > 601_000, publishNeeded(current, held, server));
        local.favorite = true;
        try std.testing.expect(publishNeeded(.{ .workspaces = &test_ws, .tabs = &.{local} }, held, server));
    }
    const empty = Layout{ .workspaces = &test_ws, .tabs = &.{} };
    try std.testing.expect(publishNeeded(initial, empty, empty));
    synced.used = null;
    base.used = 600_001;
    const unknown = Layout{ .workspaces = &test_ws, .tabs = &.{synced} };
    const first = Layout{ .workspaces = &test_ws, .tabs = &.{base} };
    try std.testing.expect(publishNeeded(first, first, unknown));
}

test "visits apply held rebase cache union and publish bypass used throttle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var b = one;
    b.visits = &.{ 1, 2 };
    b.used = 1000;
    var e = b;
    e.visits = &.{ 2, 3 };
    e.used = 1001;
    var r = b;
    r.visits = &.{ 2, 4 };
    const base = Layout{ .workspaces = &test_ws, .tabs = &.{b} };
    const edit = Layout{ .workspaces = &test_ws, .tabs = &.{e} };
    const remote = Layout{ .workspaces = &test_ws, .tabs = &.{r} };
    const applied = try apply(a, edit, &.{true}, remote, 9, 256);
    try std.testing.expectEqualSlices(u64, &.{ 2, 3, 4 }, applied.tabs[0].visits.?);
    const held = try keepHeld(a, base, edit, &.{});
    try std.testing.expectEqualSlices(u64, &.{ 1, 2, 3 }, held.tabs[0].visits.?);
    const rebased = try rebase(a, base, edit, remote);
    try std.testing.expectEqualSlices(u64, &.{ 1, 2, 3, 4 }, rebased.tabs[0].visits.?);
    try std.testing.expect(!equal(base, edit));
    try std.testing.expect(publishNeeded(edit, base, base));
    try std.testing.expect(publishNeeded(edit, edit, base));
    try std.testing.expect(!publishNeeded(edit, edit, edit));
    const cached = try prepareCache(a, "{\"tabs\":[{\"tmux_session\":\"one\",\"tmux_host\":0,\"visits\":[1,3]}]}", remote);
    const parsed = try std.json.parseFromSlice(std.json.Value, a, cached, .{});
    defer parsed.deinit();
    const visits = @import("json_reader.zig").visits(parsed.value.object.get("tabs").?.array.items[0]);
    try std.testing.expectEqualSlices(u64, &.{ 1, 2, 3, 4 }, visits.optional().?);
}

test "input apply held and rebase merge all known times by maximum" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]?u64{ null, 0, 1000, 4000 }) |old| for ([_]?u64{ null, 0, 2000, 5000 }) |edit| for ([_]?u64{ null, 0, 3000, 6000 }) |incoming| {
        var b = one;
        b.input = old;
        var e = one;
        e.input = edit;
        var r = one;
        r.tmux_session = "ONE";
        r.input = incoming;
        const base = Layout{ .workspaces = &test_ws, .tabs = &.{b} };
        const edited = Layout{ .workspaces = &test_ws, .tabs = &.{e} };
        const remote = Layout{ .workspaces = &test_ws, .tabs = &.{r} };
        const applied = try apply(a, edited, &.{true}, remote, 9, 256);
        try std.testing.expectEqual(if (edit == null and incoming == null) @as(?u64, null) else @as(?u64, @max(edit orelse 0, incoming orelse 0)), applied.tabs[0].input);
        const held = try keepHeld(a, base, edited, &.{});
        try std.testing.expectEqual(if (old == null and edit == null) @as(?u64, null) else @as(?u64, @max(old orelse 0, edit orelse 0)), held.tabs[0].input);
        const rebased = try rebase(a, base, edited, remote);
        try std.testing.expectEqual(if (old == null and edit == null and incoming == null) @as(?u64, null) else @as(?u64, @max(old orelse 0, edit orelse 0, incoming orelse 0)), rebased.tabs[0].input);
        const added = try rebase(a, .{ .workspaces = &test_ws, .tabs = &.{} }, edited, remote);
        try std.testing.expectEqual(if (edit == null and incoming == null) @as(?u64, null) else @as(?u64, @max(edit orelse 0, incoming orelse 0)), added.tabs[0].input);
    };
}

test "input publish first input and strictly after sixty seconds since synced" {
    var remote = one;
    remote.input = 1_800_000_000_000;
    const synced = Layout{ .workspaces = &test_ws, .tabs = &.{remote} };
    for ([_]u64{ 0, 1, 59_999, 60_000, 60_001 }) |delta| {
        var tab = remote;
        tab.input = remote.input.? + delta;
        const local = Layout{ .workspaces = &test_ws, .tabs = &.{tab} };
        try std.testing.expectEqual(delta > 60_000, publishNeeded(local, local, synced));
        try std.testing.expect(publishNeeded(local, local, initial));
    }
}

test "input cache keeps maximum without using Windows epoch or used history" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var remote = one;
    remote.input = 2000;
    const prepared = try prepareCache(a, "{\"tabs\":[{\"tmux_session\":\"one\",\"tmux_host\":0,\"input\":3000,\"used\":9999}]}", .{ .workspaces = &test_ws, .tabs = &.{remote} });
    const parsed = try std.json.parseFromSlice(std.json.Value, a, prepared, .{});
    try std.testing.expectEqual(@as(u64, 3000), @import("json_reader.zig").uint(parsed.value.object.get("tabs").?.array.items[0], "input"));
}

test "ISSUE-423 settings rebase merges only locally changed keys including implicit defaults" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    inline for (std.meta.fields(layout.Settings)) |changed| {
        for ([_]bool{ false, true }) |before| {
            var base = initial;
            if (!before) base.settings = .{ .frequent = false, .favorites = false, .all = false, .frequent_first = false };
            var edited = base;
            if (edited.settings == null) edited.settings = .{};
            @field(edited.settings.?, changed.name) = !before;
            var remote = initial;
            remote.settings = .{ .frequent = false, .favorites = false, .all = false, .frequent_first = false };
            const result = try rebase(a, base, edited, remote);
            inline for (std.meta.fields(layout.Settings)) |field| {
                const expected = if (eq(u8, changed.name, field.name)) !before else false;
                try std.testing.expectEqual(expected, @field(result.settings.?, field.name));
            }
            const missing = try rebase(a, base, edited, initial);
            inline for (std.meta.fields(layout.Settings)) |field| {
                const expected = if (eq(u8, changed.name, field.name)) !before else true;
                try std.testing.expectEqual(expected, @field(missing.settings orelse layout.Settings{}, field.name));
            }
            try std.testing.expect(publishNeeded(edited, base, base));
        }
    }
    var remote = initial;
    remote.settings = .{ .favorites = false };
    remote.hosts = &.{.{ .slot = 0, .name = "Host 1", .hostname = "example.com", .port = 22, .user = "owner" }};
    var rename = initial;
    var tab = one;
    tab.name = "Renamed";
    rename.tabs = &.{ tab, two };
    const result = try rebase(a, initial, rename, remote);
    try std.testing.expectEqualDeep(remote.settings, result.settings);
    try std.testing.expectEqualDeep(remote.hosts, result.hosts);
    const reset = try rebase(a, remote, initial, remote);
    try std.testing.expect(reset.settings.?.favorites);
    const unchanged = try rebase(a, initial, initial, initial);
    try std.testing.expectEqual(@as(?layout.Settings, null), unchanged.settings);
}

test "ISSUE-423 settings survive apply held edits cache and layout encoding" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var remote = initial;
    remote.settings = .{ .frequent = false, .frequent_first = false };
    remote.hosts = &.{.{ .slot = 0, .name = "Host 1", .hostname = "example.com", .port = 22, .user = "owner" }};
    const applied = try apply(a, initial, &.{ true, true }, remote, 9, 256);
    try std.testing.expectEqualDeep(remote.settings, applied.settings);
    try std.testing.expectEqualDeep(remote.hosts, applied.hosts);
    const held = try keepHeld(a, initial, remote, &.{});
    try std.testing.expectEqualDeep(remote.settings, held.settings);
    try std.testing.expectEqualDeep(remote.hosts, held.hosts);
    const json = try layout.encode(a, held);
    const parsed = try layout.parse(a, json);
    defer parsed.deinit();
    try std.testing.expectEqualDeep(remote.settings, parsed.value.settings);
    try std.testing.expectEqualDeep(remote.hosts, parsed.value.hosts);
    const cache = try prepareCache(a, "{\"tabs\":[],\"settings\":{\"favorites\":false}}", remote);
    const saved = try std.json.parseFromSlice(std.json.Value, a, cache, .{});
    defer saved.deinit();
    try std.testing.expect(!saved.value.object.get("settings").?.object.get("frequent").?.bool);
    try std.testing.expect(saved.value.object.get("settings").?.object.get("favorites").?.bool);
    const reset = try prepareCache(a, cache, initial);
    const defaults = try std.json.parseFromSlice(std.json.Value, a, reset, .{});
    defer defaults.deinit();
    try std.testing.expect(!defaults.value.object.contains("settings"));
    try std.testing.expect(!equal(initial, remote));
    var explicit_defaults = initial;
    explicit_defaults.settings = .{};
    try std.testing.expect(equal(initial, explicit_defaults));
    try std.testing.expect(!publishNeeded(initial, explicit_defaults, explicit_defaults));
}
