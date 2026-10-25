const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
function declaration(name) {
  const start = source.indexOf(`const ${name} = struct {`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n};', start) + 3);
}
const prelude = String.raw`
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const chat_echo = @import("chat_echo.zig");
const ChatEchoState = chat_echo.OutboxState;
const CHAT_OUTBOX_KEY_CAP = 256;
const CHAT_OUTBOX_TOTAL_MAX = 400;
const chat_transcript = struct { const Identity = struct {
    shell_id: u32 = 1, host: u8 = 0, codex: bool = false,
    sid: [40]u8 = @splat(0), tmux: [64]u8 = @splat(0), cwd: [192]u8 = @splat(0),
}; };
var g_chat_outbox: std.ArrayList(ChatOutboxEntry) = .empty;
var g_chat_full_settle_job: ?*ChatFullSettleJob = null;
var g_chat_full_settle_attempts: [CHAT_OUTBOX_TOTAL_MAX]ChatFullSettleAttempt = @splat(.{});
var shells = [_]struct { kind: enum { tmux, local, ssh } = .tmux }{.{}};
const g_chat_history_channels = [_]u8{0, 0, 0};
var test_key: chat_transcript.Identity = .{};
var fake_tick: u64 = 100_000;
var fake_now_ms: i64 = 100_000;
var worker: ?std.Thread = null;
var ui_thread: std.Thread.Id = undefined;
var requests: usize = 0;
var starts: usize = 0;
var saves: usize = 0;
var changes: usize = 0;
var after_ms: i64 = 0;
var deliver: [16]bool = @splat(false);
var fail_request = false;
var fail_spawn = false;
fn nowFileTime() u64 { return @as(u64, @intCast(fake_now_ms)) * 10_000 + 116444736000000000; }
fn GetTickCount64() u64 { return fake_tick; }
fn chatFileIdentityForShell(_: u32) chat_transcript.Identity { return test_key; }
fn chatOutboxShellForKey(_: []const u8) ?u32 { return 0; }
fn saveChatOutbox() bool { saves += 1; return true; }
fn chatOutboxChanged() void { changes += 1; }
var settled_logs: usize = 0;
fn debugLog(line: []const u8) void { if (std.mem.startsWith(u8, line, "chat-outbox settled id=")) settled_logs += 1; }
const TestThread = struct {
    real: std.Thread,
    fn detach(self: TestThread) void { worker = self.real; }
};
fn testSpawn(options: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) !TestThread {
    if (fail_spawn) return error.TestSpawnFailed;
    starts += 1;
    return .{ .real = try std.Thread.spawn(options, function, args) };
}
fn chatHistoryPersistent(host: u8, id: u32, query: []const u8, limit: usize, out: *std.ArrayList(u8), written: ?*bool) bool {
    std.debug.assert(std.Thread.getCurrentId() != ui_thread);
    std.debug.assert(host == test_key.host and limit == 4096 and written == null);
    requests += 1;
    if (fail_request) return false;
    const a = std.heap.page_allocator;
    const parsed = std.json.parseFromSlice(std.json.Value, a, query, .{}) catch unreachable;
    defer parsed.deinit();
    const obj = parsed.value.object;
    std.debug.assert(std.mem.eql(u8, obj.get("op").?.string, "settle"));
    std.debug.assert(std.mem.eql(u8, obj.get("sid").?.string, "sid"));
    std.debug.assert(std.mem.eql(u8, obj.get("tmux").?.string, "term-1"));
    std.debug.assert(std.mem.eql(u8, obj.get("cwd").?.string, "/work/demo"));
    std.debug.assert(!obj.get("codex").?.bool);
    after_ms = obj.get("after_ms").?.integer;
    const texts = obj.get("texts").?.array.items;
    const header = std.fmt.allocPrint(a, "@mp\t{d}\tsettle\tok\t-\t{d}\n", .{id, texts.len}) catch unreachable;
    defer a.free(header);
    out.appendSlice(a, header) catch unreachable;
    for (texts, 0..) |text, i| {
        std.debug.assert(std.mem.eql(u8, text.string, "please check the build"));
        const line = std.fmt.allocPrint(a, "{{\"i\":{d},\"delivered_ms\":{d},\"line\":{d}}}\n", .{i, @as(i64, if (deliver[i]) 40_000 else 0), @as(u32, if (deliver[i]) 55 else 0)}) catch unreachable;
        defer a.free(line);
        out.appendSlice(a, line) catch unreachable;
    }
    out.appendSlice(a, "@@MP_END@@\n") catch unreachable;
    return true;
}
fn joinWorker() void {
    if (worker) |thread| thread.join();
    worker = null;
}
fn clear() void {
    joinWorker();
    chatFullSettleFinish();
    for (g_chat_outbox.items) |entry| std.heap.page_allocator.free(entry.text);
    g_chat_outbox.deinit(std.heap.page_allocator);
    g_chat_outbox = .empty;
    g_chat_full_settle_attempts = @splat(.{});
    test_key = .{};
    @memcpy(test_key.sid[0..3], "sid");
    @memcpy(test_key.tmux[0..6], "term-1");
    @memcpy(test_key.cwd[0..10], "/work/demo");
    fake_tick = 100_000; fake_now_ms = 100_000;
    shells[0].kind = .tmux;
    requests = 0; starts = 0; saves = 0; changes = 0; settled_logs = 0;
    deliver = @splat(false); fail_request = false; fail_spawn = false;
    ui_thread = std.Thread.getCurrentId();
}
fn add(id: u64, state: ChatEchoState, written: bool, queued: bool, sent: i64) !void {
    var entry: ChatOutboxEntry = .{ .id = id, .key_len = 13, .state = state, .write_started = written,
        .transcript_queued = queued, .anchor = .{.sent_ms = sent}, .sent_tick_ms = sent,
        .text = try std.unicode.utf8ToUtf16LeAlloc(std.heap.page_allocator, "please check the build") };
    @memcpy(entry.key[0..13], "tmux:0:term-1");
    try g_chat_outbox.append(std.heap.page_allocator, entry);
}
test "full settle retires only delivered snapshot targets and saves once" {
    clear(); defer clear();
    try add(1, .delivered, true, false, 30_000);
    try add(2, .not_sent, true, false, 40_000);
    try add(3, .not_sent, true, false, 35_000);
    deliver[0] = true; deliver[1] = true;
    chatFullSettleStart();
    try std.testing.expect(g_chat_full_settle_job != null);
    chatFullSettleStart();
    try std.testing.expectEqual(@as(usize, 1), starts);
    joinWorker();
    try std.testing.expectEqual(@as(i64, 30_000), after_ms);
    chatFullSettleFinish();
    try std.testing.expect(g_chat_full_settle_job == null);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(u64, 3), g_chat_outbox.items[0].id);
    try std.testing.expectEqual(@as(usize, 1), saves);
    try std.testing.expectEqual(@as(usize, 1), changes);
    try std.testing.expectEqual(@as(usize, 2), settled_logs);
}
test "full settle skips young never written queued sending local and unsupported channels" {
    clear(); defer clear();
    try add(1, .delivered, true, false, 40_001);
    try add(2, .not_sent, false, false, 1);
    try add(3, .queued, true, false, 1);
    try add(4, .sending, true, false, 1);
    try add(5, .delivered, true, true, 1);
    chatFullSettleStart();
    try std.testing.expectEqual(@as(usize, 0), starts);
    try add(6, .not_sent, true, false, 1);
    for (0..4) |i| {
        switch (i) { 0 => shells[0].kind = .local, 1 => shells[0].kind = .ssh,
            2 => { shells[0].kind = .tmux; test_key.host = 3; }, 3 => { test_key.host = 0; test_key.tmux[0] = 0; }, else => unreachable }
        chatFullSettleStart();
        try std.testing.expectEqual(@as(usize, 0), starts);
    }
}
test "full settle batches sixteen fairly and throttles each key for thirty seconds" {
    clear(); defer clear();
    for (1..21) |id| try add(id, .delivered, true, false, 1);
    chatFullSettleStart(); joinWorker();
    try std.testing.expectEqual(@as(usize, 16), g_chat_full_settle_job.?.count);
    try std.testing.expectEqual(@as(u64, 16), g_chat_full_settle_job.?.entries[15].id);
    chatFullSettleFinish();
    fake_tick += 29_999;
    chatFullSettleStart();
    try std.testing.expectEqual(@as(usize, 1), starts);
    fake_tick += 1;
    chatFullSettleStart(); joinWorker();
    try std.testing.expectEqual(@as(usize, 2), starts);
    try std.testing.expectEqual(@as(u64, 17), g_chat_full_settle_job.?.entries[0].id);
    try std.testing.expectEqual(@as(u64, 20), g_chat_full_settle_job.?.entries[3].id);
    try std.testing.expectEqual(@as(u64, 1), g_chat_full_settle_job.?.entries[4].id);
    chatFullSettleFinish();
    try std.testing.expectEqual(@as(usize, 20), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), saves + changes);
}
test "full settle leaves failures and retried or removed entries untouched" {
    clear(); defer clear();
    try add(1, .delivered, true, false, 1);
    fail_spawn = true; chatFullSettleStart();
    try std.testing.expect(g_chat_full_settle_job == null);
    fail_spawn = false; fail_request = true;
    chatFullSettleStart(); joinWorker(); chatFullSettleFinish();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    fake_tick += 30_000; fail_request = false; deliver[0] = true;
    chatFullSettleStart(); joinWorker();
    g_chat_outbox.items[0].anchor.sent_ms = 2;
    chatFullSettleFinish();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    fake_tick += 30_000;
    chatFullSettleStart(); joinWorker();
    chatOutboxRemoveAtIn(&g_chat_outbox, std.heap.page_allocator, 0);
    chatFullSettleFinish();
    try std.testing.expectEqual(@as(usize, 0), saves + changes);
}
`;
function execute(disabled = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-full-settle-'));
  try {
    copyZig(['chat_echo.zig'], dir);
    const functions = ['chatFullSettleStart', 'chatFullSettleThread', 'chatFullSettleFinish', 'chatOutboxIndexById', 'chatOutboxRemoveAtIn'].map(body).join('\n')
      .replaceAll('std.Thread.spawn', 'testSpawn').replaceAll('@import("chat_session.zig").chatHistoryPersistent', 'chatHistoryPersistent');
    const checks = disabled ? prelude.slice(0, prelude.indexOf('test "full settle')) + String.raw`
      test "disabled full settle leaves old written entries unchanged" {
        clear(); defer clear();
        try add(1, .delivered, true, false, 1);
        chatFullSettleStart();
        try std.testing.expectEqual(@as(usize, 0), starts);
        try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
      }
    ` : prelude;
    fs.writeFileSync(path.join(dir, 'test.zig'), (`const ISSUE_349_FULL_SETTLE = ${!disabled};\n` + checks +
      ['ChatOutboxEntry', 'ChatFullSettleJob', 'ChatFullSettleAttempt'].map(declaration).join('\n') + functions).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', disabled ? 'disabled full settle' : 'full settle'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('production full settlement executes off the UI thread with batching, throttling and safe completion', () => {
  const result = execute();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 6 tests passed/);
});
test('full settlement switch off preserves the outbox', () => {
  const result = execute(true);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 1 tests passed/);
});
test('outbox tick owns full settlement completion and startup behind the switch', () => {
  assert.match(source, /const ISSUE_349_FULL_SETTLE = true;/);
  assert.match(body('chatOutboxTick'), /if \(ISSUE_349_FULL_SETTLE\) chatFullSettleFinish\(\)/);
  assert.match(body('chatOutboxTick'), /if \(ISSUE_349_FULL_SETTLE\) chatFullSettleStart\(\)/);
  assert.match(body('chatFullSettleStart'), /std\.Thread\.spawn\([^]*chatFullSettleThread/);
  assert.match(body('armChatOutboxTimerIfNeeded'), /g_chat_full_settle_job != null/);
});
