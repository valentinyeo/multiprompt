const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const source = fs.readFileSync(path.join(__dirname, '../src/chat_transport.zig'), 'utf8');
const start = source.indexOf('pub fn openReady(');
const end = source.indexOf('\n}', start) + 2;

test('MUBO-280 a history worker waits for startup rather than backing off a healthy connection', () => {
  assert.ok(start >= 0 && end > start);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-transport-ready-'));
  try {
    const file = path.join(dir, 'ready.zig');
    fs.writeFileSync(file, `
const std = @import("std");
const Channel = struct {};
var ready_channel: Channel = .{};
const Mutex = struct { fn unlock(_: *Mutex) void {} };
const Host = struct { mutex: Mutex = .{}, ready: ?*anyopaque = @ptrFromInt(1), starting: bool = false, running: bool = false };
var hosts: [3]Host = @splat(.{});
var waits: usize = 0;
var opens: usize = 0;
var outcome: enum { ready, failed, timeout } = .ready;
fn lock(_: *Host) void {}
fn open(index: u8, _: bool) ?*Channel {
    opens += 1;
    if (index >= hosts.len) return null;
    if (hosts[index].running) return &ready_channel;
    hosts[index].starting = true;
    return null;
}
const w = struct {
    fn WaitForSingleObject(handle: ?*anyopaque, timeout: u32) u32 {
        std.debug.assert(handle != null and timeout == 15_000);
        waits += 1;
        hosts[0].starting = false;
        hosts[0].running = outcome == .ready;
        return if (outcome == .timeout) 258 else 0;
    }
};
${source.slice(start, end)}
test "cold startup and existing startup return the channel without a retry delay" {
    for ([_]bool{ false, true }) |starting| {
        hosts = @splat(.{});
        hosts[0].starting = starting;
        waits = 0;
        opens = 0;
        outcome = .ready;
        try std.testing.expect(openReady(0, true) == &ready_channel);
        try std.testing.expectEqual(@as(usize, 1), waits);
        try std.testing.expectEqual(@as(usize, 2), opens);
    }
}
test "ready connections never wait and invalid hosts never wait" {
    hosts[0].running = true;
    waits = 0;
    try std.testing.expect(openReady(0, false) == &ready_channel);
    try std.testing.expect(openReady(3, false) == null);
    try std.testing.expectEqual(@as(usize, 0), waits);
}
test "failed and timed out startup still fail" {
    for ([_]@TypeOf(outcome){ .failed, .timeout }) |result| {
        hosts = @splat(.{});
        outcome = result;
        waits = 0;
        try std.testing.expect(openReady(0, false) == null);
        try std.testing.expectEqual(@as(usize, 1), waits);
    }
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('MUBO-280 startup completion and cancellation release waiting history workers', () => {
  assert.match(source, /host.ready = w.CreateEventW\(null, 1, 0, null\)/);
  for (const name of ['abortBoot', 'handshakeWorker', 'shutdown', 'respawn']) {
    const begin = source.indexOf(`fn ${name}(`);
    const body = source.slice(begin, source.indexOf('\n}', begin) + 2);
    assert.match(body, /w.SetEvent\((?:b\.)?host.ready\)/, name);
  }
});
