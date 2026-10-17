const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
const start = source.indexOf('fn debugLog(');
const logger = source.slice(start, source.indexOf('\n}', start) + 2);
const mutexStart = source.indexOf('const SpinMutex = struct {');
const mutex = source.slice(mutexStart, source.indexOf('\n};', mutexStart) + 3);

function contention(withLock) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'multiprompt-debug-log-'));
  try {
    const body = withLock ? logger : logger
      .replace('    while (!g_debug_log_mutex.tryLock()) Sleep(1);\n', '')
      .replace('    defer g_debug_log_mutex.unlock();\n', '');
    const fixture = `const std = @import("std");
${mutex}
var g_debug_log_mutex: SpinMutex = .{};
${body}
const HANDLE = usize;
var opened: std.atomic.Value(bool) = .init(false);
var attempts: std.atomic.Value(u32) = .init(0);
var records: std.atomic.Value(u32) = .init(0);
var ready: std.atomic.Value(u32) = .init(0);
var go: std.atomic.Value(bool) = .init(false);
fn verboseLoggingEnabled() bool { return true; }
fn getLogPath(_: *[512]u8) ?[]const u8 { return "debug.log"; }
fn Sleep(_: u32) void { std.atomic.spinLoopHint(); }
fn win32OpenAppend(_: []const u8) ?HANDLE {
    if (opened.swap(true, .acq_rel)) return null;
    for (0..10000) |_| std.atomic.spinLoopHint();
    return 1;
}
fn win32WriteAll(_: HANDLE, bytes: []const u8) void {
    if (std.mem.eql(u8, bytes, "paint record")) _ = records.fetchAdd(1, .monotonic);
}
fn CloseHandle(_: HANDLE) bool { opened.store(false, .release); return true; }
fn writer() void {
    _ = ready.fetchAdd(1, .release);
    while (!go.load(.acquire)) std.atomic.spinLoopHint();
    for (0..100) |_| {
        _ = attempts.fetchAdd(1, .monotonic);
        debugLog("paint record");
    }
}
test "concurrent exclusive appends retain every paint record" {
    var threads: [8]std.Thread = undefined;
    for (&threads) |*thread| thread.* = try std.Thread.spawn(.{}, writer, .{});
    while (ready.load(.acquire) != threads.len) std.atomic.spinLoopHint();
    go.store(true, .release);
    for (threads) |thread| thread.join();
    try std.testing.expectEqual(@as(u32, 800), attempts.load(.acquire));
    try std.testing.expectEqual(attempts.load(.acquire), records.load(.acquire));
}
`;
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, fixture);
    return spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

test('concurrent UI and worker debug logs retain all exclusive-append records', () => {
  const result = contention(true);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('unserialized pre-fix logger loses records under the same contention oracle', () => {
  assert.match(source, /var g_debug_log_mutex: SpinMutex = \.\{\};/);
  assert.match(logger, /while \(!g_debug_log_mutex\.tryLock\(\)\) Sleep\(1\);/);
  const result = contention(false);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /FAIL \(TestExpectedEqual\)/);
});
