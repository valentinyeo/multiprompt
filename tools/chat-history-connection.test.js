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
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const HANDLE = ?*anyopaque;
const DWORD = u32;
const SpinMutex = struct {
    held: bool = false,
    fn tryLock(self: *@This()) bool { if (self.held) return false; self.held = true; return true; }
    fn unlock(self: *@This()) void { std.debug.assert(self.held); self.held = false; }
};
const chat_transcript = struct {
    const Identity = struct {
        host: u8 = 0, shell_id: u32 = 1, codex: bool = false,
        sid: [40]u8 = @splat(0), tmux: [64]u8 = @splat(0), cwd: [192]u8 = @splat(0),
    };
};
const chat_history = struct {
    const TAIL_BYTES = 512 * 1024;
    const History = struct {
        sid: [40]u8 = @splat(0), inode: u64 = 0, offset: u64 = 0, start: u64 = 0,
        mtime: u64 = 0, probe: [64]u8 = @splat(0),
    };
};
var now: u64 = 0;
var starts: usize = 0;
var fallbacks: usize = 0;
var terminations: usize = 0;
var closes: usize = 0;
var writes: usize = 0;
var fail_start = false;
var partial_write = false;
var mode: enum { good, dead, hang, malformed, wrong_id, reader_error, truncated } = .good;
var frames: [3][2048]u8 = undefined;
var lengths: [3]usize = @splat(0);
var offsets: [3]usize = @splat(0);
fn GetTickCount64() u64 { return now; }
fn Sleep(ms: u32) void { now += ms; }
fn CloseHandle(_: HANDLE) i32 { closes += 1; return 1; }
fn TerminateProcess(_: HANDLE, _: u32) i32 { terminations += 1; return 1; }
fn WaitForSingleObject(_: HANDLE, _: u32) u32 { return if (mode == .dead or mode == .truncated) 0 else 258; }
fn chatBenchEnabled() bool { return false; }
fn chatBenchFetch(_: u32, _: u32, _: []const u8, _: *std.ArrayList(u8)) bool { unreachable; }
fn chatHistoryChannelStart(host: u8, ch: *ChatHistoryChannel) bool {
    std.debug.assert(g_chat_history_channel_mutex.held);
    starts += 1;
    if (fail_start) return false;
    ch.process = @ptrFromInt(1 + @as(usize, host));
    ch.input = @ptrFromInt(10 + @as(usize, host));
    ch.output = @ptrFromInt(20 + @as(usize, host));
    return true;
}
fn chatHistoryFetchOnce(_: u8, _: []const u8, _: usize, out: *std.ArrayList(u8)) bool {
    fallbacks += 1;
    std.debug.assert(out.items.len == 0);
    out.appendSlice(std.heap.page_allocator, "fallback") catch unreachable;
    return true;
}
fn WriteFile(h: HANDLE, bytes: [*]const u8, count: DWORD, written: *DWORD, _: ?*anyopaque) i32 {
    std.debug.assert(g_chat_history_channel_mutex.held);
    written.* = if (partial_write) count - 1 else count;
    if (count == 1) return 1;
    writes += 1;
    const host = @intFromPtr(h.?) - 10;
    const q = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, bytes[0..count], .{}) catch unreachable;
    defer q.deinit();
    const id = q.value.object.get("id").?.integer;
    const wire = if (mode == .reader_error) "@mp\t0\thistory\terror\t-\t0\n@@MP_END@@\n" else "@mp\t7\thistory\tok\tsid\t0\n{\"text\":\"escaped \\\" 雪\"}\n@@MP_END@@\n";
    const frame = std.json.Stringify.valueAlloc(std.heap.page_allocator, .{ .id = if (mode == .wrong_id) id + 1 else id, .wire = wire }, .{}) catch unreachable;
    defer std.heap.page_allocator.free(frame);
    const value = if (mode == .malformed) "not json" else frame;
    @memcpy(frames[host][0..value.len], value);
    frames[host][value.len] = '\n';
    lengths[host] = value.len + @as(usize, if (mode == .truncated) 0 else 1);
    offsets[host] = 0;
    return 1;
}
fn PeekNamedPipe(h: HANDLE, _: ?*anyopaque, _: u32, _: ?*u32, available: *DWORD, _: ?*u32) i32 {
    const host = @intFromPtr(h.?) - 20;
    available.* = if (mode == .dead or mode == .hang) 0 else @intCast(lengths[host] - offsets[host]);
    return 1;
}
fn ReadFile(h: HANDLE, target: [*]u8, count: DWORD, read: *DWORD, _: ?*anyopaque) i32 {
    const host = @intFromPtr(h.?) - 20;
    const n = @min(count, 13);
    @memcpy(target[0..n], frames[host][offsets[host]..][0..n]);
    offsets[host] += n;
    read.* = n;
    return 1;
}
fn reset() void {
    for (&g_chat_history_channels) |*ch| chatHistoryChannelClose(ch);
    g_chat_history_channels = @splat(.{});
    g_chat_history_channels_closing.store(false, .release);
    now = 0; starts = 0; fallbacks = 0; terminations = 0; closes = 0; writes = 0;
    fail_start = false; partial_write = false; mode = .good;
}
fn fetch(host: u8, out: *std.ArrayList(u8)) bool {
    out.clearRetainingCapacity();
    return chatHistoryFetch(.{ .host = host }, 7, .{}, 0, out);
}
`;
const checks = String.raw`
test "connection reuse is per host and chunked JSON replies preserve escaped transcript" {
    reset();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.heap.page_allocator);
    for (0..12) |_| {
        try std.testing.expect(fetch(0, &out));
        try std.testing.expect(std.mem.endsWith(u8, out.items, "@@MP_END@@\n"));
    }
    try std.testing.expectEqual(@as(usize, 1), starts);
    try std.testing.expect(fetch(1, &out));
    try std.testing.expect(fetch(2, &out));
    try std.testing.expectEqual(@as(usize, 3), starts);
    try std.testing.expectEqual(@as(usize, 0), fallbacks);
    closeAllChatHistoryChannels();
    try std.testing.expectEqual(@as(usize, 3), terminations);
    try std.testing.expectEqual(@as(usize, 9), closes);
}
test "death hang malformed stale error and truncated replies fall back and restart only after backoff" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.heap.page_allocator);
    inline for (.{ .dead, .hang, .malformed, .wrong_id, .reader_error, .truncated }) |failure| {
        reset(); mode = failure;
        try std.testing.expect(fetch(0, &out));
        try std.testing.expectEqualStrings("fallback", out.items);
        try std.testing.expect(g_chat_history_channels[0].process == null);
        try std.testing.expectEqual(@as(usize, 1), terminations);
        try std.testing.expectEqual(now + 60_000, g_chat_history_channels[0].retry_at);
        try std.testing.expect(g_chat_history_channels[0].input == null);
        try std.testing.expect(g_chat_history_channels[0].output == null);
        try std.testing.expectEqual(@as(usize, 3), closes);
        if (failure == .hang) try std.testing.expectEqual(@as(u64, 15_000), now);
        mode = .good;
        try std.testing.expect(fetch(0, &out));
        try std.testing.expectEqual(@as(usize, 1), starts);
        now = g_chat_history_channels[0].retry_at;
        try std.testing.expect(fetch(0, &out));
        try std.testing.expectEqual(@as(usize, 2), starts);
        try std.testing.expectEqual(@as(usize, 2), fallbacks);
        try std.testing.expectEqual(@as(u64, 0), g_chat_history_channels[0].retry_at);
    }
}
test "unreachable host and short writes fall back; oversized frame closes the channel" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.heap.page_allocator);
    reset(); fail_start = true;
    try std.testing.expect(fetch(0, &out));
    try std.testing.expectEqual(@as(usize, 1), fallbacks);
    reset(); partial_write = true;
    try std.testing.expect(fetch(0, &out));
    try std.testing.expectEqual(@as(usize, 1), terminations);
    reset();
    try std.testing.expect(!chatHistoryPersistent(0, 7, "{\"id\":7}", 1, &out, null));
    try std.testing.expectEqual(@as(usize, 1), terminations);
}
test "send write reservation distinguishes prewrite failure from lost acknowledgement" {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.heap.page_allocator);
    var request_written = false;
    reset(); fail_start = true;
    try std.testing.expect(!chatHistoryPersistent(0, 7, "{\"id\":7,\"op\":\"send\"}", 4096, &out, &request_written));
    try std.testing.expect(!request_written);
    reset(); partial_write = true;
    try std.testing.expect(!chatHistoryPersistent(0, 7, "{\"id\":7,\"op\":\"send\"}", 4096, &out, &request_written));
    try std.testing.expect(!request_written);
    reset(); mode = .hang;
    try std.testing.expect(!chatHistoryPersistent(0, 7, "{\"id\":7,\"op\":\"send\"}", 4096, &out, &request_written));
    try std.testing.expect(request_written);
    try std.testing.expectEqual(@as(u64, 15_000), now);
}
test "shutdown during a fetch blocks new spawns and fallback and defers handle closure to lock owner" {
    reset();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.heap.page_allocator);
    try std.testing.expect(fetch(0, &out));
    try std.testing.expect(g_chat_history_channel_mutex.tryLock());
    closeAllChatHistoryChannels();
    try std.testing.expectEqual(@as(usize, 0), terminations);
    g_chat_history_channel_mutex.unlock();
    try std.testing.expect(!fetch(0, &out));
    try std.testing.expectEqual(@as(usize, 1), terminations);
    try std.testing.expectEqual(@as(usize, 1), starts);
    try std.testing.expectEqual(@as(usize, 0), fallbacks);
}
`;

test('persistent history production transport: reuse, framing, timeout, fallback, backoff and shutdown', () => {
  const start = source.indexOf('const ChatHistoryChannel = struct {');
  const end = source.indexOf('\nfn chatHistoryChannelClose(', start);
  assert.ok(start >= 0 && end > start);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-connection-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, (prelude + source.slice(start, end) + '\n' + ['chatHistoryChannelClose', 'closeAllChatHistoryChannels', 'chatHistoryPersistent', 'chatHistoryFetch'].map(body).join('\n') + checks).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 5 tests passed/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('persistent reader bootstrap is stdin-only, noninteractive and job-owned before sending source', () => {
  const start = body('chatHistoryChannelStart');
  assert.ok(start.includes("python3 -u -c 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))' --serve"));
  assert.match(start, /BatchMode=yes.*ConnectTimeout=5/);
  assert.match(start, /SetHandleInformation\(ch.input, HANDLE_FLAG_INHERIT, 0\)/);
  assert.match(start, /SetHandleInformation\(ch.output, HANDLE_FLAG_INHERIT, 0\)/);
  assert.match(start, /g_tunnel_job == null or AssignProcessToJobObject\(g_tunnel_job, ch.process\) == 0\) return false/);
  assert.ok(start.indexOf('AssignProcessToJobObject') < start.indexOf('WriteFile'));
  assert.match(body('chatHistoryFetchOnce'), /g_tunnel_job == null or AssignProcessToJobObject\(g_tunnel_job, pi.hProcess\) == 0\) return false/);
  assert.match(source, /closeAllAcChannels\(\);\s*closeAllChatHistoryChannels\(\);/);
});
