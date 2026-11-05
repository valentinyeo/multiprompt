const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');

function declaration(source, marker) {
  const start = source.indexOf(marker);
  assert.ok(start >= 0, `missing ${marker}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  let end = open + 1;
  while (depth && end < source.length) {
    if (source[end] === '{') depth++;
    if (source[end] === '}') depth--;
    end++;
  }
  return source.slice(start, end);
}

function zig(source) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'freeze-upload-'));
  try {
    const file = path.join(dir, 'test.zig');
    const model = path.join(root, 'src/watchdog_health.zig');
    assert.ok(fs.existsSync(model), 'watchdog coverage tracker exists');
    fs.copyFileSync(model, path.join(dir, 'watchdog_health.zig'));
    fs.writeFileSync(file, source);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('a hidden, non-pumping window records once even when sent WM_NULL succeeds', () => {
  const source = fs.readFileSync(path.join(root, 'src/freeze_recorder.zig'), 'utf8');
  zig(`const std = @import("std");
const THRESHOLD_MS = 5000;
const upload = struct { const Kind = enum { freeze, blank_chat }; };
var g_stop: ?*anyopaque = null;
var g_window: ?*anyopaque = null;
var g_message: u32 = 0xC000;
var g_ack = std.atomic.Value(u32).init(0);
var g_blank_pending = std.atomic.Value(bool).init(false);
var g_paint_demand = std.atomic.Value(u64).init(0);
var g_active = false;
var cancel_paint = false;
var last_reason: ?Reason = null;
var tick: u64 = 0;
var records: usize = 0;
var posts: usize = 0;
var healthy = false;
var health_reports: usize = 0;
var last_health: @import("watchdog_health.zig").Snapshot = .{};
const PostMessageW = win.PostMessageW;
fn awakeMillis() u64 { return tick; }
fn unixTime() i64 { return 100; }
fn publishHealth(_: i64, _: u64, _: u32, value: @import("watchdog_health.zig").Snapshot) void {
    health_reports += 1;
    last_health = value;
}
${declaration(source, 'const Reason = enum')};
fn record(_: upload.Kind, _: u64, reason: Reason) void { records += 1; last_reason = reason; }
const win = struct {
    const HANDLE = ?*anyopaque;
    fn WaitForSingleObject(_: HANDLE, timeout: u32) u32 {
        if (timeout == 0) return 0x102;
        tick += timeout;
        if (cancel_paint and tick >= 3000) activation(false);
        return if (tick <= 65000) 0x102 else 0;
    }
    fn IsWindow(_: HANDLE) i32 { return 1; }
    fn IsWindowVisible(_: HANDLE) i32 { return 0; }
    fn SendMessageTimeoutW(_: HANDLE, _: u32, _: usize, _: isize, _: u32, _: u32, _: *usize) usize { return 1; }
    fn PostMessageW(_: HANDLE, _: u32, token: usize, _: isize) i32 {
        posts += 1;
        if (healthy) g_ack.store(@truncate(token), .release);
        return 1;
    }
};
${declaration(source, 'pub const Detector = struct')};
${declaration(source, 'const PaintDetector = struct')};
${declaration(source, 'pub fn activation(')}
${declaration(source, 'pub fn painted(')}
${declaration(source, 'fn worker(')}
test "hidden hang and healthy negative control" {
    _ = worker(null);
    try std.testing.expectEqual(@as(usize, 1), records);
    try std.testing.expectEqual(@as(usize, 1), posts);
    try std.testing.expectEqual(@as(usize, 1), health_reports);
    try std.testing.expectEqual(@as(u32, 1), last_health.freezes);
    try std.testing.expectEqual(@as(u64, 0), last_health.responsive_ms);
    tick = 0; records = 0; posts = 0; healthy = true; health_reports = 0;
    _ = worker(null);
    try std.testing.expectEqual(@as(usize, 0), records);
    try std.testing.expect(posts > 1);
    try std.testing.expectEqual(@as(usize, 1), health_reports);
    try std.testing.expectEqual(@as(u32, 0), last_health.freezes);
    try std.testing.expectEqual(@as(u64, 60000), last_health.responsive_ms);
    tick = 0; records = 0; posts = 0; last_reason = null;
    activation(true);
    _ = worker(null);
    try std.testing.expectEqual(@as(usize, 1), records);
    try std.testing.expectEqual(Reason.paint, last_reason.?);
    try std.testing.expect(posts > 1);
    activation(false);
    tick = 0; records = 0; posts = 0; cancel_paint = true;
    activation(true);
    _ = worker(null);
    try std.testing.expectEqual(@as(usize, 0), records);
    tick = 0; records = 0; posts = 0; cancel_paint = false;
    activation(true);
    painted();
    _ = worker(null);
    try std.testing.expectEqual(@as(usize, 0), records);
}
`);
});

test('upload payload uses the existing service schema without messages, paths or hosts', () => {
  const file = path.join(root, 'src/report_upload.zig');
  assert.ok(fs.existsSync(file), 'desktop reports must have an upload payload');
  const source = fs.readFileSync(file, 'utf8');
  zig(`const std = @import("std");
${declaration(source, 'pub const Kind = enum')};
${declaration(source, 'pub const Module = enum')};
${declaration(source, 'pub const FreezeContext = union')};
${declaration(source, 'pub fn payload(')}
${declaration(source, 'fn contextualPayload(')}
${declaration(source, 'pub fn watchdogPayload(')}
test "watchdog coverage uses numeric diagnostics without private input" {
    var out: [2048]u8 = undefined;
    const bytes = watchdogPayload(&out, "watchdog-100-2-300-0", "0.28.1", 160, .{ .observed_ms = 60000, .responsive_ms = 59500, .unobserved_ms = 0, .freezes = 0 }).?;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, bytes, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 7), parsed.value.object.count());
    try std.testing.expectEqualStrings("Windows watchdog health", parsed.value.object.get("summary").?.string);
    try std.testing.expectEqualStrings("watchdog", parsed.value.object.get("thread").?.string);
    try std.testing.expectEqualStrings("observed_ms: 60000\\nresponsive_ms: 59500\\nunobserved_ms: 0\\nfreezes: 0\\n", parsed.value.object.get("stack_trace").?.string);
    try std.testing.expect(watchdogPayload(&out, "private/path", "0.28.1", 160, .{}) == null);
    try std.testing.expect(watchdogPayload(&out, "watchdog-100-2-300-0", "private/path", 160, .{}) == null);
    try std.testing.expect(watchdogPayload(&out, "watchdog-100-2-300-0", "0.28.1", 160, .{ .responsive_ms = 1 }) == null);
}
test "service payload and private input rejection" {
    var out: [8192]u8 = undefined;
    for ([_]Kind{.freeze, .crash, .blank_chat}) |kind| {
        const bytes = payload(&out, "report-12345", kind, "0.28.1", 1793016000, 0xC0000005, &.{0x1234, 0x5678}).?;
        const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, bytes, .{});
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 7), parsed.value.object.count());
        try std.testing.expectEqualStrings("0.28.1", parsed.value.object.get("app_version").?.string);
        try std.testing.expectEqualStrings("exception_code: 0xC0000005\\nstack_rvas:\\n  0x1234\\n  0x5678\\n", parsed.value.object.get("stack_trace").?.string);
    }
    try std.testing.expect(payload(&out, "private/path", .crash, "0.28.1", 0, 0, &.{}) == null);
    try std.testing.expect(payload(&out, "report-12345", .crash, "private/path", 0, 0, &.{}) == null);
    try std.testing.expect(payload(&out, "report-12345", .crash, "private\\\"text", 0, 0, &.{}) == null);
}
`);
});
