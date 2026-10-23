const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const vm = require('node:vm');
const { spawn } = require('node:child_process');
const test = require('node:test');
const root = process.env.ZSB_CDP_SOURCE_ROOT || path.resolve(__dirname, '..');
const extension = fs.readFileSync(path.join(root, 'extension/bridge.js'), 'utf8');
const native = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
const app = fs.readFileSync(path.join(root, 'src/browser_bridge.zig'), 'utf8');
const wrapper = path.join(root, 'tools/vps-multiprompt-browser.sh');

function functionSource(name) {
  const start = extension.search(new RegExp(`^(?:async )?function ${name}\\(`, 'm'));
  assert.ok(start >= 0, `missing ${name}`);
  return extension.slice(start, extension.indexOf('\n}', start) + 2);
}

function harness(command = async () => ({}), timers = {}) {
  const calls = [], listeners = new Set(), scheduled = [];
  let enabled = false;
  const context = vm.createContext({
    chrome: { debugger: {
      attach: async target => { calls.push(['attach', target.tabId]); },
      detach: async target => { enabled = false; calls.push(['detach', target.tabId]); },
      sendCommand: async (target, method, params) => {
        calls.push([method, target.tabId, params]);
        if (method === 'Profiler.enable') enabled = true;
        if (method === 'Profiler.start' && !enabled) throw Error('Profiler is not enabled');
        return command(target, method, params, listeners);
      },
      onEvent: { addListener: fn => listeners.add(fn), removeListener: fn => listeners.delete(fn) },
    } },
    getTargetTab: async message => {
      calls.push(['target', message.windowId]);
      if (message.windowId !== 42) throw Error('refusing to touch another window');
      return { id: 7 };
    },
    stringOr: (value, fallback) => typeof value === 'string' ? value : fallback,
    errorText: error => error.message || String(error),
    cdpOperationChains: new Map(), cdpSessionCancels: new Map(), debuggedTabs: new Set(),
    emulatedTabs: new Map(), lostEmulationTabs: new Map(), lifecycleTabs: new Map(),
    screenshotCdpDetachTimers: new Map(), screenshotCdpDetachInFlight: new Map(),
    screenshotCdpPageEnabledTabs: new Set(),
    setTimeout: (fn, ms) => { scheduled.push(ms); return (timers.setTimeout || setTimeout)(fn, ms); },
    clearTimeout,
  });
  const names = ['withTimeout', 'clearScreenshotCdpDetachTimer', 'withCdpSession', 'setPageLifecycle', 'sendCdp'];
  for (const name of ['validateCdpScript', 'runCdpScriptStep']) {
    if (extension.includes(`function ${name}(`)) names.push(name);
  }
  vm.runInContext(names.map(functionSource).join('\n'), context);
  return { calls, listeners, scheduled, context,
    run: script => context.sendCdp({ windowId: 42, script }),
    single: method => context.sendCdp({ windowId: 42, cdpMethod: method }),
  };
}
const plain = value => JSON.parse(JSON.stringify(value));

test('IGSH-221 Profiler enable/start/stop share one attachment and retain a large profile', async () => {
  const profile = { nodes: [{ id: 1, callFrame: { functionName: 'sample'.repeat(200000) } }], samples: [1] };
  const h = harness(async (_, method) => method === 'Profiler.stop' ? { profile } : {});
  const result = plain(await h.run([{ method: 'Profiler.enable', params: {} }, { method: 'Profiler.start' }, { method: 'Profiler.stop' }]));
  assert.deepEqual(result, [{ method: 'Profiler.enable', result: {} }, { method: 'Profiler.start', result: {} }, { method: 'Profiler.stop', result: { profile } }]);
  assert.equal(h.calls.filter(c => c[0] === 'attach').length, 1);
  assert.equal(h.calls.filter(c => c[0] === 'detach').length, 1);
  assert.equal(h.context.cdpOperationChains.size, 0);
});

test('IGSH-221 new-document injection survives reload and event is armed before command', async () => {
  let injected = false;
  const h = harness(async (target, method, params, listeners) => {
    if (method === 'Page.addScriptToEvaluateOnNewDocument') { injected = true; return { identifier: '1' }; }
    if (method === 'Page.reload') {
      assert.ok(injected);
      assert.equal(listeners.size, 1);
      for (const listener of listeners) {
        listener({ tabId: 8 }, 'Page.loadEventFired', { wrong: true });
        listener({ tabId: target.tabId, sessionId: 'child' }, 'Page.loadEventFired', { wrong: true });
        listener(target, 'Page.loadEventFired', { timestamp: 123 });
      }
    }
    return {};
  });
  const results = plain(await h.run([
    { method: 'Page.addScriptToEvaluateOnNewDocument', params: { source: 'globalThis.marker = true' } },
    { method: 'Page.reload', waitEvent: 'Page.loadEventFired', timeoutMs: 15000 },
    { waitMs: 1 },
  ]));
  assert.deepEqual(results[1], { method: 'Page.reload', result: {}, event: { timestamp: 123 } });
  assert.deepEqual(results[2], { waitMs: 1 });
  assert.ok(h.calls.findIndex(c => c[0] === 'Page.enable') < h.calls.findIndex(c => c[0] === 'Page.reload'));
  assert.equal(h.listeners.size, 0);
});

test('IGSH-221 scripts hold ownership across delays and exceed the old session deadline', async () => {
  const h = harness(undefined, { setTimeout: (fn, ms) => setTimeout(fn, ms === 20000 ? 1 : ms) });
  const script = h.run([{ method: 'Profiler.enable', timeoutMs: 1000 }, { waitMs: 20000 }, { method: 'Profiler.start', timeoutMs: 1000 }]);
  await assert.rejects(h.single('Runtime.evaluate'), /CDP session busy.*zsb reset/);
  await script;
  await h.single('Runtime.evaluate');
  const methods = h.calls.map(c => c[0]).filter(c => c !== 'target');
  assert.ok(methods.indexOf('Profiler.start') < methods.indexOf('Runtime.evaluate'));
  assert.equal(methods.filter(c => c === 'attach').length, 2);
  assert.deepEqual(methods.slice(0, 5), ['attach', 'Emulation.setFocusEmulationEnabled', 'Profiler.enable', 'Profiler.start', 'detach']);
  assert.equal(h.scheduled.filter(ms => ms === 10000).length, 1);
  assert.equal(h.context.cdpSessionCancels.size, 0);
});

test('IGSH-221 reset cancellation prevents delayed scripts from issuing further commands', async () => {
  for (const phase of ['delay', 'enable']) {
    let release;
    const h = harness(async (_, method) => phase === 'enable' && method === 'Page.enable'
      ? new Promise(resolve => { release = resolve; }) : {}, {
      setTimeout: (fn, ms) => ms === 20000 ? (release = fn, undefined) : setTimeout(fn, ms),
    });
    const script = h.run(phase === 'delay'
      ? [{ waitMs: 20000 }, { method: 'Page.reload' }]
      : [{ method: 'Page.reload', waitEvent: 'Page.loadEventFired', timeoutMs: 1000 }]);
    await new Promise(resolve => setImmediate(resolve));
    const current = h.context.cdpOperationChains.get(7);
    const rejected = assert.rejects(script, /CDP session reset/);
    h.context.cdpSessionCancels.get(7)(new Error('CDP session reset; retry command'));
    h.context.cdpSessionCancels.delete(7);
    h.context.cdpOperationChains.delete(7);
    await rejected;
    release({});
    await assert.rejects(current, /CDP session reset/);
    assert.ok(!h.calls.some(c => c[0] === 'Page.reload'));
    assert.equal(h.listeners.size, 0);
    await h.single('Runtime.evaluate');
    assert.equal(h.context.cdpOperationChains.size, 0);
    assert.equal(h.context.cdpSessionCancels.size, 0);
  }
});

test('IGSH-221 step failures stop execution, preserve partial results and release ownership', async () => {
  const h = harness(async (_, method) => { if (method === 'Bad.command') throw Error('No window with id: 99'); return {}; });
  await assert.rejects(h.run([{ method: 'Profiler.enable' }, { method: 'Bad.command' }, { method: 'Profiler.start' }]), error => {
    assert.equal(error.failedStep, 2);
    assert.match(error.message, /step 2 \(Bad.command\).*No window/);
    assert.deepEqual(plain(error.results), [{ method: 'Profiler.enable', result: {} }]);
    return true;
  });
  assert.ok(!h.calls.some(c => c[0] === 'Profiler.start'));
  assert.equal(h.calls.at(-1)[0], 'detach');
  assert.equal(h.listeners.size, 0);
  await h.single('Runtime.evaluate');
});

test('IGSH-221 event timeout and command error remove listeners without later steps', async () => {
  for (const failure of ['timeout', 'command']) {
    const h = harness(async (_, method) => { if (failure === 'command' && method === 'Page.reload') throw Error('reload rejected'); return {}; });
    await assert.rejects(h.run([{ method: 'Page.reload', waitEvent: 'Page.loadEventFired', timeoutMs: 10 }, { method: 'Profiler.start' }]), error => {
      assert.equal(error.failedStep, 1);
      assert.match(error.message, failure === 'timeout' ? /timed out/ : /reload rejected/);
      return true;
    });
    assert.equal(h.listeners.size, 0);
    assert.equal(h.calls.at(-1)[0], 'detach');
    assert.ok(!h.calls.some(c => c[0] === 'Profiler.start'));
  }
});

test('IGSH-221 standalone event waits return parameters and late enable cannot send a timed-out command', async () => {
  const h = harness();
  const waiting = h.run([{ waitEvent: 'Runtime.consoleAPICalled', timeoutMs: 1000 }]);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.listeners.size, 1);
  for (const listener of h.listeners) listener({ tabId: 7 }, 'Runtime.consoleAPICalled', { type: 'log' });
  assert.deepEqual(plain(await waiting), [{ waitEvent: 'Runtime.consoleAPICalled', event: { type: 'log' } }]);
  assert.equal(h.listeners.size, 0);

  let finishEnable;
  const late = harness(async (_, method) => method === 'Page.enable' ? new Promise(resolve => { finishEnable = resolve; }) : {});
  await assert.rejects(late.run([{ method: 'Page.reload', waitEvent: 'Page.loadEventFired', timeoutMs: 10 }]), /timed out/);
  finishEnable({});
  await late.single('Runtime.evaluate');
  assert.ok(!late.calls.some(c => c[0] === 'Page.reload'));
  assert.equal(late.listeners.size, 0);
});

test('IGSH-221 host dispatch returns structured errors without a legacy script-wide timeout', async () => {
  const h = harness(async (_, method) => { if (method === 'Bad.command') throw Error('rejected'); return {}; });
  const replies = [];
  Object.assign(h.context, {
    extensionOutdated: false, extensionReloadTimer: null,
    dispatch: message => h.context.sendCdp(message),
    sendResponse: (_, reply) => replies.push(plain(reply)),
  });
  vm.runInContext(functionSource('handleHostMessage'), h.context);
  await h.context.handleHostMessage({ method: 'cdp', windowId: 42, script: [{ method: 'Bad.command', timeoutMs: 1000 }] });
  assert.equal(replies[0].ok, false);
  assert.equal(replies[0].failedStep, 1);
  assert.deepEqual(replies[0].results, []);
  assert.ok(!h.scheduled.includes(15000));
});

test('IGSH-221 malformed steps and excessive budgets fail before debugger attachment', async () => {
  for (const script of [[], {}, [null], [{ method: '' }], [{ method: 'Page.reload', params: [] }], [{ waitMs: -1 }], [{ waitMs: 1, method: 'Page.reload' }], [{ waitEvent: 3 }], [{ method: 'Page.reload', timeoutMs: 0 }], [{ method: 'Page.reload', tabId: 99 }], [{ waitMs: 300000 }, { method: 'Page.reload' }]]) {
    const h = harness();
    await assert.rejects(h.run(script), /CDP script/);
    assert.ok(!h.calls.some(c => c[0] === 'attach'));
  }
  const h = harness();
  await assert.rejects(h.context.sendCdp({ windowId: 99, script: [{ method: 'Page.reload' }] }), /refusing/);
  assert.ok(!h.calls.some(c => c[0] === 'attach'));
});

function runWrapper(args, port, input = '', env = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', [wrapper, ...args], { env: { ...process.env, TMUX: '', ZSB_SESSION: 'test-session', ZSB_PORT: String(port), ...env } });
    let stdout = '', stderr = '';
    child.stdout.on('data', data => { stdout += data; });
    child.stderr.on('data', data => { stderr += data; });
    child.on('error', reject);
    child.on('close', status => resolve({ status, stdout, stderr }));
    child.stdin.end(input);
  });
}

test('IGSH-221 remote file/stdin scripts ship contents once and write complete local output', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-cdp-'));
  const steps = [{ method: 'Profiler.enable' }, { method: 'Profiler.stop' }];
  const result = [{ method: 'Profiler.stop', result: { profile: { samples: 'x'.repeat(1200000) } } }];
  const requests = [];
  const server = net.createServer(socket => {
    let wire = '';
    socket.on('data', data => {
      wire += data;
      if (!wire.endsWith('\n')) return;
      const payload = wire.trim().split(':')[2];
      requests.push(Buffer.from(payload, 'base64').toString().split('\x1f').filter(Boolean));
      socket.end(JSON.stringify(result) + '\n');
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const file = path.join(dir, 'steps.json'), output = path.join(dir, 'results.json');
    fs.writeFileSync(file, JSON.stringify(steps));
    const fromFile = await runWrapper(['cdp', '--script', file], server.address().port);
    assert.equal(fromFile.status, 0, fromFile.stderr);
    assert.deepEqual(JSON.parse(fromFile.stdout), result);
    const fromStdin = await runWrapper(['cdp', '--script', '-', '--out', output], server.address().port, JSON.stringify(steps));
    assert.equal(fromStdin.status, 0, fromStdin.stderr);
    assert.equal(fromStdin.stdout, '');
    assert.deepEqual(JSON.parse(fs.readFileSync(output, 'utf8')), result);
    assert.equal(requests.length, 2);
    for (const request of requests) {
      assert.deepEqual(request.slice(0, 2), ['cdp', '--script-json']);
      assert.deepEqual(JSON.parse(request[2]), steps);
      assert.equal(request.length, 3);
    }
  } finally {
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-221 script errors remain structured and never overwrite an output file', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-cdp-error-'));
  const output = path.join(dir, 'keep.json');
  fs.writeFileSync(output, 'keep');
  const error = { ok: false, error: 'CDP script step 2 failed', failedStep: 2, results: [{ method: 'Profiler.enable', result: {} }] };
  const server = net.createServer(socket => socket.once('data', () => socket.end(JSON.stringify(error))));
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const result = await runWrapper(['cdp', '--script', '-', '--out', output], server.address().port, '[{"method":"Profiler.enable"}]');
    assert.equal(result.status, 1);
    assert.deepEqual(JSON.parse(result.stdout), error);
    assert.equal(fs.readFileSync(output, 'utf8'), 'keep');
  } finally {
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-221 script reply deadlines honor ZSB_TIMEOUT even while replies trickle', async () => {
  let bytes = 0, requests = 0;
  const sockets = new Set(), timers = [];
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
    socket.once('data', () => {
      requests++;
      const trickle = setInterval(() => { bytes++; socket.write(' '); }, 25);
      const finish = setTimeout(() => { clearInterval(trickle); socket.end('[]'); }, 1500);
      socket.once('close', () => { clearInterval(trickle); clearTimeout(finish); });
      timers.push(trickle, finish);
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const result = await runWrapper(['cdp', '--script', '-'], server.address().port, '[{"waitMs":0}]', { ZSB_TIMEOUT: '0.2' });
    assert.equal(result.status, 1, result.stdout + result.stderr);
    const reply = JSON.parse(result.stdout);
    assert.equal(reply.error, 'reply_timeout');
    assert.match(reply.message, /deadline 0\.2s/);
    assert.match(reply.hint, /[Rr]econnect/);
    assert.ok(bytes >= 2, `fixture sent ${bytes} bytes`);
    assert.equal(requests, 1);
  } finally {
    for (const timer of timers) clearTimeout(timer);
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
  }
});

test('IGSH-221 native and remote transports preserve safety, budgets and full JSON output', () => {
  const remote = fs.readFileSync(wrapper, 'utf8');
  assert.match(remote, /if script_mode:\n    default_timeout = 360\ntry:\n    timeout = float\(os\.environ\.get\("ZSB_TIMEOUT", default_timeout\)\)/);
  assert.match(native, /readCdpScript\(allocator, source\)/);
  assert.match(native, /std\.Io\.File\.stdin\(\)\.handle/);
  const scriptBranch = native.slice(native.indexOf('if (std.mem.eql(u8, cdp_method, "--script")'), native.indexOf('const params_json = args.next();', native.indexOf('const cdp_method =')));
  assert.match(scriptBranch, /requestBrowser\(allocator, "cdp", fields.items, GetTickCount64\(\) \+ 320_000\)/);
  assert.match(native, /commandDeadline, \.\{is_script\}/);
  assert.match(native, /if \(is_script\) \{\s+Sleep\(360_000\)/);
  assert.doesNotMatch(scriptBranch, /requestBrowserWithRetry/);
  assert.match(native, /Stringify\.valueAlloc\(allocator, result/);
  assert.match(native, /writeFileBytes\(allocator, path, json\)/);
  assert.match(app, /alloc\(u8, 16 \* 1024 \* 1024\)/);
  assert.match(app, /if \(script_command\) 330_000 else 30_000/);
  assert.match(app, /object\.get\("failedStep"\) != null\) return false/);
  assert.match(functionSource('handleHostMessage'), /message\.method === "cdp" && message\.script !== undefined\s*\? await dispatch\(message\)/);
  assert.match(functionSource('handleHostMessage'), /failedStep: error\.failedStep, results: error\.results/);
  assert.match(functionSource('sendCdp'), /getTargetTab\(message\)/);
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(workflow, /node --test tools\/zsb-cdp-script\.test\.js/);
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /const zsb_help_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/zsb-help\.test\.js" \}\)/);
  assert.match(build, /zsb_help_tests\.step\.dependOn\(&bridge_install\.step\)/);
  assert.match(build, /zsb_help_tests\.setEnvironmentVariable\("BRIDGE_EXE", b\.getInstallPath\(\.bin, "zigshell-bridge\.exe"\)\)/);
  assert.match(build, /test_step\.dependOn\(&zsb_help_tests\.step\)/);
});
