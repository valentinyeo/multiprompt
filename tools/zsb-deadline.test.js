const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const vm = require('node:vm');
const { spawn, execFileSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => process.env.ZSB_DEADLINE_BASE
  ? execFileSync('git', ['show', `${process.env.ZSB_DEADLINE_BASE}:${file}`], { cwd: root, encoding: 'utf8' })
  : fs.readFileSync(path.join(root, file), 'utf8');
const extension = read('extension/bridge.js');
const native = read('src/bridge.zig');
const wrapper = path.join(root, 'tools/vps-multiprompt-browser.sh');

function section(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `missing ${start}`);
  return source.slice(a, b);
}

function harness() {
  const timers = new Map(), replies = [], ports = [], calls = [];
  let timerId = 0;
  const context = vm.createContext({
    console: { log() {}, warn() {} },
    setTimeout(callback, ms) { const id = ++timerId; timers.set(id, { callback, ms }); return id; },
    clearTimeout(id) { timers.delete(id); },
    rememberTargetWindow: async () => {},
    getRememberedZsbTargetTab: async () => ({ id: 7, windowId: 42, active: false }),
    isExtensionTab: () => false,
    isPaneBeaconTab: () => false,
    compactTab: tab => tab,
    messageWindowId: message => message.windowId ?? null,
    stringOr: (value, fallback) => typeof value === 'string' ? value : fallback,
    chrome: {
      tabs: { query: async () => [{ id: 7, windowId: 42 }], get: async id => ({ id, windowId: 42, active: false }) },
      windows: { WINDOW_ID_NONE: -1 },
      debugger: {
        attach: async () => { calls.push('attach'); },
        detach: async () => { calls.push('detach'); },
        sendCommand: async (_, method) => { calls.push(method); return { method }; },
      },
      runtime: {
        getManifest: () => ({ version: '1.0.68' }),
        reload() { calls.push('reload-worker'); },
        connectNative() {
          const port = { postMessage: message => replies.push(message),
            onMessage: { addListener: fn => port.receive = fn },
            onDisconnect: { addListener: fn => port.disconnected = fn },
            disconnect() { calls.push('disconnect-native'); } };
          ports.push(port);
          return port;
        },
      },
    },
  });
  vm.runInContext(
    section(extension, 'const HOST =', 'chrome.alarms.create(') +
    section(extension, 'function scheduleExtensionReload(', 'async function rememberTargetWindow(') +
    section(extension, 'function sendResponse(', 'function installContextMenus(') +
    section(extension, 'function withTimeout(', 'async function handleCreatedNavigationTarget(') +
    section(extension, 'function clearScreenshotCdpDetachTimer(', 'async function tryAcceptPendingDialog(') +
    section(extension, 'async function sendCdp(', 'async function consoleAction(') +
    section(extension, 'async function getTargetTab(', 'function rememberZsbTargetTab(') +
    '\nglobalThis.api = { withCdpSession, handleHostMessage, dispatch, connect };', context);
  const flush = async () => { for (let i = 0; i < 30; i++) await Promise.resolve(); };
  return { context, calls, replies, ports, timers, api: context.api, flush,
    async fire(ms) {
      const entry = [...timers].find(([, timer]) => timer.ms === ms);
      assert.ok(entry, `missing ${ms}ms deadline`);
      timers.delete(entry[0]);
      entry[1].callback();
      await flush();
    },
  };
}

const never = () => new Promise(() => {});

test('ISSUE-154 a hung CDP request cannot queue later commands, including its own tab', async () => {
  const h = harness();
  h.context.chrome.debugger.sendCommand = async (_, method) => method === 'Runtime.evaluate' ? never() : {};
  const first = h.api.handleHostMessage({ id: 'hung', method: 'cdp', cdpMethod: 'Runtime.evaluate', windowId: 42 });
  await h.flush();
  vm.runInContext('focusEmulatedTabs.clear()', h.context);
  const next = h.api.handleHostMessage({ id: 'next', method: 'activeTab', windowId: 42 });
  await h.flush();
  assert.equal(h.replies.find(reply => reply.id === 'next')?.ok, true);
  const busy = h.api.handleHostMessage({ id: 'busy', method: 'cdp', cdpMethod: 'Page.enable', windowId: 42 });
  await h.flush();
  assert.match(h.replies.find(reply => reply.id === 'busy')?.error || '', /CDP session busy.*zsb reset/);
  await h.fire(10000);
  await Promise.all([first, next, busy]);
  assert.match(h.replies.find(reply => reply.id === 'hung').error, /CDP operation timed out.*zsb reset/);
  const recovered = await h.api.withCdpSession(7, async () => 'recovered');
  assert.equal(recovered, 'recovered');
  assert.equal(h.timers.size, 0);
});

for (const stage of ['attach', 'focus', 'detach']) {
  test(`ISSUE-154 hung CDP ${stage} has a deadline and releases ownership`, async () => {
    const h = harness();
    const timeout = stage === 'attach' ? 5000 : stage === 'focus' ? 2000 : 1000;
    if (stage === 'focus') h.context.chrome.debugger.sendCommand = never;
    else h.context.chrome.debugger[stage] = never;
    const result = h.api.withCdpSession(7, async () => 'ok');
    const rejected = assert.rejects(result, new RegExp(`CDP ${stage === 'focus' ? 'focus setup' : stage} timed out`));
    await h.flush();
    await h.fire(timeout);
    await rejected;
    h.context.chrome.debugger.attach = async () => {};
    h.context.chrome.debugger.detach = async () => {};
    h.context.chrome.debugger.sendCommand = async () => ({});
    assert.equal(await h.api.withCdpSession(7, async () => 'next'), 'next');
  });
}

test('ISSUE-154 reset cancels stale work, reconnects the native host, and leaves pane tabs intact', async () => {
  const h = harness();
  h.api.connect();
  const stale = h.api.withCdpSession(7, never);
  const rejected = assert.rejects(stale, /CDP session reset/);
  await h.flush();
  await h.api.handleHostMessage({ id: 'reset', method: 'reset', windowId: 42 });
  await rejected;
  assert.equal(h.replies.at(-1).ok, true);
  assert.equal(h.replies.at(-1).result.reset, true);
  assert.equal(h.ports.length, 2);
  assert.ok(h.calls.includes('disconnect-native'));
  h.ports[0].disconnected();
  assert.equal(h.api.connect(), h.ports[1], 'late disconnect must not discard the replacement port');
  assert.equal(await h.api.withCdpSession(7, async () => 'fresh'), 'fresh');
  assert.equal(h.context.chrome.tabs.remove, undefined);
  assert.equal(h.context.chrome.windows.create, undefined);
});

test('ISSUE-154 reset reloads the bridge worker if debugger detach itself is wedged', async () => {
  const h = harness();
  h.context.chrome.debugger.detach = never;
  const reset = h.api.handleHostMessage({ id: 'reset', method: 'reset', windowId: 42 });
  await h.flush();
  await h.fire(1000);
  await reset;
  assert.equal(h.replies.at(-1).result.reloadScheduled, true);
  await h.fire(200);
  assert.ok(h.calls.includes('reload-worker'));
});

test('ISSUE-154 every native CLI request has a deadline and replies cannot block the host reader', () => {
  const request = section(native, 'fn requestBrowser(', 'fn saveScreenshotResponse(');
  assert.match(request, /const until = deadline orelse/);
  assert.match(request, /PIPE_TYPE_MESSAGE \| PIPE_READMODE_MESSAGE \| PIPE_NOWAIT/);
  assert.match(request, /while \(GetTickCount64\(\) < until\)/);
  assert.match(request, /return error\.BrowserRequestTimeout/);
  assert.doesNotMatch(request, /try waitForPipeClient/);
  const retry = section(native, 'fn requestBrowserWithRetry(', 'const VersionHealDecision');
  assert.match(retry, /requestBrowser\(allocator, method, fields_json, command_deadline\)/);
  assert.match(retry, /deadline exceeded; run zsb reset/);
  const reply = section(native, 'fn routeReplyPipe(', 'fn readPipeMessage(');
  assert.doesNotMatch(reply, /FlushFileBuffers/);
  assert.match(reply, /SetNamedPipeHandleState\(pipe, &mode, null, null\)/);
  assert.match(reply, /const mode: windows\.DWORD = PIPE_NOWAIT/);
  assert.match(native, /if \(!is_native_host\) \{\s+const watchdog = try std\.Thread\.spawn\(\.\{\}, commandDeadline/);
  assert.match(native, /command exceeded its 60 second deadline; run zsb reset/);
});

test('ISSUE-154 reset has native and remote help and forwards the reset verb', () => {
  assert.match(native, /command, "reset"\)\) \{[\s\S]*?sendBrowserRequest\(allocator, "reset", "", null\)/);
  assert.match(native, /reset +Reconnect bridge/);
  const help = execFileSync('bash', [wrapper, 'reset', '--help'], { encoding: 'utf8' });
  assert.match(help, /^usage: zsb reset/);
  assert.match(help, /keeps the pane open/);
});

async function remoteDeadline(t, drip) {
  const sockets = new Set();
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
    socket.once('data', () => { if (drip) socket.write('{'); });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
  });
  const started = Date.now();
  const result = await new Promise((resolve, reject) => {
    const child = spawn('bash', [wrapper, 'active-tab'], {
      env: { ...process.env, TMUX: '', ZSB_SESSION: 'deadline-fixture', ZSB_PORT: String(server.address().port), ZSB_TIMEOUT_SECONDS: '0.15' },
    });
    const kill = setTimeout(() => child.kill('SIGKILL'), 3000);
    let stdout = '', stderr = '';
    child.stdout.on('data', chunk => stdout += chunk);
    child.stderr.on('data', chunk => stderr += chunk);
    child.once('error', reject);
    child.once('close', (code, signal) => { clearTimeout(kill); resolve({ code, signal, stdout, stderr }); });
  });
  assert.equal(result.signal, null, 'client must enforce its own deadline');
  assert.equal(result.code, 1);
  assert.equal(JSON.parse(result.stdout).error, 'reply_timeout');
  assert.match(result.stderr, /deadline.*zsb reset/);
  assert.ok(Date.now() - started < 2500);
}

for (const drip of [false, true]) {
  test(`ISSUE-154 remote client deadline errors on ${drip ? 'incomplete' : 'missing'} replies`, { skip: process.platform === 'win32' }, t => remoteDeadline(t, drip));
}

test('ISSUE-154 real Windows CLI times out a missing CDP reply while another request succeeds', { skip: process.platform !== 'win32', timeout: 35000 }, async t => {
  const profile = `deadline-${process.pid}`;
  const sockets = new Set();
  let gotFirst;
  const first = new Promise(resolve => gotFirst = resolve);
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
    let raw = '';
    socket.on('data', chunk => {
      raw += chunk;
      let request;
      try { request = JSON.parse(raw); } catch { return; }
      if (request.method === 'cdp') { gotFirst(); return; }
      const reply = net.createConnection(request.replyPipe, () => reply.end('{"ok":true,"result":{"tab":7}}'));
      reply.on('error', () => {});
    });
  });
  await new Promise(resolve => server.listen(`\\.\pipe\multiprompt-browser-isolated-${profile}`, resolve));
  t.after(async () => {
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
  });
  const cli = args => new Promise((resolve, reject) => {
    const child = spawn(process.env.BRIDGE_EXE || path.join(root, 'zig-out/bin/zigshell-bridge.exe'), ['--profile', profile, ...args]);
    const timer = setTimeout(() => child.kill('SIGKILL'), 28000);
    t.after(() => { clearTimeout(timer); if (child.exitCode === null) child.kill('SIGKILL'); });
    let stdout = '', stderr = '';
    child.stdout.on('data', chunk => stdout += chunk);
    child.stderr.on('data', chunk => stderr += chunk);
    child.once('error', reject);
    child.once('close', (code, signal) => { clearTimeout(timer); resolve({ code, signal, stdout, stderr }); });
  });
  const hung = cli(['cdp', 'Runtime.evaluate']);
  await first;
  const next = await cli(['active-tab']);
  assert.equal(next.signal, null);
  assert.equal(next.code, 0, next.stderr);
  assert.equal(JSON.parse(next.stdout).ok, true);
  const expired = await hung;
  assert.equal(expired.signal, null, 'native client must time out without the test killing it');
  assert.equal(JSON.parse(expired.stdout).ok, false);
  assert.match(JSON.parse(expired.stdout).error, /deadline exceeded.*zsb reset/);
});

test('ISSUE-154 native host still answers ping when a reply-pipe client never reads', { skip: process.platform !== 'win32', timeout: 10000 }, async t => {
  const sockets = new Set();
  const pipe = `\\.\pipe\multiprompt-deadline-unread-${process.pid}`;
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.pause();
    socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
  });
  await new Promise(resolve => server.listen(pipe, resolve));
  const child = spawn(process.env.BRIDGE_EXE || path.join(root, 'zig-out/bin/zigshell-bridge.exe'), ['--profile', `unread-${process.pid}`, 'native']);
  let buffer = Buffer.alloc(0), stderr = '';
  const waiters = [];
  child.stderr.on('data', data => stderr += data);
  child.stdout.on('data', data => {
    buffer = Buffer.concat([buffer, data]);
    while (buffer.length >= 4 && buffer.length >= buffer.readUInt32LE(0) + 4) {
      const size = buffer.readUInt32LE(0);
      const message = JSON.parse(buffer.subarray(4, size + 4));
      buffer = buffer.subarray(size + 4);
      const waiter = waiters.find(item => item.matches(message));
      if (waiter) { clearTimeout(waiter.timer); waiter.resolve(message); waiters.splice(waiters.indexOf(waiter), 1); }
    }
  });
  const waitFor = matches => new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`native host stopped answering: ${stderr}`)), 4000);
    waiters.push({ matches, resolve, timer });
  });
  const exited = new Promise(resolve => child.once('close', resolve));
  t.after(async () => {
    for (const waiter of waiters) clearTimeout(waiter.timer);
    child.stdin.end();
    const kill = setTimeout(() => child.kill('SIGKILL'), 1000);
    await exited;
    clearTimeout(kill);
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
  });
  const send = message => {
    const bytes = Buffer.from(JSON.stringify(message));
    const header = Buffer.alloc(4);
    header.writeUInt32LE(bytes.length);
    child.stdin.write(Buffer.concat([header, bytes]));
  };
  await waitFor(message => Boolean(message.bridgeVersion));
  send({ id: 'unread', replyPipe: pipe, ok: true, result: 'x'.repeat(1024 * 1024) });
  const ping = waitFor(message => message.id === 'ping');
  send({ id: 'ping', method: 'ping' });
  assert.equal((await ping).result.pong, true);
});
