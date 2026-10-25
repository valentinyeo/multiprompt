const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/vps.zig'), 'utf8');
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('executed SSH capture survives ongoing transfer progress, drains output, retains the final path, and terminates inactivity', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ssh-upload-reliability-'));
  const fixture = String.raw`
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const HANDLE = ?*anyopaque;
const DWORD = u32;
const SECURITY_ATTRIBUTES = struct { nLength: usize, lpSecurityDescriptor: HANDLE, bInheritHandle: u32 };
const STARTUPINFOW = struct { cb: usize = 0, dwFlags: u32 = 0, hStdOutput: HANDLE = null, hStdError: HANDLE = null, hStdInput: HANDLE = null };
const PROCESS_INFORMATION = struct { hProcess: HANDLE = null, hThread: HANDLE = null };
const HANDLE_FLAG_INHERIT = 1;
var tick: u64 = 0;
var emitted: u64 = 0;
var progress = true;
var killed = false;
var pumping = false;
var remaining: u32 = 0;
var written_total: u32 = 0;
fn GetTickCount64() u64 { return tick; }
fn debugLog(_: []const u8) void {}
fn sshSpawnFailed() void {}
fn sshLoaderFailed(_: HANDLE) void {}
fn CloseHandle(_: HANDLE) i32 { return 1; }
fn CreatePipe(read: *HANDLE, write: *HANDLE, _: *SECURITY_ATTRIBUTES, _: u32) i32 {
    read.* = @ptrFromInt(1); write.* = @ptrFromInt(2); return 1;
}
fn SetHandleInformation(_: HANDLE, _: u32, _: u32) i32 { return 1; }
fn CreateProcessW(_: HANDLE, _: [*:0]u16, _: HANDLE, _: HANDLE, _: u32, _: u32, _: HANDLE, _: HANDLE, _: *STARTUPINFOW, pi: *PROCESS_INFORMATION) i32 {
    pi.* = .{ .hProcess = @ptrFromInt(42), .hThread = @ptrFromInt(43) }; return 1;
}
fn WaitForSingleObject(_: HANDLE, duration: u32) u32 {
    tick += duration;
    return if (tick >= 1200) 0 else 0x102;
}
fn TerminateProcess(_: HANDLE, _: u32) i32 { killed = true; return 1; }
fn GetExitCodeProcess(_: HANDLE, code: *u32) i32 { code.* = if (killed) 1 else 0; return 1; }
fn PeekNamedPipe(_: HANDLE, _: HANDLE, _: u32, _: HANDLE, available: *u32, _: HANDLE) i32 {
    available.* = if (progress and tick % 200 == 0 and emitted != tick) 4096 else 0; return 1;
}
fn ReadFile(handle: HANDLE, data: [*]u8, size: u32, count: *u32, _: HANDLE) i32 {
    if (handle == @as(HANDLE, @ptrFromInt(9))) {
        count.* = if (pumping) @min(remaining, size) else 0;
        remaining -= count.*;
        @memset(data[0..count.*], 'x');
        return 1;
    }
    count.* = size;
    @memset(data[0..size], 'p');
    if (tick == 1200) {
        const final = "\n/home/u/1-report.pdf\n";
        @memcpy(data[size - final.len .. size], final);
    }
    emitted = tick;
    return 1;
}
fn WriteFile(_: HANDLE, _: [*]const u8, size: u32, written: *u32, _: HANDLE) i32 {
    written.* = @min(size, 1024); written_total += written.*; tick += 100; return 1;
}
test "progress outlives total deadline and output tail survives a full capture buffer" {
    var output: [64]u8 = undefined;
    const result = sshOneShotCaptureInput("ssh", &output, @ptrFromInt(9), 300);
    try std.testing.expect(result.success);
    try std.testing.expect(tick >= 1200);
    try std.testing.expect(!killed);
    try std.testing.expect(std.mem.endsWith(u8, output[0..result.len], "/home/u/1-report.pdf\n"));
}
test "an inactive upload is terminated" {
    tick = 0; emitted = 0; progress = false; killed = false;
    var output: [64]u8 = undefined;
    const result = sshOneShotCaptureInput("ssh", &output, @ptrFromInt(9), 300);
    try std.testing.expect(!result.success and killed);
    try std.testing.expect(tick >= 300 and tick < 600);
}
test "stdin partial writes refresh inactivity after each successful write" {
    tick = 0; pumping = true; remaining = 8192; written_total = 0;
    var activity = std.atomic.Value(u64).init(0);
    if (@typeInfo(@TypeOf(sshInputPump)).@"fn".params.len == 3)
        sshInputPump(@ptrFromInt(9), @ptrFromInt(2), &activity)
    else
        sshInputPump(@ptrFromInt(9), @ptrFromInt(2));
    try std.testing.expectEqual(@as(u32, 8192), written_total);
    try std.testing.expectEqual(@as(u64, 800), activity.load(.acquire));
}
`;
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, (fixture + '\n' + body('sshInputPump') + '\n' + body('sshOneShotCaptureInput')).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('server transfer reports real byte progress even after SSH has buffered all stdin', () => {
  const command = fs.readFileSync(path.join(root, 'src/chat_drop.zig'), 'utf8');
  assert.match(command, /dd bs=65536 status=progress <&3 > \$t\/data/);
});

test('production remote command falls back to cat when dd rejects status=progress and preserves bytes and upload safety', { skip: process.platform === 'win32' ? 'requires the POSIX server shell' : false }, () => {
  const { copyZig } = require('./zig-copy');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ssh-upload-fallback-'));
  try {
    copyZig(['chat_drop.zig'], dir);
    const file = path.join(dir, 'command.zig');
    const payload = Buffer.alloc(131329);
    for (let i = 0; i < payload.length; i++) payload[i] = i % 256;
    fs.writeFileSync(file, `
const std = @import("std");
const drop = @import("chat_drop.zig");
pub fn main() void {
    var buf: [2048]u8 = undefined;
    std.debug.print("{s}", .{drop.uploadCommand("..session; unsafe", "report; unsafe.bin", ${payload.length}, &buf)});
}
`);
    const generated = spawnSync(process.env.ZIG || 'zig', ['run', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(generated.status, 0, generated.stdout + generated.stderr);
    const command = generated.stderr;
    assert.ok(command.startsWith("sh -c '"));
    assert.ok(!command.includes('"'));
    const bin = path.join(dir, 'bin');
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, 'dd'), `#!/bin/sh
printf '%s\\n' "$*" >> "$DD_CALLS"
for arg; do
  if [ "$arg" = status=progress ]; then
    printf '%s\\n' 'dd: invalid argument status=progress' >&2
    exit 1
  fi
done
exec /bin/dd "$@"
`, { mode: 0o755 });
    const calls = path.join(dir, 'dd-calls');
    const home = path.join(dir, 'home with spaces');
    fs.mkdirSync(home);
    const env = { ...process.env, HOME: home, PATH: bin + path.delimiter + process.env.PATH, DD_CALLS: calls };
    const send = input => spawnSync('/bin/sh', ['-c', command], { env, input, encoding: 'utf8', timeout: 10000 });
    const destination = path.join(home, '.multiprompt/uploads/__session__unsafe');
    for (const name of ['report__unsafe.bin', '1-report__unsafe.bin']) {
      const result = send(payload);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stderr, '');
      const uploaded = path.join(destination, name);
      assert.equal(result.stdout, uploaded + '\n');
      assert.deepEqual(fs.readFileSync(uploaded), payload);
      assert.equal(fs.statSync(uploaded).mode & 0o777, 0o600);
      assert.equal(fs.statSync(destination).mode & 0o777, 0o700);
      assert.deepEqual(fs.readdirSync(destination).filter(name => name.startsWith('.staging.')), []);
    }
    const truncated = send(payload.subarray(0, payload.length - 1));
    assert.notEqual(truncated.status, 0);
    assert.equal(truncated.stdout, '');
    assert.equal(truncated.stderr, '');
    assert.deepEqual(fs.readdirSync(destination).sort(), ['1-report__unsafe.bin', 'report__unsafe.bin']);
    assert.deepEqual(fs.readFileSync(path.join(destination, 'report__unsafe.bin')), payload);
    assert.deepEqual(fs.readFileSync(calls, 'utf8').trimEnd().split('\n'), Array(3).fill('if=/dev/null of=/dev/null status=progress'));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('production remote command emits byte progress before stdin closes', { skip: process.platform === 'win32' ? 'requires the POSIX server shell' : false }, async () => {
  const { copyZig } = require('./zig-copy');
  const { spawn } = require('node:child_process');
  const { setTimeout: delay } = require('node:timers/promises');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ssh-upload-progress-'));
  let child;
  try {
    copyZig(['chat_drop.zig'], dir);
    const file = path.join(dir, 'command.zig');
    fs.writeFileSync(file, String.raw`
const std = @import("std");
const drop = @import("chat_drop.zig");
pub fn main() void {
    var buf: [2048]u8 = undefined;
    std.debug.print("{s}", .{drop.uploadCommand("session", "report.pdf", 655360, &buf)});
}
`);
    const generated = spawnSync(process.env.ZIG || 'zig', ['run', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(generated.status, 0, generated.stdout + generated.stderr);
    child = spawn('/bin/sh', ['-c', generated.stderr], { env: { ...process.env, HOME: dir } });
    let stderr = '';
    let stdout = '';
    child.stderr.on('data', data => { stderr += data; });
    child.stdout.on('data', data => { stdout += data; });
    const exited = new Promise((resolve, reject) => {
      child.on('error', reject);
      child.on('close', code => resolve(code));
    });
    for (let i = 0; i < 10; i++) {
      child.stdin.write(Buffer.alloc(65536, 0x5a));
      await delay(250);
    }
    const progressBeforeEof = stderr;
    child.stdin.end();
    assert.equal(await exited, 0, stderr);
    assert.match(progressBeforeEof, /\d+ bytes .* copied/);
    const uploaded = stdout.trim();
    assert.equal(uploaded, path.join(dir, '.multiprompt/uploads/session/report.pdf'));
    assert.deepEqual(fs.readFileSync(uploaded), Buffer.alloc(655360, 0x5a));
  } finally {
    if (child && child.exitCode === null) child.kill();
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
