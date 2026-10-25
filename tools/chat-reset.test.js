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
const harness = `
const std = @import("std");
const chat_echo = @import("chat_echo.zig");
const ChatEchoState = chat_echo.OutboxState;
const CHAT_OUTBOX_KEY_CAP = 256;
const CHAT_OUTBOX_MSG_CAP = 16384;
const CHAT_OUTBOX_TOTAL_MAX = 400;
const CHAT_OUTBOX_MAX_PER_KEY = 20;
var g_chat_echo_next_id: u64 = 1;
var g_chat_outbox: std.ArrayList(ChatOutboxEntry) = .empty;
var g_chat_verify_echo_id: u64 = 0;
var g_chat_verify_shell_id: u32 = 11;
var shell_count: u32 = 2;
var active_shell: u32 = 0;
const Shell = struct { shell_id: u32, pid: u32 };
var shells = [_]Shell{ .{ .shell_id = 11, .pid = 123 }, .{ .shell_id = 22, .pid = 456 } };
var g_chat_active = true;
const Entry = struct { key: Shell, cache_cancelled: std.atomic.Value(bool) = .init(false), disk_loaded: bool = false };
var old_entry = Entry{ .key = .{ .shell_id = 11, .pid = 0 } };
var new_entry = Entry{ .key = .{ .shell_id = 11, .pid = 0 } };
var entries = [_]*Entry{&old_entry};
var g_chat_histories = struct { items: []*Entry }{ .items = &entries };
const Mutex = struct {
    locked: bool = false,
    fn tryLock(self: *@This()) bool { std.debug.assert(!self.locked); self.locked = true; return true; }
    fn unlock(self: *@This()) void { std.debug.assert(self.locked); self.locked = false; }
};
var g_chat_cache_write_mutex = Mutex{};
var deleted: usize = 0;
var forgotten: u32 = 0;
var saved: usize = 0;
var refreshed: usize = 0;
var deferred: usize = 0;
var confirmed_dropped: ?[]const u8 = null;
const composer = std.unicode.utf8ToUtf16LeStringLiteral("unsent typed text");
var composer_text: []const u16 = composer;
fn chatOutboxKeyForShell(idx: u32, _: []u8) []const u8 { return if (idx == 0) "one" else "two"; }
fn chatVerifyClear() void { g_chat_verify_echo_id = 0; }
fn chatConfirmedDropKey(key: []const u8) void { confirmed_dropped = key; }
fn saveChatOutbox() bool { saved += 1; return true; }
fn chatOutboxChanged() void {}
fn chatFileIdentityForShell(idx: u32) Shell { return shells[idx]; }
fn Sleep(_: u32) void { unreachable; }
fn chatHistoryForget(id: u32) void {
    std.debug.assert(g_chat_cache_write_mutex.locked);
    if (old_entry.key.shell_id == id) std.debug.assert(old_entry.cache_cancelled.load(.acquire));
    forgotten = id;
}
fn chatHistoryPath(_: Shell, _: *[560]u8) ?[]const u8 { return "one.jsonl"; }
fn win32WidePath(_: *[600]u16, _: []const u8) ?struct { ptr: [*:0]const u16 } { return .{ .ptr = std.unicode.utf8ToUtf16LeStringLiteral("one.jsonl") }; }
fn DeleteFileW(_: [*:0]const u16) i32 { std.debug.assert(g_chat_cache_write_mutex.locked); deleted += 1; return 1; }
fn chatHistoryEntry(_: Shell) ?*Entry { return &new_entry; }
fn chatDeferTranscriptLoad() void { deferred += 1; }
fn refreshChatTranscript(force: bool) void { std.debug.assert(force and new_entry.disk_loaded); refreshed += 1; }
`;
const acceptance = `
test "reset: every local phase clears only the target, cancels verification and preserves composer/session" {
    defer {
        for (g_chat_outbox.items) |e| std.heap.page_allocator.free(e.text);
        g_chat_outbox.deinit(std.heap.page_allocator);
    }
    const text = std.unicode.utf8ToUtf16LeStringLiteral("stuck");
    for ([_]ChatEchoState{ .queued, .sending, .not_sent, .delivered }) |state| {
        try std.testing.expect(chatOutboxEnqueueInState(&g_chat_outbox, std.heap.page_allocator, "one", text, state));
        g_chat_outbox.items[g_chat_outbox.items.len - 1].retryable = state == .not_sent;
    }
    g_chat_verify_echo_id = g_chat_outbox.items[1].id;
    try std.testing.expect(chatOutboxEnqueueInState(&g_chat_outbox, std.heap.page_allocator, "two", text, .queued));
    const before = shells;
    chatResetForShell(0);
    try std.testing.expectEqual(@as(usize, 1), g_chat_outbox.items.len);
    try std.testing.expectEqualStrings("two", g_chat_outbox.items[0].key[0..g_chat_outbox.items[0].key_len]);
    try std.testing.expectEqual(@as(u64, 0), g_chat_verify_echo_id);
    try std.testing.expectEqual(@as(usize, 1), saved);
    try std.testing.expectEqual(@as(usize, 1), deleted);
    try std.testing.expectEqual(@as(u32, 11), forgotten);
    try std.testing.expectEqual(@as(usize, 1), deferred);
    try std.testing.expectEqual(@as(usize, 1), refreshed);
    try std.testing.expectEqualStrings("one", confirmed_dropped.?);
    try std.testing.expectEqualSlices(u16, composer, composer_text);
    try std.testing.expectEqualDeep(before, shells);
    // Reset an inactive right-click target: no composer/transcript switch and
    // the other tab's in-flight verification remains intact.
    g_chat_verify_echo_id = g_chat_outbox.items[0].id;
    g_chat_verify_shell_id = 22;
    old_entry.cache_cancelled.store(false, .release);
    old_entry.key.shell_id = 22;
    chatResetForShell(0); // now the verifier belongs to the other tab
    try std.testing.expect(g_chat_verify_echo_id != 0);
    const refresh_before = refreshed;
    chatResetForShell(1);
    try std.testing.expectEqual(@as(usize, 0), g_chat_outbox.items.len);
    try std.testing.expectEqual(@as(u64, 0), g_chat_verify_echo_id);
    try std.testing.expectEqual(refresh_before, refreshed);
    try std.testing.expectEqual(@as(u32, 0), active_shell);
    try std.testing.expectEqualDeep(before, shells);
}
`;
test('executed production reset clears all phases only for its tab, preserves draft and session, retires workers and deletes cache', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh307-reset-'));
  try {
    copyZig(['chat_echo.zig'], dir);
    const names = ['chatOutboxCountIn', 'chatOutboxFirstIndexIn', 'chatOutboxIndexById', 'chatOutboxRemoveAtIn', 'chatOutboxClearIn', 'chatOutboxEnqueueInState', 'chatOutboxDropForKey', 'chatResetForShell'];
    fs.writeFileSync(path.join(dir, 'test.zig'), harness + declaration('ChatOutboxEntry') + names.map(body).join('\n') + acceptance);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', 'reset:'], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
test('reset has all command surfaces and rejects obsolete cache writes/results', () => {
  assert.match(source, /SEARCH_CHAT_RESET_OFFSET: usize = 6394/);
  assert.match(source, /SEARCH_TABCTX_CHAT_RESET: usize = 7117/);
  assert.match(source, /SEARCH_CHAT_RESET_OFFSET => "chat view reset this chat/);
  assert.match(source, /SEARCH_TABCTX_CHAT_RESET => "chat view reset this chat/);
  assert.match(body('updateSearchResults'), /g_search_results\[g_search_result_count\] = SEARCH_CHAT_RESET_OFFSET/);
  assert.match(body('updateSearchResults'), /g_search_results\[g_search_result_count\] = SEARCH_TABCTX_CHAT_RESET/);
  assert.match(source, /target == SEARCH_CHAT_RESET_OFFSET[\s\S]*?chatResetForShell\(active_shell\)/);
  assert.match(source, /target == SEARCH_TABCTX_CHAT_RESET[\s\S]*?chatResetForShell\(ti\)/);
  assert.match(source.slice(source.indexOf('const SHORTCUT_ROWS')), /Chat View: Reset this chat/);
  assert.match(fs.readFileSync('openwiki/operations/keyboard-shortcuts.md', 'utf8'), /Chat View: Reset this chat/);
  const worker = body('chatFileFetchThread');
  assert.ok(worker.indexOf('g_chat_cache_write_mutex.tryLock()') < worker.indexOf('entry.cache_cancelled.load(.acquire)'));
  assert.match(worker, /if \(!entry.cache_cancelled.load\(.acquire\)\) \{\s+if \(writeFileAtomicW/);
  assert.match(body('chatHistoryForget'), /if \(entry.pending\) \{\s+entry.retired = true/);
  assert.match(body('chatFileOnReady'), /if \(entry.retired\) \{[\s\S]*?continue;/);
  assert.match(body('chatFileOnReady'), /if \(!disk and !history.more and history.start == 0\) entry.loaded_ms/);
  const loadOutbox = body('loadChatOutbox');
  assert.match(loadOutbox, /const version = json_reader\.uintDefault\(parsed\.value, "version", 0\);\s+if \(version != 1 and version != 2\) return;\s+_ = chatOutboxPurgeOrphans\(\);\s+_ = saveChatOutbox\(\);/);
  assert.equal(loadOutbox.match(/saveChatOutbox\(/g)?.length, 1);
});
