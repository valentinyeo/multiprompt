const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');

function extract(name) {
  const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'chat_send.zig'), 'utf8');
  const start = source.indexOf(`pub fn ${name}(`) >= 0 ? source.indexOf(`pub fn ${name}(`) : source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist in chat_send.zig`);
  const end = source.indexOf('\n}', start) + 2;
  assert.ok(end > start, `${name} must close`);
  return source.slice(start, end);
}

const extracted = ['chatEchoRowLanded', 'chatEchoTranscriptHasRow', 'chatEchoRowKnown', 'chatEchoTakenSettledIn'].map(extract).join('\n\n');

function run(control) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-hidden-pending-'));
  try {
    copyZig(['chat_echo.zig', 'chat_live.zig', 'chat_shell_sync.zig', 'chat_transcript.zig', 'chat_markdown.zig'], dir);
    if (control === 'retire-while-waiting') {
      const file = path.join(dir, 'chat_echo.zig');
      const source = fs.readFileSync(file, 'utf8');
      const changed = source.replace('!phaseTaken(phase) or !landed', '!phaseTaken(phase) or !(landed or !landed)');
      assert.notEqual(changed, source, 'the landed gate must be present in takenSettled');
      fs.writeFileSync(file, changed);
    }
    if (control === 'raw-queue-match') {
      const file = path.join(dir, 'chat_shell_sync.zig');
      const source = fs.readFileSync(file, 'utf8');
      const changed = source.replace('chat_echo.queueTextMatches(entry.text, item.text[0..item.len])', 'chat_echo.sameText(clipped(entry.text), item.text[0..item.len])');
      assert.notEqual(changed, source, 'the queue copy matcher must be present');
      fs.writeFileSync(file, changed);
    }
    fs.writeFileSync(path.join(dir, 'parity.zig'), String.raw`
const std = @import("std");
const echo = @import("chat_echo.zig");
const chat_echo = echo;
const live = @import("chat_live.zig");
const md = @import("chat_markdown.zig");
const sync = @import("chat_shell_sync.zig");
const transcript = @import("chat_transcript.zig");
const app_state = @This();

const ChatEchoState = echo.OutboxState;
const SID = "11111111-2222-3333-4444-555555555555";

const ChatOutboxEntry = struct {
    id: u64 = 0,
    key: [24]u8 = std.mem.zeroes([24]u8),
    key_len: u32 = 0,
    text: []u16 = &.{},
    state: ChatEchoState = .queued,
    reset_pending: bool = false,
    message_v1: bool = false,
    message_phase: [16]u8 = @splat(0),
    message_wire_id: [81]u8 = @splat(0),
    sent_tick_ms: i64 = 0,
    anchor: echo.Anchor = .{},
    delivery_watch: echo.DeliveryWatch = .{},
};

pub var shells = [_]struct { shell_id: u32 }{.{ .shell_id = 101 }};
pub var shell_count: usize = 1;
pub var g_chat_blocks: []const md.Block = &.{};
pub var g_chat_block_count: usize = 0;
pub var g_chat_outbox: std.ArrayList(ChatOutboxEntry) = .empty;
pub var g_chat_verify_echo_id: u64 = 0;

fn chatOutboxShellForKey(key: []const u8) ?usize {
    return if (std.mem.eql(u8, key, "tmux:7:soft-2929")) 0 else null;
}

fn chatVerifyClear() void {}

fn chatConfirmedAddReceipt(e: ChatOutboxEntry) void {
    _ = e;
}

fn chatOutboxRemoveAtIn(list: *std.ArrayList(ChatOutboxEntry), allocator: std.mem.Allocator, index: usize) void {
    _ = allocator;
    _ = list.orderedRemove(index);
}

` + extracted + String.raw`

fn longText(out: []u16) void {
    for (out, 0..) |*c, i| c.* = if (i % 11 == 10) ' ' else 'a' + @as(u16, @intCast(i % 26));
}

fn statusWith(text: []const u16, sent: bool) transcript.Status {
    var status: transcript.Status = .{ .live_known = true };
    const item = &status.queue[0];
    @memcpy(item.text[0..text.len], text);
    item.len = text.len;
    item.sent = sent;
    status.queue_len = 1;
    return status;
}

fn waitingCopies(entry: *const ChatOutboxEntry, queue_text: []const u16, queue_sent: bool) usize {
    var copies: usize = if (chatEchoRowLanded(entry.*)) 0 else 1;
    var status = statusWith(queue_text, queue_sent);
    const pending = [_]sync.Pending{.{ .id = entry.id, .text = entry.text }};
    var view: sync.View = .{};
    sync.build(&view, &status, &pending);
    for (view.rows[0..view.count]) |row| {
        if (row.local or row.sent) continue;
        if (echo.queueTextMatches(entry.text, row.slice())) copies += 1;
    }
    return copies;
}

fn refresh(entry: *const ChatOutboxEntry, reply_ms: i64, now_ms: i64) bool {
    return chatEchoTakenSettledIn(&app_state.g_chat_outbox, std.testing.allocator, entry.key[0..entry.key_len], reply_ms, now_ms, false, true);
}

test "SOFT-2929 a long waiting message stays rendered until its transcript line arrives, then once" {
    const a = std.testing.allocator;
    var text: [600]u16 = undefined;
    longText(&text);
    defer {
        app_state.g_chat_outbox.deinit(a);
        app_state.g_chat_outbox = .empty;
    }
    try app_state.g_chat_outbox.append(a, .{ .id = 42, .text = &text, .state = .delivered, .message_v1 = true, .sent_tick_ms = 1000 });
    const entry = &app_state.g_chat_outbox.items[0];
    @memcpy(entry.key[0..16], "tmux:7:soft-2929");
    entry.key_len = 16;
    @memcpy(entry.message_phase[0..8], "accepted");
    @memcpy(entry.message_wire_id[0..9], "desktop-1");
    entry.anchor = .{ .sent_ms = 1000, .after_ms = 900 };

    _ = live.begin(101, 0, SID);
    defer live.release(101);
    try std.testing.expect(live.applyPage(101, SID, "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{\"message_id\":\"desktop-1\"}}}]}}"));

    const queue_copy = text[0..200];
    try std.testing.expectEqual(@as(usize, 1), waitingCopies(entry, queue_copy, false));
    try std.testing.expect(!refresh(entry, 2000, 2000));
    try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), waitingCopies(entry, queue_copy, false));
    try std.testing.expect(!refresh(entry, 1500, 4000));
    try std.testing.expectEqual(@as(usize, 1), waitingCopies(entry, queue_copy, false));
    try std.testing.expect(!refresh(entry, 0, 1000 + echo.TAKEN_MAX_AGE_MS * 30));
    try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), waitingCopies(entry, queue_copy, false));

    try std.testing.expect(live.applyPage(101, SID, "{\"result\":{\"events\":[{\"seq\":2,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-2\",\"payload\":{\"message_id\":\"desktop-1\",\"uuids\":[\"u-1\"]}}}]}}"));
    var blocks: [1]md.Block = .{.{ .start = 0, .len = text.len, .role = .user, .row_key = md.rowKey("u-1") }};
    app_state.g_chat_blocks = &blocks;
    app_state.g_chat_block_count = 1;
    defer {
        app_state.g_chat_blocks = &.{};
        app_state.g_chat_block_count = 0;
    }
    const taken = entry.*;
    try std.testing.expect(chatEchoRowLanded(taken));
    try std.testing.expect(refresh(&taken, 3000, 5000));
    try std.testing.expectEqual(@as(usize, 0), app_state.g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), waitingCopies(&taken, queue_copy, true));
    try std.testing.expectEqual(@as(usize, 1), app_state.g_chat_block_count);
}

test "SOFT-2929 a short message queued behind a busy turn waits the same way" {
    const a = std.testing.allocator;
    const literal = std.unicode.utf8ToUtf16LeStringLiteral("check the deploy log");
    var text: [literal.len]u16 = undefined;
    @memcpy(&text, literal);
    defer {
        app_state.g_chat_outbox.deinit(a);
        app_state.g_chat_outbox = .empty;
    }
    try app_state.g_chat_outbox.append(a, .{ .id = 43, .text = &text, .state = .delivered, .message_v1 = true, .sent_tick_ms = 1000 });
    const entry = &app_state.g_chat_outbox.items[0];
    @memcpy(entry.key[0..16], "tmux:7:soft-2929");
    entry.key_len = 16;
    @memcpy(entry.message_phase[0..8], "accepted");
    @memcpy(entry.message_wire_id[0..9], "desktop-2");
    entry.anchor = .{ .sent_ms = 1000, .after_ms = 900 };
    _ = live.begin(101, 0, SID);
    defer live.release(101);
    try std.testing.expect(live.applyPage(101, SID, "{\"result\":{\"events\":[{\"seq\":1,\"event\":{\"kind\":\"turn.started\",\"turn\":\"t-1\",\"payload\":{\"message_id\":\"desktop-2\"}}}]}}"));
    try std.testing.expectEqual(@as(usize, 1), waitingCopies(entry, &text, false));
    try std.testing.expect(!refresh(entry, 2000, 2000));
    try std.testing.expectEqual(@as(usize, 1), waitingCopies(entry, &text, false));
}
`);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'parity.zig'), '--test-filter', 'SOFT-2929', '-femit-bin=' + path.join(dir, 'parity')], { encoding: 'utf8', timeout: 300000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('SOFT-2929 a long waiting message stays rendered until its transcript line arrives once', () => {
  const result = run();
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All 5 tests passed/);
  console.log(result.stderr.trim());
});

for (const control of ['retire-while-waiting', 'raw-queue-match']) {
  test(`SOFT-2929 parity oracle rejects ${control}`, () => {
    const result = run(control);
    assert.equal(result.error, undefined);
    assert.notEqual(result.status, 0, 'the control must fail');
    assert.match(result.stderr, /FAIL \(Test/);
  });
}
