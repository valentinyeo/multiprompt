const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/voice.zig'), 'utf8');
const start = source.indexOf('pub fn dictationAudit(');
const current = source.slice(start, source.indexOf('\n}', start) + 2);
const before = fs.readFileSync(path.join(__dirname, 'fixtures/IGSH-893/dictation-audit-before.zig'), 'utf8');

function recordAudit(body) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'dictation-append-'));
  try {
    fs.mkdirSync(path.join(directory, 'ZigShell'));
    const file = path.join(directory, 'test.zig');
    copyZig(['win32.zig', 'file_io.zig'], directory);
    fs.writeFileSync(file, `const std = @import("std");
const win = @import("win32.zig");
const io = @import("file_io.zig");
const GetTickCount64 = win.GetTickCount64;
const CloseHandle = win.CloseHandle;
const CreateFileW = win.CreateFileW;
const FILE_APPEND_DATA = win.FILE_APPEND_DATA;
const FILE_SHARE_READ = win.FILE_SHARE_READ;
const FILE_SHARE_WRITE = win.FILE_SHARE_WRITE;
const OPEN_ALWAYS = win.OPEN_ALWAYS;
const FILE_ATTRIBUTE_NORMAL = win.FILE_ATTRIBUTE_NORMAL;
const INVALID_HANDLE_VALUE_PTR = win.INVALID_HANDLE_VALUE_PTR;
const win32WidePath = io.win32WidePath;
const win32OpenAppend = io.win32OpenAppend;
const win32WriteAll = io.win32WriteAll;
fn GetEnvironmentVariableA(_: [*:0]const u8, out: [*]u8, _: u32) u32 {
    const value = ${JSON.stringify(directory)};
    @memcpy(out[0..value.len], value);
    return value.len;
}
fn writeAuditU64(h: win.HANDLE, value: u64) void {
    var buffer: [24]u8 = undefined;
    win32WriteAll(h, std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable);
}
${body}
fn writer(index: usize) void {
    for (0..100) |value| dictationAudit("concurrent", index * 1000 + value);
}
test "audit survives another open writer and concurrent records" {
    var wide: [520]u16 = undefined;
    const filename = win32WidePath(&wide, ${JSON.stringify(path.join(directory, 'ZigShell', 'dictation-audit.log'))}).?;
    const held = CreateFileW(filename.ptr, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, null, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, null);
    try std.testing.expect(held != INVALID_HANDLE_VALUE_PTR);
    dictationAudit("held-writer", 1);
    _ = CloseHandle(held);
    var threads: [4]std.Thread = undefined;
    for (&threads, 0..) |*thread, index| thread.* = try std.Thread.spawn(.{}, writer, .{index});
    for (threads) |thread| thread.join();
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '-lkernel32'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const audit = path.join(directory, 'ZigShell', 'dictation-audit.log');
    return fs.existsSync(audit) ? fs.readFileSync(audit, 'utf8').trim().split('\n') : [];
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

function complete(records) {
  assert.equal(records.length, 401);
  assert.ok(records.some(line => /^\d+\theld-writer\t1$/.test(line)));
  const values = records.filter(line => /^\d+\tconcurrent\t\d+$/.test(line)).map(line => Number(line.split('\t')[2]));
  assert.equal(new Set(values).size, 400);
  for (let thread = 0; thread < 4; thread++) {
    for (let value = 0; value < 100; value++) assert.ok(values.includes(thread * 1000 + value));
  }
}

test('IGSH-893 every audit record survives concurrent Windows writers', { skip: process.platform !== 'win32' }, () => {
  complete(recordAudit(current));
  assert.throws(() => complete(recordAudit(before)), assert.AssertionError);
  console.log('DICTATION_ATOMIC_APPEND_OK; DICTATION_OLD_EXCLUSIVE_APPEND_REJECTED');
});
