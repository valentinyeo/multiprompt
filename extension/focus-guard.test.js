const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, 'bridge.js'), 'utf8');

function audit(text) {
  assert.doesNotMatch(text, /focused:\s*true/, 'automatic extension flows have no physical-user focus authority');
  assert.doesNotMatch(text, /chrome\.windows\.update\([^]*?focused:\s*true/);
}

test('automatic window creation is nonactivating; the explicit focus leak is rejected', () => {
  audit(source);
  assert.throws(() => audit(source + '\nchrome.windows.update(10, {focused: true});'));

});

test('executed navigate, activate, reconnect, reload and screenshot commands do not focus an OS window', async () => {
  let harness = fs.readFileSync(path.join(__dirname, 'bridge-routing.test.js'), 'utf8');
  harness = harness.slice(0, harness.indexOf('\ntest('));
  harness = harness.replace('outsideWindows.push(options);', 'assert.notEqual(options.focused, true); outsideWindows.push(options);');
  harness = harness.replace('update: async () => ({}),', 'update: async (_id, options) => { assert.notEqual(options.focused, true); throw new Error("unexpected OS window update"); },');
  harness = harness.replace('clearTimeout() {},', 'clearTimeout(id) { clearTimeout(id); },');
  harness = harness.replace('if (delay === 150) saveCallback = callback;\n      return 1;', 'if (delay === 150) { saveCallback = callback; return 1; }\n      return setTimeout(callback, delay);');
  const context = vm.createContext({ require, __dirname, process, console, URL, setTimeout, clearTimeout });
  vm.runInContext(harness + '\nglobalThis.makeHarness = createHarness;', context);
  const h = context.makeHarness({ protectedFocused: false });
  h.setTab({ id: 42, windowId: 10, index: 0, active: true, url: 'https://old.example/', title: 'Old' });
  const opened = await h.api.dispatch({ method: 'navigate', windowId: 10, url: 'https://new.example/', newTab: true, activate: true });
  assert.equal(h.createdTabs.at(-1).active, true);
  assert.equal(h.createdTabs.at(-1).windowId, 10);
  await h.api.dispatch({ method: 'activate', windowId: 10, tabId: 42 });
  assert.ok(h.updatedTabs.some(({ tabId, options }) => tabId === 42 && options.active));
  await h.api.dispatch({ method: 'protectWindow', windowId: 10, shellId: 1, ownerPid: 100 });
  const reload = await h.api.dispatch({ method: 'extensionReload', windowId: 10 });
  assert.equal(reload.reloadScheduled, true);
  await h.api.dispatch({ method: 'screenshot', windowId: 10, tab: String(opened.tabId || opened.id || 42) }).catch(() => {});
  assert.equal(h.outsideWindows.length, 0);
  await h.api.dispatch({ method: 'navigate', windowId: 10, url: 'https://agent.example/', newTab: true });
  assert.equal(h.createdTabs.at(-1).active, false);
  await h.api.dispatch({ method: 'createPaneWindow', url: 'data:text/html,<title>ZSPANE1-2</title>' });
  assert.equal(h.outsideWindows.length, 1);
  assert.equal(h.outsideWindows[0].focused, false);
});
