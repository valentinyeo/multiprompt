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
var tick: u64 = 0;
var records: usize = 0;
var posts: usize = 0;
var healthy = false;
const PostMessageW = win.PostMessageW;
fn awakeMillis() u64 { return tick; }
${source.includes("record(.freeze,") ? "fn record(_: upload.Kind, _: u64) void" : "fn record(_: u64) void"} { records += 1; }
const win = struct {
    const HANDLE = ?*anyopaque;
    fn WaitForSingleObject(_: HANDLE, timeout: u32) u32 {
        if (timeout == 0) return 0x102;
        tick += timeout;
        return if (tick <= 20000) 0x102 else 0;
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
${declaration(source, 'fn worker(')}
test "hidden hang and healthy negative control" {
    _ = worker(null);
    try std.testing.expectEqual(@as(usize, 1), records);
    try std.testing.expectEqual(@as(usize, 1), posts);
    tick = 0; records = 0; posts = 0; healthy = true;
    _ = worker(null);
    try std.testing.expectEqual(@as(usize, 0), records);
    try std.testing.expect(posts > 1);
}
`);
});

test('upload payload uses the existing service schema without messages, paths or hosts', () => {
  const file = path.join(root, 'src/report_upload.zig');
  assert.ok(fs.existsSync(file), 'desktop reports must have an upload payload');
  const source = fs.readFileSync(file, 'utf8');
  zig(`const std = @import("std");
${declaration(source, 'pub const Kind = enum')};
${declaration(source, 'pub fn payload(')}
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
