const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
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
const prelude = `
const std = @import("std");
const chat_echo = @import("chat_echo.zig");
const json_reader = @import("json_reader.zig");
const chat_markdown = @import("chat_markdown.zig");
const chat_history = @import("chat_history.zig");
const chat_transcript = @import("chat_transcript.zig");
const ChatBlock = chat_markdown.Block;
const ChatEchoState = chat_echo.OutboxState;
const CHAT_OUTBOX_MAX_PER_KEY = 20;
const CHAT_OUTBOX_TOTAL_MAX = 400;
const CHAT_OUTBOX_MSG_CAP = 16384;
const CHAT_OUTBOX_KEY_CAP = 256;
const CHAT_ECHO_PREFIX_CAP = 40;
const CHAT_CONFIRMED_MAX_PER_KEY = 50;
const ShellSendResult = enum { ok, write_failed, enter_failed };
const Shell = struct { shell_id: u32 = 1, kind: u8 = 0, activity: enum { idle, active } = .idle };
var shells = [_]Shell{.{}};
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var g_chat_active = true;
var g_chat_screen_working = false;
var g_chat_scroll_bottom_pending = false;
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn chatOutboxTick() void { _ = chatOutboxTrySendEntry(0, 0); }
var g_chat_echo_next_id: u64 = 1;
var g_chat_outbox: std.ArrayList(ChatOutboxEntry) = .empty;
var g_chat_confirmed: std.ArrayList(ChatConfirmedEcho) = .empty;
var g_chat_verify_echo_id: u64 = 0;
var g_chat_block_storage: [300]ChatBlock = undefined;
var g_chat_blocks: []ChatBlock = &g_chat_block_storage;
var g_chat_block_count: usize = 0;
var g_chat_capture: []const u16 = &.{};
var g_chat_last_len: usize = 0;
var g_chat_last_hash: u64 = 0;
var g_chat_outbox_revision: u64 = 0;
var g_chat_reconcile_shell: u32 = 0;
var g_chat_reconcile_hash: u64 = 0;
var g_chat_reconcile_outbox: u64 = 0;
var g_chat_reconcile_generation: u64 = 0;
var g_chat_cache_generation: u64 = 0;
var reconcile_passes: usize = 0;
fn chatPerf(_: []const u8, _: u64, _: usize) void { reconcile_passes += 1; }
fn GetTickCount64() u64 { return @intCast(fake_now_ms); }
var writes: usize = 0;
var persisted: ?[]u8 = null;
var persist_ok = true;
var paste_ok = true;
fn saveChatOutbox() bool {
    if (!persist_ok) return false;
    var n: usize = 0;
    const bytes = chatOutboxSerialize(&g_chat_outbox, std.heap.page_allocator, &n) orelse return false;
    defer std.heap.page_allocator.free(bytes);
    if (persisted) |p| std.heap.page_allocator.free(p);
    persisted = std.heap.page_allocator.dupe(u8, bytes[0..n]) catch return false;
    return true;
}
fn clear() void {
    for (g_chat_outbox.items) |e| std.heap.page_allocator.free(e.text);
    g_chat_outbox.deinit(std.heap.page_allocator);
    g_chat_outbox = .empty;
    g_chat_confirmed.deinit(std.heap.page_allocator);
    g_chat_confirmed = .empty;
    if (persisted) |p| std.heap.page_allocator.free(p);
    persisted = null;
    g_chat_block_count = 0;
    g_chat_capture = &.{};
    g_chat_last_len = 0;
    g_chat_last_hash +%= 1;
    g_chat_outbox_revision +%= 1;
    reconcile_passes = 0;
    writes = 0;
    fake_now_ms = 2000;
    fake_loaded_ms = 0;
    history_entry.history.deinit(std.heap.page_allocator);
    g_chat_screen_working = false;
    persist_ok = true;
    paste_ok = true;
    shells[0].activity = .idle;
}
fn chatOutboxKeyForShell(_: u32, buf: []u8) []const u8 { @memcpy(buf[0..4], "test"); return buf[0..4]; }
fn chatBlockDisplayRange(_: []const u16, b: ChatBlock) struct { start: usize, len: usize } { return .{ .start = b.start, .len = b.len }; }
var fake_now_ms: i64 = 2000;
var fake_loaded_ms: i64 = 0;
var fake_history: chat_history.History = .{};
const HistoryEntry = struct { retired: bool = false, key: struct { shell_id: u32 = 1 } = .{}, history: chat_history.History = .{} };
var history_entry = HistoryEntry{};
var history_entries = [_]*HistoryEntry{&history_entry};
var g_chat_histories = struct { items: []*HistoryEntry }{ .items = &history_entries };
fn nowFileTime() u64 { return @as(u64, @intCast(fake_now_ms)) * 10000 + 116444736000000000; }
fn chatEchoLoadedMs() i64 { return fake_loaded_ms; }
fn chatEchoWindowFull() bool { return false; }
fn chatEchoAnchorNow(_: u32) chat_echo.Anchor { return .{ .after_ms = 1000, .sent_ms = 1500, .counted = true, .user_count = 1 }; }
fn chatShouldUseDirectInput(_: u32) bool { return true; }
fn chatSendForceBracketed(_: u32) bool { return true; }
fn chatSendEnterDelayMs(_: u8) u32 { return 0; }
fn Sleep(_: u32) void {}
fn pasteTextToShellDirectEx(_: u32, _: []const u16, _: bool) bool {
    // The disk reservation must precede the first byte, even a partial failure.
    std.debug.assert(persisted != null and std.mem.indexOf(u8, persisted.?, "\\\"x\\\":1") != null);
    writes += 1;
    return paste_ok;
}
fn sendLocalChatPrompt(_: u32, _: []const u16) bool { unreachable; }
fn sendEnterToShell(_: u32) bool { return true; }
fn chatArmSendVerify(_: u32, _: []const u16, id: u64) bool { g_chat_verify_echo_id = id; return true; }
fn chatVerifyClear() void { g_chat_verify_echo_id = 0; }
fn chatOutboxChanged() void { g_chat_outbox_revision +%= 1; }
fn chatOutboxInputRowIdle(_: u32) bool { return true; }
`;
const acceptance = `
fn enqueue(text: []const u16, state: ChatEchoState) !void {
    try std.testing.expect(chatOutboxEnqueueInState(&g_chat_outbox, std.heap.page_allocator, "test", text, state));
    g_chat_outbox.items[g_chat_outbox.items.len - 1].anchor = chatEchoAnchorNow(0);
    g_chat_outbox.items[g_chat_outbox.items.len - 1].write_started = state != .queued;
    g_chat_outbox_revision +%= 1;
}
fn reload() !void {
    const bytes = try std.heap.page_allocator.dupe(u8, persisted.?);
    defer std.heap.page_allocator.free(bytes);
    for (g_chat_outbox.items) |e| std.heap.page_allocator.free(e.text);
    g_chat_outbox.clearRetainingCapacity();
    g_chat_confirmed.clearRetainingCapacity();
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, bytes);
}
fn transcript(text: []const u16, stamp: i64) void {
    g_chat_last_hash +%= 1;
    g_chat_capture = text;
    g_chat_last_len = text.len;
    g_chat_blocks[0] = .{ .role = .user, .start = 0, .len = text.len, .stamp_ms = stamp };
    g_chat_block_count = 1;
}
test "delivery: busy then idle, restart queued, type once, transcript replaces pending" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral(" https://screencast2.com/a3CKb.png ");
    try enqueue(text, .queued);
    try std.testing.expect(saveChatOutbox());
    try reload();
    shells[0].activity = .active;
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 0), writes);
    shells[0].activity = .idle;
    try std.testing.expect(chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try reload(); // restart while send verification is still running
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("https://screencast2.com/a3CKb.png"), 2000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try reload();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), writes);
}
test "delivery: persistence failure writes nothing; partial failure cannot retype" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("a prompt"), .queued);
    persist_ok = false;
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 0), writes);
    persist_ok = true;
    paste_ok = false;
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try reload();
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 1), writes);
}
test "delivery: repeats survive old history, even if an untyped queue has a newer matching turn" {
    defer clear();
    const yes = std.unicode.utf8ToUtf16LeStringLiteral("yes");
    try enqueue(yes, .delivered);
    try enqueue(yes, .queued);
    try enqueue(yes, .not_sent);
    g_chat_verify_echo_id = g_chat_outbox.items[2].id;
    transcript(yes, 100); // older than after_ms and sent_ms
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 3), g_chat_outbox.items.len);
    try std.testing.expect(g_chat_verify_echo_id != 0);
    try std.testing.expectEqual(@as(usize, 0), g_chat_confirmed.items.len);
    try std.testing.expect(saveChatOutbox());
    try reload();
    try std.testing.expectEqual(@as(usize, 3), g_chat_outbox.items.len);
    transcript(yes, 2000);
    chatEchoMatchActive(); // Only the oldest actually written intent confirms.
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[0].state);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: repeats in an offline queue cannot be confirmed before typing" {
    defer clear();
    const yes = std.unicode.utf8ToUtf16LeStringLiteral("yes");
    try enqueue(yes, .queued);
    transcript(yes, 2000); // A newer external user turn still cannot consume unsent intent.
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: legacy offline queues survive upgrade and uncertain writes never auto-retry" {
    defer clear();
    const legacy = "{\\\"version\\\":1,\\\"queues\\\":[{\\\"key\\\":\\\"test\\\",\\\"messages\\\":[{\\\"t\\\":\\\"old uncertain\\\",\\\"s\\\":2},{\\\"t\\\":\\\"queued\\\",\\\"s\\\":0}]}]}";
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, legacy);
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
    try std.testing.expectEqual(ChatEchoState.queued, g_chat_outbox.items[1].state);
    try std.testing.expect(!g_chat_outbox.items[1].write_started);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: aged unconfirmed messages remain recoverable without transcript access and after restart" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("not in transcript");
    try enqueue(text, .delivered);
    try enqueue(text, .queued);
    fake_now_ms = 601500;
    fake_loaded_ms = 1500;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    fake_loaded_ms = 1501;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 2), g_chat_outbox.items.len);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    try reload();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
    try std.testing.expectEqual(@as(usize, 0), writes);
}
test "delivery: unchanged refreshes cache reconciliation, revision and expiry changes still run" {
    defer clear();
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("not represented"), .queued);
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("another prompt"), 2000);
    const before = reconcile_passes;
    for (0..1000) |_| chatEchoMatchActive();
    try std.testing.expectEqual(before + 1, reconcile_passes);
    g_chat_last_hash +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(before + 2, reconcile_passes);
    g_chat_outbox_revision +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(before + 3, reconcile_passes);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
}
fn setFacts(rows: []const u8) !void {
    history_entry.history.rows.clearRetainingCapacity();
    try history_entry.history.rows.appendSlice(std.heap.page_allocator, rows);
    g_chat_last_hash +%= 1;
}
test "delivery: refused real slash command is retryable and a later matching block still confirms" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("/hormozi-skills:audit-offer can you use this also to review my own offer");
    try enqueue(text, .delivered);
    try setFacts("{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:59.442Z\\",\\"settlement\\":{\\"operation\\":\\"rejected\\",\\"content\\":\\"Unknown command: /hormozi-skills:audit-offer\\"}}\\n");
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    try reload();
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    transcript(text, 2000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: busy idle grace needs a fresh transcript, matches win, idle alone does not settle" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("also review the offer");
    try enqueue(text, .delivered);
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    fake_now_ms = 5000;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    shells[0].activity = .active;
    chatEchoMatchActive();
    shells[0].activity = .idle;
    fake_now_ms = 6000;
    chatEchoMatchActive();
    fake_now_ms = 25999;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 26000;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    transcript(text, 27000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: queue removal settles after transcript grace, persists and explicitly retries once" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("also review the offer");
    try enqueue(text, .delivered);
    try setFacts("{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:22.591Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"also review the offer\\"}}\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:59.442Z\\",\\"settlement\\":{\\"operation\\":\\"remove\\",\\"content\\":\\"also review the offer\\"}}\\n");
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 21999;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 22000;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try reload();
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    chatEchoRetryAllForActive();
    try std.testing.expectEqual(@as(usize, 1), writes);
    try std.testing.expect(!g_chat_outbox.items[0].retryable);
    try std.testing.expect(g_chat_outbox.items[0].write_started);
    try std.testing.expect(!chatOutboxTrySendEntry(0, 0));
}
test "delivery: midturn queued attachment and merged normal block win over refusal removal and turn expiry" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("also review the offer");
    try enqueue(text, .delivered);
    shells[0].activity = .active;
    chatEchoMatchActive();
    try history_entry.history.apply(std.heap.page_allocator, "@mp\\t1\\thistory\\tok\\tsid\\t0\\t100\\t9\\t0\\tclaude\\t-\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:22.591Z\\",\\"settlement\\":{\\"operation\\":\\"enqueue\\",\\"content\\":\\"also review the offer\\"}}\\n{\\"role\\":\\"assistant\\",\\"text\\":\\"\\",\\"timestamp\\":\\"2026-10-13T11:06:59.442Z\\",\\"settlement\\":{\\"operation\\":\\"remove\\",\\"content\\":\\"also review the offer\\"}}\\n{\\"role\\":\\"user\\",\\"text\\":\\"also review the offer\\",\\"timestamp\\":\\"2026-10-13T11:06:59.443Z\\"}\\n@@MP_END@@\\n", 1, chat_transcript.Identity.init(1, 0, false, "sid", ""));
    const h = &history_entry.history;
    g_chat_capture = h.text.items;
    g_chat_last_len = h.text.items.len;
    @memcpy(g_chat_blocks[0..h.blocks.items.len], h.blocks.items);
    g_chat_block_count = h.blocks.items.len;
    g_chat_last_hash +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), g_chat_confirmed.items.len);
    shells[0].activity = .idle;
    fake_now_ms = 30000;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try enqueue(text, .delivered);
    g_chat_outbox.items[0].anchor.after_ms = 1000;
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("start here\\n\\nalso review the offer"), 40000);
    fake_now_ms = 700000;
    fake_loaded_ms = fake_now_ms;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: legacy delivered entries without a timestamp cannot stay queued forever" {
    defer clear();
    const legacy = "{\\\"version\\\":1,\\\"queues\\\":[{\\\"key\\\":\\\"test\\\",\\\"messages\\\":[{\\\"t\\\":\\\"legacy stuck\\\",\\\"s\\\":3}]}]}";
    chatOutboxParseJson(&g_chat_outbox, std.heap.page_allocator, legacy);
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    transcript(std.unicode.utf8ToUtf16LeStringLiteral("legacy stuck"), 100);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: old delivered outbox settles on load without waiting for another turn and keeps late matching" {
    defer clear();
    const text = std.unicode.utf8ToUtf16LeStringLiteral("older persisted message");
    try enqueue(text, .delivered);
    try std.testing.expect(saveChatOutbox());
    fake_now_ms = 601499;
    try reload();
    try std.testing.expectEqual(ChatEchoState.delivered, g_chat_outbox.items[0].state);
    fake_now_ms = 601500;
    try reload();
    try std.testing.expectEqual(ChatEchoState.not_sent, g_chat_outbox.items[0].state);
    try std.testing.expect(!g_chat_outbox.items[0].write_started);
    try std.testing.expect(g_chat_outbox.items[0].retryable);
    transcript(text, 2000);
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
}
test "delivery: cache round trip preserves timestamp and matches beyond 256 blocks, not injected rows" {
    defer clear();
    const a = std.testing.allocator;
    const key = chat_transcript.Identity.init(1, 0, false, "sid", "/repo");
    var h = chat_history.History{};
    defer h.deinit(a);
    const row = "{\\\"role\\\":\\\"user\\\",\\\"timestamp\\\":\\\"2026-10-12T18:00:00Z\\\",\\\"text\\\":\\\"hello  world\\\"}\\n";
    const wire = "@mp\\t7\\thistory\\tok\\tsid\\t0\\t100\\t4\\t0\\tclaude\\t-\\n" ++ row ++ "@@MP_END@@\\n";
    try h.apply(a, wire, 7, key);
    const disk = try h.encode(a, key);
    defer a.free(disk);
    var restored = try chat_history.History.decode(a, disk, key);
    defer restored.deinit(a);
    try enqueue(std.unicode.utf8ToUtf16LeStringLiteral("hello\\nworld "), .not_sent);
    g_chat_outbox.items[0].anchor = .{ .after_ms = chat_echo.stampMs("2026-10-12T17:59:00Z") };
    g_chat_capture = restored.text.items;
    g_chat_last_len = restored.text.items.len;
    for (g_chat_blocks[0..299]) |*b| b.* = .{ .role = .injected, .start = 0, .len = restored.text.items.len, .stamp_ms = restored.blocks.items[0].stamp_ms };
    g_chat_block_count = 299;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    g_chat_blocks[299] = restored.blocks.items[0];
    g_chat_block_count = 300;
    g_chat_last_hash +%= 1;
    chatEchoMatchActive();
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(usize, 1), g_chat_confirmed.items.len);
}
`;
const names = ['chatOutboxCountIn', 'chatOutboxFirstIndexIn', 'chatOutboxFirstSendableIndexIn', 'chatOutboxFindSending', 'chatOutboxIndexById', 'chatOutboxRemoveAtIn', 'chatOutboxEnqueueInState', 'chatOutboxSerialize', 'chatOutboxParseJson', 'appendJsonEscaped', 'appendJsonEscapedWide', 'chatEchoNormalizePrefix', 'chatEchoAssignForKey', 'chatEchoStoreAnchors', 'chatEchoAssignedBlock', 'chatConfirmedCountIn', 'chatConfirmedFirstIndexIn', 'chatConfirmedAdd', 'chatEchoMatchActive', 'chatEchoDeliveryEvidence', 'chatEchoRetryAllForActive', 'sendTextToShellVerifiedAt', 'chatOutboxTrySendEntry'];
function runHarness(control = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh307-'));
  try {
    for (const file of ['chat_echo.zig', 'chat_history.zig', 'chat_transcript.zig', 'chat_markdown.zig', 'chat_style.zig', 'chat_image.zig', 'json_reader.zig', 'archive_rules.zig', 'voice_filter.zig']) fs.copyFileSync(`src/${file}`, path.join(dir, file));
    if (control === true) {
      const file = path.join(dir, 'chat_history.zig');
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(/        for \(self.blocks.items\[first_block\.\.\]\) \|\*block\| block.stamp_ms = .*;\n/, ''));
    }
    let functions = names.map(body).join('\n');
    if (control === 'settlement') {
      functions = functions.replace('const facts = chatEchoDeliveryEvidence(e);', 'const facts: chat_echo.DeliveryEvidence = .{};');
      assert.notEqual(functions, names.map(body).join('\n'));
    }
    if (control === 'repeats' || control === 'unreadable') {
      const old = fs.readFileSync('tools/fixtures/chat-before-2b45249.zig', 'utf8');
      const oldBody = name => { const start = old.indexOf(`fn ${name}(`); return old.slice(start, old.indexOf('\n}', start) + 2); };
      functions = functions.replace(body('chatEchoMatchActive'), oldBody('chatEchoMatchActive').replaceAll(', now_ms, loaded_ms)', ', now_ms)').replace('    const loaded_ms = chatEchoLoadedMs();\n', '')) + '\n' + oldBody('chatEchoRepresentedBlock');
    }
    fs.writeFileSync(path.join(dir, 'test.zig'), prelude + ['ChatOutboxEntry', 'ChatConfirmedEcho', 'ChatEchoAssignment'].map(declaration).join('\n') + functions + acceptance);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', control === 'settlement' ? 'delivery: refused real' : control === 'repeats' ? 'delivery: repeats' : control === 'unreadable' ? 'delivery: aged unconfirmed' : 'delivery:'], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('correctness repeats and unreadable: executed production outbox, write reservation and matching handle restart, busy/idle, repeated text and cache reload', () => {
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('cache timestamp oracle rejects the actual integration omission (positive control)', () => {
  const result = runHarness(true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected 0, found 1/);
});
test('retry UI cannot retype reserved messages and pending bubbles never say Sent', () => {
  assert.match(body('chatEchoRetryAt'), /write_started/);
  assert.match(body('chatEchoRetryAllForActive'), /write_started/);
  assert.doesNotMatch(body('chatPaintEchoStatus'), /2713.*Sent/);
  assert.doesNotMatch(body('chatEchoMatchActive'), /chatEchoRepresentedBlock/);
  assert.match(body('chatDeferTranscriptLoad'), /chatEchoMatchActive\(\)/);
});

test('correctness repeats: old destructive cleanup fails the queued-repeat oracle', () => {
  const result = runHarness('repeats');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /repeats.*FAIL|expected 3, found 0/);
});
test('correctness unreadable: old expiry erasure fails the recoverable-intent oracle', () => {
  const result = runHarness('unreadable');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /aged unconfirmed.*FAIL|expected 2, found 1/);
});

test('stuck-refusal oracle rejects ignored delivery evidence (positive control)', () => {
  const result = runHarness('settlement');
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /expected .+not_sent, found .+delivered/);
});
