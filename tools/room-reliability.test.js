const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const roomView = require('./room-view-harness.cjs');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
function declaration(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, marker);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, marker);
  return source.slice(start, end + 2) + (source[end + 2] === ';' ? ';' : '');
}
function run(source, files = {}, expectedStatus = 0) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'room-reliability-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), source);
    for (const [name, contents] of Object.entries(files)) fs.writeFileSync(path.join(dir, name), contents);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'test.zig'], { cwd: dir, encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined, result.error?.message);
    assert.equal(result.status, expectedStatus, `${result.stdout || ''}${result.stderr || ''}`);
    return result.stderr;
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('refresh survives restart and the newest answer cannot hide an older unanswered question', () => {
  const source = read('room_frontend.zig');
  run(`
const std = @import("std");
const HumanEvent = struct { id: []const u8, recipients: []const []const u8 };
const Message = struct { author: ?u8 = 1, question_id: []const u8, member_id: []const u8 = "beta" };
const OwnedModel = struct {
    human_events: struct { items: []const HumanEvent },
    messages: struct { items: []const Message },
    bindings: struct { items: []const struct { id: []const u8 } } = .{ .items = &.{ .{ .id = "alpha" }, .{ .id = "beta" } } },
    value: struct { room_id: []const u8 = "room" } = .{},
};
const Location = struct { room_id: [4]u8 = "room".* };
var front: union(enum) { hidden, selected: Location } = .{ .selected = .{} };
var owned_model: ?*OwnedModel = null;
const enabled = true;
const created = true;
var shown = true;
var visible = true;
const reply_fast_ms = 120000;
const reply_window_ms = 1800000;
var last_post_room: ?Location = null;
var last_post_tick: u64 = 0;
const w = struct { fn GetTickCount64() u64 { return 3600000; } };
fn isVisible() bool { return visible; }
fn sameLocation(a: Location, b: Location) bool { return std.meta.eql(a, b); }
${declaration(source, 'fn replyPending(')}
${declaration(source, 'fn replyDelay(')}
test "restart refreshes all stored unanswered questions without a recent send" {
    const questions = [_]HumanEvent{ .{ .id = "older", .recipients = &.{ "alpha", "beta" } }, .{ .id = "newer", .recipients = &.{"beta"} } };
    const answers = [_]Message{ .{ .question_id = "older", .member_id = "alpha" }, .{ .question_id = "newer" } };
    var item = OwnedModel{ .human_events = .{ .items = &questions }, .messages = .{ .items = &answers } };
    owned_model = &item;
    try std.testing.expect(replyPending(&item));
    try std.testing.expect(replyDelay() != null);
    front = .hidden;
    try std.testing.expectEqual(@as(?u32, null), replyDelay());
    front = .{ .selected = .{} };
    try std.testing.expect(replyDelay() != null);
    const complete = [_]Message{ answers[0], answers[1], .{ .question_id = "older" } };
    item.messages.items = &complete;
    try std.testing.expect(!replyPending(&item));
    try std.testing.expectEqual(@as(?u32, null), replyDelay());
}
`);
});

test('freshly created rooms send posts through the journal, including capability-gated requests', () => {
  const frontend = read('room_frontend.zig');
  const journal = read('room_journal.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/room-send.zig'), 'utf8');
  const declarations = ['pub const StoreLocation = struct {', 'pub const RoomLocation = struct {', 'pub const Front = union(enum) {', 'const PendingCommand = struct {'];
  const source = `${fixture}
${declarations.map(marker => declaration(frontend, marker)).join('\n')}
const PendingBinding = journal.Binding;
var front: Front = .{ .selected = .{ .store = .{ .account = @splat(0), .account_len = 0, .store_uuid = test_store.* }, .room_id = test_room.* } };
const journal = struct {
    ${['pub const Kind = enum', 'pub const State = enum', 'pub const Scope = struct', 'pub const Binding = struct'].map(marker => journal.slice(journal.indexOf(marker), journal.indexOf('\n', journal.indexOf(marker)))).join('\n')}
    ${declaration(journal, 'pub const Record = struct {')}
    ${['fn field(', 'fn text(', 'fn number(', 'fn uuidValid(', 'fn validText(', 'fn validAlias(', 'fn validPostRequest('].map(marker => declaration(journal, marker)).join('\n')}
    const Entry = struct {
        value: Record,
        fn record(self: *const Entry) *const Record { return &self.value; }
        fn deinit(_: *Entry) void {}
    };
    fn newCommandId() ?[36]u8 { return test_command.*; }
    fn load(_: Scope) !?Entry {
        if (existing_record) |record| return Entry{ .value = record };
        return Entry{ .value = .{ .account_digest = &test_scope.account_digest, .store_uuid = test_store, .kind = .create, .command_id = test_room, .room_id = "", .revision = 0, .request = "", .bindings = &.{}, .state = .accepted, .evidence = "" } };
    }
    fn abandon(_: Scope, id: []const u8) !void {
        const record = existing_record orelse return error.NotFound;
        if (record.state == .uncertain) return error.UnresolvedCommand;
        if (record.state != .prepared) return error.TerminalCommand;
        if (!std.mem.eql(u8, record.command_id, id)) return error.WrongCommand;
        existing_record = null;
        abandoned += 1;
    }
    fn prepare(_: Scope, kind: Kind, id: []const u8, room: []const u8, revision: u64, request: []const u8, bindings: []const Binding) !void {
        if (existing_record) |saved| {
            if ((saved.state == .prepared or saved.state == .uncertain) and (!std.mem.eql(u8, saved.command_id, id) or !std.mem.eql(u8, saved.request, request))) return error.UnresolvedCommand;
        }
        const record = Record{ .account_digest = &test_scope.account_digest, .store_uuid = test_store, .kind = kind, .command_id = id, .room_id = room, .revision = revision, .request = request, .bindings = bindings, .state = .prepared, .evidence = "" };
        var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, request, .{});
        defer parsed.deinit();
        if (fail_prepare or !validPostRequest(record, parsed.value)) return error.InvalidJournal;
        staged_record = record;
    }
};
${frontend.includes('fn rejectPost(') ? declaration(frontend, 'fn rejectPost(') : ''}
${['fn postRequest(', 'fn resumeSavedSend(', 'fn beginPost('].map(marker => declaration(frontend, marker)).join('\n')}
test "legacy requests remain valid and unknown capabilities or extra fields are rejected" {
    defer reset();
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 1, draft));
    const record = staged_record.?;
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, record.request, .{});
    defer parsed.deinit();
    try std.testing.expect(journal.validPostRequest(record, parsed.value));
    parsed.value.object.getPtr("room_features").?.* = .{ .integer = 2 };
    try std.testing.expect(!journal.validPostRequest(record, parsed.value));
    parsed.value.object.getPtr("room_features").?.* = .null;
    try std.testing.expect(!journal.validPostRequest(record, parsed.value));
    _ = parsed.value.object.swapRemove("room_features");
    try std.testing.expect(journal.validPostRequest(record, parsed.value));
    try parsed.value.object.put(std.testing.allocator, "unexpected", .{ .integer = 1 });
    defer _ = parsed.value.object.swapRemove("unexpected");
    try std.testing.expect(!journal.validPostRequest(record, parsed.value));
}
const rewritten_draft = std.unicode.utf8ToUtf16LeStringLiteral("Hello rooms");
fn sentRequest(buffer: []u8) []const u8 {
    @memcpy(buffer[0..staged_record.?.request.len], staged_record.?.request);
    return buffer[0..staged_record.?.request.len];
}
test "a send the room may have accepted is confirmed before a changed draft replaces it" {
    defer reset();
    var buffer: [4096]u8 = undefined;
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 1, draft));
    const earlier_request = sentRequest(&buffer);
    reset();
    existing_record = .{ .account_digest = &test_scope.account_digest, .store_uuid = test_store, .kind = .post, .command_id = test_command, .room_id = test_room, .revision = 1, .request = earlier_request, .bindings = &.{}, .state = .uncertain, .evidence = "" };
    try std.testing.expectEqual(room_view.ActionResult.failed, beginPost(test_token, test_room, 1, rewritten_draft));
    try std.testing.expectEqual(@as(usize, 0), abandoned);
    try std.testing.expect(existing_record != null);
    try std.testing.expect(staged_record == null);
    try std.testing.expectEqual(@as(?journal.Kind, null), sent_kind);
    try std.testing.expect(confirmed != null);
    try std.testing.expect(std.mem.eql(u8, confirmed.?.command_id, test_command));
    try std.testing.expect(std.mem.eql(u8, confirmed.?.request, earlier_request));
    try std.testing.expect(std.mem.indexOf(u8, last_error, "still being confirmed") != null);
    try std.testing.expect(std.mem.indexOf(u8, last_error, "draft is kept") != null);
    try std.testing.expect(std.mem.indexOf(u8, last_log[0..last_log_len], "confirming") != null);
}
test "a send that never reached the room is resent with its own body instead of the changed draft" {
    defer reset();
    var buffer: [4096]u8 = undefined;
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 1, draft));
    const earlier_request = sentRequest(&buffer);
    reset();
    existing_record = .{ .account_digest = &test_scope.account_digest, .store_uuid = test_store, .kind = .post, .command_id = test_command, .room_id = test_room, .revision = 1, .request = earlier_request, .bindings = &.{}, .state = .uncertain, .evidence = "" };
    try std.testing.expectEqual(room_view.ActionResult.failed, beginPost(test_token, test_room, 1, rewritten_draft));
    try std.testing.expect(confirmed != null);
    try std.testing.expect(std.mem.indexOf(u8, confirmed.?.request, "Hello room") != null);
    try std.testing.expect(std.mem.indexOf(u8, confirmed.?.request, "Hello rooms") == null);
    try std.testing.expect(staged_record == null);
}
test "a definite refusal lets the next message start a fresh command" {
    defer reset();
    existing_record = .{ .account_digest = &test_scope.account_digest, .store_uuid = test_store, .kind = .post, .command_id = "40000000-0000-4000-8000-000000000004", .room_id = test_room, .revision = 1, .request = "refused", .bindings = &.{}, .state = .rejected, .evidence = "{\\"error\\":\\"room_host_upgrade_required\\"}" };
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 1, draft));
    try std.testing.expectEqual(@as(usize, 0), abandoned);
    try std.testing.expectEqual(journal.Kind.post, sent_kind.?);
    try std.testing.expect(!std.mem.eql(u8, staged_record.?.command_id, "40000000-0000-4000-8000-000000000004"));
    try std.testing.expect(std.mem.eql(u8, staged_record.?.command_id, test_command));
}
test "retrying the same draft keeps its original command id" {
    defer reset();
    var buffer: [4096]u8 = undefined;
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 1, draft));
    const earlier_request = sentRequest(&buffer);
    reset();
    existing_record = .{ .account_digest = &test_scope.account_digest, .store_uuid = test_store, .kind = .post, .command_id = test_command, .room_id = test_room, .revision = 1, .request = earlier_request, .bindings = &.{}, .state = .uncertain, .evidence = "" };
    try std.testing.expectEqual(room_view.ActionResult.pending, beginPost(test_token, test_room, 1, draft));
    try std.testing.expectEqual(@as(usize, 0), abandoned);
    try std.testing.expect(confirmed == null);
    try std.testing.expect(std.mem.eql(u8, staged_record.?.command_id, test_command));
    try std.testing.expect(std.mem.eql(u8, staged_record.?.request, earlier_request));
}
`;
  const files = { 'room_post.zig': read('room_post.zig') };
  run(source, files);
  const before = source.replace(/    const features = field\(obj, "room_features"\);[\s\S]*?    const op = text\(obj, "op"\) orelse return false;/, '    if (obj.object.count() != 7 or r.bindings.len != 0 or r.revision == 0 or !uuidValid(r.room_id)) return false;\n    const op = text(obj, "op") orelse return false;');
  assert.notEqual(before, source);
  assert.match(run(before, files, 1), /a freshly created room with events loaded sends kind post through the saved command validator\.\.\.[\s\S]*FAIL \(TestExpectedEqual\)/);
  const replaced = source.replace('if (earlier.? == .uncertain) {', 'if (earlier.? == .accepted) {');
  assert.notEqual(replaced, source);
  const unresolved = run(replaced, files, 1);
  assert.match(unresolved, /a send the room may have accepted is confirmed before a changed draft replaces it\.\.\.[\s\S]*FAIL/);
  assert.match(unresolved, /a send that never reached the room is resent with its own body instead of the changed draft\.\.\.[\s\S]*FAIL/);
});

test('a saved room send is shown before the room is read again', () => {
  const frontend = read('room_frontend.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/accepted-post.zig'), 'utf8');
  run(`${fixture}\n${declaration(frontend, 'fn applyAcceptedPost(')}\n${declaration(frontend, 'fn wide(')}`, { 'room_post.zig': read('room_post.zig') });
  const hidden = frontend.replace('    loaded.value.messages = loaded.messages.items;\n', '');
  assert.notEqual(hidden, frontend);
  assert.match(run(`${fixture}\n${declaration(hidden, 'fn applyAcceptedPost(')}\n${declaration(hidden, 'fn wide(')}`, { 'room_post.zig': read('room_post.zig') }, 1), /a saved send is shown in the room before the room is read again[\s\S]*FAIL/);
});

test('a send pressed while a room opens is held for that room and never sent elsewhere', () => {
  const source = read('room_view.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/deferred-send.zig'), 'utf8');
  const stubs = {
    draft: `    fn draft(_: *View, buffer: []u16) ?[]const u16 {
        if (w.composer_len == 0 or w.composer_len >= buffer.len) return null;
        @memcpy(buffer[0..w.composer_len], w.composer_text[0..w.composer_len]);
        return buffer[0..w.composer_len];
    }`,
  };
  const harness = `
const std = @import("std");
const w = struct {
    pub const BOOL = i32;
    pub const HANDLE = ?*anyopaque;
    pub const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
    var composer_text: [256]u16 = @splat(0);
    var composer_len: usize = 0;
    fn compose(value: []const u16) void {
        @memcpy(composer_text[0..value.len], value);
        composer_len = value.len;
    }
    pub fn GetWindowTextLengthW(_: HANDLE) i32 {
        return @intCast(composer_len);
    }
    pub fn GetWindowTextW(_: HANDLE, buffer: [*]u16, count: i32) i32 {
        if (count <= 0) return 0;
        const length = @min(composer_len, @as(usize, @intCast(count)));
        @memcpy(buffer[0..length], composer_text[0..length]);
        return @intCast(length);
    }
    pub fn InvalidateRect(_: HANDLE, _: ?*const RECT, _: BOOL) BOOL {
        return 1;
    }
};
const Member = struct { id: []const u8 };
const ViewModel = struct {
    room_id: []const u8,
    name: []const u16 = &.{},
    revision: u64 = 0,
    members: []const Member = &.{},
    candidates: []const Member = &.{},
    messages: []const u8 = &.{},
};
var sent: usize = 0;
var sent_room: []const u8 = "";
var sent_revision: u64 = 0;
var sent_text: [256]u16 = @splat(0);
var sent_len: usize = 0;
var context: u8 = 0;
fn onSubmit(_: *anyopaque, _: ActionToken, room_id: []const u8, revision: u64, text: []const u16) ActionResult {
    sent += 1;
    sent_room = room_id;
    sent_revision = revision;
    sent_len = text.len;
    @memcpy(sent_text[0..text.len], text);
    return .accepted;
}
fn onEntry(_: *anyopaque, _: ActionToken, _: []const u16, _: []const []const u8) ActionResult {
    return .failed;
}
fn onEdit(_: *anyopaque, _: ActionToken, _: []const u8, _: u64, _: []const u16, _: []const []const u8) ActionResult {
    return .failed;
}
fn onRestart(_: *anyopaque, _: ActionToken, _: []const u8, _: []const u8) ActionResult {
    return .failed;
}
const callbacks = Callbacks{ .context = &context, .create = onEntry, .edit = onEdit, .submit = onSubmit, .restart = onRestart };
fn reset() void {
    sent = 0;
    sent_room = "";
    sent_revision = 0;
    sent_len = 0;
    w.compose(&.{});
}
${roomView.view({ source, copy: ['flushDeferred'], stub: stubs })}
${fixture}`;
  run(harness, { 'diagnostics.zig': 'pub fn syncLog(_: []const u8) void {}\n' });
  const alwaysSends = harness.replace('        if (w.GetWindowTextLengthW(self.composer) <= 0) return;\n', '');
  assert.notEqual(alwaysSends, harness);
  assert.match(run(alwaysSends, { 'diagnostics.zig': 'pub fn syncLog(_: []const u8) void {}\n' }, 1), /a held send whose draft was cleared sends nothing and shows no error[\s\S]*FAIL/);
  const unscoped = harness.replace('        if (!self.openingRoom(room_id)) self.deferred_submit = false;\n', '');
  assert.notEqual(unscoped, harness);
  assert.match(run(unscoped, { 'diagnostics.zig': 'pub fn syncLog(_: []const u8) void {}\n' }, 1), /a held send never follows you into another room or back again[\s\S]*FAIL/);
});

test('a finished room send releases the action the view is holding without touching the draft', () => {
  const source = read('room_view.zig');
  const stubs = {
    draft: `    fn draft(_: *View, buffer: []u16) ?[]const u16 {
        if (w.composer_len == 0 or w.composer_len >= buffer.len) return null;
        @memcpy(buffer[0..w.composer_len], w.composer_text[0..w.composer_len]);
        return buffer[0..w.composer_len];
    }`,
  };
  run(`
const std = @import("std");
const w = struct {
    pub const BOOL = i32;
    pub const HANDLE = ?*anyopaque;
    pub const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
    var composer_text: [256]u16 = @splat(0);
    var composer_len: usize = 0;
    fn compose(value: []const u16) void {
        @memcpy(composer_text[0..value.len], value);
        composer_len = value.len;
    }
    pub fn GetWindowTextLengthW(_: HANDLE) i32 { return @intCast(composer_len); }
    pub fn GetWindowTextW(_: HANDLE, buffer: [*]u16, count: i32) i32 {
        if (count <= 0) return 0;
        const length = @min(composer_len, @as(usize, @intCast(count)));
        @memcpy(buffer[0..length], composer_text[0..length]);
        return @intCast(length);
    }
    pub fn InvalidateRect(_: HANDLE, _: ?*const RECT, _: BOOL) BOOL { return 1; }
};
const Member = struct { id: []const u8 };
const ViewModel = struct {
    room_id: []const u8,
    name: []const u16 = &.{},
    revision: u64 = 0,
    members: []const Member = &.{},
    candidates: []const Member = &.{},
    messages: []const u8 = &.{},
};
var sent: usize = 0;
var context: u8 = 0;
fn onSubmit(_: *anyopaque, _: ActionToken, _: []const u8, _: u64, _: []const u16) ActionResult { sent += 1; return .pending; }
fn onEntry(_: *anyopaque, _: ActionToken, _: []const u16, _: []const []const u8) ActionResult { return .failed; }
fn onEdit(_: *anyopaque, _: ActionToken, _: []const u8, _: u64, _: []const u16, _: []const []const u8) ActionResult { return .failed; }
fn onRestart(_: *anyopaque, _: ActionToken, _: []const u8, _: []const u8) ActionResult { return .failed; }
const callbacks = Callbacks{ .context = &context, .create = onEntry, .edit = onEdit, .submit = onSubmit, .restart = onRestart };
${roomView.view({ source, stub: stubs })}
test "a send the room accepted keeps the draft until the answer arrives" {
    const room = ViewModel{ .room_id = "room-a", .revision = 4 };
    var view = View{ .model = &room, .callbacks = callbacks };
    try std.testing.expect(view.setModel(&room));
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Hello room"));
    view.submit();
    const token = view.pending orelse return error.NoPending;
    try std.testing.expectEqual(@as(usize, 1), sent);
    try std.testing.expectEqual(ActionResult.pending, view.result.?);
    try std.testing.expectEqual(@as(usize, 10), w.composer_len);
    view.completeAction(token, .accepted);
    try std.testing.expectEqual(@as(?ActionToken, null), view.pending);
    try std.testing.expectEqual(ActionResult.accepted, view.result.?);
    try std.testing.expectEqual(@as(usize, 10), w.composer_len);
}
test "an older send cannot release the action a newer one is holding" {
    const room = ViewModel{ .room_id = "room-a", .revision = 4 };
    const other = ViewModel{ .room_id = "room-b", .revision = 9 };
    var view = View{ .model = &room, .callbacks = callbacks };
    try std.testing.expect(view.setModel(&room));
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Hello room"));
    view.submit();
    const stale = view.pending.?;
    try std.testing.expect(view.setModel(&other));
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Second room"));
    view.submit();
    const current = view.pending.?;
    try std.testing.expect(!std.meta.eql(stale, current));
    view.completeAction(stale, .accepted);
    try std.testing.expectEqual(current, view.pending.?);
    view.completeAction(current, .accepted);
    try std.testing.expectEqual(@as(?ActionToken, null), view.pending);
}
`, { 'diagnostics.zig': 'pub fn syncLog(_: []const u8) void {}\n' });
});

test('a room command that finishes releases its view action wherever the user is looking', () => {
  const frontend = read('room_frontend.zig');
  const gated = source => /if \(visible\) view\.completeAction/.test(source) || /if \(commandVisible\(item\)\) \{[^}]*view\.completeAction/.test(source);
  const finish = frontend.slice(frontend.indexOf('fn finishCommand('), frontend.indexOf('fn driveRestore('));
  const launch = frontend.slice(frontend.indexOf('fn launchQueuedCommand('), frontend.indexOf('pub fn pollTimer('));
  const evidence = frontend.slice(frontend.indexOf('pub fn retryCommandEvidence('), frontend.indexOf('fn matchesPending('));
  for (const part of [finish, launch, evidence]) {
    assert.ok(part.length > 0, 'production room command path is present');
    assert.ok(!gated(part), 'a finished room command releases its action without a visibility test');
  }
  assert.match(finish, /releaseCommandAction\(item, /);
  assert.match(launch, /releaseCommandAction\(item, /);
  assert.match(evidence, /releaseCommandAction\(item, item\.evidence_state == \.accepted\);\n    freePending\(item\);/);
  assert.ok(gated('if (visible) view.completeAction(item.token, .failed);'), 'the visibility gate would fail this check');
});

test('a saved room send keeps the command identity the room store deduplicates on', () => {
  const frontend = read('room_frontend.zig');
  const journal = read('room_journal.zig');
  const service = read('room_service.py');
  assert.ok(journal.includes('if (record.state == .uncertain) return error.UnresolvedCommand;'), 'a command that may have reached the room is never deleted');
  assert.ok(journal.includes('return validErrorCode(code);'), 'a definite refusal is kept under any code the room host reports');
  assert.ok(frontend.includes('retryCommand(location) catch |err| return rejectPost'), 'a saved command is resent before a changed draft replaces it');
  assert.ok(frontend.includes('journal.abandon(scope, &item.id)'), 'only a command that never left this computer may be replaced');
  assert.ok(service.includes("result = json.loads(previous['receipt'])"), 'an identical retry returns the original receipt instead of a second message');
});

test('a room send the room never confirmed is retried from the journal instead of locking the composer', () => {
  const frontend = read('room_frontend.zig');
  assert.ok(frontend.includes('fn stillWorking('), 'the view asks the room frontend whether a saved action is still running');
  assert.ok(frontend.includes('.still_working = stillWorking'), 'the production view receives that answer');
  assert.ok(frontend.includes('resumeSavedSend(c)'), 'a saved send whose transport stopped is retried rather than refused forever');
  assert.ok(frontend.includes('@memcpy(&item.id, record.command_id);'), 'the retry reloads the saved command identity so the room cannot store the message twice');
  assert.ok(frontend.includes('item.request = try a.dupe(u8, record.request);'), 'the retry reloads the saved body so a rewritten draft is never sent in its place');
  assert.ok(frontend.includes('rejectPost("command_confirming"'), 'the retry tells the user the earlier message is still being confirmed');
  const resumed = frontend.slice(frontend.indexOf('fn resumeSavedSend('), frontend.indexOf('fn beginPost('));
  assert.ok(!/journal\.abandon|newCommandId|launchPrepared|SetTimer|dropDraft/.test(resumed), 'a resumed send neither abandons the saved command nor launches or times a copy of its own');
  const retry = frontend.slice(frontend.indexOf('pub fn retryCommand('), frontend.indexOf('pub fn retryCommandEvidence('));
  assert.ok(retry.includes('if (pending_command) |item| {\n        if (item.evidence != null) return error.CommandBusy;\n        releaseCommandAction(item, false);\n        freePending(item);'), 'the retry takes over the saved copy so the saved journal command can lead it');
  assert.ok(!/journal\.abandon|newCommandId|dropDraft/.test(retry), 'the retry keeps both the journal record and the draft');
  assert.ok(frontend.includes('fn stopPoll(c: *const rooms.Controller) void {\n    if (c.job != null or savedSendAwaitingOutcome()) return;'), 'room polling keeps running while a reply or a saved send is outstanding');
});

test('a saved room send that the frontend no longer runs does not keep the composer locked', () => {
  const source = read('room_view.zig');
  const stubs = {
    draft: `    fn draft(_: *View, buffer: []u16) ?[]const u16 {
        if (w.composer_len == 0 or w.composer_len >= buffer.len) return null;
        @memcpy(buffer[0..w.composer_len], w.composer_text[0..w.composer_len]);
        return buffer[0..w.composer_len];
    }`,
  };
  run(`
const std = @import("std");
const w = struct {
    pub const BOOL = i32;
    pub const HANDLE = ?*anyopaque;
    pub const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
    var composer_text: [256]u16 = @splat(0);
    var composer_len: usize = 0;
    fn compose(value: []const u16) void {
        @memcpy(composer_text[0..value.len], value);
        composer_len = value.len;
    }
    pub fn GetWindowTextLengthW(_: HANDLE) i32 { return @intCast(composer_len); }
    pub fn GetWindowTextW(_: HANDLE, buffer: [*]u16, count: i32) i32 {
        if (count <= 0) return 0;
        const length = @min(composer_len, @as(usize, @intCast(count)));
        @memcpy(buffer[0..length], composer_text[0..length]);
        return @intCast(length);
    }
    pub fn InvalidateRect(_: HANDLE, _: ?*const RECT, _: BOOL) BOOL { return 1; }
};
const Member = struct { id: []const u8 };
const ViewModel = struct {
    room_id: []const u8,
    name: []const u16 = &.{},
    revision: u64 = 0,
    members: []const Member = &.{},
    candidates: []const Member = &.{},
    messages: []const u8 = &.{},
};
var sent: usize = 0;
var send_in_flight = true;
var context: u8 = 0;
fn onSubmit(_: *anyopaque, _: ActionToken, _: []const u8, _: u64, _: []const u16) ActionResult { sent += 1; return .pending; }
fn onEntry(_: *anyopaque, _: ActionToken, _: []const u16, _: []const []const u8) ActionResult { return .failed; }
fn onEdit(_: *anyopaque, _: ActionToken, _: []const u8, _: u64, _: []const u16, _: []const []const u8) ActionResult { return .failed; }
fn onRestart(_: *anyopaque, _: ActionToken, _: []const u8, _: []const u8) ActionResult { return .failed; }
fn stillWorking(_: *anyopaque, _: ActionToken) bool { return send_in_flight; }
const callbacks = Callbacks{ .context = &context, .create = onEntry, .edit = onEdit, .submit = onSubmit, .restart = onRestart, .still_working = stillWorking };
${roomView.view({ source, stub: stubs })}
test "a send the frontend still runs keeps the composer waiting" {
    const room = ViewModel{ .room_id = "room-a", .revision = 4 };
    var view = View{ .model = &room, .callbacks = callbacks };
    try std.testing.expect(view.setModel(&room));
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("First room message"));
    view.submit();
    try std.testing.expectEqual(@as(usize, 1), sent);
    send_in_flight = true;
    w.compose(std.unicode.utf8ToUtf16LeStringLiteral("Second room message"));
    view.submit();
    try std.testing.expectEqual(@as(usize, 1), sent);
    try std.testing.expectEqual(ActionResult.failed, view.result.?);
    send_in_flight = false;
    view.submit();
    try std.testing.expectEqual(@as(usize, 2), sent);
}
`, { 'diagnostics.zig': 'pub fn syncLog(_: []const u8) void {}\n' });
});

test('shown-name mentions support spaces, case, legacy aliases and reject ambiguous names', () => {
  run(`
const std = @import("std");
const post = @import("room_post.zig");
test "names resolve to stable aliases" {
    const members = [_]post.Recipient{ .{ .alias = "agent_123", .display_name = "Research Notes" }, .{ .alias = "beta", .display_name = "Beta" } };
    var out: [post.max_recipients][]const u8 = undefined;
    try std.testing.expectEqual(@as(?usize, 1), post.namedRecipients("@rEsEaRcH nOtEs hello", &members, &out));
    try std.testing.expectEqualStrings("agent_123", out[0]);
    try std.testing.expectEqual(@as(?usize, 1), post.namedRecipients("@agent_123 again", &members, &out));
    try std.testing.expectEqual(@as(?usize, null), post.namedRecipients("@Research NotesElse", &members, &out));
    try std.testing.expectEqual(@as(?usize, 0), post.namedRecipients("a@b.example", &members, &out));
    const ambiguous = [_]post.Recipient{ .{ .alias = "a", .display_name = "Same" }, .{ .alias = "b", .display_name = "Same" } };
    try std.testing.expectEqual(@as(?usize, null), post.namedRecipients("@same hello", &ambiguous, &out));
}
`, { 'room_post.zig': read('room_post.zig') });
});

test('the member picker accepts unopened server chats without requiring local shells', () => {
  const source = read('room_frontend.zig');
  run(`
const std = @import("std");
const rooms = struct { const Controller = struct { host_uuid: [36]u8 = @splat('s') }; };
${declaration(source, 'const Candidate = struct {')}
var candidates: [768]Candidate = undefined;
var candidate_count: usize = 0;
var status_generation: u64 = 1;
var candidate_generation: u64 = 1;
var member_names: std.StringHashMapUnmanaged([]u8) = .empty;
var route_key: [64]u8 = @splat('0');
${declaration(source, 'fn textField(')}
${declaration(source, 'fn memberDisplayName(')}
${declaration(source, 'fn acceptMembers(')}
test "unopened chats retain their shown names and stable bindings" {
    const data = "{\\"members\\":[{\\"provider\\":\\"claude\\",\\"sid\\":\\"unopened-server-chat\\",\\"display_name\\":\\"Research Notes\\",\\"alive\\":false}]}";
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, data, .{});
    defer parsed.deinit();
    const c = rooms.Controller{};
    try std.testing.expect(acceptMembers(&c, parsed.value));
    try std.testing.expectEqual(@as(usize, 1), candidate_count);
    try std.testing.expectEqualStrings("Research Notes", candidates[0].display_name[0..candidates[0].display_name_len]);
    try std.testing.expectEqualStrings("claude:unopened-server-chat", candidates[0].session_identity[0..candidates[0].session_identity_len]);
    const alias = candidates[0].alias;
    const alias_len = candidates[0].alias_len;
    try std.testing.expect(acceptMembers(&c, parsed.value));
    try std.testing.expectEqualSlices(u8, alias[0..alias_len], candidates[0].alias[0..candidates[0].alias_len]);
    try std.testing.expect(!candidates[0].online);
}
`);
});

test('creation uses account display names for unopened server chats and retains them after closing a tab', () => {
  const source = read('room_frontend.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/member-names.zig'), 'utf8');
  const harness = `${fixture}\n${declaration(source, 'const Candidate = struct {')}\n${declaration(source, 'fn cacheMemberNames(')}\n${declaration(source, 'fn memberDisplayName(')}\n${declaration(source, 'fn textField(')}\n${declaration(source, 'fn acceptMembers(')}`;
  const files = { 'session_layout.zig': 'pub const Tab = struct { tmux_host: u8, tmux_session: []const u8, name: []const u8 };\n' };
  run(harness, files);
  const before = harness.replace('const name = memberDisplayName(member, host_name);', 'const name = host_name;');
  assert.notEqual(before, harness);
  assert.match(run(before, files, 1), /creation lists an unopened server chat by the account name instead of its tmux name\.\.\.[\s\S]*Alpha[\s\S]*rooms-alpha[\s\S]*FAIL \(TestExpectedEqual\)/);
});

test('fresh-profile room discovery probes configured hosts without local pins or tabs', () => {
  const source = read('room_frontend.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/store-discovery.zig'), 'utf8');
  run(`${fixture}\n${declaration(source, 'const StoreDiscovery = struct {')}\nvar store_discovery: [3]?*StoreDiscovery = @splat(null);\n${declaration(source, 'fn discoverStores(')}\n${declaration(source, 'fn clearStoreDiscovery(')}\n${declaration(source, 'fn cacheCatalog(')}\n${declaration(source, 'pub fn catalog(')}`);
});

test('unavailable creation reports a reason instead of silently returning', () => {
  const source = read('room_frontend.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/create-errors.zig'), 'utf8');
  run(`${fixture}\n${declaration(source, 'pub fn openCreate(')}`, { 'workspaces.zig': 'pub fn updateMainWindowTitle() void {}\n' });
});

test('room picker inserts the shown name and does not offer a stub restart', () => {
  const source = read('room_view.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/mention-picker.zig'), 'utf8');
  run(`${fixture}\n${declaration(source, 'fn chooseMention(')}\n${declaration(source, 'fn mentionStart(')}`);
  assert.doesNotMatch(source, /text\(dc, L\("Restart"\)/);
});

test('the room bridge builds its python command line the way the chat path does', () => {
  const consoleSource = read('console.zig');
  const room = read('room_transport.zig');
  const chat = read('chat_transport.zig');
  assert.doesNotMatch(room, /python3 -u -c \\"/, 'the room bridge must not double-quote its bootstrap');
  assert.match(room, /appendRemotePythonScript\(&cmd, &pos, bootstrap\)/, 'the room bridge must use the shared single-quoted bootstrap');
  assert.match(chat, /appendRemotePythonScript\(/, 'the chat path must use the shared single-quoted bootstrap');
  run(`
const std = @import("std");
${declaration(consoleSource, 'pub fn appendWideAscii(')}
${declaration(consoleSource, 'pub fn appendRemotePythonScript(')}
test "room and chat bootstraps quote identically" {
    var want: [256]u16 = undefined;
    var chat: [256]u16 = undefined;
    var chat_pos: usize = 0;
    try std.testing.expect(appendRemotePythonScript(&chat, &chat_pos, "import base64,sys;exec(x())"));
    const chat_len = try std.unicode.utf8ToUtf16Le(&want, "python3 -u -c 'import base64,sys;exec(x())'");
    try std.testing.expectEqualSlices(u16, want[0..chat_len], chat[0..chat_pos]);
    var room: [256]u16 = undefined;
    var room_pos: usize = 0;
    try std.testing.expect(appendRemotePythonScript(&room, &room_pos, "b=types.ModuleType('room_bridge')"));
    const room_len = try std.unicode.utf8ToUtf16Le(&want, "python3 -u -c 'b=types.ModuleType('\\\\''room_bridge'\\\\'')'");
    try std.testing.expectEqualSlices(u16, want[0..room_len], room[0..room_pos]);
}
`);
});

test('room actions publish the shared chat helper on an account that never sent a chat', () => {
  const transport = read('room_transport.zig');
  const bridge = read('room_bridge.py');
  const start = transport.indexOf('const bootstrap = "');
  assert.notEqual(start, -1, 'the room transport keeps a bootstrap');
  const end = transport.indexOf('";', start);
  assert.notEqual(end, -1, 'the room transport bootstrap is a complete string');
  const bootstrap = transport.slice(start, end);
  assert.equal(5, bootstrap.split('sys.stdin.buffer.readline()').length - 1, 'room_service, room_bridge, the reader digest, the reader and the account key each arrive on stdin');
  assert.match(bootstrap, /f=sys\.stdin\.buffer\.readline\(\)\.decode\('ascii'\)\.strip\(\);/, 'the third stdin line names the reader the app expects');
  assert.match(bootstrap, /p=base64\.b64decode\(sys\.stdin\.buffer\.readline\(\)\);/, 'the fourth stdin line carries the reader only when the app sends it');
  assert.match(bootstrap, /b\.serve\(os\.path\.expanduser\([^)]*\),p,f\)/, 'the reader and the expected digest are handed to the bridge');
  assert.match(transport, /const reader = bundleReader\(\) orelse return;/, 'the room transport carries the same reader the chat path publishes');
  assert.match(transport, /attempt\(job, &reader\.digest, ""\)/, 'a room request asks first without carrying the reader');
  assert.match(transport, /attempt\(job, &reader\.digest, reader\.source\)/, 'only a miss carries the reader');
  assert.match(bridge, /def serve\(directory, source=b'', fingerprint=''\):/, 'the bridge takes the reader only when the app sends it');
  assert.match(bridge, /if runtime_ready\(\):\n        sys\.stderr\.write\('\[room_bridge\] runtime already published/, 'a hit says the helper is already published');
  assert.match(bridge, /else:\n        publish_runtime\(\)/, 'a miss publishes the helper');
  assert.match(bridge, /subprocess\.run\(\[sys\.executable, '-u', '-c', bootstrap, 'host', 'list'\], input=base64\.b64encode\(RUNTIME_SOURCE\)/, 'the carried reader installs the shared helper itself');
  assert.match(bridge, /\[room_bridge\] published runtime/, 'a real publish is logged with its digest');
  assert.doesNotMatch(bridge, /def install_runtime/, 'the bridge reuses the reader install path instead of copying it');
});

test('a room request that finds the helper published does not ask for the reader', () => {
  const transport = read('room_transport.zig');
  const bridge = read('room_bridge.py');
  assert.match(transport, /fn republishRequested\(job: \*Job\) bool \{\n    return job\.success and std\.mem\.indexOf\(u8, job\.output\[0\.\.job\.output_len\], republish_error\) != null;\n\}/, 'a reply that asks for the reader is recognised');
  assert.match(transport, /job\.output_len = 0;\n    job\.error_len = 0;\n    job\.success = false;\n    diagnostics\.syncLog\("\[rooms\] bridge publishing the shared helper"\);/, 'the second attempt starts from a clean reply and says so');
  assert.match(bridge, /def runtime_ready\(\):\n    marker = published_marker\(\)\n    if not marker or marker\['reader'\] != runtime_fingerprint\(\):\n        return False\n    active = active_runtime\(\)\n    return isinstance\(active, dict\) and active\.get\('sha256'\) == marker\['active'\]/, 'the published digest must still be the one this app published');
  assert.match(bridge, /remember_published\(runtime_fingerprint\(\), digest\)/, 'the published pair is remembered for the next request');
  assert.match(bridge, /fail\('runtime_unavailable' if RUNTIME_SOURCE or not RUNTIME_FINGERPRINT else 'runtime_republish_required'\)/, 'only a request without the reader asks for it');
});

test('a request answered runtime_republish_required publishes the helper once and retries once', () => {
  const transport = read('room_transport.zig');
  assert.doesNotMatch(transport, /if \(attempt\(job, &reader\.digest, ""\)\) return;/, 'a reply that asks for the helper must not end the request');
  assert.match(transport, /const first = attempt\(job, &reader\.digest, ""\);\n    if \(nextStep\(first, false\) != \.publish\)/, 'the first attempt publishes only when the host asks for the helper');
  run(`
const std = @import("std");
const Reply = enum { ok, republish, start_failed, failed };
const Step = enum { stop, publish, host_start };
${declaration(transport, 'fn nextStep(')}
const Driven = struct { sends: usize, publishes: usize, host_start: bool };
fn drive(script: []const Reply) Driven {
    var published = false;
    var sends: usize = 0;
    var publishes: usize = 0;
    for (script) |reply| {
        sends += 1;
        const step = nextStep(reply, published);
        if (step != .publish) return .{ .sends = sends, .publishes = publishes, .host_start = step == .host_start };
        published = true;
        publishes += 1;
    }
    return .{ .sends = sends, .publishes = publishes, .host_start = false };
}
test "a capabilities reply that asks for the helper publishes once and retries once" {
    const cold = drive(&.{ .republish, .ok });
    try std.testing.expectEqual(@as(usize, 2), cold.sends);
    try std.testing.expectEqual(@as(usize, 1), cold.publishes);
    try std.testing.expect(!cold.host_start);
    const warm = drive(&.{.ok});
    try std.testing.expectEqual(@as(usize, 1), warm.sends);
    try std.testing.expectEqual(@as(usize, 0), warm.publishes);
    const broken = drive(&.{.failed});
    try std.testing.expectEqual(@as(usize, 1), broken.sends);
    try std.testing.expectEqual(@as(usize, 0), broken.publishes);
}
`);
});

test('a publish that fails stops after one try and says the room host could not start', () => {
  const transport = read('room_transport.zig');
  const rooms = read('rooms.zig');
  const bridge = read('room_bridge.py');
  assert.match(transport, /const host_start_error = "\\"error\\":\\"runtime_republish_failed\\"";/, 'the bridge names a publish that left the host unable to start');
  assert.match(transport, /if \(nextStep\(second, true\) == \.host_start\) \{\n        job\.host_start = true;/, 'a second miss after publishing is capped and reported as a start failure');
  assert.match(rooms, /if \(job\.host_start\) return \.host_start;/, 'the room failure carries the start reason to the dialog');
  assert.match(bridge, /if RUNTIME_SOURCE and not runtime_ready\(\):\n            PUBLISH_FAILED = True/, 'the bridge knows its publish left no usable helper');
  assert.match(bridge, /if PUBLISH_FAILED:\n        fail\('runtime_republish_failed'\)/, 'every later request reports the failed publish');
  run(`
const std = @import("std");
const Reply = enum { ok, republish, start_failed, failed };
const Step = enum { stop, publish, host_start };
${declaration(transport, 'fn nextStep(')}
test "a failed publish is not retried" {
    try std.testing.expectEqual(Step.host_start, nextStep(.start_failed, true));
    try std.testing.expectEqual(Step.host_start, nextStep(.republish, true));
    try std.testing.expectEqual(Step.stop, nextStep(.failed, true));
    try std.testing.expectEqual(Step.stop, nextStep(.ok, true));
    try std.testing.expectEqual(Step.publish, nextStep(.republish, false));
    try std.testing.expectEqual(Step.host_start, nextStep(.start_failed, false));
}
`);
});

test('room bridge failures log full stderr and the exit code even after the dialog error fills', () => {
  const source = read('room_transport.zig');
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/MUBO-533/bridge-errors.zig'), 'utf8');
  const start = source.indexOf('    defer {\n        if (w.WaitForSingleObject(process.hProcess, 1000)');
  assert.notEqual(start, -1);
  const end = source.indexOf('    const worker_handle = ', start);
  assert.notEqual(end, -1);
  assert.match(source, /bridge start failed win32_error=\{d\}/);
  run(`${fixture}\n${declaration(source, 'fn readErrors(')}\nfn finish(job: *Job, process: Process, errors: w.HANDLE) void {\n${source.slice(start, end)}\n}`);
});

test('a room host that never answers says it could not start and offers a retry', () => {
  const rooms = read('rooms.zig');
  const frontend = read('room_frontend.zig');
  const view = read('room_view.zig');
  assert.match(rooms, /host_start/, 'a host that dies before its first reply needs its own reason');
  assert.match(frontend, /failure\.reason == \.host_start\) "The room host could not start/, 'the room host start failure needs its own sentence');
  assert.doesNotMatch(frontend, /\.host_start\) "[^"]*check its connection/i, 'a start failure must not blame the connection');
  assert.match(frontend, /view\.showHostStartError\(message\)/, 'a start failure must reach the retry label');
  assert.match(view, /Retry · \{d\}/, 'the create dialog offers Retry after a start failure');
  const markers = rooms.slice(rooms.indexOf('const ssh_transport_errors'), rooms.indexOf('pub fn sshTransportError'));
  run(`
const std = @import("std");
const FailureReason = enum { transport, timeout, cancelled, parse, remote, host_start };
${markers}
${declaration(rooms, 'pub fn sshTransportError(')}
${declaration(rooms, 'pub fn failedReason(')}
test "a host that dies before its first reply is not reported as a connection problem" {
    try std.testing.expectEqual(FailureReason.host_start, failedReason(false, false, 0, "bash: -c: line 1: syntax error: unexpected end of file"));
    try std.testing.expectEqual(FailureReason.transport, failedReason(false, false, 0, "ssh: connect to host example.test port 22: Connection refused"));
    try std.testing.expectEqual(FailureReason.transport, failedReason(false, false, 9, "partial"));
    try std.testing.expectEqual(FailureReason.timeout, failedReason(true, false, 0, ""));
    try std.testing.expectEqual(FailureReason.cancelled, failedReason(false, true, 0, ""));
}
`);
});
