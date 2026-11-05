const std = @import("std");
const rooms = struct {
    const Controller = struct {
        job: ?*anyopaque = null,
        has_host_uuid: bool = true,
        host_uuid: [36]u8 = @splat('s'),
        fn catalogMetadata(_: *@This(), _: []const u8) bool { return false; }
    };
};
var front: union(enum) { hidden, create, selected: struct { store: struct { store_uuid: [36]u8 = @splat('s') } = .{} } } = .{ .selected = .{} };
var selection_waiting = true;
var candidate_scan: usize = 0;
var discovered_count: usize = 0;
var request_generation: u64 = 1;
var account_generation: u64 = 1;
var route_slot: u8 = 0;
var route_key: [64]u8 = @splat('k');
var route_valid = true;
var snapshots: usize = 0;
var catalog_complete = false;
var metadata_cursor: usize = 0;
var metadata_generation: u64 = 0;
var catalog_generation: u64 = 0;
var metadata_read: ?struct { room_id: [36]u8, store_uuid: [36]u8, catalog_generation: u64, read_generation: u64 } = null;
const Row = struct { id: []const u8 = "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", metadata_state: enum { queued, loading, failed }, read_generation: u64 = 0 };
var rows = [_]Row{.{ .metadata_state = .queued }};
var catalog_rows = struct { items: []Row }{ .items = &rows };
var last_failure: struct { kind: enum { catalog_metadata }, reason: enum { transport } } = undefined;
fn nextStatus(_: *rooms.Controller) bool { return false; }
fn pumpRefresh(_: *rooms.Controller) bool { return false; }
fn configuredRoute(_: u8) ?u8 { return if (route_valid) 1 else null; }
fn routeKey(_: u8) [64]u8 { return @splat('k'); }
fn startSnapshot(_: *rooms.Controller) bool { snapshots += 1; return true; }
const app_state = struct { const g_main_hwnd = 0; };
const TIMER_ROOM = 1;
const w = struct {
    fn InvalidateRect(_: usize, _: ?*anyopaque, _: usize) bool { return true; }
    fn SetTimer(_: usize, _: usize, _: usize, _: ?*anyopaque) usize { return 1; }
};
test "selected history refresh survives an interrupted incomplete catalog" {
    var c = rooms.Controller{};
    try std.testing.expect(scheduleMetadata(&c));
    try std.testing.expectEqual(@as(usize, 1), snapshots);
    try std.testing.expect(rows[0].metadata_state == .queued);
}
test "incomplete catalogs never start metadata and route checks still apply" {
    var c = rooms.Controller{};
    snapshots = 0;
    front = .hidden;
    try std.testing.expect(!scheduleMetadata(&c));
    try std.testing.expect(rows[0].metadata_state == .queued);
    front = .{ .selected = .{} };
    route_valid = false;
    try std.testing.expect(!scheduleMetadata(&c));
    route_valid = true;
    account_generation = 2;
    try std.testing.expect(!scheduleMetadata(&c));
    try std.testing.expectEqual(@as(usize, 0), snapshots);
}
