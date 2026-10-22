const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function harness({ timeoutMs, realTarget = false } = {}) {
  const listeners = {};
  const calls = [];
  const attached = new Set();
  const overrides = new Map();
  let failMethod;
  let heldMethod;
  let release;
  const commandState = new Map();
  const event = name => ({ addListener(fn) { listeners[name] = fn; } });
  const namespace = name => new Proxy({}, { get(target, key) {
    return target[key] ??= String(key).startsWith('on') ? event(`${name}.${key}`) : async () => [];
  } });
  const chrome = new Proxy({}, { get(target, key) { return target[key] ??= namespace(key); } });
  chrome.runtime.connectNative = () => ({ onMessage: event('port.message'), onDisconnect: event('port.disconnect'), postMessage() {}, disconnect() {} });
  chrome.storage.local = { get: async () => ({}), set: async () => {}, remove: async () => {} };
  chrome.debugger.attach = async ({ tabId }) => {
    assert.equal(attached.has(tabId), false, 'one debugger session per tab');
    attached.add(tabId);
    calls.push({ tabId, method: 'attach' });
  };
  chrome.debugger.detach = async ({ tabId }) => {
    calls.push({ tabId, method: 'detach' });
    attached.delete(tabId);
    overrides.delete(tabId);
    commandState.delete(tabId);
    listeners['debugger.onDetach']({ tabId }, 'canceled_by_user');
  };
  chrome.debugger.sendCommand = async ({ tabId }, method, params) => {
    assert.ok(attached.has(tabId), `${method} needs an attached debugger`);
    calls.push({ tabId, method, params: JSON.parse(JSON.stringify(params || {})) });
    if (method === failMethod) throw new Error('synthetic CDP failure');
    if (method === 'Synthetic.enableUnknownFailure') throw new Error('original command failure');
    if (method === heldMethod) await new Promise(resolve => { release = resolve; });
    const enabled = commandState.get(tabId) || new Set();
    if (method.endsWith('.enable') || /^(Network.setBlockedURLs|Debugger.pause|Synthetic.enableUnknown|DOM.getDocument|DOM.getFlattenedDocument)$/.test(method)) enabled.add(method);
    if (method.endsWith('.disable')) {
      const domain = method.split('.')[0];
      for (const entry of enabled) if (entry.startsWith(`${domain}.`)) enabled.delete(entry);
    }
    if (method === 'Network.setBlockedURLs' && params.urls.length === 0) enabled.delete(method);
    if (method === 'Debugger.resume') enabled.delete('Debugger.pause');
    commandState.set(tabId, enabled);
    const state = overrides.get(tabId) || {};
    if (method === 'Emulation.setDeviceMetricsOverride') state.metrics = params;
    if (method === 'Emulation.setUserAgentOverride') {
      state.userAgent = params.userAgent;
      state.userAgentMetadata = params.userAgentMetadata;
    }
    if (method === 'Emulation.setTouchEmulationEnabled') state.touch = params.enabled;
    overrides.set(tabId, state);
    if (method === 'Page.captureScreenshot') return { data: 'iVBORsynthetic' };
    if (method === 'Runtime.evaluate') return { result: { value: 42 } };
    if (method === 'Synthetic.enableUnknown') return { acted: true, actionCount: 1 };
    return {};
  };
  chrome.windows.get = async id => ({ id, type: 'normal' });
  chrome.windows.create = async () => ({ id: 20 });
  chrome.windows.getAll = async () => [{ id: 10, type: 'normal' }];
  chrome.tabs.query = async () => [{ id: 1, windowId: 10, active: true, url: 'https://example.test' }];
  chrome.tabs.get = async tabId => ({ id: tabId, url: 'https://example.test' });
  chrome.scripting.executeScript = async ({ func }) => {
    if (func.name === 'evalInPage') throw new Error('Content Security Policy unsafe-eval');
    return [{ result: { found: true, editable: true, x: 20, y: 30, text: 'Menu' } }];
  };
  const context = vm.createContext({ chrome, console, URL, navigator: { userAgent: 'Synthetic Desktop' }, setTimeout: (fn, ms) => setTimeout(fn, timeoutMs && ms === 15000 ? timeoutMs : ms), clearTimeout });
  vm.runInContext(fs.readFileSync(process.env.BRIDGE_SOURCE || path.join(__dirname, 'bridge.js'), 'utf8'), context);
  if (!realTarget) vm.runInContext('rememberTargetWindow = async () => {}; getTargetTab = async message => ({ id: message.tabId || 1 });', context);
  return {
    calls, attached, overrides, commandState, context,
    windowless: message => context.dispatch(message),
    emulated: tabId => vm.runInContext(`emulatedTabs.has(${tabId})`, context),
    hold: method => { heldMethod = method; },
    release: () => { heldMethod = undefined; release(); },
    screenshot: tabId => context.captureScreenshotViaCdp(tabId),
    run: message => context.dispatch({ windowId: 10, ...message }),
    fail: method => { failMethod = method; },
    navigate: async (tabId, frameId = 0) => {
      if (frameId === 0) overrides.delete(tabId);
      await listeners['webNavigation.onCommitted']({ tabId, frameId, url: 'https://example.test/next', transitionType: 'link' });
      await vm.runInContext(`cdpOperationChains.get(${tabId})`, context);
    },
    remove: tabId => listeners['tabs.onRemoved'](tabId),
    detach: async tabId => { attached.delete(tabId); overrides.delete(tabId); await listeners['debugger.onDetach']({ tabId }, 'canceled_by_user'); },
  };
}

test('device emulation persists through CDP, screenshot and top-level navigation until off', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  assert.equal(h.attached.has(1), true);
  assert.equal(h.overrides.get(1).metrics.width, 390);
  assert.equal(h.overrides.get(1).metrics.height, 844);
  assert.equal(h.overrides.get(1).metrics.mobile, true);
  assert.match(h.overrides.get(1).userAgent, /iPhone/);
  assert.equal(h.overrides.get(1).touch, true);
  await h.run({ method: 'cdp', cdpMethod: 'Runtime.evaluate', params: { expression: '1' } });
  assert.equal(await h.screenshot(1), 'iVBORsynthetic');
  assert.equal(h.calls.filter(call => call.method === 'attach').length, 1);
  assert.equal(h.calls.filter(call => call.method === 'detach').length, 0);
  await h.navigate(1);
  assert.equal(h.overrides.get(1).metrics.width, 390);
  assert.match(h.overrides.get(1).userAgent, /iPhone/);
  assert.equal(h.overrides.get(1).touch, true);
  await h.run({ method: 'emulate', device: 'off' });
  assert.equal(h.attached.has(1), false);
  assert.equal(h.overrides.has(1), false);
  await h.navigate(1);
  assert.equal(h.attached.has(1), false);
  await h.run({ method: 'cdp', cdpMethod: 'Page.enable' });
  assert.equal(h.attached.has(1), false, 'ordinary sessions remain ephemeral');
});

test('pixel, desktop sizes and mobile sizes update independently per tab', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'pixel' });
  assert.match(h.overrides.get(1).userAgent, /Android.*Pixel/);
  await h.run({ method: 'emulate', tabId: 2, device: '800x600' });
  assert.equal(h.overrides.get(2).metrics.width, 800);
  assert.equal(h.overrides.get(2).metrics.mobile, false);
  assert.equal(h.overrides.get(2).userAgent, '');
  assert.equal(h.overrides.get(2).touch, false);
  await h.run({ method: 'emulate', tabId: 2, device: '360x740', mobile: true });
  assert.equal(h.overrides.get(2).metrics.mobile, true);
  assert.match(h.overrides.get(2).userAgent, /Mobile/);
  assert.equal(h.overrides.get(2).touch, true);
  await h.run({ method: 'emulate', tabId: 2, device: 'off' });
  assert.equal(h.attached.has(1), true);
  assert.equal(h.attached.has(2), false);
  await h.run({ method: 'emulate', device: 'off' });
});

test('invalid emulation never attaches or changes existing overrides', async () => {
  const h = harness();
  for (const message of [{}, { device: 'unknown' }, { device: '0x10' }, { device: '10x0' }, { device: '999999x10' }, { device: '1.5x10' }, { device: 'off', mobile: true }]) {
    await assert.rejects(h.run({ method: 'emulate', ...message }));
  }
  assert.equal(h.calls.length, 0);
  await h.run({ method: 'emulate', device: 'iphone' });
  const count = h.calls.length;
  await assert.rejects(h.run({ method: 'emulate', device: 'bad' }));
  assert.equal(h.calls.length, count);
  assert.equal(h.overrides.get(1).metrics.width, 390);
  await h.run({ method: 'emulate', device: 'off' });
});

test('failed setup detaches, external detach forgets state, and closed tabs are not reattached', async () => {
  const h = harness();
  h.fail('Emulation.setTouchEmulationEnabled');
  await assert.rejects(h.run({ method: 'emulate', device: 'iphone' }), /synthetic CDP failure/);
  assert.equal(h.attached.size, 0);
  h.fail(undefined);
  await h.run({ method: 'emulate', device: 'iphone' });
  await h.detach(1);
  await h.navigate(1);
  assert.equal(h.attached.size, 0);
  await h.run({ method: 'emulate', device: 'iphone' });
  h.remove(1);
  await h.detach(1);
  await h.navigate(1);
  assert.equal(h.attached.size, 0);
});

test('queued navigation and off cannot resurrect emulation', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  await Promise.all([h.navigate(1), h.run({ method: 'emulate', device: 'off' })]);
  await h.navigate(1);
  assert.equal(h.attached.size, 0);
});

test('subframe navigation does not reapply, and ordinary CDP errors retain emulation', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  const count = h.calls.length;
  await h.navigate(1, 2);
  assert.equal(h.calls.length, count);
  h.fail('Runtime.evaluate');
  await assert.rejects(h.run({ method: 'cdp', cdpMethod: 'Runtime.evaluate' }), /synthetic CDP failure/);
  assert.equal(h.attached.has(1), true);
  assert.equal(h.overrides.get(1).metrics.width, 390);
  h.fail(undefined);
  await h.run({ method: 'emulate', device: 'off' });
});


test('extension release version is unused and matches self-test documentation', () => {
  const manifest = JSON.parse(fs.readFileSync(process.env.MANIFEST_SOURCE || path.join(__dirname, 'manifest.json'), 'utf8'));
  const { execFileSync } = require('node:child_process');
  let floor = '1.0.71';
  try {
    floor = JSON.parse(execFileSync('git', ['show', 'origin/master:extension/manifest.json'], { cwd: path.join(__dirname, '..'), encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })).version;
  } catch {}
  const parts = manifest.version.split('.').map(Number);
  const base = floor.split('.').map(Number);
  assert.ok(parts[0] > base[0] || (parts[0] === base[0] && (parts[1] > base[1] || (parts[1] === base[1] && parts[2] > base[2]))), `${manifest.version} must be above master/fallback ${floor}`);
  const docs = fs.readFileSync(path.join(__dirname, '../openwiki/browser/zsb-selftest.md'), 'utf8');
  assert.ok(docs.includes(`version **${manifest.version}**`));
});

test('ordinary CDP command state is reset explicitly while emulation is preserved', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  const operations = [
    () => h.run({ method: 'cdp', cdpMethod: 'Fetch.enable' }),
    () => h.run({ method: 'cdp', cdpMethod: 'Network.setBlockedURLs', params: { urls: ['*'] } }),
    () => h.run({ method: 'cdp', cdpMethod: 'Debugger.enable' }),
    () => h.run({ method: 'cdp', cdpMethod: 'Debugger.pause' }),
    () => h.screenshot(1),
    () => h.run({ method: 'console', clear: true }),
  ];
  for (const operation of operations) {
    const start = h.calls.length;
    await operation();
    assert.equal(h.calls.slice(start).filter(call => call.method === 'detach').length, 0, 'known command state is reset without detaching');
    assert.equal(h.calls.slice(start).filter(call => /Emulation\.(clear|setDeviceMetrics|setUserAgent|setTouch)/.test(call.method)).length, 0);
    assert.equal(h.commandState.get(1).size, 0);
    assert.equal(h.attached.has(1), true);
    assert.equal(h.emulated(1), true);
    assert.equal(h.overrides.get(1).metrics.width, 390);
    assert.match(h.overrides.get(1).userAgent, /iPhone/);
    assert.equal(h.overrides.get(1).touch, true);
  }
  h.fail('Runtime.evaluate');
  await assert.rejects(h.run({ method: 'cdp', cdpMethod: 'Runtime.evaluate' }), /synthetic CDP failure/);
  assert.equal(h.commandState.get(1).size, 0);
  assert.equal(h.overrides.get(1).metrics.width, 390);
  h.fail(undefined);
  await h.run({ method: 'emulate', device: 'off' });
});

test('mobile client hints match each preset and reset for desktop and off', async () => {
  const h = harness();
  for (const [device, platform, platformVersion, model] of [
    ['iphone', 'iOS', '17.0.0', 'iPhone'],
    ['pixel', 'Android', '14.0.0', 'Pixel 8'],
    ['360x740', 'Android', '14.0.0', 'Pixel 8'],
  ]) {
    await h.run({ method: 'emulate', device, mobile: true });
    const metadata = h.overrides.get(1).userAgentMetadata;
    assert.ok(metadata, 'UA string overrides also need matching client hints');
    assert.equal(metadata.mobile, true);
    assert.equal(metadata.platform, platform);
    assert.equal(metadata.platformVersion, platformVersion);
    assert.equal(metadata.model, model);
    assert.equal(metadata.architecture, '');
    await h.navigate(1);
    assert.equal(h.overrides.get(1).userAgentMetadata.mobile, true);
    await h.run({ method: 'emulate', device: '800x600' });
    assert.equal(h.overrides.get(1).userAgentMetadata, undefined);
    await h.run({ method: 'emulate', device, mobile: true });
    await h.run({ method: 'emulate', device: 'off' });
    assert.equal(h.overrides.has(1), false);
    const reset = h.calls.filter(call => call.method === 'Emulation.setUserAgentOverride').at(-1);
    assert.equal(reset.params.userAgent, '');
    assert.equal(reset.params.userAgentMetadata, undefined);
  }
});

test('failed emulation apply times out without a retained session, including late completion and reconfiguration', async () => {
  for (const existing of [false, true]) {
    for (const method of ['Emulation.setDeviceMetricsOverride', 'Emulation.setUserAgentOverride', 'Emulation.setTouchEmulationEnabled']) {
      const h = harness({ timeoutMs: 20 });
      if (existing) await h.run({ method: 'emulate', device: 'pixel' });
      h.hold(method);
      const pending = assert.rejects(h.run({ method: 'emulate', device: 'iphone' }), /CDP operation timed out/);
      await new Promise(resolve => setImmediate(resolve));
      const recordedBeforeSuccess = h.emulated(1);
      await pending;
      if (!existing) assert.equal(recordedBeforeSuccess, false, 'setup is not recorded before apply succeeds');
      assert.equal(h.emulated(1), false, `${method}: no half-applied record`);
      assert.equal(h.attached.has(1), false, `${method}: no debugging bar`);
      h.release();
      await new Promise(resolve => setImmediate(resolve));
      assert.equal(h.emulated(1), false, 'late completion cannot restore a timed-out record');
      assert.equal(h.attached.has(1), false);
      await h.navigate(1);
      assert.equal(h.attached.has(1), false);
      await h.run({ method: 'emulate', device: 'pixel' });
      assert.equal(h.overrides.get(1).metrics.width, 412);
      await h.run({ method: 'emulate', device: 'off' });
    }
  }
});


test('ordinary CDP timeout resets command state and failed restore releases the debugger', async () => {
  const h = harness({ timeoutMs: 20 });
  await h.run({ method: 'emulate', device: 'iphone' });
  h.hold('Fetch.enable');
  await assert.rejects(h.run({ method: 'cdp', cdpMethod: 'Fetch.enable' }), /CDP operation timed out/);
  assert.equal(h.commandState.get(1).size, 0);
  assert.equal(h.overrides.get(1).metrics.width, 390);
  h.release();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.commandState.get(1).size, 0, 'late raw enable is disabled again');
  h.fail('Emulation.setDeviceMetricsOverride');
  const reply = await h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' });
  assert.match(reply.warning, /emulation lost.*synthetic CDP failure/i);
  assert.equal(reply.emulationLost, true);
  assert.equal(h.attached.has(1), false);
  assert.equal(h.emulated(1), false);
  h.fail(undefined);
  await h.navigate(1);
  assert.equal(h.attached.has(1), false);
});


test('built-in commands never bounce an emulated viewport and release only their enabled domains', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  for (const operation of [
    async () => {
      const result = await h.run({ method: 'click', selector: '#menu' });
      assert.equal(result.clicked, true);
      assert.equal(result.trusted, true);
    },
    () => h.run({ method: 'key', combo: 'Enter' }),
    () => h.run({ method: 'type', selector: '#field', text: 'hello' }),
    () => h.run({ method: 'eval', code: '42' }),
    () => h.screenshot(1),
    () => h.run({ method: 'console', clear: true }),
  ]) {
    const start = h.calls.length;
    await operation();
    const calls = h.calls.slice(start);
    assert.equal(calls.filter(call => call.method === 'detach').length, 0);
    assert.equal(calls.filter(call => /Emulation\.(clear|setDeviceMetrics|setUserAgent|setTouch)/.test(call.method)).length, 0);
    const enabled = calls.filter(call => call.method.endsWith('.enable')).map(call => call.method.replace('.enable', '.disable')).sort();
    assert.deepEqual(calls.filter(call => call.method.endsWith('.disable')).map(call => call.method).sort(), enabled);
    assert.equal(h.commandState.get(1).size, 0);
    assert.equal(h.overrides.get(1).metrics.width, 390);
  }
  await h.run({ method: 'emulate', device: 'off' });
});

test('raw CDP known enabling methods disable explicitly and unknown enabling state falls back to reset', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  for (const domain of ['Fetch', 'Network', 'Debugger', 'DOM', 'CSS', 'Overlay', 'Page', 'Runtime', 'Log']) {
    const start = h.calls.length;
    await h.run({ method: 'cdp', cdpMethod: `${domain}.enable` });
    const calls = h.calls.slice(start);
    assert.ok(calls.some(call => call.method === `${domain}.disable`), `${domain}.enable must be undone`);
    assert.equal(calls.filter(call => call.method === 'detach').length, 0);
    assert.equal(h.commandState.get(1).size, 0);
  }
  const start = h.calls.length;
  await h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' });
  assert.equal(h.calls.slice(start).filter(call => call.method === 'detach').length, 1);
  assert.equal(h.overrides.get(1).metrics.width, 390);
  assert.equal(h.commandState.get(1).size, 0);
  await h.run({ method: 'emulate', device: 'off' });
});

test('restore failure preserves command result and reports lost emulation without retrying the action', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  h.fail('Emulation.setDeviceMetricsOverride');
  const result = await h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' });
  assert.equal(result.acted, true);
  assert.equal(result.actionCount, 1);
  assert.match(result.warning, /emulation lost.*synthetic CDP failure/i);
  assert.equal(result.emulationLost, true);
  assert.equal(h.calls.filter(call => call.method === 'Synthetic.enableUnknown').length, 1);
  assert.equal(h.emulated(1), false);
  assert.equal(h.attached.has(1), false);
  await assert.rejects(h.run({ method: 'key', combo: 'Enter' }), /emulation lost.*zsb emulate/i);
  h.fail(undefined);
  const recovered = await h.run({ method: 'emulate', device: 'iphone' });
  assert.match(recovered.warning, /emulation lost/i);
  assert.equal(recovered.emulating, true);
  await h.run({ method: 'key', combo: 'Enter' });
  await h.run({ method: 'emulate', device: 'off' });
});

test('cleanup failure never replaces the original command error', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  h.fail('Emulation.setDeviceMetricsOverride');
  await assert.rejects(h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknownFailure' }), /original command failure/);
  assert.equal(h.emulated(1), false);
  assert.equal(h.attached.has(1), false);
});


test('built-in domain cleanup survives command errors and timeouts without viewport resets', async () => {
  for (const timeout of [false, true]) {
    const h = harness({ timeoutMs: 20 });
    await h.run({ method: 'emulate', device: 'iphone' });
    const start = h.calls.length;
    if (timeout) h.hold('Runtime.enable');
    else h.fail('Log.enable');
    await assert.rejects(h.run({ method: 'console', clear: true }), timeout ? /timed out/ : /synthetic CDP failure/);
    if (timeout) {
      h.release();
      await new Promise(resolve => setImmediate(resolve));
    }
    assert.equal(h.commandState.get(1).size, 0);
    assert.equal(h.calls.slice(start).filter(call => call.method === 'detach' || /Emulation\.(clear|setDeviceMetrics|setUserAgent|setTouch)/.test(call.method)).length, 0);
    assert.equal(h.overrides.get(1).metrics.width, 390);
    h.fail(undefined);
    await h.run({ method: 'emulate', device: 'off' });
  }
});


test('raw CDP implicit DOM enabling and known emulation overrides reset without detaching', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  for (const cdpMethod of ['DOM.getDocument', 'DOM.getFlattenedDocument', 'Emulation.setGeolocationOverride', 'Emulation.setTimezoneOverride', 'Emulation.setEmulatedMedia']) {
    const start = h.calls.length;
    await h.run({ method: 'cdp', cdpMethod, params: {} });
    const calls = h.calls.slice(start);
    assert.equal(calls.filter(call => call.method === 'detach').length, 0);
    if (cdpMethod.startsWith('DOM.')) assert.ok(calls.some(call => call.method === 'DOM.disable'));
    else assert.ok(calls.some((call, index) => index > calls.findIndex(entry => entry.method === cdpMethod) && (call.method === cdpMethod || call.method === 'Emulation.clearGeolocationOverride')));
    assert.equal(h.commandState.get(1).size, 0);
    assert.equal(h.overrides.get(1).metrics.width, 390);
  }
  await h.run({ method: 'emulate', device: 'off' });
});

test('raw device override cleanup uses the emulation active when its queued command runs', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  await Promise.all([
    h.run({ method: 'emulate', device: 'pixel' }),
    h.run({ method: 'cdp', cdpMethod: 'Emulation.setDeviceMetricsOverride', params: { width: 100, height: 100, mobile: false, deviceScaleFactor: 1 } }),
  ]);
  assert.equal(h.overrides.get(1).metrics.width, 412);
  assert.equal(h.overrides.get(1).metrics.height, 915);
  assert.match(h.overrides.get(1).userAgent, /Pixel/);
  await h.run({ method: 'emulate', device: 'off' });
});

for (const [method, fields, expected] of [
  ['createPaneWindow', { url: 'data:text/html,<title>ZSPANE-test</title>' }, { windowId: 20, focused: false }],
  ['setTheme', { theme: 'dark' }, { theme: 'dark', applied: true }],
  ['protectWindow', { windowId: 10, shellId: 5 }, { windowId: 10, shellId: 5, protected: true }],
  ['resolveWindow', {}, { windowId: 10 }],
]) {
  test(`lost emulation permits window-level ${method}`, async () => {
    const h = harness({ realTarget: true });
    await h.run({ method: 'emulate', device: 'iphone' });
    h.fail('Emulation.setDeviceMetricsOverride');
    await h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' });
    assert.equal(h.emulated(1), false);
    const result = await h.windowless({ method, ...fields });
    for (const [key, value] of Object.entries(expected)) assert.equal(result[key], value);
    assert.equal(result.warning, undefined);
  });
}

test('lost emulation lookup errors never block window-level dispatch', async () => {
  const h = harness({ realTarget: true });
  vm.runInContext('lostEmulationTabs.set(1, "lost"); getTargetTab = async () => { throw new Error("no tab"); };', h.context);
  const result = await h.run({ method: 'protectWindow', shellId: 5 });
  assert.equal(result.protected, true);
});

for (const value of ['hello', 42, null, { acted: true }]) {
  test(`lost emulation warning retains ${JSON.stringify(value)} result`, async () => {
    const h = harness();
    h.context.commandResult = value;
    vm.runInContext('dispatchAction = async () => { lostEmulationTabs.set(1, "emulation lost: synthetic restore failure"); return commandResult; };', h.context);
    const reply = await h.run({ method: 'eval', code: 'value' });
    assert.deepEqual(JSON.parse(JSON.stringify(reply)), {
      ...(value !== null && typeof value === 'object' ? value : { result: value }),
      warning: 'emulation lost: synthetic restore failure', emulationLost: true,
    });
  });
}

test('zsb prints wrapped plain values and a separate warning without changing transport JSON', () => {
  const { spawnSync } = require('node:child_process');
  const os = require('node:os');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-warning-'));
  try {
    fs.writeFileSync(path.join(dir, 'multiprompt-browser'), `#!/usr/bin/env bash\nprintf '%s\\n' "$ZSB_TEST_REPLY"\nexit "\${ZSB_TEST_EXIT:-0}"\n`, { mode: 0o755 });
    for (const value of ['hello', 42, null, { acted: true }]) {
      const reply = { ok: true, result: { ...(value !== null && typeof value === 'object' ? value : { result: value }), warning: 'emulation lost', emulationLost: true } };
      const run = spawnSync('bash', [path.join(__dirname, '../tools/vps-zsb.sh'), 'eval', 'value'], {
        encoding: 'utf8', env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, ZSB_TEST_REPLY: JSON.stringify(reply) },
      });
      assert.equal(run.status, 0, run.stderr);
      assert.equal(run.stderr, 'Warning: emulation lost\n');
      if (value !== null && typeof value === 'object') assert.deepEqual(JSON.parse(run.stdout), reply);
      else assert.equal(run.stdout, `${typeof value === 'string' ? value : JSON.stringify(value)}\n`);
    }
    for (const [raw, code] of [['usage: zsb eval', 0], ['{"ok":true,"result":"hello"}', 0], ['{"ok":false,"error":"failed"}', 2]]) {
      const run = spawnSync('bash', [path.join(__dirname, '../tools/vps-zsb.sh'), 'eval', 'value'], {
        encoding: 'utf8', env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, ZSB_TEST_REPLY: raw, ZSB_TEST_EXIT: String(code) },
      });
      assert.equal(run.status, code);
      assert.equal(run.stdout, `${raw}\n`);
      assert.equal(run.stderr, '');
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});


test('non-emulated busy CDP fails promptly and reset cancels queued emulated work without stale cleanup', async () => {
  const h = harness();
  h.hold('Runtime.evaluate');
  const first = h.run({ method: 'cdp', cdpMethod: 'Runtime.evaluate' });
  await new Promise(resolve => setImmediate(resolve));
  await assert.rejects(h.run({ method: 'cdp', cdpMethod: 'Page.enable' }), /CDP session busy.*zsb reset/);
  h.release();
  await first;
  await h.run({ method: 'emulate', device: 'iphone' });
  h.hold('Synthetic.enableUnknown');
  const pending = assert.rejects(h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' }), /CDP session reset/);
  await new Promise(resolve => setImmediate(resolve));
  const queued = assert.rejects(h.run({ method: 'key', combo: 'Enter' }), /CDP session reset/);
  const result = await h.run({ method: 'reset' });
  assert.equal(result.reset, true);
  await Promise.all([pending, queued]);
  assert.equal(h.emulated(1), false);
  await h.run({ method: 'emulate', device: 'pixel' });
  h.release();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(h.overrides.get(1).metrics.width, 412);
  assert.equal(h.attached.has(1), true);
  await h.run({ method: 'emulate', device: 'off' });
});

for (const method of ['tabs', 'activeTab', 'url', 'frames', 'text', 'links', 'snapshot', 'find', 'navigate', 'closeTab', 'reset', 'resolveWindow']) {
  test(`lost emulation permits warned lifecycle or read-only ${method}`, async () => {
    const h = harness();
    await h.run({ method: 'emulate', device: 'iphone' });
    h.fail('Emulation.setDeviceMetricsOverride');
    await h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' });
    h.fail(undefined);
    h.context.actionCalls = 0;
    vm.runInContext(`dispatchAction = async message => {
      actionCalls++;
      if (message.method === 'reset' || message.method === 'closeTab') lostEmulationTabs.delete(1);
      return { method: message.method, acted: true };
    };`, h.context);
    const result = await h.run({ method });
    assert.equal(result.method, method);
    assert.equal(result.acted, true);
    assert.match(result.warning, /emulation lost/i);
    assert.equal(result.emulationLost, !['reset', 'closeTab'].includes(method));
    assert.equal(h.context.actionCalls, 1);
  });
}

for (const method of ['screenshot', 'eval', 'click', 'key', 'type']) {
  test(`lost emulation blocks viewport-sensitive ${method} before dispatch`, async () => {
    const h = harness();
    await h.run({ method: 'emulate', device: 'iphone' });
    h.fail('Emulation.setDeviceMetricsOverride');
    await h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' });
    h.context.actionCalls = 0;
    vm.runInContext('dispatchAction = async () => { actionCalls++; return {}; };', h.context);
    await assert.rejects(h.run({ method }), /emulation lost.*zsb emulate/i);
    assert.equal(h.context.actionCalls, 0);
  });
}

test('reset clears lost emulation and permits viewport-sensitive commands again', async () => {
  const h = harness();
  await h.run({ method: 'emulate', device: 'iphone' });
  h.fail('Emulation.setDeviceMetricsOverride');
  await h.run({ method: 'cdp', cdpMethod: 'Synthetic.enableUnknown' });
  h.fail(undefined);
  const result = await h.run({ method: 'reset' });
  assert.equal(result.reset, true);
  assert.match(result.warning, /emulation lost/i);
  assert.equal(result.emulationLost, false);
  await h.run({ method: 'key', combo: 'Enter' });
});

test('native screenshot output preserves lost-emulation metadata', () => {
  const source = fs.readFileSync(process.env.NATIVE_SOURCE || path.join(__dirname, '../src/bridge.zig'), 'utf8');
  const body = source.slice(source.indexOf('fn saveScreenshotResponse('), source.indexOf('\nfn getScreenshotBase64('));
  assert.match(body, /getString\(result\.object\.get\("warning"\)\)/);
  assert.match(body, /appendJsonString\(&out, warning\)/);
  assert.match(body, /result\.object\.get\("emulationLost"\)/);
  assert.match(body, /getBool\(emulation_lost\)/);
});

test('shell screenshot output preserves warning and emulationLost for both PNG response shapes', () => {
  const { spawnSync } = require('node:child_process');
  const os = require('node:os');
  const source = fs.readFileSync(process.env.BROWSER_SOURCE || path.join(__dirname, '../tools/vps-multiprompt-browser.sh'), 'utf8');
  const start = source.indexOf("<<'PY'\n", source.indexOf('if [ -n "$output_path" ]')) + "<<'PY'\n".length;
  assert.ok(start > "<<'PY'\n".length);
  const script = source.slice(start, source.indexOf('\nPY\n', start));
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-screenshot-'));
  try {
    for (const data of [{ data: 'iVBORw0KGgo=' }, { dataUrl: 'data:image/png;base64,iVBORw0KGgo=' }]) {
      for (const lost of [true, false, undefined]) {
        const result = { ...data, via: 'synthetic', ...(lost === undefined ? {} : { warning: 'emulation lost: "restore" failed', emulationLost: lost }) };
        const input = path.join(dir, 'reply.json');
        const output = path.join(dir, 'shot.png');
        fs.writeFileSync(input, JSON.stringify({ ok: true, result }));
        const run = spawnSync('python3', ['-c', script, output, input], { encoding: 'utf8' });
        assert.equal(run.status, 0, run.stderr);
        assert.deepEqual(JSON.parse(run.stdout), { ok: true, path: output, bytes: 8, via: 'synthetic', ...(lost === undefined ? {} : { warning: result.warning, emulationLost: lost }) });
        assert.deepEqual(fs.readFileSync(output), Buffer.from('iVBORw0KGgo=', 'base64'));
      }
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('release version guard compares against the current git master with a fixed fallback', () => {
  const source = fs.readFileSync(__filename, 'utf8');
  const guard = source.slice(source.indexOf("test('extension release version"), source.indexOf("test('ordinary CDP command state"));
  assert.match(guard, /execFileSync\('git', \['show', 'origin\/master:extension\/manifest\.json'\]/);
  assert.match(guard, /catch/);
  assert.match(guard, /1\.0\.71/);
});
