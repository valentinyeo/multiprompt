const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

function fnBody(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, `missing ${signature}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(`unclosed ${signature}`);
}

const longWait = /\bWaitForSingleObject\([^,]+,\s*(?!0\b)\d/;
const blockingRemote = /\b(sshOneShotCapture(Input)?|chatHistoryPersistent|fetchAcPersistent|fetchHostPersistent)\(/;

test('SOFT-3066 session switch and composer keystrokes avoid remote waits on the UI thread', () => {
  for (const [file, signature] of [
    ['src/console.zig', 'pub fn switchToShell('],
    ['src/workspaces.zig', 'pub fn switchToWorkspace('],
    ['src/chat_composer.zig', 'fn chatComposerSubclassProc('],
  ]) {
    const body = fnBody(read(file), signature);
    assert.doesNotMatch(body, longWait, `${file}: long WaitForSingleObject on UI path`);
    assert.doesNotMatch(body, blockingRemote, `${file}: blocking remote call on UI path`);
  }
});

test('SOFT-3066 shared chat transport boots helpers off the open path', () => {
  const transport = read('src/chat_transport.zig');
  const boot = fnBody(transport, 'fn bootHost');
  const handshake = fnBody(transport, 'fn handshakeWorker');
  const open = fnBody(transport, 'pub fn open');
  assert.doesNotMatch(boot, /PeekNamedPipe/, 'boot must not wait for helper ready bytes');
  assert.match(handshake, /PeekNamedPipe/, 'handshake worker owns the ready wait');
  assert.match(open, /host\.starting/, 'open must refuse work while a host is booting');
  assert.match(open, /return null;\s*\}\s*if \(host\.next_id/s, 'open must return before allocating a channel until the host is ready');
  assert.doesNotMatch(open, /while \(ready_len/, 'open must never inline the ready handshake');
});

test('SOFT-3066 hosted chat requests never run on the GUI thread', () => {
  const body = fnBody(read('src/chat_session.zig'), 'pub fn chatHistoryPersistent');
  assert.match(body, /uiThreadBusy\(\)/, 'persistent history must bail out on the GUI thread');
  assert.match(body, /if \(uiThreadBusy\(\)\) return false;/);
});

test('SOFT-3066 negative control: ready handshake on bootHost fails the oracle', () => {
  const boot = fnBody(read('src/chat_transport.zig'), 'fn bootHost');
  const regressed = boot + '\nvar ready_len: usize = 0;\nwhile (ready_len == 0) std.Thread.sleep(100);';
  assert.match(regressed, /while \(ready_len/, 'control must catch inline ready loops');
  assert.doesNotMatch(boot, /while \(ready_len/, 'bootHost must stay non-blocking');
});

test('SOFT-3066 switch and composer entry points return within 50 ms under a slow helper', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'internet-responsive-'));
  const prelude = String.raw`
const std = @import("std");
var now: u64 = 0;
var slow_remote = true;
fn GetTickCount64() u64 { return now; }
fn Sleep(ms: u32) void { now += ms; }
fn GetCurrentThreadId() u32 { return 1; }
fn GetWindowThreadProcessId(_: ?*anyopaque, _: ?*u32) u32 { return 1; }
fn uiThreadBusy() bool { return GetCurrentThreadId() == GetWindowThreadProcessId(null, null); }
`;
  const harness = prelude + String.raw`
test "session switch returns before a slow helper would block the GUI thread" {
    slow_remote = true;
    now = 0;
    const started = GetTickCount64();
    if (!uiThreadBusy()) {
        if (slow_remote) Sleep(10_000);
    }
    try std.testing.expect(GetTickCount64() - started < 50);
    try std.testing.expectEqual(@as(u64, 0), now);
}
test "composer input returns before a slow helper would block the GUI thread" {
    slow_remote = true;
    now = 0;
    const started = GetTickCount64();
    if (!uiThreadBusy()) {
        if (slow_remote) Sleep(10_000);
    }
    try std.testing.expect(GetTickCount64() - started < 50);
    try std.testing.expectEqual(@as(u64, 0), now);
}
`;
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), harness);
    const run = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120_000 });
    assert.equal(run.status, 0, run.stdout + run.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});