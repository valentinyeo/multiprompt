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
    const DUPLICATE_SAME_ACCESS = 2;
    extern fn ReadFile(HANDLE, [*]u8, u32, *u32, HANDLE) c_int;
    extern fn WriteFile(HANDLE, [*]const u8, u32, *u32, HANDLE) c_int;
    extern fn CreateEventW(HANDLE, c_int, c_int, HANDLE) HANDLE;
    extern fn SetEvent(HANDLE) c_int;
    extern fn WaitForSingleObject(HANDLE, u32) u32;
    extern fn WaitForMultipleObjects(u32, [*]const HANDLE, c_int, u32) u32;
    extern fn TerminateProcess(HANDLE, u32) c_int;
    extern fn CloseHandle(HANDLE) c_int;
    extern fn GetCurrentProcess() HANDLE;
    extern fn GetCurrentThread() HANDLE;
    extern fn DuplicateHandle(HANDLE, HANDLE, HANDLE, *HANDLE, u32, c_int, u32) c_int;
    extern fn CancelSynchronousIo(HANDLE) c_int;
    extern fn GetTickCount64() u64;
    extern fn Sleep(u32) void;
    extern fn PostMessageW(HANDLE, u32, usize, isize) c_int;
};
const state = struct {
    const SpinMutex = struct {
        held: std.atomic.Value(bool) = .init(false),
        fn tryLock(self: *@This()) bool { return !self.held.swap(true, .acquire); }
        fn unlock(self: *@This()) void { self.held.store(false, .release); }
    };
    var g_chat_history_channels_closing: std.atomic.Value(bool) = .init(false);
};
extern fn mp_spawn([*:0]const u8, *w.HANDLE, *w.HANDLE, *w.HANDLE, c_int) c_int;
extern fn mp_release_leaks() void;
extern fn mp_set_thread(w.HANDLE, usize) void;
extern fn mp_pause(w.HANDLE) c_int;
extern fn mp_writing_large_packet() c_int;
const TestThread = struct {
    thread: std.Thread,
    done: w.HANDLE,
    fn spawn(config: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) !TestThread {
        const Entry = struct {
            fn run(done: w.HANDLE, arguments: @TypeOf(args)) void {
                defer _ = w.SetEvent(done);
                @call(.auto, function, arguments);
            }
        };
        const done = w.CreateEventW(null, 1, 0, null);
        const thread = try std.Thread.spawn(config, Entry.run, .{ done, args });
        mp_set_thread(done, @intFromPtr(thread.getHandle()));
        return .{ .thread = thread, .done = done };
    }
    fn getHandle(self: TestThread) w.HANDLE { return self.done; }
    fn join(self: TestThread) void { self.thread.join(); _ = w.CloseHandle(self.done); }
};
var starts: usize = 0;
var retain: bool = false;

fn start(host: *Host, _: u8) bool {
    if (host.wake == null) host.wake = w.CreateEventW(null, 0, 0, null);
    if (mp_spawn("broker.py", &host.process, &host.input, &host.output, @intFromBool(retain and starts == 0)) == 0) return false;
    starts += 1;
    const reader = "import json,sys\nfor line in sys.stdin:\n print(json.dumps(json.loads(line)),flush=True)\n";
    var encoded: [256]u8 = undefined;
    const size = std.base64.standard.Encoder.calcSize(reader.len);
    _ = std.base64.standard.Encoder.encode(encoded[0..size], reader);
    if (!writeAll(host.input, encoded[0..size]) or !writeAll(host.input, "\n")) return false;
    var ready: [15]u8 = undefined;
    var offset: usize = 0;
    while (offset < ready.len) {
        var count: u32 = 0;
        if (w.ReadFile(host.output, ready[offset..].ptr, @intCast(ready.len - offset), &count, null) == 0 or count == 0) return false;
        offset += count;
    }
    if (!std.mem.eql(u8, &ready, "{\"ready\":true}\n")) return false;
    host.running = true;
    const thread = std.Thread.spawn(.{}, receive, .{host}) catch return false;
    thread.detach();
    return true;
}

fn delivered(index: u8, message: []const u8) bool {
    const channel = open(index, false) orelse return false;
    defer close(channel);
    const request = std.json.Stringify.valueAlloc(a, .{ .text = message }, .{}) catch return false;
    defer a.free(request);
    if (!write(channel, request)) return false;
    const deadline = w.GetTickCount64() + 1000;
    var bytes: [65536]u8 = undefined;
    while (w.GetTickCount64() < deadline) {
        const count = read(channel, &bytes, false) orelse return false;
        if (count > 0) return std.mem.indexOf(u8, bytes[0..count], message) != null;
        w.Sleep(1);
    }
    respawn(index);
    return false;
}

fn stop(index: u8) void {
    mp_release_leaks();
    respawn(index);
    const host = &hosts[index];
    const deadline = w.GetTickCount64() + 3000;
    while (w.GetTickCount64() < deadline) {
        lock(host);
        const stopped = !host.running and !host.stopping;
        host.mutex.unlock();
        if (stopped) break;
        w.Sleep(1);
    }
    host.channels.deinit(a);
    if (host.wake != null) _ = w.CloseHandle(host.wake);
    host.* = .{};
}

export fn main() c_int {
    reconnect() catch |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
        return 1;
    };
    return 0;
}

fn reconnect() !void {
    for ([_]bool{ false, true }) |inherited| {
        starts = 0;
        retain = inherited;
        const index: u8 = 1;
        defer stop(index);
        try std.testing.expect(delivered(index, "before-death"));
        if (inherited) {
            try std.testing.expect(mp_pause(hosts[index].process) != 0);
            const blocked = open(index, false) orelse return error.ChannelUnavailable;
            defer close(blocked);
            const filler = try a.alloc(u8, 1024 * 1024);
            defer a.free(filler);
            @memset(filler, 'x');
            try std.testing.expect(write(blocked, filler));
            const write_deadline = w.GetTickCount64() + 3000;
            while (mp_writing_large_packet() == 0 and w.GetTickCount64() < write_deadline) w.Sleep(1);
            try std.testing.expect(mp_writing_large_packet() != 0);
        }
        lock(&hosts[index]);
        _ = w.TerminateProcess(hosts[index].process, 0);
        hosts[index].mutex.unlock();
        const queued = "queued-after-broker-death";
        const deadline = w.GetTickCount64() + 5000;
        var received = false;
        while (w.GetTickCount64() < deadline) {
            if (delivered(index, queued)) { received = true; break; }
            std.debug.print("[chat] submit not sent: the chat channel is not up yet, will retry\n", .{});
            w.Sleep(50);
        }
        lock(&hosts[index]);
        std.debug.print("retained inherited pipe handles={any}, broker starts={d}, queued send delivered={any}, running={any}, stopping={any}, channels={d}\n", .{ inherited, starts, received, hosts[index].running, hosts[index].stopping, hosts[index].channels.items.len });
        hosts[index].mutex.unlock();
        try std.testing.expect(received);
        try std.testing.expect(starts >= 2);
    }
}
`;

test('production desktop transport recovers from a killed real broker with inherited pipe handles', { skip: process.platform !== 'linux' }, () => {
  let source = fs.readFileSync(path.join(root, 'src/chat_transport.zig'), 'utf8');
  const start = source.indexOf('fn start(');
  const end = source.indexOf('\npub fn open(', start);
  assert.ok(start >= 0 && end > start);
  source = (source.slice(0, start) + source.slice(end))
    .replace('const w = @import("win32.zig");', '')
    .replace('const state = @import("app_state.zig");', '')
    .replace('@import("idle_budget.zig")', 'struct { pub fn bump(_: anytype) void {} }')
    .replaceAll('std.Thread', 'TestThread');
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-broker-reconnect-'));
  try {
    fs.copyFileSync(path.join(root, 'src/chat_transport.py'), path.join(folder, 'broker.py'));
    fs.writeFileSync(path.join(folder, 'reconnect.zig'), source + boundary);
    const compiled = spawnSync('cc', ['-c', '-pthread', path.join(root, 'tools/fixtures/SOFT-2685/kernel.c'), '-o', path.join(folder, 'kernel.o')], { encoding: 'utf8', timeout: 15000 });
    assert.equal(compiled.status, 0, compiled.stderr);
    const built = spawnSync(process.env.ZIG || 'zig', ['build-obj', '-j2', 'reconnect.zig', '-lc', '-fcompiler-rt', '-femit-bin=reconnect.o'], { cwd: folder, encoding: 'utf8', timeout: 60000 });
    assert.equal(built.status, 0, JSON.stringify({ signal: built.signal, error: built.error?.message, stdout: built.stdout, stderr: built.stderr }));
    const linked = spawnSync('cc', ['reconnect.o', 'kernel.o', '-pthread', '-no-pie', '-o', 'reconnect-test'], { cwd: folder, encoding: 'utf8', timeout: 15000 });
    assert.equal(linked.status, 0, linked.stderr);
    const result = spawnSync(path.join(folder, 'reconnect-test'), [], { cwd: folder, encoding: 'utf8', timeout: 30000 });
    process.stdout.write(result.stdout || '');
    process.stdout.write(result.stderr || '');
    assert.equal(result.status, 0, JSON.stringify({ signal: result.signal, error: result.error?.message, stdout: result.stdout, stderr: result.stderr }));
  } finally {
    fs.rmSync(folder, { recursive: true, force: true });
  }
});
