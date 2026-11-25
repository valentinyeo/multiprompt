const std = @import("std");
const room_post = @import("room_post.zig");
const enabled = true;
const created = true;
const room_view = struct {
    pub const ActionResult = enum { accepted, pending, unsupported, failed };
    pub const ActionToken = struct { generation: u64, serial: u64, kind: enum { submit } };
};
var last_error: []const u8 = "";
var last_log: [256]u8 = undefined;
var last_log_len: usize = 0;
const diagnostics = struct {
    fn syncLog(message: []const u8) void {
        last_log_len = @min(message.len, last_log.len);
        @memcpy(last_log[0..last_log_len], message[0..last_log_len]);
    }
};
var view = struct {
    fn showError(_: *@This(), message: []const u8) void { last_error = message; }
}{};
const w = struct {
    fn SetTimer(_: usize, _: usize, _: u32, _: ?*anyopaque) usize { return 1; }
};
const app_state = struct { const g_main_hwnd: usize = 1; };
const TIMER_ROOM: usize = 1;
const test_room = "10000000-0000-4000-8000-000000000001";
const test_store = "20000000-0000-4000-8000-000000000002";
const test_command = "30000000-0000-4000-8000-000000000003";
var account: [256]u8 = @splat(0);
const account_len: usize = 0;
const selection_generation: u64 = 1;
var selection_waiting = false;
const MemberBinding = struct { member: room_post.Recipient };
const OwnedModel = struct {
    value: struct { room_id: []const u8 = test_room, revision: u64 = 1 } = .{},
    bindings: struct { items: []const MemberBinding = &.{ .{ .member = .{ .alias = "alpha", .display_name = "Alpha" } }, .{ .member = .{ .alias = "bravo", .display_name = "Bravo" } } } = .{},
};
var loaded_model = OwnedModel{};
var owned_model: ?*OwnedModel = &loaded_model;
var controller: ?rooms.Controller = .{};
var pending_command: ?*PendingCommand = null;
var sent_kind: ?journal.Kind = null;
const rooms = struct {
    const Controller = struct {
        live_send: bool = true,
        room_features: bool = true,
        has_host_uuid: bool = true,
        host_uuid: [36]u8 = test_store.*,
        journal_lock: ?u8 = null,
        job: ?u8 = null,
        fn launchPrepared(_: *Controller, kind: journal.Kind, id: []const u8, room: []const u8, revision: u64) !void {
            const record = staged_record orelse return error.NotPrepared;
            if (!std.mem.eql(u8, id, record.command_id) or !std.mem.eql(u8, room, record.room_id) or revision != record.revision) return error.WrongCommand;
            sent_kind = kind;
        }
    };
};
var staged_record: ?journal.Record = null;
const test_scope = journal.Scope{ .account_digest = @splat('a'), .store_uuid = test_store.* };
fn commandScope(_: StoreLocation) ?journal.Scope { return test_scope; }
fn sameLocation(a: RoomLocation, b: RoomLocation) bool { return std.meta.eql(a, b); }
fn dropDraft(_: RoomLocation, _: []const u8) void {}
fn retryCommandEvidence() !void {}
fn startSnapshot(_: *rooms.Controller) bool { return true; }
fn reset() void {
    if (pending_command) |item| {
        item.arena.deinit();
        std.heap.page_allocator.destroy(item);
    }
    pending_command = null;
    staged_record = null;
    sent_kind = null;
    last_error = "";
    last_log_len = 0;
    loaded_model.value.revision = 1;
    controller = .{};
}
const test_token = room_view.ActionToken{ .generation = 1, .serial = 1, .kind = .submit };
const draft = std.unicode.utf8ToUtf16LeStringLiteral("Hello room");
test "a freshly created room with events loaded sends kind post through the saved command validator" {
    defer reset();
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 1, draft));
    try std.testing.expectEqual(journal.Kind.post, sent_kind.?);
    const record = staged_record.?;
    try std.testing.expectEqual(@as(u64, 1), record.revision);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, record.request, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("post_human", parsed.value.object.get("op").?.string);
    try std.testing.expectEqual(@as(i64, 1), parsed.value.object.get("room_features").?.integer);
    try std.testing.expectEqualStrings("Hello room", parsed.value.object.get("text").?.string);
    try std.testing.expectEqual(@as(usize, 0), parsed.value.object.get("recipients").?.array.items.len);
}
test "send after membership and events refresh uses the refreshed revision" {
    defer reset();
    loaded_model.value.revision = 2;
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 2, draft));
    try std.testing.expectEqual(journal.Kind.post, sent_kind.?);
    try std.testing.expectEqual(@as(u64, 2), staged_record.?.revision);
}
test "stale revision and local validation failures explain why without blaming the connection" {
    defer reset();
    loaded_model.value.revision = 2;
    try std.testing.expectEqual(room_view.ActionResult.failed, beginPost(test_token, test_room, 1, draft));
    try std.testing.expectEqual(@as(?journal.Kind, null), sent_kind);
    try std.testing.expect(std.mem.indexOf(u8, last_error, "members changed") != null);
    try std.testing.expect(std.mem.indexOf(u8, last_log[0..last_log_len], "revision_changed") != null);
    loaded_model.value.revision = 1;
    fail_prepare = true;
    defer fail_prepare = false;
    try std.testing.expectEqual(room_view.ActionResult.failed, beginPost(test_token, test_room, 1, draft));
    try std.testing.expect(std.mem.indexOf(u8, last_error, "on this computer") != null);
    try std.testing.expect(std.mem.indexOf(u8, last_error, "connection") == null);
    try std.testing.expect(std.mem.indexOf(u8, last_log[0..last_log_len], "InvalidJournal") != null);
}
var fail_prepare = false;
