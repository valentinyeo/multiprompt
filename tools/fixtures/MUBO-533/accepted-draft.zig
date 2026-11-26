const std = @import("std");

const test_room = "10000000-0000-4000-8000-000000000001";
const other_room = "20000000-0000-4000-8000-000000000002";
const test_store = "30000000-0000-4000-8000-000000000003";

const ViewModel = struct { room_id: []const u8 = test_room };
const Draft = struct { location: RoomLocation, text: [:0]u16 };
const PendingBinding = struct { alias: []const u8, id: []const u8 };
const PendingCommand = struct {
    location: StoreLocation,
    kind: journal.Kind = .post,
    room_id: [36]u8,
    request: []const u8,
    bindings: []const PendingBinding = &.{},
};
const room_post = @import("room_post.zig");
const test_receipt = "{\"event\":{\"id\":\"40000000-0000-4000-8000-000000000004\",\"room_id\":\"" ++ test_room ++ "\",\"seq\":7,\"type\":\"human\",\"text\":\"RESTART534\"}}";
const foreign_receipt = "{\"event\":{\"id\":\"40000000-0000-4000-8000-000000000004\",\"room_id\":\"" ++ other_room ++ "\",\"seq\":7,\"type\":\"human\",\"text\":\"RESTART534\"}}";
const changed_receipt = "{\"event\":{\"id\":\"40000000-0000-4000-8000-000000000004\",\"room_id\":\"" ++ test_room ++ "\",\"seq\":7,\"type\":\"human\",\"text\":\"RESTART534 but not mine\"}}";
const journal = struct {
    const Kind = enum { create, edit, post };
    const State = enum { prepared, uncertain, accepted, rejected };
    const Record = struct {
        kind: Kind = .post,
        room_id: []const u8 = test_room,
        request: []const u8 = "",
        evidence: []const u8 = test_receipt,
        state: State = .accepted,
    };
};

var room_model = ViewModel{};
var other_model = ViewModel{ .room_id = other_room };
var drafts: std.ArrayList(Draft) = .empty;
var composer_buf: [256]u16 = @splat(0);
var composer_len: usize = 0;
var created = true;
var front: Front = .hidden;
var buffered_location: ?RoomLocation = null;
var saved: usize = 0;
var dirty: usize = 0;

const w = struct {
    fn SetTimer(_: usize, _: usize, _: u32, _: ?*anyopaque) usize {
        return 1;
    }
};
const app_state = struct { const g_main_hwnd: usize = 1; };
const TIMER_ROOM_UI: usize = 1;
var view = struct {
    model: *const ViewModel = &room_model,
    fn draft(_: *@This(), buffer: []u16) ?[]const u16 {
        if (composer_len >= buffer.len) return null;
        @memcpy(buffer[0..composer_len], composer_buf[0..composer_len]);
        return buffer[0..composer_len];
    }
    fn setDraft(_: *@This(), value: [:0]const u16) bool {
        composer_len = value.len;
        @memcpy(composer_buf[0..composer_len], value);
        return true;
    }
}{};

fn markUiDirty() void {
    dirty += 1;
}
fn flushUi() bool {
    saved += 1;
    return true;
}

fn storeLocation() StoreLocation {
    return .{ .account = @splat(0), .account_len = 0, .store_uuid = test_store.* };
}

fn roomLocation(room: [36]u8) RoomLocation {
    return .{ .store = storeLocation(), .room_id = room };
}

fn seed(room: [36]u8, text: []const u16) void {
    const copy = std.heap.page_allocator.dupeZ(u16, text) catch unreachable;
    drafts.append(std.heap.page_allocator, .{ .location = roomLocation(room), .text = copy }) catch unreachable;
}

fn composer(text: []const u16) void {
    composer_len = text.len;
    @memcpy(composer_buf[0..composer_len], text);
}

fn reset() void {
    for (drafts.items) |entry| std.heap.page_allocator.free(entry.text);
    drafts.deinit(std.heap.page_allocator);
    drafts = .empty;
    composer_len = 0;
    created = true;
    front = .hidden;
    view.model = &room_model;
    buffered_location = null;
    saved = 0;
    dirty = 0;
}

test "an accepted room send is retired and saved so a restart cannot bring it back" {
    defer reset();
    seed(test_room.*, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534"));
    composer(std.unicode.utf8ToUtf16LeStringLiteral("RESTART534"));
    front = .hidden;
    const item = PendingCommand{ .location = storeLocation(), .room_id = test_room.*, .request = "{\"text\":\"RESTART534\"}" };
    retireSubmittedDraft(&item);
    try std.testing.expectEqual(@as(usize, 0), drafts.items.len);
    try std.testing.expectEqual(@as(usize, 0), composer_len);
    try std.testing.expectEqual(@as(usize, 1), saved);
}

test "a different edited draft survives an accepted send and is still saved" {
    defer reset();
    seed(test_room.*, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534 edited by me"));
    composer(std.unicode.utf8ToUtf16LeStringLiteral("RESTART534 edited by me"));
    front = .hidden;
    const item = PendingCommand{ .location = storeLocation(), .room_id = test_room.*, .request = "{\"text\":\"RESTART534\"}" };
    retireSubmittedDraft(&item);
    try std.testing.expectEqual(@as(usize, 1), drafts.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534 edited by me"), drafts.items[0].text);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534 edited by me"), composer_buf[0..composer_len]);
    try std.testing.expectEqual(@as(usize, 1), saved);
}

test "an accepted receipt retires only its own saved draft after a restart" {
    defer reset();
    seed(test_room.*, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534"));
    seed(test_room.*, std.unicode.utf8ToUtf16LeStringLiteral("a different draft"));
    seed(other_room.*, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534"));
    const record = journal.Record{ .state = .accepted, .kind = .post, .room_id = test_room, .request = "{\"text\":\"RESTART534\"}", .evidence = test_receipt };
    retireAcceptedDraft(&record, storeLocation());
    try std.testing.expectEqual(@as(usize, 2), drafts.items.len);
    for (drafts.items) |entry| {
        try std.testing.expect(!std.mem.eql(u16, entry.text, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534")) or !std.mem.eql(u8, &entry.location.room_id, test_room));
    }
    try std.testing.expectEqual(@as(usize, 1), saved);
}

test "a receipt for another room, another body or no receipt at all never accepts the send" {
    const item = PendingCommand{ .location = storeLocation(), .room_id = test_room.*, .request = "{\"text\":\"RESTART534\"}" };
    var receipt = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, test_receipt, .{});
    defer receipt.deinit();
    try std.testing.expect(acceptsReceipt(&item, receipt.value));
    var foreign = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, foreign_receipt, .{});
    defer foreign.deinit();
    try std.testing.expect(!acceptsReceipt(&item, foreign.value));
    var changed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, changed_receipt, .{});
    defer changed.deinit();
    try std.testing.expect(!acceptsReceipt(&item, changed.value));
    try std.testing.expect(!acceptsReceipt(&item, .null));
    var empty = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{}", .{});
    defer empty.deinit();
    try std.testing.expect(!acceptsReceipt(&item, empty.value));
}

test "a saved accepted record whose receipt names another room or body keeps its draft" {
    defer reset();
    seed(test_room.*, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534"));
    const other_room_record = journal.Record{ .state = .accepted, .kind = .post, .room_id = test_room, .request = "{\"text\":\"RESTART534\"}", .evidence = foreign_receipt };
    retireAcceptedDraft(&other_room_record, storeLocation());
    try std.testing.expectEqual(@as(usize, 1), drafts.items.len);
    const changed_record = journal.Record{ .state = .accepted, .kind = .post, .room_id = test_room, .request = "{\"text\":\"RESTART534\"}", .evidence = changed_receipt };
    retireAcceptedDraft(&changed_record, storeLocation());
    try std.testing.expectEqual(@as(usize, 1), drafts.items.len);
    try std.testing.expectEqual(@as(usize, 0), saved);
}

test "an uncertain send keeps its saved draft and its original body" {
    defer reset();
    seed(test_room.*, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534"));
    const record = journal.Record{ .state = .uncertain, .kind = .post, .room_id = test_room, .request = "{\"text\":\"RESTART534\"}" };
    retireAcceptedDraft(&record, storeLocation());
    try std.testing.expectEqual(@as(usize, 1), drafts.items.len);
    try std.testing.expectEqual(@as(usize, 0), saved);
}

test "an accepted send does not clear another room's composer" {
    defer reset();
    seed(test_room.*, std.unicode.utf8ToUtf16LeStringLiteral("RESTART534"));
    composer(std.unicode.utf8ToUtf16LeStringLiteral("a draft in the other room"));
    view.model = &other_model;
    front = .hidden;
    const item = PendingCommand{ .location = storeLocation(), .room_id = test_room.*, .request = "{\"text\":\"RESTART534\"}" };
    retireSubmittedDraft(&item);
    try std.testing.expectEqual(@as(usize, 0), drafts.items.len);
    try std.testing.expectEqualSlices(u16, std.unicode.utf8ToUtf16LeStringLiteral("a draft in the other room"), composer_buf[0..composer_len]);
    try std.testing.expectEqual(@as(usize, 1), saved);
}
