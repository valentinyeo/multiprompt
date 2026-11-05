const std = @import("std");
const journal = struct {
    const State = enum { accepted, rejected };
    fn update(_: u8, _: *const [36]u8, _: State, _: []const u8) !void {}
};
const rooms = struct { const Controller = struct { job: ?*anyopaque = null }; };
const RoomLocation = struct { store: u8, room_id: [36]u8 };
const Pending = struct {
    kind: enum { create, edit, post },
    evidence: ?[]const u8 = "receipt",
    evidence_state: journal.State = .accepted,
    scope: u8 = 1,
    location: u8 = 1,
    id: [36]u8 = @splat('a'),
    room_id: [36]u8 = @splat('r'),
    request: []const u8 = "sent question",
};
var pending_command: ?*Pending = null;
var controller: ?rooms.Controller = .{};
var front: union(enum) { hidden, selected: struct { room_id: [36]u8 } } = .hidden;
var selection_waiting = false;
var snapshots: usize = 0;
var catalogs: usize = 0;
var drafts_cleared: usize = 0;
fn commandScope(_: u8) ?u8 { return 1; }
fn clearPostedDraft(_: RoomLocation, _: []const u8) bool { drafts_cleared += 1; return true; }
fn enqueueRefresh(_: u8) bool { return true; }
fn startSnapshot(_: *rooms.Controller) bool {
    if (!selection_waiting) return false;
    snapshots += 1;
    return true;
}
fn pumpRefresh(_: *rooms.Controller) bool { catalogs += 1; return true; }
fn freePending(_: *Pending) void { pending_command = null; }

test "accepted posts and edits refresh selected history, not just its catalog" {
    for ([_]Pending{ .{ .kind = .post }, .{ .kind = .edit }, .{ .kind = .create } }) |value| {
        var item = value;
        pending_command = &item;
        front = .{ .selected = .{ .room_id = @splat('r') } };
        selection_waiting = false;
        snapshots = 0;
        catalogs = 0;
        drafts_cleared = 0;
        try retryCommandEvidence();
        try std.testing.expectEqual(@as(usize, if (item.kind == .create) 0 else 1), snapshots);
        try std.testing.expectEqual(@as(usize, if (item.kind == .create) 1 else 0), catalogs);
        try std.testing.expectEqual(@as(usize, if (item.kind == .post) 1 else 0), drafts_cleared);
        try std.testing.expect(pending_command == null);
    }
}

test "accepted posts never read another selected rooms history" {
    var item = Pending{ .kind = .post };
    pending_command = &item;
    front = .{ .selected = .{ .room_id = @splat('s') } };
    selection_waiting = false;
    snapshots = 0;
    catalogs = 0;
    try retryCommandEvidence();
    try std.testing.expectEqual(@as(usize, 0), snapshots);
    try std.testing.expectEqual(@as(usize, 1), catalogs);
}

test "rejected posts do not refresh history or clear their draft" {
    var item = Pending{ .kind = .post, .evidence_state = .rejected };
    pending_command = &item;
    front = .{ .selected = .{ .room_id = @splat('r') } };
    selection_waiting = false;
    snapshots = 0;
    drafts_cleared = 0;
    try retryCommandEvidence();
    try std.testing.expectEqual(@as(usize, 0), snapshots);
    try std.testing.expectEqual(@as(usize, 0), drafts_cleared);
}
