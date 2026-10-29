const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
const start = source.indexOf('fn debugLog(');
const logger = source.slice(start, source.indexOf('\n}', start) + 2);
const lineStart = source.indexOf('fn buildDebugLine(');
const lineBuilder = source.slice(lineStart, source.indexOf('\n}', lineStart) + 2);
const mutexStart = source.indexOf('const SpinMutex = struct {');
const mutex = source.slice(mutexStart, source.indexOf('\n};', mutexStart) + 3);

function contention(withLock) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'multiprompt-debug-log-'));
  try {
    const body = withLock ? logger : logger
      .replace('    while (!g_debug_log_mutex.tryLock()) Sleep(1);\n', '')
      .replace('    defer g_debug_log_mutex.unlock();\n', '');
    const fixture = `const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
${mutex}
var g_debug_log_mutex: SpinMutex = .{};
${body}
${lineBuilder}
const HANDLE = usize;
const SYSTEMTIME = struct {};
fn GetLocalTime(_: *SYSTEMTIME) void {}
fn formatLogTimestamp(buf: []u8, _: SYSTEMTIME) ?[]const u8 {
    const ts = "2026-10-18 03:04:05.067";
    @memcpy(buf[0..ts.len], ts);
    return buf[0..ts.len];
}
fn openAppendRotating(p: []const u8) ?HANDLE { return win32OpenAppend(p); }
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
    if (std.mem.eql(u8, bytes, "2026-10-18 03:04:05.067 paint record\\n")) _ = records.fetchAdd(1, .monotonic);
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
    fs.writeFileSync(file, fixture.replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
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


test('IGSH-1149 audit escaping preserves every byte without a file write per character', () => {
  const extract = name => {
    const start = source.indexOf(`fn ${name}(`);
    assert.ok(start >= 0, name);
    return source.slice(start, source.indexOf('\n}', start) + 2);
  };
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'audit-batches-'));
  try {
    const code = String.raw`const std = @import("std");
const HANDLE = usize;
var output: [20000]u8 = undefined;
var used: usize = 0;
var writes: usize = 0;
fn win32WriteAll(_: HANDLE, bytes: []const u8) void {
    @memcpy(output[used..][0..bytes.len], bytes);
    used += bytes.len;
    writes += 1;
}
${extract('writeAuditEscapedBytes')}
${extract('writeAuditEscapedWideAscii')}
test "complete audit text keeps escaping and uses batched writes" {
    const plain: [3000]u8 = @splat('a');
    writeAuditEscapedBytes(1, &plain);
    try std.testing.expectEqualSlices(u8, &plain, output[0..used]);
    try std.testing.expectEqual(@as(usize, 1), writes);
    used = 0; writes = 0;
    writeAuditEscapedBytes(1, &.{'a', '\\', '"', '\r', '\n', 'b'});
    try std.testing.expectEqualSlices(u8, &.{'a', '\\', '\\', '\\', '"', '\\', 'r', '\\', 'n', 'b'}, output[0..used]);
    used = 0; writes = 0;
    const wide: [10000]u16 = @splat('z');
    writeAuditEscapedWideAscii(1, &wide);
    try std.testing.expectEqual(@as(usize, wide.len), used);
    for (output[0..used]) |c| try std.testing.expectEqual(@as(u8, 'z'), c);
    try std.testing.expect(writes <= 3);
    used = 0; writes = 0;
    writeAuditEscapedWideAscii(1, &.{'a', '\\', 0x65e5, '\n', '"'});
    try std.testing.expectEqualSlices(u8, &.{'a', '\\', '\\', '?', '?', '\\', '"'}, output[0..used]);
    used = 0; writes = 0;
    writeAuditEscapedBytes(1, "");
    writeAuditEscapedWideAscii(1, &.{});
    try std.testing.expectEqual(@as(usize, 0), used);
    try std.testing.expectEqual(@as(usize, 0), writes);
}
`;
    fs.writeFileSync(path.join(dir, 'audit.zig'), code);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'audit.zig')], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
