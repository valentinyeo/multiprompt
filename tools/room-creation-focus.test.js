const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const os = require('node:os');
const path = require('node:path');
const harness = require('./room-view-harness.cjs');

test('accepted room creation waits for its model without exposing an empty room or allowing another create', () => {
  const source = fs.readFileSync('src/room_view.zig', 'utf8');
  const view = harness.view({
    source,
    stub: {
      ownsFocus: '    fn ownsFocus(_: *const View) bool { return owns_focus; }',
      layout: '    fn layout(_: *View) void { layout_calls += 1; }',
      setFocus: '    fn setFocus(self: *View, target: w.HANDLE) void {\n        std.debug.assert(target == self.composer);\n        focus_calls += 1;\n    }',
    },
  });
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'room-create-state-'));
  try {
    fs.writeFileSync(path.join(directory, 'diagnostics.zig'), 'pub fn syncLog(_: []const u8) void {}\n');
    fs.writeFileSync(path.join(directory, 'creation.zig'), String.raw`
const std = @import("std");
const Member = struct { id: []const u8 };
const ViewModel = struct { room_id: []const u8, name: []const u16, members: []const Member = &.{}, candidates: []const Member = &.{}, revision: u64 = 0, messages: []const u8 = &.{} };
const w = struct {
    pub const BOOL = i32;
    pub const HANDLE = ?*anyopaque;
    pub const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
    pub fn InvalidateRect(_: HANDLE, _: ?*const RECT, _: BOOL) BOOL { return 1; }
};
var owns_focus = true;
var layout_calls: usize = 0;
var focus_calls: usize = 0;
var context: u8 = 0;
fn onCreate(_: *anyopaque, _: ActionToken, _: []const u16, _: []const []const u8) ActionResult { return .pending; }
fn onEdit(_: *anyopaque, _: ActionToken, _: []const u8, _: u64, _: []const u16, _: []const []const u8) ActionResult { return .pending; }
fn onSubmit(_: *anyopaque, _: ActionToken, _: []const u8, _: u64, _: []const u16) ActionResult { return .pending; }
fn onRestart(_: *anyopaque, _: ActionToken, _: []const u8, _: []const u8) ActionResult { return .pending; }
const callbacks = Callbacks{ .context = &context, .create = onCreate, .edit = onEdit, .submit = onSubmit, .restart = onRestart };
` + view + String.raw`
test "accepted creation retains creation focus and prevents another admission until the room model arrives" {
    defer {
        owns_focus = true;
        layout_calls = 0;
        focus_calls = 0;
    }
    const empty = ViewModel{ .room_id = "", .name = &.{} };
    const room = ViewModel{ .room_id = "room", .name = std.unicode.utf8ToUtf16LeStringLiteral("Product sync") };
    const token = ActionToken{ .generation = 1, .serial = 1, .kind = .create };
    var view = View{ .model = &empty, .callbacks = callbacks, .mode = .create, .pending = token };
    view.completeAction(token, .accepted);
    try std.testing.expectEqual(Mode.create, view.mode);
    try std.testing.expectEqual(token, view.pending.?);
    try std.testing.expectEqual(@as(usize, 0), layout_calls);
    try std.testing.expectEqual(@as(usize, 0), focus_calls);
    try std.testing.expect(view.setModel(&room));
    try std.testing.expectEqual(Mode.room, view.mode);
    try std.testing.expectEqual(@as(?ActionToken, null), view.pending);
    try std.testing.expectEqualStrings("room", view.model.room_id);
    try std.testing.expectEqual(@as(usize, 1), layout_calls);
    try std.testing.expectEqual(@as(usize, 1), focus_calls);
}
test "background publication never steals focus from another view" {
    defer owns_focus = true;
    const empty = ViewModel{ .room_id = "", .name = &.{} };
    const room = ViewModel{ .room_id = "room", .name = std.unicode.utf8ToUtf16LeStringLiteral("Room") };
    owns_focus = false;
    var view = View{ .model = &empty, .callbacks = callbacks, .mode = .create, .pending = null };
    try std.testing.expect(view.setModel(&room));
    try std.testing.expectEqual(@as(usize, 0), focus_calls);
    try std.testing.expectEqual(Mode.room, view.mode);
}
test "rejected creation can retry and accepted edits return to the existing room" {
    defer focus_calls = 0;
    const room = ViewModel{ .room_id = "room", .name = std.unicode.utf8ToUtf16LeStringLiteral("Room") };
    const create = ActionToken{ .generation = 1, .serial = 1, .kind = .create };
    var view = View{ .model = &room, .callbacks = callbacks, .mode = .create, .pending = create };
    view.completeAction(create, .failed);
    try std.testing.expectEqual(Mode.create, view.mode);
    try std.testing.expectEqual(@as(?ActionToken, null), view.pending);
    const edit = ActionToken{ .generation = 1, .serial = 2, .kind = .edit };
    view.mode = .edit;
    view.pending = edit;
    view.completeAction(create, .accepted);
    try std.testing.expectEqual(edit, view.pending.?);
    try std.testing.expectEqual(Mode.edit, view.mode);
    view.completeAction(edit, .accepted);
    try std.testing.expectEqual(Mode.room, view.mode);
    try std.testing.expectEqual(@as(?ActionToken, null), view.pending);
    try std.testing.expectEqual(@as(usize, 1), focus_calls);
}
`);
    const result = spawnSync(process.env.ZIG || process.env.ZIG_EXE || 'zig', ['test', path.join(directory, 'creation.zig')], { encoding: 'utf8', timeout: 180000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
