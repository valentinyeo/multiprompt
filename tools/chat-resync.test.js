const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('Resync retires cached generation without touching draft or delivery, and evidence rejects broken repair', async () => {
  const source = read('src/chat_session.zig');
  const match = source.match(/pub fn chatResync\(\) void \{[^]*?\n\}/);
  assert.ok(match, 'Existing chat menu needs a non-destructive Resync action');
  const body = match[0].replace('pub fn', 'fn').replaceAll('app_state.', '');
  assert.doesNotMatch(body, /chatResetForShell|sendChat|chatOutbox|SetWindowText|DeleteFile/);
  assert.match(source, /entry\.resync and !disk and !history\.more and history\.start == 0/);
  assert.match(source, /showHeaderNoticeAscii\("Chat resynced"/);
  assert.match(read('src/more_menu.zig'), /\.resync => "Resync chat"/);
  assert.match(read('src/main.zig'), /Item\.resync\) => @import\("chat_session.zig"\)\.chatResync\(\)/);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-resync-'));
  try {
    fs.writeFileSync(path.join(dir, 'proof.zig'), String.raw`
const std = @import("std");
const Key = struct { shell_id: u32 = 42 };
const Entry = struct { key: Key = .{}, cache_cancelled: std.atomic.Value(bool) = .init(false), disk_loaded: bool = false, resync: bool = false };
var old: Entry = .{};
var fresh: Entry = .{};
var entries = [_]*Entry{&old};
var g_chat_histories = struct { items: []*Entry }{ .items = &entries };
var active_shell: u32 = 0;
var shell_count: u32 = 1;
var owns = true;
var allocate = true;
var requests: usize = 0;
var forgotten: usize = 0;
var notices: usize = 0;
var draft: [5]u8 = "draft".*;
var outbox: [4]u8 = "sent".*;
var g_chat_cache_write_mutex = struct {
    held: bool = false,
    fn tryLock(self: *@This()) bool { std.debug.assert(!self.held); self.held = true; return true; }
    fn unlock(self: *@This()) void { std.debug.assert(self.held); self.held = false; }
}{};
fn Sleep(_: u32) void { unreachable; }
fn chatViewOwnsInput() bool { return owns; }
fn chatFileIdentity() Key { return .{}; }
fn chatHistoryForget(id: u32) void {
    std.debug.assert(g_chat_cache_write_mutex.held and id == 42 and old.cache_cancelled.load(.acquire));
    forgotten += 1;
}
fn chatHistoryEntry(_: Key) ?*Entry { return if (allocate) &fresh else null; }
fn chatFileRequest(_: Key) void {
    std.debug.assert(!g_chat_cache_write_mutex.held and fresh.disk_loaded and fresh.resync);
    requests += 1;
}
fn debugLog(_: []const u8) void { notices += 1; }
` + body + String.raw`
test "fresh source without stale disk, unchanged draft and outbox, guarded invalid states" {
    chatResync();
    try std.testing.expectEqual(@as(usize, 1), requests);
    try std.testing.expectEqual(@as(usize, 1), forgotten);
    try std.testing.expectEqualStrings("draft", &draft);
    try std.testing.expectEqualStrings("sent", &outbox);
    owns = false;
    chatResync();
    owns = true;
    active_shell = 1;
    chatResync();
    try std.testing.expectEqual(@as(usize, 1), requests);
    active_shell = 0;
    allocate = false;
    chatResync();
    try std.testing.expectEqual(@as(usize, 1), requests);
    try std.testing.expect(!g_chat_cache_write_mutex.held);
}
`);
    const result = spawnSync(process.env.ZIG_EXE || 'zig', ['test', path.join(dir, 'proof.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  const { verifyObserved } = await import('./chat-resync-proof.mjs');
  const value = {error: null, draftBefore: 'draft stays here', draftAfter: 'draft stays here', waitingBefore: 'queued:stale waiting message', waitingAfter: '', copied: 'After  resync', sendStart: 10, sendEnd: 20};
  const rewrite = {before: 'Before resync', after: 'After  resync', bytes: 13};
  const log = '[chat] resync requested\n[chat] resync completed';
  assert.equal(verifyObserved(value, [], rewrite, log), true);
  assert.throws(() => verifyObserved({...value, draftAfter: ''}, [], rewrite, log), /draft preserved/);
  assert.throws(() => verifyObserved({...value, waitingAfter: value.waitingBefore}, [], rewrite, log), /waiting label repaired/);
  assert.throws(() => verifyObserved(value, [{ms: 15, argv: ['send-keys', 'Enter']}], rewrite, log), /no message transport/);
  assert.throws(() => verifyObserved(value, [], rewrite, ''), /source reload completed/);
});
