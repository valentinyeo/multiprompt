const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function harness({ timeoutMs } = {}) {
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
  chrome.runtime.connectNative = () => ({ onMessage: event('port.message'), onDisconnect: event('port.disconnect'), postMessage() {} });
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
    if (method === heldMethod) await new Promise(resolve => { release = resolve; });
    const enabled = commandState.get(tabId) || new Set();
    if (!method.startsWith('Emulation.')) enabled.add(method);
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
    return {};
  };
  const context = vm.createContext({ chrome, console, URL, navigator: { userAgent: 'Synthetic Desktop' }, setTimeout: (fn, ms) => setTimeout(fn, timeoutMs && ms === 15000 ? timeoutMs : ms), clearTimeout });
  vm.runInContext(fs.readFileSync(process.env.BRIDGE_SOURCE || path.join(__dirname, 'bridge.js'), 'utf8'), context);
  vm.runInContext('rememberTargetWindow = async () => {}; getTargetTab = async message => ({ id: message.tabId || 1 });', context);
  return {
    calls, attached, overrides, commandState,
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
  assert.equal(h.calls.filter(call => call.method === 'attach').length, 3);
  assert.equal(h.calls.filter(call => call.method === 'detach').length, 2);
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
  const parts = manifest.version.split('.').map(Number);
  assert.ok(parts[0] > 1 || (parts[0] === 1 && (parts[1] > 0 || parts[2] > 70)), '1.0.68 is on master; 1.0.69 and 1.0.70 are already allocated');
  const docs = fs.readFileSync(path.join(__dirname, '../openwiki/browser/zsb-selftest.md'), 'utf8');
  assert.ok(docs.includes(`version **${manifest.version}**`));
});

test('ordinary CDP command state is reset while emulation is restored', async () => {
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
    const detaches = h.calls.filter(call => call.method === 'detach').length;
    await operation();
    assert.equal(h.calls.filter(call => call.method === 'detach').length, detaches + 1, 'detach resets every command-enabled domain');
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
      const pending = h.run({ method: 'emulate', device: 'iphone' });
      await new Promise(resolve => setImmediate(resolve));
      if (!existing) assert.equal(h.emulated(1), false, 'setup is not recorded before apply succeeds');
      await assert.rejects(pending, /CDP operation timed out/);
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
  h.fail('Emulation.setDeviceMetricsOverride');
  await assert.rejects(h.run({ method: 'cdp', cdpMethod: 'Runtime.evaluate' }), /synthetic CDP failure/);
  assert.equal(h.attached.has(1), false);
  assert.equal(h.emulated(1), false);
  h.fail(undefined);
  await h.navigate(1);
  assert.equal(h.attached.has(1), false);
});
