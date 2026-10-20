const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

function eventSlot(listeners, name) {
  return { addListener(listener) { listeners[name] = listener; } };
}

function createHarness({
  bookmarkedUrls = [],
  protectedFocused = true,
  deferProtectedLoad = false,
  failOutsideCreate = false,
  themeExtensions = [],
  userAgent = "Mozilla/5.0 Chrome/130.0 Safari/537.36 Edg/130.0",
  savedTargets = {},
  scriptFrames = [{ frameId: 0, url: "https://page.example/" }],
  failedFrames = [],
} = {}) {
  let now = 1000;
  const tabs = new Map();
  const createdTabs = [];
  const updatedTabs = [];
  let nextTabId = 100;
  const listeners = {};
  const outsideWindows = [];
  const themeEnableCalls = [];
  const debuggerCommands = [];
  const scriptCalls = [];
  let saveCallback;
  const windows = new Map([[10, { id: 10, type: "normal" }]]);
  const portEvent = { addListener() {} };
  const port = { onMessage: portEvent, onDisconnect: portEvent, postMessage() {} };
  const noopEvent = (name) => eventSlot(listeners, name);
  const bookmarkSet = new Set(bookmarkedUrls.map((url) => new URL(url).href));
  let focusedWindowId = protectedFocused ? 10 : -1;
  const storageState = {
    zigshellProtectedWindows: [10],
    multipromptProtectedWindowMetaV1: {},
    multipromptRoutingAuditV1: [],
    multipromptZsbTargetTabsV1: savedTargets,
  };
  let releaseProtectedLoad;
  const protectedLoadGate = deferProtectedLoad ? new Promise((resolve) => {
    releaseProtectedLoad = () => resolve({
      zigshellProtectedWindows: [...storageState.zigshellProtectedWindows],
      multipromptProtectedWindowMetaV1: { ...storageState.multipromptProtectedWindowMetaV1 },
    });
  }) : null;

  const chrome = {
    action: { onClicked: noopEvent("action.onClicked") },
    alarms: { create() {}, onAlarm: noopEvent("alarms.onAlarm") },
    bookmarks: {
      search: async ({ url }) => bookmarkSet.has(new URL(url).href)
        ? [{ id: "bookmark-1", url: new URL(url).href }]
        : [],
    },
    commands: { onCommand: noopEvent("commands.onCommand") },
    contextMenus: {
      create() {},
      removeAll: async () => {},
      onClicked: noopEvent("contextMenus.onClicked"),
    },
    debugger: {
      attach: async (debuggee) => { debuggerCommands.push({ tabId: debuggee.tabId, method: "attach" }); },
      detach: async () => {},
      sendCommand: async (debuggee, method, params) => {
        debuggerCommands.push({ tabId: debuggee.tabId, method, params });
        if (method === "Runtime.evaluate") {
          const expression = params.expression;
          if (expression.includes("function getVisibleText(")) return { result: { value: { text: "selftest page", length: 13, url: tabs.get(debuggee.tabId).url } } };
          if (expression.includes("function locateSelectorForTrustedInput(")) return { result: { value: { x: 40, y: 25, text: "Target" } } };
          if (expression.includes("function evalInPage(")) return { result: { value: "typed value" } };
        }
        return {};
      },
      onDetach: noopEvent("debugger.onDetach"),
      onEvent: noopEvent("debugger.onEvent"),
    },
    runtime: {
      connectNative: () => port,
      getURL: (value) => value,
      lastError: null,
      onInstalled: noopEvent("runtime.onInstalled"),
      onMessage: noopEvent("runtime.onMessage"),
      onStartup: noopEvent("runtime.onStartup"),
    },
    scripting: {
      executeScript: async ({ target, func }) => {
        if (!func) return [];
        scriptCalls.push({ target, name: func.name });
        if (/^data:/i.test(tabs.get(target.tabId)?.url || "")) throw new Error("Cannot access contents of url data:text/html");
        const frames = target.allFrames ? scriptFrames : scriptFrames.filter((frame) =>
          (target.frameIds || [0]).includes(frame.frameId));
        if (frames.some((frame) => frame.url.startsWith("chrome-extension://"))) {
          throw new Error("Cannot access a chrome-extension:// URL of different extension");
        }
        if (frames.some((frame) => failedFrames.includes(frame.frameId))) throw new Error("Cannot access contents of url https://denied.example/");
        return frames.map((frame) => ({
          frameId: frame.frameId,
          result: func.name === "locateSelectorForTrustedInput"
            ? { x: 40, y: 25, text: "Target" }
            : func.name === "getFocusedEditableTarget"
              ? { editable: true, tag: "input" }
              : { url: frame.url, text: `frame ${frame.frameId}`, length: 7 },
        }));
      },
    },
    storage: {
      local: {
        get: async (keys) => {
          const requested = Array.isArray(keys) ? keys : [keys];
          if (protectedLoadGate && requested.includes("zigshellProtectedWindows")) return protectedLoadGate;
          if (requested.length === 1 && requested[0] === undefined) return { ...storageState };
          const result = {};
          for (const key of requested) {
            if (typeof key === "string" && Object.hasOwn(storageState, key)) result[key] = storageState[key];
          }
          return result;
        },
        remove: async (keys) => {
          for (const key of Array.isArray(keys) ? keys : [keys]) delete storageState[key];
        },
        set: async (values) => { Object.assign(storageState, values); },
      },
    },
    management: {
      getAll: async () => themeExtensions.map((item) => ({ ...item })),
      setEnabled: async (id, enabled) => {
        themeEnableCalls.push({ id, enabled });
        if (enabled) {
          for (const item of themeExtensions) {
            if (item.type === "theme") item.enabled = item.id === id;
          }
        } else {
          const item = themeExtensions.find((candidate) => candidate.id === id);
          if (item) item.enabled = false;
        }
      },
    },
    tabs: {
      create: async (options) => {
        createdTabs.push(options);
        const tab = { id: nextTabId++, windowId: options.windowId, url: options.url, active: options.active === true };
        tabs.set(tab.id, tab);
        return tab;
      },
      get: async (tabId) => {
        if (!tabs.has(tabId)) throw new Error(`missing tab ${tabId}`);
        return tabs.get(tabId);
      },
      move: async (tabId, options) => {
        const tab = tabs.get(tabId);
        if (!tab) throw new Error(`missing tab ${tabId}`);
        const moved = { ...tab, windowId: options.windowId };
        tabs.set(tabId, moved);
        return moved;
      },
      query: async (options) => [...tabs.values()].filter((tab) =>
        (!Number.isInteger(options?.windowId) || tab.windowId === options.windowId) &&
        (options?.active !== true || tab.active === true) &&
        (options?.lastFocusedWindow !== true || tab.windowId === focusedWindowId)),
      reload: async () => {},
      remove: async (tabId) => { tabs.delete(tabId); },
      sendMessage: async () => {},
      update: async (tabId, options) => {
        updatedTabs.push({ tabId, options });
        const current = tabs.get(tabId) || { id: tabId };
        const updated = { ...current, ...options };
        tabs.set(tabId, updated);
        return updated;
      },
      onActivated: noopEvent("tabs.onActivated"),
      onCreated: noopEvent("tabs.onCreated"),
      onRemoved: noopEvent("tabs.onRemoved"),
      onUpdated: noopEvent("tabs.onUpdated"),
    },
    webNavigation: {
      getAllFrames: async () => scriptFrames,
      onCommitted: noopEvent("webNavigation.onCommitted"),
      onCreatedNavigationTarget: noopEvent("webNavigation.onCreatedNavigationTarget"),
    },
    windows: {
      WINDOW_ID_NONE: -1,
      create: async (options) => {
        if (failOutsideCreate) throw new Error("outside window create failed");
        outsideWindows.push(options);
        if (Number.isInteger(options.tabId) && tabs.has(options.tabId)) {
          tabs.set(options.tabId, { ...tabs.get(options.tabId), windowId: 99 });
        }
        return { id: 99 };
      },
      get: async (windowId) => {
        if (!windows.has(windowId)) throw new Error(`No window with id: ${windowId}.`);
        return { ...windows.get(windowId), focused: focusedWindowId === windowId };
      },
      getAll: async (options) => [...windows.values()].filter((win) =>
        !options?.windowTypes || options.windowTypes.includes(win.type)),
      getLastFocused: async () => null,
      update: async () => ({}),
      onFocusChanged: noopEvent("windows.onFocusChanged"),
      onRemoved: noopEvent("windows.onRemoved"),
    },
  };

  class FakeDate extends Date {
    static now() { return now; }
  }

  const context = vm.createContext({
    URL,
    Promise,
    Date: FakeDate,
    chrome,
    navigator: { userAgent: userAgent },
    clearTimeout() {},
    console: { log() {}, warn() {}, error() {} },
    crypto: { randomUUID: () => "test-id" },
    setTimeout(callback, delay) {
      if (delay === 150) saveCallback = callback;
      return 1;
    },
  });
  const source = fs.readFileSync(process.env.ZSB_BRIDGE_JS || path.join(__dirname, "bridge.js"), "utf8");
  vm.runInContext(`${source}\n;globalThis.__routing = {
    handlePossibleExternalTab,
    handlePossibleExternalTabUpdate,
    handleCommittedNavigation,
    handleCreatedNavigationTarget,
    handleWebNotificationClick,
    browserDropGesture,
    protectWindow,
    getRoutingAudit,
    loadProtectedWindows,
    protectedWindowIdsSnapshot: () => [...protectedWindowIds].sort((a, b) => a - b),
    navigate,
    applyBrowserTheme,
    clickAction,
    typeAction,
    keyAction,
    insertAction,
    dispatch,
    resolveWindow,
    listTabs,
    getTargetTab,
    textAction,
    runInAllFrames,
    rememberZsbTargetTab,
    targetTabsSnapshot: () => Object.fromEntries(zsbTargetTabsByWindow),
  };`, context);
  if (!deferProtectedLoad) {
    vm.runInContext("protectedWindowIds = new Set([10]); protectedWindowIdsLoaded = true; protectedWindowIdsLoadPromise = Promise.resolve();", context);
  }

  return {
    api: context.__routing,
    createdTabs,
    debuggerCommands,
    scriptCalls,
    listeners,
    outsideWindows,
    themeEnableCalls,
    storageState,
    updatedTabs,
    setTab(tab) {
      tabs.set(tab.id, tab);
      if (!windows.has(tab.windowId)) windows.set(tab.windowId, { id: tab.windowId, type: "normal" });
    },
    setWindow(id, type = "normal") { windows.set(id, { id, type }); },
    removeTab(id) {
      tabs.delete(id);
      listeners["tabs.onRemoved"]?.(id);
    },
    removeWindow(id) {
      windows.delete(id);
      for (const [tabId, tab] of tabs) if (tab.windowId === id) tabs.delete(tabId);
      listeners["windows.onRemoved"]?.(id);
    },
    flushSave() { saveCallback?.(); },
    reloadRegistry() {
      vm.runInContext("protectedWindowIds = new Set(); protectedWindowMeta.clear(); zsbTargetTabsByWindow.clear(); agentNavigateTabs.clear(); protectedWindowIdsLoadPromise = undefined;", context);
    },
    getTab(tabId) { return tabs.get(tabId); },
    async focusWindow(windowId) {
      focusedWindowId = windowId;
      listeners["windows.onFocusChanged"]?.(windowId);
      await Promise.resolve();
      await Promise.resolve();
    },
    releaseProtectedLoad,
    forgetEscapeWindowMemory() { vm.runInContext("externalEscapeWindowId = null", context); },
    advance(ms) { now += ms; },
  };
}

test("browser theme sync activates the exact bundled palette and is idempotent", async () => {
  const themes = [
    { id: "third-party", name: "Into The Black Hole", type: "theme", enabled: true },
    { id: "light-theme", name: "multiprompt browser theme - Light", type: "theme", enabled: false },
  ];
  const harness = createHarness({ themeExtensions: themes });

  const first = await harness.api.applyBrowserTheme({ theme: "LIGHT" });
  assert.equal(first.theme, "light");
  assert.equal(first.extensionId, "light-theme");
  assert.equal(first.applied, true);
  assert.deepEqual(harness.themeEnableCalls, [{ id: "light-theme", enabled: true }]);
  assert.equal(themes[0].enabled, false);
  assert.equal(themes[1].enabled, true);

  const second = await harness.api.applyBrowserTheme({ theme: "light" });
  assert.equal(second.applied, false);
  assert.equal(harness.themeEnableCalls.length, 1);
});

test("browser theme sync rejects unknown palettes and restarts for an unloaded palette", async () => {
  const harness = createHarness();
  await assert.rejects(
    harness.api.applyBrowserTheme({ theme: "sepia" }),
    /unsupported multiprompt browser theme/,
  );
  const missing = await harness.api.applyBrowserTheme({ theme: "dark" });
  assert.equal(missing.theme, "dark");
  assert.equal(missing.restartRequired, true);
  assert.equal(missing.restartScheduled, true);
  assert.equal(harness.themeEnableCalls.length, 0);
});

test("issue: plain navigate reuses the new session target, not the selected or foreign tab", async () => {
  for (const protectedFocused of [false, true]) {
    const h = createHarness({ protectedFocused });
    h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
    h.setTab({ id: 2, windowId: 20, active: true, url: "https://foreign.example/" });
    const first = (await h.api.dispatch({ method: "navigate", windowId: 10, url: "https://first.example/", newTab: true })).tab;
    for (const [index, flag] of [undefined, false, undefined].entries()) {
      const url = `https://next.example/${index}`;
      const result = (await h.api.dispatch({ method: "navigate", windowId: 10, url, newTab: flag })).tab;
      assert.equal(result.id, first.id);
      assert.equal(result.url, url);
      assert.equal(result.active, false);
      assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, first.id);
    }
    assert.equal(h.createdTabs.length, 1);
    assert.equal(h.getTab(1).url, "https://user.example/");
    assert.equal(h.getTab(2).url, "https://foreign.example/");
    const second = (await h.api.dispatch({ method: "navigate", windowId: 10, url: "https://second.example/", newTab: true })).tab;
    assert.notEqual(second.id, first.id);
    assert.equal(h.createdTabs.length, 2);
    assert.deepEqual(h.outsideWindows, []);
  }
});

test("issue: missing, closed, moved, or unproven targets create a fresh background tab", async () => {
  for (const state of ["none", "closed", "moved", "user", "reload"]) {
    const h = createHarness({ savedTargets: state === "user" ? { 10: 2 } : {} });
    h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
    if (state === "user") h.setTab({ id: 2, windowId: 10, active: false, url: "https://saved-user.example/" });
    if (["closed", "moved", "reload"].includes(state)) {
      const target = (await h.api.navigate({ windowId: 10, url: "https://agent.example/" })).tab;
      if (state === "closed") {
        h.removeTab(target.id);
      }
      if (state === "moved") h.setTab({ ...h.getTab(target.id), windowId: 20 });
      if (state === "reload") { h.flushSave(); h.reloadRegistry(); }
    }
    const count = h.createdTabs.length;
    const result = (await h.api.navigate({ windowId: 10, url: "https://replacement.example/" })).tab;
    assert.equal(h.createdTabs.length, count + 1, state);
    assert.equal(result.active, false);
    assert.equal(result.windowId, 10);
    assert.equal(h.updatedTabs.length, 0, state);
    assert.equal(h.getTab(1).url, "https://user.example/");
    if (state === "user") assert.equal(h.getTab(2).url, "https://saved-user.example/");
  }
});

test("issue: user activation, including activate-away, permanently retires reuse authority", async () => {
  for (const activateAway of [false, true]) {
    const h = createHarness();
    h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
    const first = (await h.api.navigate({ windowId: 10, url: "https://agent.example/", newTab: true })).tab;
    h.setTab({ ...h.getTab(first.id), active: true });
    await h.listeners["tabs.onActivated"]({ windowId: 10, tabId: first.id });
    if (activateAway) {
      h.setTab({ ...h.getTab(first.id), active: false });
      await h.listeners["tabs.onActivated"]({ windowId: 10, tabId: 1 });
      h.api.rememberZsbTargetTab(10, first.id);
    }
    const next = (await h.api.navigate({ windowId: 10, url: "https://next.example/" })).tab;
    assert.notEqual(next.id, first.id);
    assert.equal(h.createdTabs.length, 2);
    assert.equal(h.getTab(first.id).url, "https://agent.example/");
    assert.equal(h.updatedTabs.length, 0);
  }
});

test("issue: an active target is never reused even if its activation event was missed", async () => {
  const h = createHarness();
  const first = (await h.api.navigate({ windowId: 10, url: "https://agent.example/", newTab: true })).tab;
  h.setTab({ ...h.getTab(first.id), active: true });
  const next = (await h.api.navigate({ windowId: 10, url: "https://next.example/" })).tab;
  assert.notEqual(next.id, first.id);
  assert.equal(h.getTab(first.id).url, "https://agent.example/");
});

test("issue: clicked or user-navigated targets are not overwritten", async () => {
  for (const takeover of ["click", "typed", "link", "reload", "back"]) {
    const h = createHarness();
    h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
    const first = (await h.api.navigate({ windowId: 10, url: "https://agent.example/", newTab: true })).tab;
    if (takeover === "click") {
      h.setTab({ ...h.getTab(first.id), active: true });
      await h.listeners["tabs.onActivated"]({ windowId: 10, tabId: first.id });
    } else {
      h.setTab({ ...h.getTab(first.id), url: "https://user-navigation.example/" });
      h.listeners["webNavigation.onCommitted"]({ frameId: 0, tabId: first.id, url: h.getTab(first.id).url,
        transitionType: takeover === "back" ? "typed" : takeover,
        transitionQualifiers: takeover === "typed" ? ["from_address_bar"] : takeover === "back" ? ["forward_back"] : [] });
    }
    const preservedUrl = h.getTab(first.id).url;
    const next = (await h.api.navigate({ windowId: 10, url: "https://next.example/" })).tab;
    assert.notEqual(next.id, first.id, takeover);
    assert.equal(h.getTab(first.id).url, preservedUrl);
    assert.equal(h.createdTabs.length, 2);
    assert.equal(h.updatedTabs.length, 0);
  }
});

test("issue: own link/typed commits, late commits and server redirects retain reuse authority", async () => {
  for (const transitionType of ["typed", "link"]) {
    const h = createHarness();
    h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
    const first = (await h.api.navigate({ windowId: 10, url: "https://agent.example/", newTab: true })).tab;
    const second = (await h.api.navigate({ windowId: 10, url: "https://redirect.example/" })).tab;
    h.listeners["webNavigation.onCommitted"]({ frameId: 0, tabId: first.id, url: first.url, transitionType });
    h.listeners["webNavigation.onCommitted"]({ frameId: 0, tabId: first.id, url: "https://final.example/", transitionType, transitionQualifiers: ["server_redirect"] });
    h.setTab({ ...h.getTab(first.id), url: "https://final.example/" });
    h.listeners["webNavigation.onCommitted"]({ frameId: 1, tabId: first.id, url: "https://frame.example/", transitionType: "link" });
    const third = (await h.api.navigate({ windowId: 10, url: "https://last.example/" })).tab;
    assert.equal(second.id, first.id);
    assert.equal(third.id, first.id);
    assert.equal(h.createdTabs.length, 1);
  }
});

test("issue: explicit user navigation to a still-pending agent URL retires reuse", async () => {
  for (const transitionType of ["typed", "reload", "auto_bookmark"]) {
    const h = createHarness();
    h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
    const first = (await h.api.navigate({ windowId: 10, url: "https://agent.example/", newTab: true })).tab;
    h.listeners["webNavigation.onCommitted"]({ frameId: 0, tabId: first.id, url: first.url, transitionType,
      transitionQualifiers: transitionType === "typed" ? ["from_address_bar"] : [] });
    const next = (await h.api.navigate({ windowId: 10, url: "https://next.example/" })).tab;
    assert.notEqual(next.id, first.id);
    assert.equal(h.getTab(first.id).url, first.url);
    assert.equal(h.createdTabs.length, 2);
  }
});

test("issue: retargeting a user tab gives no agent provenance, and explicit user navigation creates", async () => {
  const h = createHarness();
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
  h.setTab({ id: 2, windowId: 10, active: false, url: "https://other-user.example/" });
  await h.api.dispatch({ method: "activate", windowId: 10, tabId: 2, targetOnly: true });
  const first = (await h.api.navigate({ windowId: 10, url: "https://agent.example/", tabId: 2 })).tab;
  assert.equal(h.getTab(2).url, "https://other-user.example/");
  const user = (await h.api.navigate({ windowId: 10, url: "https://selected.example/", activate: true })).tab;
  assert.notEqual(user.id, first.id);
  assert.equal(user.active, true);
  const next = (await h.api.navigate({ windowId: 10, url: "https://next.example/" })).tab;
  assert.notEqual(next.id, user.id);
  assert.equal(h.createdTabs.length, 3);
});

test("issue: --new-tab always creates, including beside the active launch beacon", async () => {
  const h = createHarness();
  h.setTab({ id: 1, windowId: 10, active: true, url: "data:text/html,<title>ZSPANE1-2</title>" });
  const first = (await h.api.navigate({ windowId: 10, url: "https://first.example/", newTab: true })).tab;
  const second = (await h.api.navigate({ windowId: 10, url: "https://second.example/", newTab: true })).tab;
  assert.notEqual(first.id, second.id);
  assert.equal(h.createdTabs.length, 2);
  assert.equal(h.updatedTabs.length, 0);
  assert.equal(h.getTab(1).url, "data:text/html,<title>ZSPANE1-2</title>");
});

test("issue: reuse authority cannot cross a pane registration to another session", async () => {
  const h = createHarness();
  const first = (await h.api.navigate({ windowId: 10, url: "https://first.example/" })).tab;
  await h.api.protectWindow({ windowId: 10, shellId: 101, ownerPid: 1000 });
  const second = (await h.api.navigate({ windowId: 10, url: "https://second.example/" })).tab;
  assert.notEqual(first.id, second.id, "a newly registered owner must not inherit an unproven session's tab");
  await h.api.protectWindow({ windowId: 10, shellId: 101, ownerPid: 1000 });
  const third = (await h.api.navigate({ windowId: 10, url: "https://third.example/" })).tab;
  assert.equal(second.id, third.id, "same-owner protection refresh retains provenance");
});

test("an explicit user navigation activates its fresh tab before browser focus", async () => {
  const harness = createHarness({ protectedFocused: false });
  harness.setTab({ id: 1, windowId: 10, url: "https://keep.example/", active: true });

  await harness.api.navigate({
    windowId: 10,
    url: "https://selected.example/",
    newTab: true,
    activate: true,
  });

  assert.equal(harness.createdTabs.length, 1);
  assert.equal(harness.createdTabs[0].url, "https://selected.example/");
  assert.equal(harness.createdTabs[0].active, true);
});

test("an inside button keeps its screencast target in the protected multiprompt pane", async () => {
  const harness = createHarness({ protectedFocused: false });
  const source = { id: 1, windowId: 10, url: "https://inside.example/" };
  const target = { id: 2, windowId: 10, url: "https://screencast2.com/F5wlI.png" };
  harness.setTab(source);
  harness.setTab(target);

  await harness.api.handlePossibleExternalTab(target);
  await harness.api.handleCreatedNavigationTarget({ tabId: target.id, sourceTabId: source.id });
  harness.advance(1201);
  await harness.api.handlePossibleExternalTabUpdate(target.id, { url: target.url }, target);

  assert.equal(harness.outsideWindows.length, 0);
  assert.notEqual(harness.getTab(target.id).muted, true,
    "an internal protected-profile tab must never be muted");
});

test("the shielded profile keeps every protected-window tab inside", async () => {
  for (const protectedFocused of [false, true]) {
    const harness = createHarness({ protectedFocused });
    const target = {
      id: 2,
      windowId: 10,
      openerTabId: 999,
      url: "https://deployment.example/",
      mutedInfo: { muted: false },
    };
    harness.setTab(target);

    await harness.api.handlePossibleExternalTab(target);
    await harness.api.handleCommittedNavigation({
      frameId: 0,
      tabId: target.id,
      url: "https://deployment.example/",
      transitionType: "link",
      transitionQualifiers: ["server_redirect"],
    });
    harness.advance(3000);
    await harness.api.handlePossibleExternalTabUpdate(target.id, { url: target.url }, target);

    assert.equal(harness.outsideWindows.length, 0);
    assert.equal(harness.getTab(target.id).windowId, 10);
    assert.notEqual(harness.getTab(target.id).muted, true);
    const audit = await harness.api.getRoutingAudit({ limit: 20 });
    const authorization = audit.entries.find((entry) =>
      entry.event === "tab_authorized" && entry.tabId === target.id);
    assert.equal(authorization?.reason, "isolated_profile_navigation");
    assert.equal(audit.entries.some((entry) =>
      entry.event === "tab_quarantined" && entry.tabId === target.id), false);
  }
});

test("keyboard typing emits one ordered key pair per Unicode character", async () => {
  const harness = createHarness();
  harness.setTab({ id: 1, windowId: 10, url: "https://app.example/", active: true });
  const result = await harness.api.typeAction({ windowId: 10, text: "Ab_9é🙂", keys: true });
  assert.equal(result.mode, "keys");
  assert.equal(harness.debuggerCommands.some(c => c.method === "Input.insertText"), false);
  const events = harness.debuggerCommands.filter(c => c.method === "Input.dispatchKeyEvent").map(c => c.params);
  assert.deepEqual(events.map(e => e.type), Array.from({ length: 6 }, () => ["keyDown", "keyUp"]).flat());
  assert.equal(events.filter(e => e.type === "keyDown").map(e => e.text).join(""), "Ab_9é🙂");
  assert.equal(events[4].code, "Minus");
  assert.equal(events[4].modifiers, 8);
  assert.ok(events.filter(e => e.type === "keyUp").every(e => e.text === undefined));
});

test("trusted click, type, and key operations reach the targeted tab through CDP", async () => {
  const harness = createHarness();
  harness.setTab({ id: 1, windowId: 10, url: "https://app.example/", active: true });

  const clicked = await harness.api.clickAction({ windowId: 10, selector: "#save" });
  assert.equal(clicked.trusted, true);
  assert.deepEqual(
    harness.debuggerCommands.filter((item) => item.method === "Input.dispatchMouseEvent").map((item) => item.params.type),
    ["mouseMoved", "mousePressed", "mouseReleased"],
  );

  const typed = await harness.api.typeAction({ windowId: 10, text: "hello" });
  assert.equal(typed.trusted, true);
  assert.ok(harness.debuggerCommands.some((item) =>
    item.method === "Input.insertText" && item.params.text === "hello"));

  await harness.api.keyAction({ windowId: 10, combo: "Ctrl+K" });
  assert.deepEqual(
    harness.debuggerCommands.filter((item) => item.method === "Input.dispatchKeyEvent").slice(-2).map((item) => item.params.type),
    ["rawKeyDown", "keyUp"],
  );
});

test("trusted input into a background tab turns on focus emulation before any Input command", async () => {
  const harness = createHarness();
  harness.setTab({ id: 1, windowId: 10, url: "https://app.example/", active: false });
  const actions = [
    () => harness.api.clickAction({ windowId: 10, selector: "#save" }),
    () => harness.api.typeAction({ windowId: 10, selector: "#name", text: "hello" }),
    () => harness.api.insertAction({ windowId: 10, text: "hello" }),
    () => harness.api.keyAction({ windowId: 10, combo: "Enter" }),
  ];
  for (const action of actions) {
    harness.debuggerCommands.length = 0;
    await action();
    const sessions = [];
    for (const command of harness.debuggerCommands) {
      if (command.method === "attach") sessions.push([]);
      else sessions.at(-1)?.push(command);
    }
    const inputSessions = sessions.filter((session) => session.some((command) => command.method.startsWith("Input.")));
    assert.ok(inputSessions.length > 0);
    for (const session of inputSessions) {
      assert.equal(session[0].method, "Emulation.setFocusEmulationEnabled");
      assert.equal(session[0].params.enabled, true);
    }
  }
});

test("concurrent pane registrations cannot be overwritten by the initial storage load", async () => {
  const harness = createHarness({ deferProtectedLoad: true });
  harness.setWindow(11);
  harness.setWindow(12);

  const first = harness.api.protectWindow({ windowId: 11, shellId: 101 });
  const second = harness.api.protectWindow({ windowId: 12, shellId: 102 });
  await Promise.resolve();
  harness.releaseProtectedLoad();
  await Promise.all([first, second]);

  assert.deepEqual([...harness.api.protectedWindowIdsSnapshot()], [10, 11, 12]);
  const audit = await harness.api.getRoutingAudit({ limit: 20 });
  const protectedEvents = audit.entries.filter((entry) => entry.event === "window_protected");
  assert.deepEqual(protectedEvents.map((entry) => entry.shellId).sort((a, b) => a - b), [101, 102]);
});

test("runtime routing has no update or commit listener that can eject a shielded tab", () => {
  const source = fs.readFileSync(path.join(__dirname, "bridge.js"), "utf8");
  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "manifest.json"), "utf8"));
  assert.match(source, /const ISOLATED_PROFILE_CONTAINS_ALL_TABS = true/);
  assert.doesNotMatch(source, /chrome\.tabs\.onUpdated\.addListener/);
  const observer = source.slice(source.indexOf("chrome.webNavigation.onCommitted.addListener"), source.indexOf("chrome.tabs.onRemoved.addListener"));
  assert.match(observer, /agentNavigateTabs\.delete/);
  assert.doesNotMatch(observer, /deflect|quarantine|tabs\.(move|remove|update)|windows\.(create|update)/);
  assert.doesNotMatch(source, /chrome\.webNavigation\.onCreatedNavigationTarget\.addListener/);
  assert.equal(manifest.permissions.includes("webNavigation"), true,
    "frame traversal and the non-ejecting takeover observer need webNavigation");
  assert.equal(manifest.permissions.includes("bookmarks"), false);
});

test("native pane registration carries shell identity and exposes the routing audit CLI", () => {
  const mainSource = require('../tools/app-source').readAppSource();
  const bridgeSource = fs.readFileSync(path.join(__dirname, "..", "src", "bridge.zig"), "utf8");

  assert.match(mainSource, /protect-window --shell-id \{d\}/,
    "each adopted pane must register the owning multiprompt shell in the audit trail");
  assert.match(bridgeSource, /std\.mem\.eql\(u8, command, "routing-audit"\)/,
    "the persistent routing history must be retrievable without opening Edge DevTools");
  assert.match(bridgeSource, /sendRequiredBrowserRequest\(allocator, "protectWindow", fields\.items, 8\)/,
    "pane protection must retry until the extension acknowledges it");
  assert.match(mainSource, /GetEnvironmentVariableA\("LOCALAPPDATA"[\s\S]{0,900}?\\\\EdgeUserData/,
    "the pane must retain the dedicated process-level routing boundary");
});

test("ordinary links, popups, bookmarks, and redirects never leave the shielded profile", async () => {
  const samples = [
    { url: "https://inside.example/plain", openerTabId: 1 },
    { url: "https://inside.example/bookmark" },
    { url: "https://deployment.example/" },
    { url: "https://inside.example/popup", openerTabId: 1 },
  ];
  for (const [index, sample] of samples.entries()) {
    const harness = createHarness({ protectedFocused: index % 2 === 0 });
    const target = { id: index + 2, windowId: 10, mutedInfo: { muted: false }, ...sample };
    harness.setTab(target);

    await harness.api.handlePossibleExternalTab(target);
    await harness.api.handleCommittedNavigation({
      frameId: 0,
      tabId: target.id,
      url: target.url,
      transitionType: "link",
      transitionQualifiers: index === 2 ? ["server_redirect"] : [],
    });
    harness.advance(5000);
    await harness.api.handlePossibleExternalTabUpdate(target.id, { url: target.url }, target);

    assert.equal(harness.outsideWindows.length, 0);
    assert.equal(harness.getTab(target.id).windowId, 10);
    assert.notEqual(harness.getTab(target.id).muted, true);
  }
});

test("physical bookmark-drop observations cannot move a shielded tab", async () => {
  const harness = createHarness({ protectedFocused: false });
  const target = { id: 2, windowId: 10, url: "https://deployment.example/" };
  harness.setTab(target);
  await harness.api.handlePossibleExternalTab(target);
  await harness.api.browserDropGesture({ windowId: 10 });
  harness.advance(5000);
  await harness.api.handlePossibleExternalTabUpdate(target.id, { url: target.url }, target);

  assert.equal(harness.outsideWindows.length, 0);
  assert.equal(harness.getTab(target.id).windowId, 10);
});

test("a multiprompt-created tab is authorized without quarantine", async () => {
  const harness = createHarness({ protectedFocused: true });
  await harness.api.navigate({
    windowId: 10,
    url: "https://inside.example/agent",
    newTab: true,
  });
  const target = harness.getTab(100);

  await harness.api.handlePossibleExternalTab(target);

  assert.equal(harness.outsideWindows.length, 0);
  assert.equal(harness.updatedTabs.length, 0);
  const audit = await harness.api.getRoutingAudit({ limit: 20 });
  const authorization = audit.entries.find((entry) =>
    entry.event === "tab_authorized" && entry.tabId === target.id);
  assert.equal(authorization?.reason, "multiprompt_navigation");
  assert.equal(audit.entries.some((entry) =>
    entry.event === "tab_quarantined" && entry.tabId === target.id), false);
});

test("a blank in-pane new tab can later accept a typed URL", async () => {
  const harness = createHarness({ protectedFocused: false });
  const target = { id: 2, windowId: 10, url: "edge://newtab/" };
  harness.setTab(target);

  await harness.api.handlePossibleExternalTab(target);
  harness.advance(1201);
  await harness.api.handlePossibleExternalTabUpdate(target.id, { url: target.url }, target);
  target.url = "https://typed-later.example/";
  await harness.api.handlePossibleExternalTabUpdate(target.id, { url: target.url }, target);

  assert.equal(harness.outsideWindows.length, 0);
});

test("a legacy Firebase notification target stays in the exact protected window", async () => {
  const harness = createHarness({ protectedFocused: true });
  const sender = { id: 1, windowId: 10, url: "https://app.example.com/demo" };
  harness.setTab(sender);

  const result = await harness.api.handleWebNotificationClick({
    url: "https://app.example.com/demo",
  }, { tab: sender });

  assert.equal(result.handled, true);
  assert.equal(result.windowId, 10);
  assert.equal(harness.outsideWindows.length, 0);
  assert.equal(harness.createdTabs.length, 1);
  assert.equal(harness.createdTabs[0].windowId, 10);
  assert.equal(harness.createdTabs[0].active, true);
});

test("a protected page cannot relay a cross-origin notification target", async () => {
  const harness = createHarness({ protectedFocused: true });
  const sender = { id: 1, windowId: 10, url: "https://app.example.com/demo" };
  harness.setTab(sender);

  const result = await harness.api.handleWebNotificationClick({
    url: "https://outside.example/steal-focus",
  }, { tab: sender });

  assert.equal(result.handled, false);
  assert.equal(result.reason, "cross_origin_url");
  assert.equal(harness.outsideWindows.length, 0);
});

test("the protected-pane content guard relays Firebase notification clicks", () => {
  const listeners = {};
  const relayed = [];
  const chrome = {
    runtime: {
      lastError: null,
      onMessage: { addListener(listener) { listeners.runtime = listener; } },
      sendMessage(message, callback) {
        if (message?.type === "multiprompt:isProtectedWindow") {
          callback?.({ protected: true });
          return;
        }
        relayed.push(message);
        callback?.({ ok: true });
      },
    },
  };
  const navigator = {
    serviceWorker: {
      addEventListener(name, listener) { listeners[`serviceWorker.${name}`] = listener; },
    },
  };
  const window = {
    location: {
      href: "https://app.example.com/demo",
      origin: "https://app.example.com",
      assign() {},
    },
    addEventListener(name, listener) { listeners[`window.${name}`] = listener; },
    postMessage(message, origin) {
      listeners["window.message"]?.({ data: message, origin, source: window });
    },
    open() {},
  };
  const context = vm.createContext({
    URL,
    chrome,
    console: { log() {}, warn() {}, error() {} },
    globalThis: null,
    HTMLAnchorElement: class HTMLAnchorElement {},
    navigator,
    window,
  });
  context.globalThis = context;
  const guardSource = fs.readFileSync(path.join(__dirname, "pane-click-guard.js"), "utf8");
  const mainSource = fs.readFileSync(path.join(__dirname, "notification-click-main.js"), "utf8");
  vm.runInContext(guardSource, context);
  vm.runInContext(mainSource, context);

  listeners["serviceWorker.message"]({
    data: {
      isFirebaseMessaging: true,
      messageType: "notification-clicked",
      fcmOptions: { link: "https://app.example.com/demo" },
    },
  });

  assert.equal(relayed.length, 1);
  assert.equal(relayed[0].type, "multiprompt:webNotificationClick");
  assert.equal(relayed[0].url, "https://app.example.com/demo");
});

test("a notification click waits for protected-window lookup after worker wake", () => {
  const listeners = {};
  const relayed = [];
  let protectionReply;
  const chrome = {
    runtime: {
      lastError: null,
      onMessage: { addListener(listener) { listeners.runtime = listener; } },
      sendMessage(message, callback) {
        if (message?.type === "multiprompt:isProtectedWindow") {
          protectionReply = callback;
          return;
        }
        relayed.push(message);
        callback?.({ ok: true });
      },
    },
  };
  const navigator = {
    serviceWorker: {
      addEventListener(name, listener) { listeners[`serviceWorker.${name}`] = listener; },
    },
  };
  const window = {
    location: {
      href: "https://app.example.com/demo",
      origin: "https://app.example.com",
      assign() {},
    },
    addEventListener(name, listener) { listeners[`window.${name}`] = listener; },
    postMessage(message, origin) {
      listeners["window.message"]?.({ data: message, origin, source: window });
    },
    open() {},
  };
  const context = vm.createContext({
    URL,
    chrome,
    console: { log() {}, warn() {}, error() {} },
    globalThis: null,
    HTMLAnchorElement: class HTMLAnchorElement {},
    navigator,
    window,
  });
  context.globalThis = context;
  vm.runInContext(fs.readFileSync(path.join(__dirname, "pane-click-guard.js"), "utf8"), context);
  vm.runInContext(fs.readFileSync(path.join(__dirname, "notification-click-main.js"), "utf8"), context);

  listeners["serviceWorker.message"]({
    data: {
      isFirebaseMessaging: true,
      messageType: "notification-clicked",
      fcmOptions: { link: "https://app.example.com/demo" },
    },
  });

  assert.equal(relayed.length, 0);
  protectionReply({ protected: true });
  assert.equal(relayed.length, 1);
  assert.equal(relayed[0].type, "multiprompt:webNotificationClick");
  assert.equal(relayed[0].url, "https://app.example.com/demo");
});

test("issue: a focused Facebook popup never replaces the session's pane", async () => {
  const h = createHarness();
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://facebook.com/login" });
  await h.api.protectWindow({ windowId: 10, shellId: 101 });
  h.setTab({ id: 2, windowId: 20, active: true, url: "https://facebook.com/login" });
  h.setWindow(20, "popup");
  await h.focusWindow(20);
  assert.equal((await h.api.resolveWindow({ shellId: 101, focused: true })).windowId, 10);
  assert.equal((await h.api.resolveWindow({ shellId: 101, match: "facebook.com" })).windowId, 10);
  await assert.rejects(h.api.resolveWindow({ focused: true }), /no focused pane window/);
  await assert.rejects(h.api.protectWindow({ windowId: 20, shellId: 101 }), /not found \(no active tab\)/);
  await assert.rejects(h.api.dispatch({ method: "navigate", windowId: 20, url: "https://new.example/" }), /not found \(no active tab\)/);
  assert.equal(h.createdTabs.length, 0);
  assert.equal((await h.api.listTabs({ windowId: 10 })).tabs[0].id, 1);
});

test("issue: window resolution rejects other sessions and ambiguous URL matches", async () => {
  const h = createHarness();
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://shared.example/" });
  h.setTab({ id: 2, windowId: 11, active: true, url: "https://shared.example/" });
  await h.api.protectWindow({ windowId: 10, shellId: 101 });
  await h.api.protectWindow({ windowId: 11, shellId: 102 });
  await h.focusWindow(11);
  assert.equal((await h.api.resolveWindow({ shellId: 102, match: "shared.example" })).windowId, 11);
  await assert.rejects(h.api.resolveWindow({ match: "shared.example" }), /ambiguous/);
  await assert.rejects(h.api.resolveWindow({ shellId: 103, match: "shared.example" }), /no window with tab url matching/);
  await assert.rejects(h.api.protectWindow({ windowId: 10, shellId: 102 }), /already belongs/);
});

test("issue: a recreated normal pane resolves by its exact beacon, not popup focus", async () => {
  const h = createHarness();
  const nonce = "ZSPANE14-6183294";
  h.setTab({ id: 1, windowId: 10, active: true, url: `data:text/html,<title>${nonce}</title>` });
  await h.api.protectWindow({ windowId: 10, shellId: 101 });
  h.removeWindow(10);
  h.setTab({ id: 2, windowId: 30, active: false, url: `data:text/html,<title>${nonce}</title>` });
  h.setTab({ id: 3, windowId: 30, active: true, url: "https://secondary.example/" });
  h.setTab({ id: 4, windowId: 20, active: true, url: "https://facebook.com/login" });
  h.setWindow(20, "popup");
  await h.focusWindow(20);
  await assert.rejects(h.api.listTabs({ windowId: 10 }), /not found \(no active tab\)/);
  const fresh = await h.api.resolveWindow({ shellId: 101, match: nonce });
  assert.equal(fresh.windowId, 30);
  await h.api.protectWindow({ windowId: fresh.windowId, shellId: 101 });
  assert.equal((await h.api.getTargetTab({ windowId: 30 })).id, 3);
  const opened = await h.api.dispatch({ method: "navigate", windowId: fresh.windowId, url: "https://opened.example/" });
  assert.equal(opened.tab.windowId, 30);
  assert.equal((await h.api.listTabs({ windowId: 30 })).tabs.find((tab) => tab.target).id, opened.tab.id);
  assert.deepEqual(h.outsideWindows, []);
});

test("issue: foreign extension tabs cannot become default targets or receive CDP input", async () => {
  const h = createHarness();
  h.setTab({ id: 1, windowId: 10, active: false, url: "https://secondary.example/" });
  h.setTab({ id: 2, windowId: 10, active: true, url: "chrome-extension://onepassword/popup.html" });
  await h.api.protectWindow({ windowId: 10, shellId: 101 });
  h.api.rememberZsbTargetTab(10, 1);
  await h.listeners["tabs.onActivated"]({ windowId: 10, tabId: 2 });
  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, 1);
  assert.equal((await h.api.listTabs({ windowId: 10 })).tabs.find((tab) => tab.target).id, 1);
  await h.api.keyAction({ windowId: 10, combo: "Enter" });
  assert.ok(h.debuggerCommands.every((command) => command.tabId === 1));
  await assert.rejects(h.api.getTargetTab({ windowId: 10, tabId: 2 }), /extension tab/);
});

test("issue: background target survives worker registry reload and stays window-scoped", async () => {
  const h = createHarness({ savedTargets: { 10: 2, 11: 3 } });
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
  h.setTab({ id: 2, windowId: 10, active: false, url: "https://agent.example/" });
  h.setTab({ id: 3, windowId: 12, active: true, url: "https://other.example/" });
  h.reloadRegistry();
  await h.api.loadProtectedWindows();
  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, 2);
  h.setTab({ id: 2, windowId: 12, active: false, url: "https://agent.example/" });
  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, 1, "a remembered target moved out of the pane must not be followed");
  await assert.rejects(h.api.getTargetTab({ windowId: 11 }), /not found \(no active tab\)/);
});

test("issue: reads skip 1Password frames while retaining cross-origin page frames", async () => {
  const h = createHarness({ scriptFrames: [
    { frameId: 0, url: "https://secondary.example/" },
    { frameId: 1, url: "chrome-extension://onepassword/frame.html" },
    { frameId: 2, url: "https://cross-origin.example/" },
  ] });
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://secondary.example/" });
  const text = await h.api.textAction({ windowId: 10 });
  assert.equal(text.text, "frame 0\n\nframe 2");
  assert.deepEqual(Array.from(text.frames, (frame) => frame.frameId), [0, 2]);
  assert.ok(h.scriptCalls.every((call) => !call.target.allFrames && !call.target.frameIds?.includes(1)));
});

test("issue: one inaccessible subframe does not abort a page read, but top-frame failure does", async () => {
  const frames = [
    { frameId: 0, url: "https://secondary.example/" },
    { frameId: 2, url: "https://denied.example/" },
    { frameId: 3, url: "https://cross-origin.example/" },
  ];
  const h = createHarness({ scriptFrames: frames, failedFrames: [2] });
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://secondary.example/" });
  assert.equal((await h.api.textAction({ windowId: 10 })).text, "frame 0\n\nframe 3");
  const broken = createHarness({ scriptFrames: frames, failedFrames: [0] });
  broken.setTab({ id: 1, windowId: 10, active: true, url: "https://secondary.example/" });
  assert.equal((await broken.api.textAction({ windowId: 10 })).error, "page_error");
});

test("issue: navigation persists its target and new explicit bindings retire stale shell ownership", async () => {
  const h = createHarness({ protectedFocused: false });
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://user.example/" });
  await h.api.protectWindow({ windowId: 10, shellId: 101 });
  const opened = (await h.api.navigate({ windowId: 10, url: "https://agent.example/" })).tab;
  h.flushSave();
  assert.equal(h.storageState.multipromptZsbTargetTabsV1[10], opened.id);
  h.reloadRegistry();
  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, opened.id);
  const nonce = "ZSPANE15-6183295";
  h.setTab({ id: 3, windowId: 30, active: true, url: `data:text/html,<title>${nonce}</title>` });
  assert.equal((await h.api.resolveWindow({ shellId: 101, match: nonce })).windowId, 30,
    "exact adoption identity outranks the old registered window during teardown");
  await h.api.protectWindow({ windowId: 30, shellId: 101 });
  assert.equal((await h.api.resolveWindow({ shellId: 101 })).windowId, 30);
  assert.ok(h.api.protectedWindowIdsSnapshot().includes(10), "ownership replacement must not remove containment from old tabs");
});

test("issue: native recovery carries shell identity and retained nonce, never focus or shared URL", () => {
  const main = require('../tools/app-source').readAppSource(process.env.ZSB_MAIN_ZIG);
  const native = fs.readFileSync(process.env.ZSB_BRIDGE_ZIG || path.join(__dirname, "..", "src", "bridge.zig"), "utf8");
  const binding = main.slice(main.indexOf("fn ensureZsbPaneBindingForShell("), main.indexOf("fn forceRebindZsbForShell("));
  assert.match(binding, /startBrowserWindowResolve\(idx\)/);
  const resolver = main.slice(main.indexOf("fn startBrowserWindowResolve("), main.indexOf("fn handleBrowserWindowResolved("));
  assert.match(resolver, /browser_bind_nonce/);
  assert.match(resolver, /resolveBrowserWindowIdMatching\(job\.nonce\[0\.\.job\.nonce_len\], job\.shell_id\)/);
  assert.match(resolver, /resolveBrowserWindowIdForShell\(job\.shell_id\)/);
  assert.doesNotMatch(binding + resolver, /SetForegroundWindow|browserUrlSlice|resolveBrowserWindowIdFocused/);
  assert.match(main, /@memcpy\(shells\[target\]\.browser_bind_nonce/);
  assert.match(main, /resolve-window --shell-id \{d\} --match/);
  assert.match(main, /protect-window --shell-id \{d\} --owner-pid \{d\}/);
  assert.match(main, /resolve-window --shell-id \{d\} --owner-pid \{d\}/);
  assert.match(main, /match, GetCurrentProcessId\(\)/);
  const resolve = native.slice(native.indexOf('command, "resolve-window"'), native.indexOf('command, "help"'));
  assert.match(resolve, /arg, "--shell-id"/);
  assert.match(resolve, /shellId/);
});

test("issue: process-local shell IDs cannot cross workspace windows", async () => {
  const h = createHarness();
  h.setTab({ id: 1, windowId: 10, active: true, url: "https://same.example/" });
  h.setTab({ id: 2, windowId: 11, active: true, url: "https://same.example/" });
  await h.api.protectWindow({ windowId: 10, shellId: 0, ownerPid: 1000 });
  await h.api.protectWindow({ windowId: 11, shellId: 0, ownerPid: 2000 });
  h.flushSave();
  h.reloadRegistry();
  assert.equal((await h.api.resolveWindow({ shellId: 0, ownerPid: 1000 })).windowId, 10);
  assert.equal((await h.api.resolveWindow({ shellId: 0, ownerPid: 2000 })).windowId, 11);
  await assert.rejects(h.api.resolveWindow({ shellId: 0, ownerPid: 3000 }), /not found \(no active tab\)/);
  await assert.rejects(h.api.protectWindow({ windowId: 10, shellId: 0, ownerPid: 2000 }), /already belongs/);
});

test('selftest data pages support text, trusted type/click and value reads in the exact pane', async () => {
  const url = 'data:text/html,<title>zsb selftest remote-3 now</title><input><button>Click</button>';
  const h = createHarness({ scriptFrames: [{ frameId: 0, url }] });
  h.setTab({ id: 42, windowId: 10, url, active: true });
  h.setTab({ id: 43, windowId: 11, url, active: true });
  assert.equal((await h.api.textAction({ windowId: 10, tab: '42' })).text, 'selftest page');
  assert.equal((await h.api.typeAction({ windowId: 10, tab: '42', selector: 'input', text: 'typed value' })).trusted, true);
  assert.equal((await h.api.clickAction({ windowId: 10, tab: '42', selector: 'button' })).trusted, true);
  assert.equal(await h.api.dispatch({ method: 'eval', windowId: 10, tab: '42', code: "document.querySelector('input').value" }), 'typed value');
  assert.ok(h.debuggerCommands.some(command => command.method === 'Input.insertText'));
  assert.ok(h.debuggerCommands.some(command => command.method === 'Input.dispatchMouseEvent'));
  assert.ok(h.debuggerCommands.every(command => command.tabId === 42));
  assert.equal(h.scriptCalls.length, 0, 'data pages cannot rely on extension scripting injection');
  await assert.rejects(h.api.textAction({ windowId: 10, tab: '43' }), /not found|outside|window|session/);
});

test("Chrome theme sync never toggles the theme (that drops Chrome to grey) and never closes windows", async () => {
  const themes = [
    { id: "cur", name: "multiprompt browser theme", type: "theme", enabled: true },
    { id: "other", name: "Some other theme", type: "theme", enabled: false },
  ];
  const harness = createHarness({ themeExtensions: themes, userAgent: "Mozilla/5.0 Chrome/130.0 Safari/537.36" });
  const result = await harness.api.applyBrowserTheme({ theme: "amoled" });
  assert.equal(result.themeInstalled, true);
  assert.equal(result.restartRequired, false);
  assert.deepEqual(harness.themeEnableCalls, []);
  assert.match(result.hint, /Update in chrome:\/\/extensions/);
  assert.equal(harness.outsideWindows.length, 0);
});

test("Chrome theme sync reports a clear hint when the theme folder is not loaded", async () => {
  const harness = createHarness({ userAgent: "Mozilla/5.0 Chrome/130.0 Safari/537.36" });
  const result = await harness.api.applyBrowserTheme({ theme: "amoled" });
  assert.equal(result.themeInstalled, false);
  assert.match(result.hint, /themes\\current once in chrome:\/\/extensions/);
  assert.equal(result.restartRequired, false);
  assert.equal(harness.themeEnableCalls.length, 0);
});

test("issue: agent navigate appends a background tab, even in an unfocused or focused pane", async () => {
  for (const protectedFocused of [false, true]) {
    const h = createHarness({ protectedFocused });
    h.setTab({ id: 1, windowId: 10, index: 0, url: "https://user.example/", active: true });
    if (protectedFocused) await h.focusWindow(10);
    const opened = (await h.api.dispatch({ method: "navigate", windowId: 10, url: "https://agent.example/", newTab: true })).tab;
    assert.equal(h.createdTabs.length, 1);
    assert.equal(h.createdTabs[0].active, false, "an agent tab must stay in the background");
    assert.equal(h.updatedTabs.some(({ options }) => options.active === true), false, "no later activation either");
    assert.equal(h.getTab(1).active, true, "the page the user is looking at stays selected");
    assert.deepEqual(h.outsideWindows, [], "navigation never creates a window");
    assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, opened.id, "follow-up commands still target the new tab");
  }
});

test("issue: only an explicit activate (the app's own user action) selects the new tab", async () => {
  const h = createHarness({ protectedFocused: false });
  h.setTab({ id: 1, windowId: 10, url: "https://user.example/", active: true });
  await h.api.dispatch({ method: "navigate", windowId: 10, url: "https://a.example/", newTab: true, activate: false });
  await h.api.dispatch({ method: "navigate", windowId: 10, url: "https://b.example/", newTab: true, activate: "true" });
  await h.api.dispatch({ method: "navigate", windowId: 10, url: "https://c.example/", newTab: true, activate: true });
  assert.deepEqual(h.createdTabs.map((tab) => tab.active), [false, false, true]);
});

test("issue: an agent navigate preserves the active launch placeholder and creates in background", async () => {
  const h = createHarness({ protectedFocused: false });
  const beacon = { id: 5, windowId: 10, active: true, url: "data:text/html,<title>ZSPANE3-42</title>" };
  h.setTab(beacon);
  const opened = (await h.api.dispatch({ method: "navigate", windowId: 10, url: "https://ticket.example/" })).tab;
  assert.equal(h.createdTabs.length, 1);
  assert.equal(h.updatedTabs.length, 0);
  assert.notEqual(opened.id, 5);
  assert.equal(opened.active, false);
  assert.equal(h.getTab(5).url, beacon.url);
  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, opened.id);
  assert.deepEqual(h.outsideWindows, []);
});

test("issue: a woken pane window is created inactive and only for a launch placeholder", async () => {
  const h = createHarness();
  const beaconUrl = "data:text/html,<title>ZSPANE9-77</title><style>body{background:%23000;margin:0}</style>";
  const created = await h.api.dispatch({ method: "createPaneWindow", url: beaconUrl, left: 10, top: 20, width: 400, height: 300 });
  assert.equal(created.focused, false);
  assert.equal(h.outsideWindows.length, 1);
  assert.equal(h.outsideWindows[0].focused, false, "the new pane window must never take focus");
  assert.equal(h.outsideWindows[0].url, beaconUrl);
  assert.equal(h.outsideWindows[0].type, "normal");
  assert.equal(h.outsideWindows[0].left, 10);
  await h.api.dispatch({ method: "createPaneWindow", url: beaconUrl, app: true });
  assert.equal(h.outsideWindows[1].type, "popup");
  await assert.rejects(h.api.dispatch({ method: "createPaneWindow", url: "https://evil.example/" }), /only opens a pane launch placeholder/);
  assert.equal(h.outsideWindows.length, 2);
});

test("issue: a remote agent's activate only retargets; the app's own activate still selects", async () => {
  const h = createHarness({ protectedFocused: false });
  h.setTab({ id: 1, windowId: 10, url: "https://user.example/", active: true });
  h.setTab({ id: 2, windowId: 10, url: "https://agent.example/", active: false });
  const remote = await h.api.dispatch({ method: "activate", windowId: 10, tabId: 2, targetOnly: true });
  assert.equal(remote.targetOnly, true);
  assert.equal(h.updatedTabs.length, 0, "no tab selection for an agent");
  assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, 2);
  await h.api.dispatch({ method: "activate", windowId: 10, tabId: 2 });
  assert.equal(JSON.stringify(h.updatedTabs), JSON.stringify([{ tabId: 2, options: { active: true } }]));
});

test("issue: no extension source path asks Chromium for window focus", () => {
  const source = fs.readFileSync(path.join(__dirname, "bridge.js"), "utf8");
  assert.doesNotMatch(source, /focused:\s*true/);
  const nav = source.slice(source.indexOf("async function navigate(message)"), source.indexOf("async function createPaneWindow(message) {"));
  assert.match(nav, /const activate = message\?\.activate === true;/);
  assert.match(nav, /const createOpts = \{ url, active: activate, windowId: wid \};/);
  assert.match(nav, /if \(tab\?\.id && activate\) tab = await chrome\.tabs\.update\(tab\.id, \{ active: true \}\);/);
  assert.equal((nav.match(/active:\s*true/g) || []).length, 2, "only the active-tab query and user-gated move update mention active:true");
  assert.doesNotMatch(nav, /windows\.(create|update)/);
});
