const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const os = require('node:os');
const path = require('node:path');

test('room input waits for the multiline composer instead of retaining the creation name field', () => {
  assert.ok(fs.existsSync('tools/verify-rooms/drive.ps1'), 'The native room journey exists');
  const driver = fs.readFileSync('tools/verify-rooms/drive.ps1', 'utf8');
  assert.match(driver, /function Room-Composer\(\[IntPtr\]\$Room\)/);
  assert.match(driver, /GetWindowLongW\(\$edit, -16\) -band 4/);
  assert.match(driver, /Wait-For 'room composer'[^\n]*Room-Composer \$h/);
  assert.match(driver, /Wait-For 'composer owns focus'/);
  assert.match(driver, /Wait-For 'created room selected by the app'/);
  assert.match(driver, /Wait-PaintedMessages 'after-send' 1 2/);
  assert.match(driver, /Wait-PaintedMessages 'after-restart' 1 2/);
  assert.match(driver, /\$_.event.PSObject.Properties\['kind'\]/);
});

for (const source of ['src/room_message.zig', 'src/room_journal.zig', 'src/rooms.zig']) {
  test(`desktop rooms protocol: ${source}`, () => {
    assert.ok(fs.existsSync('src/room_message.zig'), 'Rooms must plan explicit recipients before persisting a message');
    const result = spawnSync(process.env.ZIG || process.env.ZIG_EXE || 'zig', ['test', source], {
      encoding: 'utf8', timeout: 180000, maxBuffer: 8 * 1024 * 1024,
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  });
}


test('accepted room creation waits for its model without exposing an empty room or allowing another create', () => {
  const source = fs.readFileSync('src/room_view.zig', 'utf8');
  function method(signature) {
    const start = source.indexOf(signature);
    const end = source.indexOf('\n    }', start);
    assert.ok(start >= 0 && end > start, `production method ${signature}`);
    return source.slice(start, end + 6);
  }
  function declaration(name) {
    const match = source.match(new RegExp(`^(?:pub )?const ${name} = .+;$`, 'm'));
    assert.ok(match, `production declaration ${name}`);
    return match[0];
  }
  function helper(name) {
    const start = source.indexOf(`fn ${name}(`);
    const end = source.indexOf('\n}', start);
    assert.ok(start >= 0 && end > start, `production helper ${name}`);
    return source.slice(start, end + 2);
  }
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'room-create-state-'));
  try {
    const fixture = String.raw`
const std = @import("std");
const Member = struct { id: []const u8 };
const ViewModel = struct { room_id: []const u8, name: []const u16, members: []const Member = &.{}, candidates: []const Member = &.{} };
` + ['ActionResult', 'ActionKind', 'ActionToken', 'Mode'].map(declaration).join('\n') + '\n' + ['sameRoom', 'validModel'].map(helper).join('\n') + String.raw`
const View = struct {
    model: *const ViewModel,
    mode: Mode,
    pending: ?ActionToken,
    result: ?ActionResult = .pending,
    generation: u64 = 1,
    selected_count: usize = 0,
    scroll: i32 = 0,
    presented_revision: u64 = 0,
    picker: bool = false,
    composer: u32 = 7,
    layout_calls: usize = 0,
    focus_calls: usize = 0,
    owns_focus: bool = true,
    fn clearHits(_: *View) void {}
    fn ownsFocus(self: *View) bool { return self.owns_focus; }
    fn layout(self: *View) void { self.layout_calls += 1; }
    fn setFocus(self: *View, target: u32) void { std.debug.assert(target == self.composer); self.focus_calls += 1; }
    fn invalidate(_: *View) void {}
` + [method('    pub fn completeAction('), method('    pub fn setModel('), method('    fn retire(')].join('\n') + String.raw`
};
test "accepted creation retains creation focus and prevents another admission until the room model arrives" {
    const empty = ViewModel{ .room_id = "", .name = &.{} };
    const room = ViewModel{ .room_id = "room", .name = std.unicode.utf8ToUtf16LeStringLiteral("Product sync") };
    const token = ActionToken{ .generation = 1, .serial = 1, .kind = .create };
    var view = View{ .model = &empty, .mode = .create, .pending = token };
    view.completeAction(token, .accepted);
    try std.testing.expectEqual(Mode.create, view.mode);
    try std.testing.expectEqual(token, view.pending.?);
    try std.testing.expectEqual(@as(usize, 0), view.layout_calls);
    try std.testing.expectEqual(@as(usize, 0), view.focus_calls);
    try std.testing.expect(view.setModel(&room));
    try std.testing.expectEqual(Mode.room, view.mode);
    try std.testing.expectEqual(@as(?ActionToken, null), view.pending);
    try std.testing.expectEqualStrings("room", view.model.room_id);
    try std.testing.expectEqual(@as(usize, 1), view.layout_calls);
    try std.testing.expectEqual(@as(usize, 1), view.focus_calls);
}
test "background publication never steals focus from another view" {
    const empty = ViewModel{ .room_id = "", .name = &.{} };
    const room = ViewModel{ .room_id = "room", .name = std.unicode.utf8ToUtf16LeStringLiteral("Room") };
    var view = View{ .model = &empty, .mode = .create, .pending = null, .owns_focus = false };
    try std.testing.expect(view.setModel(&room));
    try std.testing.expectEqual(@as(usize, 0), view.focus_calls);
    try std.testing.expectEqual(Mode.room, view.mode);
}
test "rejected creation can retry and accepted edits return to the existing room" {
    const room = ViewModel{ .room_id = "room", .name = std.unicode.utf8ToUtf16LeStringLiteral("Room") };
    const create = ActionToken{ .generation = 1, .serial = 1, .kind = .create };
    var view = View{ .model = &room, .mode = .create, .pending = create };
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
    try std.testing.expectEqual(@as(usize, 1), view.focus_calls);
}
`;
    fs.writeFileSync(path.join(directory, 'creation.zig'), fixture);
    const result = spawnSync(process.env.ZIG || process.env.ZIG_EXE || 'zig', ['test', path.join(directory, 'creation.zig')], { encoding: 'utf8', timeout: 180000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
