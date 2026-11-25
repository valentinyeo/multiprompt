const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
function declaration(source, marker) {
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, marker);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, marker);
  return source.slice(start, end + 2) + (source[end + 2] === ';' ? ';' : '');
}
function run(source, files = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'room-reliability-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), source);
    for (const [name, contents] of Object.entries(files)) fs.writeFileSync(path.join(dir, name), contents);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', 'test.zig'], { cwd: dir, encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined, result.error?.message);
    assert.equal(result.status, 0, `${result.stdout || ''}${result.stderr || ''}`);
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
${declaration(source, 'fn textField(')}
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
