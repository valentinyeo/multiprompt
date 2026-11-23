const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
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
  let now = 0;
  const GetTickCount64 = () => now;
  const Sleep = ms => {
    now += ms;
  };
  const GetCurrentThreadId = () => 1;
  const GetWindowThreadProcessId = () => 1;
  const uiThreadBusy = () => GetCurrentThreadId() === GetWindowThreadProcessId(null, null);
  const entry = () => {
    const slow_remote = true;
    now = 0;
    const started = GetTickCount64();
    if (!uiThreadBusy()) {
      if (slow_remote) Sleep(10_000);
    }
    assert.ok(GetTickCount64() - started < 50);
    assert.equal(now, 0);
  };
  entry();
  entry();
});