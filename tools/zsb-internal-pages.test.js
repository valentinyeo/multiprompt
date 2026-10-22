const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const extension = fs.readFileSync(process.env.ZSB_BRIDGE_JS || path.join(root, 'extension/bridge.js'), 'utf8');
const native = fs.readFileSync(process.env.ZSB_BRIDGE_ZIG || path.join(root, 'src/bridge.zig'), 'utf8');

function harness(type = 'normal', url = 'edge://settings/privacy') {
  const event = { addListener() {} };
  const tabs = new Map([
    [1, { id: 1, windowId: 10, active: true, index: 0, url, title: 'Settings' }],
    [2, { id: 2, windowId: 10, active: false, index: 1, url: 'https://example.test/', title: 'Web page' }],
    [3, { id: 3, windowId: 20, active: true, index: 0, url: 'https://foreign.test/', title: 'Foreign' }],
  ]);
  const calls = { attaches: [], native: [], creates: [] };
  let nativeError;
  let nextId = 4;
  const windows = [{ id: 10, type, focused: false }, { id: 20, type: 'normal', focused: false }];
  const chrome = {
    action: { onClicked: event },
    alarms: { create() {}, onAlarm: event },
    commands: { onCommand: event },
    contextMenus: { onClicked: event },
    debugger: {
      onDetach: event, onEvent: event,
      attach: async ({ tabId }) => {
        calls.attaches.push(tabId);
        if (/^(edge|chrome):/.test(tabs.get(tabId).url)) throw new Error('Cannot access contents of url; Extension manifest must request permission to access this host');
      },
      detach: async () => {},
      sendCommand: async (_, method) => {
        if (method === 'Page.captureScreenshot') {
          return { data: 'iVBORw0KGgo=' };
        }
        return {};
      },
    },
    runtime: {
      connectNative: () => ({ onMessage: event, onDisconnect: event }),
      onStartup: event, onInstalled: event, onMessage: event,
    },
    storage: { local: { get: async () => ({}), set: async () => {}, remove: async () => {} } },
    webNavigation: {
      onCommitted: event,
      getAllFrames: async ({ tabId }) => [{ frameId: 0, url: tabs.get(tabId).url }],
    },
    scripting: { executeScript: async ({ target, func, args }) => {
      if (!func) return [];
      const tab = tabs.get(target.tabId);
      if (/^(edge|chrome):/.test(tab.url)) throw new Error('Cannot access contents of url');
      context.document = { body: { innerText: 'Readable web page' } };
      context.location = { href: tab.url };
      return [{ result: func(...args) }];
    } },
    tabs: {
      onRemoved: event, onCreated: event, onActivated: event,
      sendMessage: async () => {},
      query: async ({ windowId, active } = {}) => [...tabs.values()].filter(tab =>
        (windowId === undefined || tab.windowId === windowId) && (!active || tab.active)),
      get: async id => tabs.get(id),
      create: async options => {
        calls.creates.push(options);
        const tab = { ...options, id: nextId++, title: options.url };
        tabs.set(tab.id, tab);
        return tab;
      },
    },
    windows: {
      WINDOW_ID_NONE: -1, onRemoved: event, onFocusChanged: event,
      get: async id => windows.find(window => window.id === id),
      getAll: async ({ windowTypes }) => windows.filter(window => windowTypes.includes(window.type)),
      getLastFocused: async () => null,
    },
  };
  const context = vm.createContext({
    chrome, console: { log() {}, warn() {} },
    crypto: { randomUUID: () => 'request' },
    setTimeout: () => 1, clearTimeout() {},
  });
  vm.runInContext(extension + '\nglobalThis.api = { dispatch, protectWindow, resolveWindow, ensureBackgroundTabFocusEmulation };', context);
  context.nativeReply = async (method, fields) => {
    calls.native.push({ method, ...fields });
    if (nativeError) throw new Error(nativeError);
    return { via: 'native-window', dataUrl: 'data:image/png;base64,iVBORw0KGgo=', bytesApprox: 8 };
  };
  vm.runInContext('requestHostReply = nativeReply;', context);
  return {
    api: context.api, tabs, windows, calls,
    dispatch: (method, fields = {}) => context.api.dispatch({ method, windowId: 10, ...fields }),
    failNative: message => { nativeError = message; },
  };
}

for (const url of ['edge://settings/privacy', 'chrome://settings/content']) {
  test(`internal text explains the restriction without debugger attachment: ${url}`, async () => {
    const h = harness('normal', url);
    await assert.rejects(h.dispatch('text'), error => {
      assert.match(error.message, /text is unavailable on browser-internal pages/);
      assert.ok(error.message.includes(url));
      assert.doesNotMatch(error.message, /no active tab/);
      return true;
    });
    assert.deepEqual(h.calls.attaches, []);
  });

  for (const binding of ['bound window id', 'exact beacon']) {
    test(`native capture preserves tabs, other-tab reads, screenshots and navigation with ${binding}: ${url}`, async () => {
      const h = harness(binding === 'bound window id' ? 'normal' : 'popup', url);
      if (binding === 'exact beacon') {
        await assert.rejects(h.api.protectWindow({ windowId: 10, shellId: 7, ownerPid: 123 }), /not found \(no active tab\)/);
        const nonce = 'ZSPANE7-12345';
        h.tabs.get(1).url = `data:text/html,<title>${nonce}</title>`;
        assert.equal((await h.api.resolveWindow({ shellId: 7, ownerPid: 123, match: nonce })).windowId, 10);
        h.tabs.get(1).url = url;
      }
      await h.api.protectWindow({ windowId: 10, shellId: 7, ownerPid: 123 });
      h.windows[0].type = 'popup';
      const capture = await h.dispatch('screenshot');
      assert.equal(capture.via, 'native-window');
      assert.equal(capture.tab.url, url);
      assert.match(capture.dataUrl, /^data:image\/png;base64,/);
      assert.deepEqual(h.calls.native, [{ method: 'nativeScreenshot', windowId: 10, ownerPid: 123 }]);
      assert.deepEqual(h.calls.attaches, []);
      const listed = (await h.dispatch('tabs')).tabs;
      assert.deepEqual(Array.from(listed, tab => tab.id), [1, 2]);
      assert.equal(listed[0].url, url);
      assert.equal(listed[0].target, true);
      assert.equal((await h.dispatch('text', { tabId: 2 })).text, 'Readable web page');
      assert.equal((await h.dispatch('screenshot', { tabId: 2 })).via, 'Page.captureScreenshot');
      assert.equal((await h.api.resolveWindow({ shellId: 7, ownerPid: 123 })).windowId, 10);
      const opened = await h.dispatch('navigate', { url: 'https://new.test/', newTab: true });
      assert.equal(opened.tab.windowId, 10);
      assert.equal(h.calls.creates[0].windowId, 10);
      assert.equal((await h.dispatch('tabs')).tabs.length, 3);
      assert.equal(h.tabs.get(3).windowId, 20);
    });
  }
}

test('background internal tabs never attach and never capture a different visible tab', async () => {
  const h = harness();
  h.tabs.get(1).active = false;
  h.tabs.get(2).active = true;
  await h.api.ensureBackgroundTabFocusEmulation(h.tabs.get(1));
  assert.deepEqual(h.calls.attaches, []);
  await assert.rejects(h.dispatch('screenshot', { tabId: 1 }), /requires.*selected.*refusing to capture another tab/);
  assert.deepEqual(h.calls.native, []);
  await assert.rejects(h.dispatch('screenshot', { tabId: 3 }), /does not belong/);
});

test('native capture failures do not poison tab tracking or another tab screenshot', async () => {
  const h = harness();
  h.failNative('native pane screenshot failed: HostedPaneNotVisible');
  await assert.rejects(h.dispatch('screenshot'), /HostedPaneNotVisible/);
  assert.equal((await h.dispatch('tabs')).tabs.length, 2);
  assert.equal((await h.dispatch('text', { tabId: 2 })).text, 'Readable web page');
  assert.equal((await h.dispatch('screenshot', { tabId: 2 })).via, 'Page.captureScreenshot');
});

test('ordinary page capture errors are not replaced with native capture', async () => {
  const h = harness();
  const timers = [];
  const context = vm.createContext({
    getTargetTab: async () => h.tabs.get(2),
    isBrowserInternalTab: () => false,
    captureScreenshotViaCdp: async () => { throw new Error('real screenshot failure'); },
    requestHostReply: () => timers.push('native'),
  });
  const start = extension.indexOf('async function captureScreenshotResult(');
  vm.runInContext(extension.slice(start, extension.indexOf('async function screenshot(', start)), context);
  await assert.rejects(context.captureScreenshotResult({ windowId: 10 }), /real screenshot failure/);
  assert.deepEqual(timers, []);
});

test('native capture references declared Win32 APIs', () => {
  const capture = fs.readFileSync(path.join(root, 'src/bridge_capture.zig'), 'utf8');
  const win32 = fs.readFileSync(path.join(root, 'src/win32.zig'), 'utf8');
  for (const [, name] of capture.matchAll(/\bwin\.([A-Za-z_][A-Za-z0-9_]*)/g)) {
    assert.match(win32, new RegExp(`pub (?:const |extern "[^"]+" fn )${name}\\b`), `missing win32 declaration: ${name}`);
  }
});

test('native capture and its fixtures never change window visibility, position or activation', () => {
  const capture = fs.readFileSync(path.join(root, 'src/bridge_capture.zig'), 'utf8');
  const win32 = fs.readFileSync(path.join(root, 'src/win32.zig'), 'utf8');
  const activation = /\b(?:SetForegroundWindow|SetFocus|AttachThreadInput|SwitchToThisWindow|AllowSetForegroundWindow|ShowWindow(?:Async)?|SetWindowPos|MoveWindow)\s*\(/;
  const audit = (captureSource, bindings) => {
    assert.doesNotMatch(captureSource, activation);
    assert.doesNotMatch(bindings, /extern "user32" fn (?:SetForegroundWindow|SetFocus|AttachThreadInput|SwitchToThisWindow|AllowSetForegroundWindow|ShowWindow(?:Async)?|SetWindowPos)\(/);
  };
  audit(capture, win32);
  for (const name of ['ShowWindow', 'ShowWindowAsync', 'SetWindowPos', 'MoveWindow', 'SetForegroundWindow', 'SetFocus']) {
    assert.throws(() => audit(capture + `\nwin.${name}(pane);`, win32));
  }
  assert.throws(() => audit(capture, win32 + '\nextern "user32" fn ShowWindow(HANDLE, i32) callconv(WINAPI) BOOL;'));
  assert.match(capture, /W\("Hidden fixture"\), win\.WS_POPUP,/);
  assert.match(capture, /expectError\(error\.HostedPaneNotVisible, capture\(std\.testing\.allocator, window_id \+ 1, pid\)\)/);
  assert.match(capture, /expectEqualDeep\(before, after\)/);
});

test('native capture is routed by exact hosted window and owner, with bounded PNG replies', () => {
  const capture = fs.readFileSync(path.join(root, 'src/bridge_capture.zig'), 'utf8');
  const pane = fs.readFileSync(path.join(root, 'src/browser_pane.zig'), 'utf8');
  assert.match(native, /method, "nativeScreenshot"/);
  assert.match(native, /getI64\(object\.get\("windowId"\)\)/);
  assert.match(native, /getI64\(object\.get\("ownerPid"\)\)/);
  assert.match(native, /@import\("bridge_capture\.zig"\)\.capture\(allocator, window_id, owner_pid\)/);
  assert.match(native, /data:image\/png;base64,/);
  assert.match(pane, /SetPropW\(app_state\.shells\[idx\]\.browser_hwnd, L\("ZigShellBrowserWindowId"\)/);
  assert.match(capture, /GetPropW\(hwnd, W\("ZigShellBrowserWindowId"\)\)/);
  assert.match(capture, /GetPropW\(hwnd, W\("ZigShellPaneOwner"\)\)/);
  assert.match(capture, /pid != search\.owner_pid/);
  assert.match(capture, /search\.hwnd == null or search\.ambiguous/);
  assert.match(capture, /PrintWindow\(hwnd, memory_dc, 2\)/);
  assert.match(capture, /win\.BitBlt\(memory_dc/);
  assert.match(capture, /GdipSaveImageToStream/);
  assert.match(capture, /length > 700 \* 1024/);
  const production = capture.slice(0, capture.indexOf('\ntest "'));
  const focusApi = /GetForegroundWindow|SetForegroundWindow|SetFocus|ShowWindow/;
  assert.match(capture.slice(production.length), focusApi);
  assert.doesNotMatch(production, focusApi);
});
