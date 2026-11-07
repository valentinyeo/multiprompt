const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

const boundary = String.raw`
const w = struct {
    const HANDLE = ?*anyopaque;
    fn Sleep(_: u32) void { std.Thread.yield() catch {}; }
    fn WriteFile(_: HANDLE, bytes: [*]const u8, count: u32, written: *u32, _: ?*anyopaque) i32 {
        std.debug.assert(test_host.?.mutex.tryLock());
        test_host.?.mutex.unlock();
        entered.store(true, .release);
        while (!released.load(.acquire)) Sleep(1);
        std.debug.assert(bytes[count - 1] == '\n');
        written.* = count;
        return 1;
    }
    fn TerminateProcess(_: HANDLE, _: u32) i32 { unreachable; }
    fn PostMessageW(_: HANDLE, _: u32, _: usize, _: isize) i32 { return 1; }
};
const state = struct {
    const SpinMutex = struct {
        held: std.atomic.Value(bool) = .init(false),
        fn tryLock(self: *@This()) bool { return !self.held.swap(true, .acquire); }
        fn unlock(self: *@This()) void { self.held.store(false, .release); }
    };
    var g_chat_history_channels_closing: std.atomic.Value(bool) = .init(false);
};
var test_host: ?*Host = null;
var entered: std.atomic.Value(bool) = .init(false);
var released: std.atomic.Value(bool) = .init(false);

test "blocked SSH writes leave incoming data and other channels usable with bounded queues" {
    var host = Host{ .running = true };
    test_host = &host;
    var noisy = Channel{ .host = &host, .id = 1, .watch = false };
    var healthy = Channel{ .host = &host, .id = 2, .watch = false };
    defer noisy.bytes.deinit(a);
    defer healthy.bytes.deinit(a);
    defer host.channels.deinit(a);
    defer {
        for (host.outgoing.items) |item| a.free(item.bytes);
        host.outgoing.deinit(a);
    }
    try host.channels.append(a, &noisy);
    try host.channels.append(a, &healthy);
    try std.testing.expect(write(&noisy, "first"));
    try std.testing.expect(std.mem.eql(u8, host.outgoing.items[0].bytes, "{\"channel\":1,\"watch\":false,\"terminal\":false,\"open\":true,\"data\":\"first\"}\n"));
    const writer = try std.Thread.spawn(.{}, transmit, .{&host});
    defer {
        lock(&host);
        host.running = false;
        host.mutex.unlock();
        released.store(true, .release);
        writer.join();
    }
    while (!entered.load(.acquire)) w.Sleep(1);
    for (0..256) |_| try std.testing.expect(write(&noisy, "x"));
    try std.testing.expect(std.mem.indexOf(u8, host.outgoing.items[0].bytes, "\"open\":false") != null);
    try std.testing.expect(!write(&noisy, "overflow"));
    try std.testing.expect(noisy.ended);
    try std.testing.expect(host.running);
    try std.testing.expect(write(&healthy, "still usable"));
    try std.testing.expect(dispatch(&host, "{\"channel\":2,\"data\":\"reply\"}"));
    var bytes: [32]u8 = undefined;
    const n = read(&healthy, &bytes, false).?;
    try std.testing.expectEqualStrings("reply\n", bytes[0..n]);
    try std.testing.expect(!healthy.ended);
    try std.testing.expectEqual(@as(usize, 258), host.outgoing.items.len);
    const close_packet = host.outgoing.items[256];
    try std.testing.expectEqualStrings("{\"channel\":1,\"close\":true}\n", close_packet.bytes);
}
`;

test('production SSH writer releases the host mutex and isolates input overflow', () => {
  const file = path.join(root, 'src/chat_transport.zig');
  assert.ok(fs.existsSync(file), 'shared SSH transport exists');
  const source = fs.readFileSync(file, 'utf8')
    .replace('const w = @import("win32.zig");', '')
    .replace('const state = @import("app_state.zig");', '')
    .replaceAll('@import("console.zig")', 'struct {}')
    .replaceAll('@import("chat_session.zig")', 'struct {}');
  assert.match(source, /fn transmit\(host: \*Host\)/, 'shared transport has an independent writer');
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-transport-writer-'));
  try {
    const fixture = path.join(folder, 'writer.zig');
    fs.writeFileSync(fixture, source + boundary);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', fixture], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, JSON.stringify({ signal: result.signal, error: result.error?.message, stdout: result.stdout, stderr: result.stderr }));
  } finally {
    fs.rmSync(folder, { recursive: true, force: true });
  }
});
