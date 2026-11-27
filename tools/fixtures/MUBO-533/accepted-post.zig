const std = @import("std");
const room_post = @import("room_post.zig");
const test_room = "10000000-0000-4000-8000-000000000001";
const other_room = "20000000-0000-4000-8000-000000000002";
const event_id = "30000000-0000-4000-8000-000000000003";
const RoomLocation = struct { room_id: [36]u8 };
const Front = union(enum) { hidden, selected: RoomLocation, create: void };
var front: Front = .hidden;
const PendingCommand = struct { room_id: [36]u8 };
const Message = struct {
    text: []const u16,
    author: ?u8 = null,
    time: []const u16 = &.{},
    question_id: []const u8 = "",
    member_id: []const u8 = "",
};
const ViewModel = struct {
    room_id: []const u8,
    messages: []const Message = &.{},
    revision: u64 = 2,
    members: []const u8 = &.{},
    candidates: []const u8 = &.{},
    name: []const u16 = &.{},
};
const OwnedModel = struct {
    arena: std.heap.ArenaAllocator,
    value: ViewModel,
    messages: std.ArrayList(Message) = .empty,
    highwater: u64 = 0,
};
var owned_model: ?*OwnedModel = null;
var painted: usize = 0;
var view = struct {
    fn setModel(_: *@This(), model: *const ViewModel) bool {
        painted = model.messages.len;
        return true;
    }
}{};

fn reset() void {
    if (owned_model) |loaded| {
        loaded.arena.deinit();
        std.heap.page_allocator.destroy(loaded);
    }
    owned_model = null;
    painted = 0;
    front = .{ .selected = .{ .room_id = test_room.* } };
}

fn load(highwater: u64) *OwnedModel {
    front = .{ .selected = .{ .room_id = test_room.* } };
    const loaded = std.heap.page_allocator.create(OwnedModel) catch unreachable;
    loaded.* = .{ .arena = std.heap.ArenaAllocator.init(std.heap.page_allocator), .value = .{ .room_id = test_room }, .highwater = highwater };
    const a = loaded.arena.allocator();
    loaded.messages.append(a, .{ .text = std.unicode.utf8ToUtf16LeAlloc(a, "earlier question") catch unreachable, .question_id = "40000000-0000-4000-8000-000000000004" }) catch unreachable;
    loaded.messages.append(a, .{ .text = std.unicode.utf8ToUtf16LeAlloc(a, "earlier answer") catch unreachable, .author = 1, .question_id = "40000000-0000-4000-8000-000000000004" }) catch unreachable;
    loaded.value.messages = loaded.messages.items;
    owned_model = loaded;
    return loaded;
}

fn receipt(allocator: std.mem.Allocator, room: []const u8, seq: u64, text: []const u8) std.json.Parsed(std.json.Value) {
    const body = std.fmt.allocPrint(allocator, "{{\"event\":{{\"id\":\"{s}\",\"room_id\":\"{s}\",\"seq\":{d},\"type\":\"human\",\"text\":\"{s}\"}}}}", .{ event_id, room, seq, text }) catch unreachable;
    defer allocator.free(body);
    return std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch unreachable;
}

fn lastText(loaded: *const OwnedModel) []const u16 {
    return loaded.messages.items[loaded.messages.items.len - 1].text;
}

test "a saved send is shown in the room before the room is read again" {
    defer reset();
    const item = PendingCommand{ .room_id = test_room.* };
    var parsed = receipt(std.testing.allocator, test_room, 4, "BROADCAST534");
    defer parsed.deinit();
    const loaded = load(3);
    try std.testing.expectEqual(@as(usize, 0), painted);
    applyAcceptedPost(&item, parsed.value);
    try std.testing.expectEqual(@as(usize, 3), loaded.messages.items.len);
    try std.testing.expect(std.mem.eql(u16, lastText(loaded), std.unicode.utf8ToUtf16LeStringLiteral("BROADCAST534")));
    try std.testing.expectEqual(@as(?u8, null), loaded.messages.items[2].author);
    try std.testing.expect(std.mem.eql(u8, loaded.messages.items[2].question_id, event_id));
    try std.testing.expectEqual(@as(u64, 4), loaded.highwater);
    try std.testing.expectEqual(@as(usize, 3), painted);
}

test "reading the same send again does not show it twice" {
    defer reset();
    const item = PendingCommand{ .room_id = test_room.* };
    var parsed = receipt(std.testing.allocator, test_room, 4, "BROADCAST534");
    defer parsed.deinit();
    const loaded = load(3);
    applyAcceptedPost(&item, parsed.value);
    applyAcceptedPost(&item, parsed.value);
    try std.testing.expectEqual(@as(usize, 3), loaded.messages.items.len);
}

test "a send the room already read, another room, and a refusal leave the room alone" {
    defer reset();
    const item = PendingCommand{ .room_id = test_room.* };
    var stale = receipt(std.testing.allocator, test_room, 3, "BROADCAST534");
    defer stale.deinit();
    var elsewhere = receipt(std.testing.allocator, other_room, 5, "BROADCAST534");
    defer elsewhere.deinit();
    var refused = std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"error\":\"revision_conflict\"}", .{}) catch unreachable;
    defer refused.deinit();
    const loaded = load(3);
    applyAcceptedPost(&item, stale.value);
    applyAcceptedPost(&item, elsewhere.value);
    applyAcceptedPost(&item, refused.value);
    try std.testing.expectEqual(@as(usize, 2), loaded.messages.items.len);
    try std.testing.expectEqual(@as(u64, 3), loaded.highwater);
    try std.testing.expectEqual(@as(usize, 0), painted);
    front = .hidden;
    var fresh = receipt(std.testing.allocator, test_room, 6, "BROADCAST534");
    defer fresh.deinit();
    applyAcceptedPost(&item, fresh.value);
    try std.testing.expectEqual(@as(usize, 2), loaded.messages.items.len);
}
