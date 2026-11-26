const std = @import("std");
const Route = struct {};
const rooms = struct { const Controller = struct { host_uuid: [36]u8 = @splat('s') }; };
var member_names: std.StringHashMapUnmanaged([]u8) = .empty;
var route_key: [64]u8 = @splat('0');
var candidates: [768]Candidate = undefined;
var candidate_count: usize = 0;
var status_generation: u64 = 1;
var candidate_generation: u64 = 1;
fn configuredRoute(_: u8) ?Route { return .{}; }
fn routeKeyFor(slot: u8, _: Route) [64]u8 { return @splat('0' + slot); }

fn clearNames() void {
    var names = member_names.iterator();
    while (names.next()) |entry| {
        std.heap.page_allocator.free(entry.key_ptr.*);
        std.heap.page_allocator.free(entry.value_ptr.*);
    }
    member_names.deinit(std.heap.page_allocator);
    member_names = .empty;
}

test "creation lists an unopened server chat by the account name instead of its tmux name" {
    defer clearNames();
    try std.testing.expect(cacheMemberNames(&.{.{ .tmux_host = 0, .tmux_session = "rooms-alpha", .name = "Alpha" }}));
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"members\":[{\"provider\":\"claude\",\"sid\":\"unopened-alpha\",\"tmux\":\"rooms-alpha\",\"display_name\":\"rooms-alpha\",\"alive\":true}]}", .{});
    defer parsed.deinit();
    try std.testing.expect(acceptMembers(&.{}, parsed.value));
    try std.testing.expectEqual(@as(usize, 1), candidate_count);
    try std.testing.expectEqualStrings("Alpha", candidates[0].display_name[0..candidates[0].display_name_len]);
    const alias = candidates[0].alias;
    try std.testing.expect(cacheMemberNames(&.{}));
    try std.testing.expect(acceptMembers(&.{}, parsed.value));
    try std.testing.expectEqualStrings("Alpha", candidates[0].display_name[0..candidates[0].display_name_len]);
    try std.testing.expectEqualSlices(u8, alias[0..30], candidates[0].alias[0..30]);
    try std.testing.expect(cacheMemberNames(&.{.{ .tmux_host = 0, .tmux_session = "rooms-alpha", .name = "Research Notes" }}));
    try std.testing.expect(acceptMembers(&.{}, parsed.value));
    try std.testing.expectEqualStrings("Research Notes", candidates[0].display_name[0..candidates[0].display_name_len]);
    route_key = @splat('1');
    try std.testing.expect(acceptMembers(&.{}, parsed.value));
    try std.testing.expectEqualStrings("rooms-alpha", candidates[0].display_name[0..candidates[0].display_name_len]);
    route_key = @splat('0');
    clearNames();
    try std.testing.expect(acceptMembers(&.{}, parsed.value));
    try std.testing.expectEqualStrings("rooms-alpha", candidates[0].display_name[0..candidates[0].display_name_len]);
}
