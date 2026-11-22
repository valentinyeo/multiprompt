const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, 'bridge.js'), 'utf8');
const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, 'manifest.json'), 'utf8'));

function handlers() {
  const calls = [];
  const warnings = [];
  let command, menu;
  const context = vm.createContext({
    SHOT_URL_MENU_ID: 'take-tab-screenshot-link',
    console: { warn: (...args) => warnings.push(args) },
    shotUrl: async (id, userInitiated) => { calls.push([id, userInitiated]); },
    chrome: {
      commands: { onCommand: { addListener: (fn) => { command = fn; } } },
      contextMenus: { onClicked: { addListener: (fn) => { menu = fn; } } },
      windows: { getLastFocused: async () => ({ id: 42 }) },
    },
  });
  const start = source.indexOf('chrome.contextMenus.onClicked.addListener(');
  vm.runInContext(source.slice(start, source.indexOf('\nconnect();', start)), context);
  return { calls, warnings, command, menu, context };
}

test('Chrome declares Ctrl+Shift+S while retaining the existing Alt+Shift+S binding', () => {
  assert.equal(manifest.commands['take-tab-screenshot-ctrl'].suggested_key.default, 'Ctrl+Shift+S');
  assert.equal(manifest.commands['take-tab-screenshot'].suggested_key.default, 'Alt+Shift+S');
});

test('both Chrome commands and the context menu execute the same shotUrl path', async () => {
  const h = handlers();
  await h.command('take-tab-screenshot-ctrl');
  await h.command('take-tab-screenshot');
  await h.menu({ menuItemId: 'take-tab-screenshot-link' }, { windowId: 42 });
  assert.deepEqual(h.calls, [[42, true], [42, true], [42, true]]);
  assert.deepEqual(h.warnings, []);
  await h.command('unrelated');
  await h.menu({ menuItemId: 'unrelated' }, { windowId: 99 });
  await h.menu({ menuItemId: 'take-tab-screenshot-link' }, {});
  assert.deepEqual(h.calls, [[42, true], [42, true], [42, true]]);
});

test('a missing Chrome window fails visibly without requesting a screenshot of another pane', async () => {
  const h = handlers();
  h.context.chrome.windows.getLastFocused = async () => ({});
  await h.command('take-tab-screenshot-ctrl');
  assert.deepEqual(h.calls, []);
  assert.match(h.warnings[0][1], /no last-focused browser window/);
});
