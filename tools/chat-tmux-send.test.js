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
const prelude = String.raw`
const std = @import("std");
const ShellSendResult = enum { ok, write_failed, enter_failed };
const Entry = struct {
    state: enum { queued, sending, delivered, not_sent } = .queued,
    write_started: bool = false,
    anchor: u32 = 0,
    channel_pending: bool = false,
    channel_sent: bool = false,
    channel_sent_ms: i64 = 0,
    channel_retries: u8 = 0,
};
var storage = [_]Entry{.{}};
var g_chat_outbox = struct { items: []Entry }{ .items = &storage };
const Key = struct { shell_id: u32 = 7, host: u8 = 0, tmux: [64]u8 = @splat(0) };
var shells = [_]struct { kind: enum { tmux, local, ssh } = .tmux }{.{}};
var shell_count: u32 = 1;
var test_key: Key = .{};
const g_chat_history_channels = [_]u8{ 0, 0, 0 };
var saves: usize = 0;
var save_ok = true;
var starts: usize = 0;
var spawn_ok = true;
var pastes: usize = 0;
var local_pastes: usize = 0;
var enters: usize = 0;
var verifies: usize = 0;
var direct = true;
var paste_ok = true;
var enter_ok = true;
var notices: usize = 0;
const chat_echo = struct { fn fileTimeToUnixMs(_: u64) i64 { return 12345; } };
const ChatTmuxSendJob = struct {
    key: Key = .{}, echo_id: u64 = 1, text: []u16, retry: bool = false, written: bool = false, rejected: bool = false,
    finished: std.atomic.Value(bool) = .init(true),
};
var g_chat_tmux_send_job: ?*ChatTmuxSendJob = null;
fn chatFileIdentityForShell(_: u32) Key { return test_key; }
fn chatOutboxIndexById(id: u64) ?usize { return if (id == 1) 0 else null; }
fn chatEchoAnchorNow(_: u32) u32 { return 44; }
fn saveChatOutbox() bool { saves += 1; return save_ok; }
fn chatShouldUseDirectInput(_: u32) bool { return direct; }
fn pasteTextToShellDirectEx(_: u32, _: []const u16, _: bool) bool { pastes += 1; return paste_ok; }
fn chatSendForceBracketed(_: u32) bool { return true; }
fn sendLocalChatPrompt(_: u32, _: []const u16) bool { local_pastes += 1; return paste_ok; }
fn Sleep(_: u32) void {}
fn chatSendEnterDelayMs(_: anytype) u32 { return 150; }
fn sendEnterToShell(_: u32) bool { enters += 1; return enter_ok; }
fn chatArmSendVerify(_: u32, _: []const u16, _: u64) bool { verifies += 1; return true; }
fn chatTmuxSendStart(_: u32, _: []const u16, _: u64, _: bool) bool {
    starts += 1;
    if (spawn_ok) storage[0].channel_pending = true;
    return spawn_ok;
}
fn nowFileTime() u64 { return 0; }
fn findShellById(_: u32) ?u32 { return 0; }
fn chatOutboxChanged() void { notices += 1; }
fn reset() void {
    storage[0] = .{}; shells[0].kind = .tmux; test_key = .{}; test_key.tmux[0] = 't';
    starts = 0; pastes = 0; local_pastes = 0; enters = 0; verifies = 0;
    saves = 0; save_ok = true; spawn_ok = true; direct = true; paste_ok = true; enter_ok = true;
    g_chat_tmux_send_job = null;
}
fn finishJob(written: bool, retry: bool, echo_id: u64) void {
    const job = std.heap.page_allocator.create(ChatTmuxSendJob) catch unreachable;
    job.* = .{ .text = std.heap.page_allocator.dupe(u16, &.{'x'}) catch unreachable, .written = written, .retry = retry, .echo_id = echo_id };
    g_chat_tmux_send_job = job;
    storage[0].channel_pending = true;
    chatTmuxSendFinish();
}
test "VPS tmux routing ignores console visibility lock and busy status" {
    reset();
    try std.testing.expectEqual(ShellSendResult.ok, sendTextToShellVerifiedAt(0, &.{'x'}, 1));
    try std.testing.expectEqual(@as(usize, 1), starts);
    try std.testing.expectEqual(@as(usize, 0), pastes + local_pastes + enters + verifies);
    try std.testing.expect(storage[0].write_started);
    try std.testing.expect(storage[0].channel_pending);
}
test "local plain SSH unsupported host and missing tmux retain console paste" {
    for (0..4) |case| {
        reset();
        switch (case) { 0 => shells[0].kind = .local, 1 => shells[0].kind = .ssh, 2 => test_key.host = 3, 3 => test_key.tmux[0] = 0, else => unreachable }
        try std.testing.expectEqual(ShellSendResult.ok, sendTextToShellVerifiedAt(0, &.{'x'}, 1));
        try std.testing.expectEqual(@as(usize, 0), starts);
        try std.testing.expectEqual(@as(usize, 1), pastes);
        try std.testing.expectEqual(@as(usize, 1), enters);
        try std.testing.expectEqual(@as(usize, 1), verifies);
    }
    reset(); shells[0].kind = .local; direct = false;
    try std.testing.expectEqual(ShellSendResult.ok, sendTextToShellVerifiedAt(0, &.{'x'}, 1));
    try std.testing.expectEqual(@as(usize, 1), local_pastes);
}
test "failed worker startup safely falls back once and reserved writes never repeat" {
    reset(); spawn_ok = false;
    try std.testing.expectEqual(ShellSendResult.ok, sendTextToShellVerifiedAt(0, &.{'x'}, 1));
    try std.testing.expectEqual(@as(usize, 1), pastes);
    try std.testing.expectEqual(ShellSendResult.write_failed, sendTextToShellVerifiedAt(0, &.{'x'}, 1));
    try std.testing.expectEqual(@as(usize, 1), pastes);
    reset(); save_ok = false;
    try std.testing.expectEqual(ShellSendResult.write_failed, sendTextToShellVerifiedAt(0, &.{'x'}, 1));
    try std.testing.expectEqual(@as(usize, 0), starts + pastes);
}
test "channel write failure falls back once but a written request or retry never pastes" {
    reset(); finishJob(false, false, 1);
    try std.testing.expectEqual(@as(usize, 1), pastes);
    try std.testing.expect(!storage[0].channel_sent);
    try std.testing.expect(g_chat_tmux_send_job == null);
    reset(); finishJob(true, false, 1);
    try std.testing.expectEqual(@as(usize, 0), pastes + enters + verifies);
    try std.testing.expect(storage[0].channel_sent);
    try std.testing.expectEqual(@as(i64, 12345), storage[0].channel_sent_ms);
    reset(); finishJob(false, true, 1);
    try std.testing.expectEqual(@as(usize, 0), pastes);
    try std.testing.expectEqual(@as(u8, 1), storage[0].channel_retries);
    reset(); finishJob(false, false, 999);
    try std.testing.expectEqual(@as(usize, 0), pastes);
}
`;
function execute(disabled = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-tmux-routing-'));
  try {
    const functions = ['chatTmuxSendEligible', 'sendTextToShellVerifiedAt', 'chatSendViaConsole', 'chatTmuxSendFinish'].map(body).join('\n').replaceAll('@import("inbox.zig").findShellById', 'findShellById');
    const checks = disabled ? prelude.slice(0, prelude.indexOf('test "VPS')) + String.raw`
      test "disabled switch retains paste for VPS tmux" {
        reset();
        try std.testing.expectEqual(ShellSendResult.ok, sendTextToShellVerifiedAt(0, &.{'x'}, 1));
        try std.testing.expectEqual(@as(usize, 0), starts);
        try std.testing.expectEqual(@as(usize, 1), pastes);
      }
    ` : prelude;
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `const ISSUE_349_TMUX_SEND = ${!disabled};\n` + checks + functions);
    return spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('production routing and completion execute with safe write-failure fallback', () => {
  const result = execute();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 4 tests passed/);
});
test('turning the switch off executes the original console path', () => {
  const result = execute(true);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 1 tests passed/);
});
test('worker uses existing persistent reader and background settlement uses pure transcript policy', () => {
  assert.match(source, /const ISSUE_349_TMUX_SEND = true;/);
  assert.match(body('chatTmuxSendStart'), /std\.Thread\.spawn\([^]*chatTmuxSendThread/);
  assert.match(body('chatTmuxSendThread'), /\.op = "send"[^]*chatHistoryPersistent\([^]*&job\.written/);
  assert.doesNotMatch(body('chatTmuxSendThread'), /pasteText|sendEnterToShell|chatArmSendVerify/);
  assert.match(body('chatOutboxTick'), /!entry\.channel_pending and chat_echo\.orphanedSending/);
  assert.match(body('chatFileRequestForDelivery'), /!delivery and !g_chat_active/);
  const settle = body('chatTmuxSettle');
  assert.match(settle, /chatFileRequestForDelivery\(key, true\)/);
  assert.match(settle, /facts\.enqueued[^]*transcriptStatus\(/);
  assert.match(settle, /chatEchoAssignForKey[^]*chatEchoStoreAnchors/);
  assert.match(settle, /transcriptStatus\(&entry\.delivery_watch, busy, now_ms, history\.loaded_ms, evidence\)/);
  assert.match(settle, /\.activity == \.active/);
  assert.doesNotMatch(settle, /chatTmuxSendStart|pasteText|sendEnterToShell/);
  assert.match(body('chatEchoMatchActive'), /e\.state == \.delivered and !enqueued/);
  assert.match(body('chatPaintEchoStatus'), /pendingLabel\(phase, link_down, e\.transcript_queued\)/);
  assert.match(body('chatPaintEchoStatus'), /Queued, session is busy/);
  assert.doesNotMatch(body('chatPaintEchoStatus'), /Delivered/);
});
