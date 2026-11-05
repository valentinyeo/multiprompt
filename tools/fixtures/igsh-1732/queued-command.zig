const std = @import("std");
const Kind = enum { create, edit, post, catalog, catalog_metadata, snapshot, events, status };
const Pending = struct {
    awaiting_launch: bool = true,
    kind: Kind = .post,
    id: [36]u8 = @splat('i'),
    room_id: [36]u8 = @splat('r'),
    revision: u64 = 7,
    location: u8 = 1,
    token: u8 = 3,
};
const rooms = struct {
    const Completion = union(enum) {
        pending,
        failed: struct { kind: Kind },
        finished: struct {
            kind: Kind,
            fn deinit(_: *@This()) void { disposed += 1; }
        },
    };
    const Controller = struct {
        fail_launch: bool = false,
        launches: usize = 0,
        room: [36]u8 = undefined,
        room_len: usize = 0,
        id: [36]u8 = undefined,
        kind: Kind = .catalog,
        revision: u64 = 0,
        fn launchPrepared(self: *@This(), kind: Kind, id: []const u8, room: []const u8, revision: u64) !void {
            self.launches += 1;
            if (self.fail_launch) return error.Transport;
            self.room_len = room.len;
            @memcpy(self.room[0..room.len], room);
            @memcpy(&self.id, id);
            self.kind = kind;
            self.revision = revision;
        }
    };
};
var controller: ?rooms.Controller = .{};
var pending_command: ?*Pending = null;
var disposed: usize = 0;
var discarded: usize = 0;
var refresh_failed: usize = 0;
var refresh_queued: usize = 0;
var action_failed: usize = 0;
var scope_valid = true;
var visible = true;
var journal_checked_generation: ?u64 = 1;
var discovery: usize = 0;
var front: enum { hidden, selected, create } = .selected;
var selection_waiting = false;
var candidate_scan: usize = 2;
var status_generation: u64 = 1;
var candidate_generation: u64 = 1;
var catalog_generation: u64 = 1;
const Row = struct { id: []const u8 = "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr", metadata_state: enum { loading, queued, ready } = .loading, read_generation: u64 = 1 };
var rows = [_]Row{.{}};
var catalog_rows = struct { items: []Row }{ .items = &rows };
var metadata_read: ?struct { room_id: [36]u8 = @splat('r'), catalog_generation: u64 = 1, read_generation: u64 = 1 } = null;
fn commandScope(_: u8) ?u8 { return if (scope_valid) 1 else null; }
fn commandVisible(_: *Pending) bool { return visible; }
const view = struct {
    fn completeAction(_: u8, _: enum { failed }) void { action_failed += 1; }
};
fn freePending(_: *Pending) void { pending_command = null; }
fn discardBuilding() void { discarded += 1; }
fn finishRefresh(_: *rooms.Controller, success: bool) void { if (!success) refresh_failed += 1; }
fn enqueueRefresh(_: u8) bool { refresh_queued += 1; return true; }
fn scheduleDiscovery(_: *rooms.Controller) void { discovery += 1; }
const app_state = struct { const g_main_hwnd = 0; };
const TIMER_ROOM = 1;
const w = struct {
    fn KillTimer(_: usize, _: usize) bool { return true; }
    fn SetTimer(_: usize, _: usize, _: usize, _: ?*anyopaque) usize { return 1; }
};
fn reset(item: *Pending) void {
    controller = .{};
    pending_command = item;
    disposed = 0;
    discarded = 0;
    refresh_failed = 0;
    refresh_queued = 0;
    action_failed = 0;
    scope_valid = true;
    visible = true;
    discovery = 0;
    front = .selected;
    selection_waiting = false;
    candidate_scan = 2;
    status_generation = 1;
    rows[0] = .{};
    metadata_read = null;
}
test "queued command waits for read then launches exactly once with original identity" {
    var item = Pending{};
    reset(&item);
    const c = &controller.?;
    try std.testing.expect(!launchQueuedCommand(c, .pending, true));
    try std.testing.expectEqual(@as(usize, 0), c.launches);
    try std.testing.expect(launchQueuedCommand(c, .{ .finished = .{ .kind = .catalog } }, true));
    try std.testing.expectEqual(@as(usize, 1), c.launches);
    try std.testing.expectEqual(item.id, c.id);
    try std.testing.expectEqual(item.room_id, c.room);
    try std.testing.expectEqual(item.revision, c.revision);
    try std.testing.expectEqual(Kind.post, c.kind);
    try std.testing.expectEqual(@as(usize, 1), disposed);
    try std.testing.expectEqual(@as(usize, 1), refresh_failed);
    try std.testing.expectEqual(@as(usize, 1), refresh_queued);
    try std.testing.expect(selection_waiting);
    try std.testing.expect(!launchQueuedCommand(c, .{ .finished = .{ .kind = .catalog } }, true));
    try std.testing.expectEqual(@as(usize, 1), c.launches);
}
test "selection changes never reroute an admitted command" {
    var item = Pending{};
    reset(&item);
    visible = false;
    front = .hidden;
    try std.testing.expect(launchQueuedCommand(&controller.?, .{ .failed = .{ .kind = .events } }, true));
    try std.testing.expectEqual(item.room_id, controller.?.room);
    try std.testing.expectEqual(@as(usize, 0), action_failed);
    try std.testing.expectEqual(@as(usize, 1), discarded);
}
test "stale route or account never launches queued command" {
    for ([_]bool{ true, false }) |fresh| {
        var item = Pending{};
        reset(&item);
        scope_valid = !fresh;
        try std.testing.expect(!launchQueuedCommand(&controller.?, .{ .finished = .{ .kind = .catalog } }, fresh));
        try std.testing.expectEqual(@as(usize, 0), controller.?.launches);
        try std.testing.expectEqual(@as(usize, 0), disposed);
        try std.testing.expect(pending_command == null);
    }
}
test "queued creation keeps empty room identity" {
    var item = Pending{ .kind = .create };
    reset(&item);
    front = .create;
    try std.testing.expect(launchQueuedCommand(&controller.?, .{ .failed = .{ .kind = .catalog } }, true));
    try std.testing.expectEqual(@as(usize, 0), controller.?.room_len);
    try std.testing.expectEqual(Kind.create, controller.?.kind);
}
test "launch failure frees pending action and schedules durable recovery" {
    var item = Pending{};
    reset(&item);
    controller.?.fail_launch = true;
    try std.testing.expect(launchQueuedCommand(&controller.?, .{ .finished = .{ .kind = .snapshot } }, true));
    try std.testing.expect(pending_command == null);
    try std.testing.expect(controller == null);
    try std.testing.expect(journal_checked_generation == null);
    try std.testing.expectEqual(@as(usize, 1), discovery);
    try std.testing.expectEqual(@as(usize, 1), action_failed);
    try std.testing.expectEqual(@as(usize, 1), disposed);
}
test "interrupted metadata and status reads remain eligible for refresh" {
    var item = Pending{};
    reset(&item);
    metadata_read = .{};
    try std.testing.expect(launchQueuedCommand(&controller.?, .{ .finished = .{ .kind = .catalog_metadata } }, true));
    try std.testing.expect(rows[0].metadata_state == .queued);
    try std.testing.expect(metadata_read == null);
    item.awaiting_launch = true;
    try std.testing.expect(launchQueuedCommand(&controller.?, .{ .failed = .{ .kind = .status } }, true));
    try std.testing.expectEqual(@as(usize, 1), candidate_scan);
    item.awaiting_launch = true;
    status_generation = 0;
    try std.testing.expect(launchQueuedCommand(&controller.?, .{ .failed = .{ .kind = .status } }, true));
    try std.testing.expectEqual(@as(usize, 1), candidate_scan);
}
