const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const os = require('node:os');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1170 a save on the UI thread never writes or flushes a file itself', () => {
  const source = read('src/file_io.zig');
  const queue = source.indexOf('fn queueWrite(');
  const worker = source.indexOf('fn writerLoop(');
  const entry = source.indexOf('pub fn writeFileAtomicW(');
  const sync = source.indexOf('pub fn writeFileAtomicSync(');
  assert.ok(queue >= 0, 'a write queue must exist');
  assert.ok(worker >= 0, 'one writer worker must exist');
  assert.ok(sync > entry, 'the flushing writer must be separate from the UI-thread entry point');
  const entryBody = source.slice(entry, source.indexOf('\npub fn ', entry + 10));
  assert.match(entryBody, /uiThreadBusy\(\)/, 'the entry point must know it is on the UI thread');
  assert.match(entryBody, /queueWrite\(path, bytes\)/, 'a UI-thread write must be queued');
  assert.ok(!/FlushFileBuffers/.test(entryBody), 'the UI-thread entry point must not flush');
  const workerBody = source.slice(worker, entry);
  assert.match(workerBody, /writeFileAtomicSync\(/, 'the worker performs the real write');
  const syncBody = source.slice(sync);
  assert.match(syncBody, /FlushFileBuffers\(h\)/, 'the worker keeps the flush for crash safety');
  assert.match(syncBody, /MoveFileExW\(tmp_w\.ptr, path_w\.ptr/, 'the worker keeps the atomic rename');
  assert.match(source, /pub fn flushPendingWrites\(\)/, 'shutdown must be able to drain the queue once');
  assert.match(read('src/main.zig'), /flushPendingWrites\(\);/, 'shutdown calls the drain');
});

test('IGSH-1170 the queue coalesces by path so the latest snapshot wins', () => {
  const source = read('src/file_io.zig');
  const slot = source.slice(source.indexOf('fn pendingSlot('), source.indexOf('fn queueWrite('));
  assert.match(slot, /std\.mem\.eql\(u8, slot\.path\[0\.\.slot\.path_len\], path\)/, 'a path already queued is reused');
  assert.match(source, /if \(slot\.bytes\) \|old_bytes\| std\.heap\.page_allocator\.free\(old_bytes\);/, 'the replaced snapshot is freed');
});

test('IGSH-1170 production UI save rejects failed admission without synchronous disk IO', () => {
  const source = read('src/file_io.zig');
  const start = source.indexOf('pub fn writeFileAtomicW(');
  const end = source.indexOf('\npub fn writeFileAtomicSync(', start);
  assert.ok(start >= 0 && end > start);
  const entry = source.slice(start, end);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ui-save-admission-'));
  try {
    const production = entry.replaceAll('@import("app_state.zig")', '@This()').replaceAll('@import("win32.zig")', '@This()');
    fs.writeFileSync(path.join(dir, 'test.zig'), String.raw`
const std = @import("std");
const HANDLE = ?*anyopaque;
var on_ui = true;
var admission = true;
var synchronous_ok = true;
var queue_calls: usize = 0;
var sync_calls: usize = 0;
var notices: usize = 0;
var post_ok: i32 = 1;
pub var g_app_closing = false;
pub var g_main_hwnd: HANDLE = @ptrFromInt(1);
pub const WM_APP_APP_SAVE_FAILED: u32 = 123;
var g_save_failure_pending = std.atomic.Value(bool).init(false);
pub const FocusNative = struct {
    pub fn PostMessageW(_: HANDLE, message: u32, _: usize, _: isize) i32 {
        std.debug.assert(message == WM_APP_APP_SAVE_FAILED);
        notices += 1;
        return post_ok;
    }
};
fn uiThreadBusy() bool { return on_ui; }
fn queueWrite(_: []const u8, _: []const u8) bool { queue_calls += 1; return admission; }
fn writeFileAtomicSync(_: []const u8, _: []const u8) bool { sync_calls += 1; return synchronous_ok; }
fn reset() void {
    on_ui = true; admission = true; synchronous_ok = true;
    queue_calls = 0; sync_calls = 0; notices = 0; post_ok = 1;
    g_app_closing = false; g_main_hwnd = @ptrFromInt(1);
    g_save_failure_pending.store(false, .release);
}
` + production + String.raw`
test "full queue or failed worker admission never enters synchronous IO on UI" {
    reset(); admission = false;
    try std.testing.expect(!writeFileAtomicW("settings.json", "latest"));
    try std.testing.expectEqual(@as(usize, 1), queue_calls);
    try std.testing.expectEqual(@as(usize, 0), sync_calls);
    try std.testing.expectEqual(@as(usize, 1), notices);
    try std.testing.expect(!writeFileAtomicW("settings.json", "newer"));
    try std.testing.expectEqual(@as(usize, 1), notices);
    try std.testing.expectEqual(@as(usize, 0), sync_calls);
}
test "empty UI saves use the same nonblocking admission policy" {
    reset();
    try std.testing.expect(writeFileAtomicW("empty.txt", ""));
    try std.testing.expectEqual(@as(usize, 1), queue_calls);
    try std.testing.expectEqual(@as(usize, 0), sync_calls);
    admission = false;
    try std.testing.expect(!writeFileAtomicW("empty.txt", ""));
    try std.testing.expectEqual(@as(usize, 0), sync_calls);
}
test "accepted UI save is queued once without a failure notice" {
    reset();
    try std.testing.expect(writeFileAtomicW("settings.json", "latest"));
    try std.testing.expectEqual(@as(usize, 1), queue_calls);
    try std.testing.expectEqual(@as(usize, 0), sync_calls);
    try std.testing.expectEqual(@as(usize, 0), notices);
}
test "background writes preserve synchronous success and failure results" {
    reset(); on_ui = false;
    try std.testing.expect(writeFileAtomicW("settings.json", "latest"));
    synchronous_ok = false;
    try std.testing.expect(!writeFileAtomicW("settings.json", "latest"));
    try std.testing.expectEqual(@as(usize, 0), queue_calls);
    try std.testing.expectEqual(@as(usize, 2), sync_calls);
}
test "failed notification can retry and closing suppresses notices" {
    reset(); admission = false; post_ok = 0;
    try std.testing.expect(!writeFileAtomicW("settings.json", "latest"));
    try std.testing.expect(!g_save_failure_pending.load(.acquire));
    post_ok = 1;
    try std.testing.expect(!writeFileAtomicW("settings.json", "latest"));
    try std.testing.expectEqual(@as(usize, 2), notices);
    reset(); admission = false; g_app_closing = true;
    try std.testing.expect(!writeFileAtomicW("settings.json", "latest"));
    try std.testing.expectEqual(@as(usize, 0), notices);
    try std.testing.expectEqual(@as(usize, 0), sync_calls);
}
`);
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 5 tests passed/);
    console.log(result.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
