const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const bridgeJsPath = process.env.ZSB_BRIDGE_JS || path.join(root, "extension", "bridge.js");
const mainZigPath = process.env.ZSB_MAIN_ZIG;
const bridgeZigPath = process.env.ZSB_BRIDGE_ZIG || path.join(root, "src", "bridge.zig");

const bridgeJs = fs.readFileSync(bridgeJsPath, "utf8");
const mainZig = require('./app-source').readAppSource(mainZigPath);
const bridgeZig = fs.readFileSync(bridgeZigPath, "utf8");

const BEACON_URL = "data:text/html,<title>ZSPANE14-6183294</title><style>body{background:%23000;margin:0}</style>";

function browserHarness() {
  const tabs = new Map();
  const pages = new Map();
  const windows = new Set();
  let nextId = 1;
  let focused = true;
  const event = { addListener() {} };
  const onActivated = { addListener(listener) { this.listener = listener; } };
  const onRemoved = { addListener(listener) { this.listener = listener; } };
  const chrome = {
    action: { onClicked: event },
    alarms: { create() {}, onAlarm: event },
    commands: { onCommand: event },
    contextMenus: { onClicked: event },
    debugger: {
      onDetach: event, onEvent: event,
      attach: async () => {}, detach: async () => {},
      sendCommand: async () => ({}),
    },
    runtime: { connectNative: () => ({ onMessage: event, onDisconnect: event }), onStartup: event, onInstalled: event, onMessage: event },
    storage: { local: { get: async () => ({}), set: async () => {}, remove: async () => {} } },
    webNavigation: {
      onCommitted: event,
      getAllFrames: async ({ tabId }) => {
        const page = pages.get(tabId);
        return [page, ...(page.frames || [])].map((frame, frameId) => ({ frameId, url: frame.url }));
      },
    },
    scripting: {
      executeScript: async ({ target, func, args = [] }) => {
        if (!func) return [];
        const page = pages.get(target.tabId);
        return [page, ...(page.frames || [])].map((frame, frameId) => ({ frame, frameId }))
          .filter(({ frameId }) => target.allFrames || (target.frameIds || [0]).includes(frameId))
          .map(({ frame, frameId }) => {
          context.document = {
            title: frame.title,
            body: { innerText: frame.text },
            links: (frame.links || []).map((href) => ({ href, innerText: href })),
            querySelectorAll: () => [],
          };
          context.location = { href: frame.url };
          return { frameId, result: func(...args) };
        });
      },
    },
    tabs: {
      onRemoved, onCreated: event, onActivated, sendMessage: async () => {},
      query: async ({ windowId, active }) => [...tabs.values()].filter((tab) =>
        tab.windowId === windowId && (!active || tab.active)),
      get: async (id) => {
        const tab = tabs.get(id);
        if (!tab) throw new Error(`No tab with id: ${id}.`);
        return tab;
      },
      create: async ({ url, windowId, active }) => {
        if (!windows.has(windowId)) throw new Error(`No window with id: ${windowId}.`);
        if (active) for (const tab of tabs.values()) if (tab.windowId === windowId) tab.active = false;
        const tab = { id: nextId++, windowId, url, title: url, active };

        tabs.set(tab.id, tab);
        pages.set(tab.id, { url, title: url, text: url, links: [] });
        return tab;
      },
      update: async (id, options) => {
        const tab = tabs.get(id);
        if (!tab) throw new Error(`No tab with id: ${id}.`);
        if (options.active) for (const other of tabs.values()) if (other.windowId === tab.windowId) other.active = false;
        Object.assign(tab, options);
        if (options.active) onActivated.listener?.({ windowId: tab.windowId, tabId: id });
        return tab;
      },
      remove: async (id) => {
        const removed = tabs.get(id);
        tabs.delete(id);
        onRemoved.listener?.(id);
        if (removed?.active) {
          const remaining = [...tabs.values()].find((tab) => tab.windowId === removed.windowId);
          if (remaining) {
            remaining.active = true;
            onActivated.listener?.({ windowId: remaining.windowId, tabId: remaining.id });
          }
        }
      },
    },
    windows: {
      WINDOW_ID_NONE: -1,
      onRemoved: event,
      onFocusChanged: event,
      get: async (windowId) => {
        if (!windows.has(windowId)) throw new Error(`No window with id: ${windowId}.`);
        return { id: windowId, focused };
      },
      getAll: async () => [...windows].map((id) => ({ id, focused: false })),
      getLastFocused: async () => ({ id: [...windows][0], focused }),
    },
  };
  const context = vm.createContext({ chrome, console: { log() {}, warn() {} }, crypto: { randomUUID: () => "id" }, setTimeout: () => 1, clearTimeout() {} });
  vm.runInContext(`${bridgeJs}\n;globalThis.api = {
    navigate, listTabs, textAction, getTargetTab, dispatch, protectWindow,
    rememberTarget: (windowId, tabId) => rememberZsbTargetTab(windowId, tabId),
    isBeacon: (tab) => isPaneBeaconTab(tab),
  };`, context);
  return {
    api: context.api,
    chrome,
    tabs,
    pages,
    openWindow(windowId) { windows.add(windowId); },
    setPage(tabId, text) { pages.get(tabId).text = text; },
    setFocused(value) { focused = value; },
  };
}

test("reads and clicks skip the ZSPANE launch placeholder", async () => {
  const h = browserHarness();
  h.openWindow(10);
  const beacon = await h.chrome.tabs.create({ windowId: 10, url: BEACON_URL, active: true });
  const real = await h.chrome.tabs.create({ windowId: 10, url: "https://app.example.com/demo", active: false });
  h.setPage(real.id, "Board page");
  assert.equal(h.api.isBeacon({ url: BEACON_URL }), true);
  assert.equal(h.api.isBeacon({ url: "https://x.test" }), false);

  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, real.id,
    "the placeholder must not become the session's target tab");
  assert.equal((await h.api.textAction({ windowId: 10 })).text, "Board page");
  assert.equal((await h.api.textAction({ windowId: 10 })).tab.id, real.id);
  const listed = (await h.api.listTabs({ windowId: 10 })).tabs;
  assert.equal(listed.find((tab) => tab.target).id, real.id);
  assert.equal(listed.find((tab) => tab.id === beacon.id).target, false);
  assert.equal((await h.api.dispatch({ method: "activeTab", windowId: 10 })).id, real.id);
});

test("a remembered placeholder tab is not used for reads", async () => {
  const h = browserHarness();
  h.openWindow(10);
  const beacon = await h.chrome.tabs.create({ windowId: 10, url: BEACON_URL, active: true });
  const real = await h.chrome.tabs.create({ windowId: 10, url: "https://x.test", active: false });
  h.setPage(real.id, "Real page");
  h.api.rememberTarget(10, beacon.id);
  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, real.id);
  assert.equal((await h.api.textAction({ windowId: 10 })).text, "Real page");
});

test("IGSH-613 agent navigate replaces the launch placeholder in place and targets that tab", async () => {
  for (const active of [false, true]) {
    for (const activate of [false, true]) {
      const h = browserHarness();
      h.openWindow(10);
      const beacon = await h.chrome.tabs.create({ windowId: 10, url: BEACON_URL, active });
      h.setFocused(false);
      const url = "https://example.test/page";
      const opened = (await h.api.navigate({ windowId: 10, url, activate })).tab;
      assert.equal(opened.id, beacon.id);
      assert.equal(opened.url, url);
      assert.equal(opened.active, active || activate);
      const tabs = await h.chrome.tabs.query({ windowId: 10 });
      assert.equal(tabs.length, 1, "navigation must reuse the launch tab without adding a tab");
      assert.ok(tabs.every((tab) => tab.url !== BEACON_URL && !tab.url.includes("ZSPANE")));
      assert.equal(tabs[0].id, beacon.id);
      assert.equal(tabs[0].url, url);
      assert.equal((await h.api.textAction({ windowId: 10 })).tab.id, beacon.id);
    }
  }
});

test("issue: navigate --new-tab appends a background tab without replacing the existing real page", async () => {
  const h = browserHarness();
  h.openWindow(10);
  await h.chrome.tabs.create({ windowId: 10, url: "https://existing.test", active: true });
  h.setFocused(false);
  const opened = (await h.api.navigate({ windowId: 10, url: "https://second.test", newTab: true })).tab;
  assert.equal(opened.active, false, "an agent tab must never be activated");
  assert.ok([...h.tabs.values()].some((tab) => tab.url === "https://existing.test"));
  assert.equal((await h.api.textAction({ windowId: 10 })).tab.id, opened.id);
});

test("tabs never reports an empty pane for a window this instance does not have", async () => {
  const h = browserHarness();
  h.openWindow(10);
  const first = await h.chrome.tabs.create({ windowId: 10, url: "https://x.test", active: true });
  assert.equal((await h.api.listTabs({ windowId: 10 })).tabs.length, 1);
  await assert.rejects(h.api.listTabs({ windowId: 999 }), /not found \(no active tab\)/);
  await assert.rejects(h.api.dispatch({ method: "activeTab", windowId: 999 }), /not found \(no active tab\)/);
  await assert.rejects(h.api.textAction({ windowId: 999 }), /not found \(no active tab\)/);
  assert.deepEqual(Array.from((await h.api.listTabs({})).tabs), [],
    "no bound window still returns nothing instead of an error");
  assert.equal((await h.api.listTabs({ windowId: 10 })).tabs[0].id, first.id);
});

test("protectWindow refuses a window this bridge instance does not own", async () => {
  const h = browserHarness();
  h.openWindow(10);
  await h.chrome.tabs.create({ windowId: 10, url: "https://x.test", active: true });
  await assert.rejects(h.api.protectWindow({ windowId: 999 }), /refusing to touch another window/);
  assert.equal((await h.api.protectWindow({ windowId: 10, shellId: 3 })).protected, true);
});

function functionBody(source, name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf(`fn ${nextName}(`, start);
  assert.notEqual(end, -1, `${nextName} must follow ${name}`);
  return source.slice(start, end);
}

test("zsb open proves the pane tab before answering ok", () => {
  const openStart = mainZig.indexOf('std.mem.eql(u8, argv[0], "open")');
  const openEnd = mainZig.indexOf('std.mem.eql(u8, argv[0], "sidebar")', openStart);
  assert.notEqual(openStart, -1);
  assert.notEqual(openEnd, -1);
  const branch = mainZig.slice(openStart, openEnd);
  assert.match(branch, /zsbResolvePaneWindowId\(client, session\)/,
    "open must resolve (and relaunch) the pane's bound window");
  assert.match(branch, /zsbVerifyOpenRequest\(client, session, window_id, url, out_buf\)/,
    "open must verify the tab it opened");
  assert.match(branch, /if \(zsbSessionHasWebView2\(session\)\)/,
    "the WebView2 backend has no Edge windowId to resolve or verify");

  const verify = functionBody(mainZig, "zsbVerifyOpenRequest", "zsbRetryAfterStaleBinding");
  assert.match(verify, /if \(outcome.verified\) \{\s+_ = send\(client, "ok\\n", 3, 0\);/,
    "ok may only be sent for a verified open");
  assert.match(verify, /zsbSendJsonError\(\s*client,\s*"open_failed"/,
    "an unverified open must return a structured error");

  const establish = functionBody(mainZig, "zsbEstablishOpenTab", "zsbVerifyOpenRequest");
  assert.match(establish, /const nav_argv = \[_\]\[\]const u8\{ "navigate", url \};/,
    "issue: an agent open never activates the tab it loads");
  assert.doesNotMatch(establish, /--activate/);
  assert.match(establish, /if \(!before\.beacon and zsbReplyHasUrl\(out_buf\[0\.\.out_len\], url\)\) \{/,
    "a repeated open of the page already in the background target tab adds no tab");
  assert.match(establish, /zsbRunSessionBridge\(window_id, &\[_\]\[\]const u8\{"url"\}/,
    "verification reads the session's target tab back");
  assert.match(establish, /zsbReplyHasUrl\(out_buf\[0\.\.out_len\], url\)/,
    "verification requires the requested URL in that tab");
  assert.match(establish, /zsbReadOpenTab/);
});

test("open does not navigate from the UI thread handoff", () => {
  const body = functionBody(mainZig, "zsbPreparePaneForShell", "zsbSendNoTabForSession");
  assert.match(body, /shells\[idx\]\.browser_enabled = true;/);
  assert.doesNotMatch(body, /navigateBrowserPane|bridgeExePath|spawnBrowserCli/,
    "the handoff must not load the URL itself; the worker owns that");
});

test("a stale or foreign binding forces a re-resolve and one retry", () => {
  const stale = functionBody(mainZig, "zsbLooksLikeStaleBindingError", "zsbUrlIsBeacon");
  assert.match(stale, /not found \(no active tab\)/);
  assert.match(stale, /No window with id/);

  const retry = functionBody(mainZig, "zsbRetryAfterStaleBinding", "tunnelInboundThread");
  assert.match(retry, /queueZsbRebindRequest\(session\)/);
  assert.match(retry, /zsbPollPaneWindowIdSilent\(session, 12_000, 500\)/);
  assert.match(retry, /zsbBuildBridgeCmd\(fresh_wid, argv/);
  assert.doesNotMatch(retry, /queueZsbBindRequest\(session\)/,
    "a retry must re-resolve the window instead of rewriting the same id");

  const handler = functionBody(mainZig, "handleZsbBindRequest", "scanPaneWinCandidates");
  assert.match(handler, /if \(force and shells\[ti\]\.browser_window_id != 0\) \{\s+shells\[ti\]\.browser_window_id = 0;/,
    "a forced rebind clears the stale window id before resolving");
  assert.match(mainZig, /fn queueZsbRebindRequest[\s\S]*?return queueZsbBindRequestEx\(session, true, false, null\);/);
});

test("the URL poll never persists the pane launch placeholder", () => {
  const start = mainZig.indexOf("WM_APP_BROWSER_URL_UPDATE =>");
  const end = mainZig.indexOf("WM_APP_SHELL_EXITED =>", start);
  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  const handler = mainZig.slice(start, end);
  assert.match(handler, /std\.mem\.startsWith\(u8, new_url, "data:text\/html"\)/);
  assert.match(handler, /ZSPANE/);
});

test("the bridge CLI retries a request that reached the wrong bridge instance", () => {
  assert.match(bridgeZig, /const instance_mismatch_markers = \[_\]\[\]const u8\{[\s\S]*?"not found \(no active tab\)"/);
  const retry = bridgeZig.slice(
    bridgeZig.indexOf("fn requestBrowserWithRetry("),
    bridgeZig.indexOf("const instance_mismatch_markers"),
  );
  assert.match(retry, /if \(replyIsInstanceMismatch\(response\) and attempt \+ 1 < request_attempts\)/,
    "an instance-ownership reply must be retried on the next pipe instance");
  const predicate = bridgeZig.slice(
    bridgeZig.indexOf("fn replyIsInstanceMismatch("),
    bridgeZig.indexOf("test \"only instance-ownership errors"),
  );
  assert.match(predicate, /for \(instance_mismatch_markers\)/);
  const markers_block = bridgeZig.slice(
    bridgeZig.indexOf("const instance_mismatch_markers"),
    bridgeZig.indexOf("fn replyIsInstanceMismatch("),
  );
  for (const marker of ["No window with id", "not found (no active tab)", "no window with tab url matching"]) {
    assert.ok(markers_block.includes(marker), `the retry predicate must match ${marker}`);
  }
  assert.doesNotMatch(markers_block, /does not belong to multiprompt browser window/,
    "a genuine cross-pane tab error is not an instance mismatch");
});

test('tabs lists four exact-pane tabs after restart replaces Chrome windowId', async () => {
  const h = browserHarness();
  h.openWindow(1407088821);
  const before = await h.chrome.tabs.create({ windowId: 1407088821, url: 'https://before.test', active: true });
  h.api.rememberTarget(1407088821, before.id);
  await h.chrome.tabs.remove(before.id);
  h.openWindow(1813400106);
  const current = [];
  for (let i = 0; i < 4; i++) current.push(await h.chrome.tabs.create({ windowId: 1813400106, url: `https://after.test/${i}`, active: i === 3 }));
  h.openWindow(20);
  await h.chrome.tabs.create({ windowId: 20, url: 'https://foreign.test', active: true });
  const result = await h.api.dispatch({ method: 'tabs', windowId: 1813400106 });
  assert.deepEqual(Array.from(result.tabs, tab => tab.id), current.map(tab => tab.id));
  assert.equal(result.tabs.every(tab => tab.windowId === 1813400106), true);
  await assert.rejects(h.api.listTabs({ windowId: 1407088821 }), /not found \(no active tab\)/);
});
