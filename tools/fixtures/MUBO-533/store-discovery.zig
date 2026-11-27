const std = @import("std");
const Route = struct { hostname: [4]u8 = "host".*, hostname_len: usize = 4, user: [4]u8 = "user".*, user_len: usize = 4, port: u16 = 22 };
const rooms = struct {
    const Controller = struct {
        host: u8,
        has_host_uuid: bool = false,
        host_uuid: [36]u8 = @splat('s'),
        job: ?u8 = null,
        fn init(host: u8) @This() { return .{ .host = host }; }
        fn bindAccount(_: *@This(), value: []const u8) bool { return std.mem.eql(u8, value, "account"); }
        fn bindRoute(_: *@This(), _: []const u8, _: []const u8, _: u16) bool { return true; }
        fn bindHost(_: *@This(), _: []const u8) bool { return false; }
        fn capabilities(self: *@This()) bool { probes_started[self.host] += 1; self.job = 1; return true; }
        fn shutdown(self: *@This()) void { self.job = null; }
    };
};
const CatalogRow = struct { store_uuid: [36]u8 = @splat('s'), id: []const u8, name: []const u8, revision: u64 = 1, sequence: u64 = 0 };
var applied_routes: [3]?Route = .{ .{}, null, .{} };
var account = "account".*;
var account_len: usize = 7;
var account_generation: u64 = 1;
const enabled = true;
const ui_ready = true;
const scope_blocked = false;
var request_generation: u64 = 1;
var route_slot: u8 = 0;
var route_key: [64]u8 = @splat('0');
var catalog_complete = false;
var catalog_after: u64 = 1;
var catalog_through: ?u64 = 1;
var catalog_rows: std.ArrayList(CatalogRow) = .empty;
var visible_catalog: [12288]CatalogRow = undefined;
var probes_started: [3]usize = @splat(0);
var polls: usize = 0;
fn armPoll() void { polls += 1; }
fn routeKeyFor(slot: u8, _: Route) [64]u8 { return @splat('0' + slot); }
fn routeKey(route: Route) [64]u8 { return routeKeyFor(route_slot, route); }
fn configuredRoute(slot: u8) ?Route { return applied_routes[slot]; }
fn pinPathFor(_: []u8, _: *const [64]u8) ?[]const u8 { return null; }
const file_io = struct { fn readFileAllocWin32(_: []const u8, _: usize) ?[]u8 { return null; } };

test "fresh profile probes every configured host without pins or an active tab" {
    discoverStores();
    defer clearStoreDiscovery();
    try std.testing.expectEqualSlices(usize, &.{ 1, 0, 1 }, &probes_started);
    try std.testing.expectEqual(@as(usize, 2), polls);
    discoverStores();
    try std.testing.expectEqualSlices(usize, &.{ 1, 0, 1 }, &probes_started);
    const first = store_discovery[0].?;
    const second = store_discovery[2].?;
    first.controller.job = null;
    second.controller.job = null;
    first.complete = true;
    second.complete = true;
    try first.rows.append(first.arena.allocator(), .{ .store_uuid = @splat('a'), .id = "room-a", .name = "First host room" });
    try second.rows.append(second.arena.allocator(), .{ .store_uuid = @splat('b'), .id = "room-b", .name = "Second host room" });
    var rows = catalog();
    try std.testing.expectEqual(@as(usize, 2), rows.len);
    try std.testing.expectEqualStrings("First host room", rows[0].name);
    try std.testing.expectEqualStrings("Second host room", rows[1].name);
    try std.testing.expect(!std.mem.eql(u8, &rows[0].store_uuid, &rows[1].store_uuid));
    var primary = [_]CatalogRow{.{ .store_uuid = @splat('a'), .id = "room-a", .name = "Renamed room" }};
    catalog_rows.items = &primary;
    catalog_complete = true;
    rows = catalog();
    try std.testing.expectEqual(@as(usize, 2), rows.len);
    try std.testing.expectEqualStrings("Renamed room", rows[0].name);
    first.controller.has_host_uuid = true;
    first.controller.host_uuid = @splat('a');
    cacheCatalog(&first.controller);
    catalog_complete = false;
    catalog_rows.items = &.{};
    rows = catalog();
    try std.testing.expectEqual(@as(usize, 2), rows.len);
    try std.testing.expectEqualStrings("Renamed room", rows[0].name);
    account_generation += 1;
    try std.testing.expectEqual(@as(usize, 0), catalog().len);
}
