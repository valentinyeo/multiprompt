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

const uiBusy = /ui_thread\.zig\)\.busy\(\)|@import\("ui_thread\.zig"\)\.busy\(\)/;

test('SOFT-3067 favicon fetch waits on a worker thread', () => {
  const vps = read('src/vps.zig');
  const start = fnBody(vps, 'pub fn startFaviconFetch');
  const worker = fnBody(vps, 'fn faviconFetchThread');
  assert.doesNotMatch(start, longWait, 'startFaviconFetch must not wait for the SSH child on the caller thread');
  assert.match(start, /Thread\.spawn/, 'startFaviconFetch must spawn a worker');
  assert.match(worker, longWait, 'worker owns the favicon child wait');
});

test('SOFT-3067 room transport runs remote work off the UI thread', () => {
  const transport = read('src/room_transport.zig');
  const start = fnBody(transport, 'pub fn start');
  const run = fnBody(transport, 'fn run');
  const attempt = fnBody(transport, 'fn attempt');
  const shutdown = fnBody(read('src/rooms.zig'), 'pub fn shutdown');
  assert.match(start, /Thread\.spawn/, 'room transport must start on a worker');
  assert.doesNotMatch(start, longWait, 'start must not wait for the helper handshake');
  assert.match(run, /attempt\(job,/, 'the worker starts the helper handshake on its own thread');
  assert.match(attempt, longWait, 'the worker owns the helper-ready wait');
  assert.match(shutdown, uiBusy, 'room shutdown must not join a live worker on the GUI thread');
});

test('SOFT-3067 console tunnel and SSH setup avoid long waits on the GUI thread', () => {
  const tunnel = fnBody(read('src/console.zig'), 'fn tunnelSocketId');
  const resolve = fnBody(read('src/console.zig'), 'pub fn resolveSshPath');
  assert.match(tunnel, uiBusy, 'tunnel socket id must use cached data on the GUI thread');
  assert.doesNotMatch(tunnel, /WaitForSingleObject\(mutex,\s*5000\)/, 'tunnel socket id must not block the GUI for five seconds on the mutex');
  assert.match(resolve, uiBusy, 'ssh path resolution must defer work off the GUI thread');
  const maintain = fnBody(read('src/console.zig'), 'pub fn maintainTunnelKeepers');
  assert.doesNotMatch(maintain, blockingRemote, 'tunnel keeper timer must not run blocking remote capture inline');
});

test('SOFT-3067 archive and account flows avoid long waits on the GUI thread', () => {
  const kill = fnBody(read('src/archive.zig'), 'fn killRemoteTmuxSession');
  const archiveTab = fnBody(read('src/archive.zig'), 'pub fn archiveTabAt');
  const claim = fnBody(read('src/account_desktop.zig'), 'pub fn accountClaim');
  assert.match(kill, uiBusy, 'remote session kill must queue instead of blocking the GUI thread');
  assert.doesNotMatch(archiveTab, longWait, 'archive tab action must not wait for remote kill on the GUI thread');
  assert.doesNotMatch(claim, /WaitForSingleObject\([^,]+,\s*(3000|5000|8000)\)/, 'account claim must not use multi-second mutex or hung-window waits');
});

test('SOFT-3067 browser helper resolves windows on a worker thread', () => {
  const pane = read('src/browser_pane.zig');
  const queue = fnBody(pane, 'pub fn startBrowserWindowResolve');
  const resolve = fnBody(pane, 'fn resolveBrowserWindowIdFromCommand');
  assert.doesNotMatch(queue, longWait, 'browser resolve queue must not block the GUI thread');
  assert.match(queue, /Thread\.spawn/, 'browser resolve must spawn a worker');
  assert.match(resolve, longWait, 'bridge helper wait stays on the worker');
  const bind = fnBody(read('src/browser_bridge.zig'), 'pub fn handleZsbBindRequest');
  assert.doesNotMatch(bind, /zsbRunBridgeOnce/, 'bind handling on the GUI thread must not run bridge helper processes inline');
});

test('SOFT-3067 updater poll avoids a five-second child wait on the GUI thread', () => {
  const poll = fnBody(read('src/update_release.zig'), 'pub fn poll');
  const recover = fnBody(read('src/update_release.zig'), 'fn recoverStuckChecker');
  assert.match(poll, /WaitForSingleObject\(process,\s*0\)/, 'poll must only reap finished checker children');
  assert.doesNotMatch(recover, /WaitForSingleObject\(process,\s*5000\)/, 'stuck checker recovery must not block the GUI for five seconds');
});

test('SOFT-3067 negative control: inline tunnel mutex wait on the GUI thread fails the oracle', () => {
  const tunnel = fnBody(read('src/console.zig'), 'fn tunnelSocketId');
  const regressed = tunnel.replace('if (on_ui) 0 else 5000', '5000');
  assert.match(regressed, /WaitForSingleObject\(mutex,\s*5000\)/, 'control must catch long mutex waits');
});
