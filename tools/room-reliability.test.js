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
  assert.equal(4, bootstrap.split('sys.stdin.buffer.readline()').length - 1, 'room_service, room_bridge, the reader digest and the reader each arrive on stdin');
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
