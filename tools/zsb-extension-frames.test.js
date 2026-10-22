const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(process.env.ZSB_BRIDGE_JS || path.join(root, "extension/bridge.js"), "utf8");
const extensionUrls = [
  "chrome-extension://foreign/frame.html",
  "edge-extension://foreign/frame.html",
  "moz-extension://foreign/frame.html",
  "safari-web-extension://foreign/frame.html",
  "ms-browser-extension://foreign/frame.html",
  "CHROME-EXTENSION://foreign/frame.html",
];

function bridgeFunction(name) {
  const start = source.search(new RegExp(`^(?:async )?function ${name}\\(`, "m"));
  const end = source.indexOf("\n}\n", start) + 3;
  assert.ok(start >= 0 && end > start, `missing function ${name}`);
  return source.slice(start, end);
}

const extensionAccessError = "Cannot access a chrome-extension:// URL of different extension";
const png = "iVBORw0KGgo=";

function harness(frames, {
  tabs = [{ id: 1, windowId: 10, active: true, url: frames[0].url }],
  failedFrames = [], attachError, commandError, failedCommand, captureError,
} = {}) {
  const scriptCalls = [];
  const cdpTargets = [];
  const cdpCommands = [];
  const detached = [];
  const captures = [];
  const activations = [];
  const context = vm.createContext({
    console, setTimeout, clearTimeout,
    cdpOperationChains: new Map(),
    cdpSessionCancels: new Map(),
    debuggedTabs: new Set(),
    screenshotCdpDetachTimers: new Map(),
    screenshotCdpDetachInFlight: new Map(),
    screenshotCdpPageEnabledTabs: new Set(),
    focusEmulatedTabs: new Set(),
    PANE_BEACON_URL_PREFIX: "data:text/html,<title>ZSPANE",
    resolveExplicitTargetTab: async (_, message) => tabs.find((tab) => tab.id === message.tabId) || null,
    getRememberedZsbTargetTab: async () => null,
    chrome: {
      tabs: {
        get: async (id) => tabs.find((tab) => tab.id === id),
        query: async ({ windowId, active }) => tabs.filter((tab) => tab.windowId === windowId && (!active || tab.active)),
        update: async (id, update) => {
          activations.push(id);
          const target = tabs.find((tab) => tab.id === id);
          if (update.active) {
            for (const tab of tabs.filter((tab) => tab.windowId === target.windowId)) tab.active = tab.id === id;
          }
          return target;
        },
        captureVisibleTab: async (windowId, options) => {
          captures.push({ windowId, options, tabId: tabs.find((tab) => tab.windowId === windowId && tab.active)?.id });
          if (captureError) throw new Error(captureError);
          return `data:image/png;base64,${png}`;
        },
      },
      debugger: {
        attach: async ({ tabId }) => {
          cdpTargets.push(tabId);
          if (attachError) throw new Error(attachError);
        },
        detach: async ({ tabId }) => { detached.push(tabId); },
        sendCommand: async ({ tabId }, method) => {
          cdpCommands.push({ tabId, method });
          if (method === failedCommand) throw new Error(commandError || extensionAccessError);
          return method === "Page.captureScreenshot" ? { data: png } : {};
        },
      },
      webNavigation: { getAllFrames: async () => frames },
      scripting: {
        executeScript: async ({ target, func }) => {
          scriptCalls.push(target);
          assert.equal(target.allFrames, undefined);
          const selected = frames.filter((frame) => (target.frameIds || [0]).includes(frame.frameId));
          if (selected.some((frame) => extensionUrls.includes(frame.url))) {
            throw new Error("Cannot access a chrome-extension:// URL of different extension");
          }
          if (selected.some((frame) => failedFrames.includes(frame.frameId))) {
            throw new Error("Cannot access contents of frame");
          }
          return selected.map((frame) => ({
            frameId: frame.frameId,
            result: {
              url: frame.url,
              title: `Page ${frame.frameId}`,
              text: `frame ${frame.frameId}`,
              length: 7,
              textLength: 7,
              headings: func.name === "getCompactSnapshot" ? [{ text: `Heading ${frame.frameId}` }] : [],
              controls: [],
            },
          }));
        },
      },
    },
  });
  const names = [
    "isExtensionTab", "isPaneBeaconTab", "paneContentTab", "paneWindowNotFoundMessage", "getTargetTab",
    "ensureBackgroundTabFocusEmulation", "runInFrame", "runInAllFrames", "textAction", "getSnapshot",
    "errorText", "isPageScriptingError", "pageErrorResult", "compactTab", "numberOr", "getVisibleText", "getCompactSnapshot",
    "runInDataTab", "withCdpSession", "withTimeout", "clearScreenshotCdpDetachTimer",
    "tryAcceptPendingDialog", "acceptPendingDialog", "captureScreenshotViaCdp", "captureScreenshotResult",
  ];
  if (source.includes("function isExtensionFrameAccessError(")) names.push("isExtensionFrameAccessError");
  vm.runInContext(names.map(bridgeFunction).join("\n"), context);
  const api = vm.runInContext("({ textAction, getSnapshot, getTargetTab, captureScreenshotResult, acceptPendingDialog })", context);
  return { api, scriptCalls, cdpTargets, cdpCommands, detached, captures, activations };
}

function pageFrames(url) {
  return [
    { frameId: 0, parentFrameId: -1, url: "https://page.example/" },
    { frameId: 1, parentFrameId: 0, url },
    { frameId: 2, parentFrameId: 0, url: "https://page.example/child" },
    { frameId: 3, parentFrameId: 0, url: "https://cross-origin.example/" },
  ];
}

for (const url of extensionUrls) {
  test(`text and snapshot skip ${url} without losing page frames`, async () => {
    const h = harness(pageFrames(url));
    const text = await h.api.textAction({ windowId: 10 });
    const snapshot = await h.api.getSnapshot(2000, { windowId: 10 });
    for (const result of [text, snapshot]) {
      assert.equal(result.text, "frame 0\n\nframe 2\n\nframe 3");
      assert.equal(result.total_length, 25);
      assert.deepEqual(Array.from(result.frames, (frame) => frame.frameId), [0, 2, 3]);
    }
    assert.deepEqual(Array.from(snapshot.headings, (heading) => heading.frameId), [0, 2, 3]);
    assert.deepEqual(h.scriptCalls.map((call) => Array.from(call.frameIds)), [[0], [2], [3], [0], [2], [3]]);
  });

  test(`extension target ${url} is neither selected nor attached`, async () => {
    const h = harness(pageFrames(url), { tabs: [
      { id: 1, windowId: 10, active: false, url: "https://page.example/" },
      { id: 2, windowId: 10, active: true, url },
    ] });
    assert.equal((await h.api.getTargetTab({ windowId: 10 })).id, 1);
    assert.deepEqual(h.cdpTargets, [1]);
    await assert.rejects(h.api.getTargetTab({ windowId: 10, tabId: 2 }), /extension tab/);
    assert.deepEqual(h.cdpTargets, [1]);
  });

  test(`pending extension target ${url} is rejected before attachment`, async () => {
    const h = harness(pageFrames(url), { tabs: [
      { id: 1, windowId: 10, active: false, url: "https://page.example/", pendingUrl: url },
    ] });
    await assert.rejects(h.api.getTargetTab({ windowId: 10, tabId: 1 }), /extension tab/);
    assert.deepEqual(h.cdpTargets, []);
  });
}

test("ordinary frame failures stay isolated but main-document failures remain visible", async () => {
  const frames = pageFrames("https://page.example/another-child");
  const h = harness(frames, { failedFrames: [1] });
  assert.equal((await h.api.textAction({ windowId: 10 })).text, "frame 0\n\nframe 2\n\nframe 3");
  assert.equal((await h.api.getSnapshot(2000, { windowId: 10 })).text, "frame 0\n\nframe 2\n\nframe 3");
  const broken = harness(frames, { failedFrames: [0] });
  assert.equal((await broken.api.textAction({ windowId: 10 })).error, "page_error");
  assert.equal((await broken.api.getSnapshot(2000, { windowId: 10 })).error, "page_error");
});

for (const failure of [
  { name: "attach", attachError: extensionAccessError },
  { name: "focus emulation", failedCommand: "Emulation.setFocusEmulationEnabled" },
  { name: "evaluation", failedCommand: "Runtime.evaluate" },
]) {
  test(`data-page text and snapshot use scripting when CDP refuses ${failure.name}`, async () => {
    const frames = pageFrames(extensionUrls[0]);
    frames[0].url = "data:text/html,<h1>Page</h1>";
    const h = harness(frames, failure);
    for (const result of [
      await h.api.textAction({ windowId: 10 }),
      await h.api.getSnapshot(2000, { windowId: 10 }),
    ]) {
      assert.equal(result.text, "frame 0\n\nframe 2\n\nframe 3");
      assert.equal(result.total_length, 25);
      assert.deepEqual(Array.from(result.frames, (frame) => frame.frameId), [0, 2, 3]);
    }
    assert.deepEqual(h.cdpTargets, [1, 1]);
    assert.equal(h.cdpCommands.some((call) => call.method === "Runtime.evaluate"), failure.name === "evaluation");
    assert.deepEqual(h.scriptCalls.map((call) => Array.from(call.frameIds)).sort(), [[0], [0], [2], [2], [3], [3]]);
    assert.deepEqual(h.detached, [1, 1]);
  });
}

for (const failure of [
  { name: "attach", attachError: extensionAccessError },
  { name: "focus emulation", failedCommand: "Emulation.setFocusEmulationEnabled" },
]) {
  test(`HTTP text and snapshot survive CDP ${failure.name} refusal in a background tab`, async () => {
    const h = harness(pageFrames(extensionUrls[0]), {
      ...failure,
      tabs: [{ id: 1, windowId: 10, active: false, url: "https://page.example/" }],
    });
    assert.equal((await h.api.textAction({ windowId: 10 })).text, "frame 0\n\nframe 2\n\nframe 3");
    assert.equal((await h.api.getSnapshot(2000, { windowId: 10 })).text, "frame 0\n\nframe 2\n\nframe 3");
    assert.deepEqual(h.cdpTargets, [1, 1]);
    assert.deepEqual(h.activations, []);
  });
}

for (const failure of [
  { name: "attach", attachError: extensionAccessError },
  ...["Emulation.setFocusEmulationEnabled", "Page.handleJavaScriptDialog", "Page.enable", "Page.captureScreenshot"]
    .map((failedCommand) => ({ name: failedCommand, failedCommand })),
]) {
  test(`screenshot falls back to visible-tab capture when CDP refuses ${failure.name}`, async () => {
    const h = harness(pageFrames(extensionUrls[0]), failure);
    const result = await h.api.captureScreenshotResult({ windowId: 10 });
    assert.equal(result.dataUrl, `data:image/png;base64,${png}`);
    assert.equal(result.via, "chrome.tabs.captureVisibleTab");
    assert.equal(result.bytesApprox, Math.ceil(png.length * 0.75));
    assert.deepEqual(h.cdpTargets, [1]);
    assert.equal(h.captures.length, 1);
    assert.equal(h.captures[0].windowId, 10);
    assert.equal(h.captures[0].tabId, 1);
    assert.equal(h.captures[0].options.format, "png");
    assert.deepEqual(h.detached, [1]);
  });
}

test("screenshot fallback captures the requested background tab and restores the active tab", async () => {
  const h = harness(pageFrames(extensionUrls[0]), {
    attachError: extensionAccessError,
    tabs: [
      { id: 1, windowId: 10, active: false, url: "https://page.example/" },
      { id: 2, windowId: 10, active: true, url: "https://other.example/" },
    ],
  });
  const result = await h.api.captureScreenshotResult({ windowId: 10, tabId: 1 });
  assert.equal(result.tab.id, 1);
  assert.equal(h.captures[0].tabId, 1);
  assert.deepEqual(h.activations, [1, 2]);
});

test("failed visible-tab capture still restores the previous active tab", async () => {
  const h = harness(pageFrames(extensionUrls[0]), {
    attachError: extensionAccessError, captureError: "capture failed",
    tabs: [
      { id: 1, windowId: 10, active: false, url: "https://page.example/" },
      { id: 2, windowId: 10, active: true, url: "https://other.example/" },
    ],
  });
  await assert.rejects(h.api.captureScreenshotResult({ windowId: 10, tabId: 1 }), /capture failed/);
  assert.deepEqual(h.activations, [1, 2]);
});

test("successful screenshots retain the CDP path", async () => {
  const h = harness(pageFrames(extensionUrls[0]));
  const result = await h.api.captureScreenshotResult({ windowId: 10 });
  assert.equal(result.via, "Page.captureScreenshot");
  assert.equal(result.dataUrl, `data:image/png;base64,${png}`);
  assert.deepEqual(h.captures, []);
});

test("unrelated CDP failures do not trigger scripting or visible-tab fallback", async () => {
  const frames = pageFrames(extensionUrls[0]);
  frames[0].url = "data:text/html,<h1>Page</h1>";
  const h = harness(frames, { attachError: "Debugger unavailable" });
  await assert.rejects(h.api.textAction({ windowId: 10 }), /Debugger unavailable/);
  await assert.rejects(h.api.getSnapshot(2000, { windowId: 10 }), /Debugger unavailable/);
  assert.ok(h.scriptCalls.every((call) => !call.frameIds.includes(0)));
  await assert.rejects(h.api.captureScreenshotResult({ windowId: 10 }), /failed after 3 attempts: Debugger unavailable/);
  assert.deepEqual(h.captures, []);
});

test("unrelated CDP command failures remain errors rather than fallback successes", async () => {
  const frames = pageFrames(extensionUrls[0]);
  frames[0].url = "data:text/html,<h1>Page</h1>";
  const h = harness(frames, { failedCommand: "Runtime.evaluate", commandError: "Evaluation unavailable" });
  await assert.rejects(h.api.textAction({ windowId: 10 }), /Evaluation unavailable/);
  await assert.rejects(h.api.getSnapshot(2000, { windowId: 10 }), /Evaluation unavailable/);
  assert.ok(h.scriptCalls.every((call) => !call.frameIds.includes(0)));
  const shot = harness(frames, { failedCommand: "Page.captureScreenshot", commandError: "Capture unavailable" });
  await assert.rejects(shot.api.captureScreenshotResult({ windowId: 10 }), /failed after 3 attempts: Capture unavailable/);
  assert.deepEqual(shot.captures, []);
  assert.deepEqual(shot.detached, [1, 1, 1]);
});

test("dialog cleanup remains best effort when CDP attachment is refused", async () => {
  const h = harness(pageFrames(extensionUrls[0]), { attachError: extensionAccessError });
  await h.api.acceptPendingDialog(1);
  assert.deepEqual(h.cdpTargets, [1]);
  assert.equal((await h.api.textAction({ windowId: 10 })).text, "frame 0\n\nframe 2\n\nframe 3");
});

test("CLI text and snapshot requests delegate frame traversal to the bridge", () => {
  const cli = fs.readFileSync(path.join(root, "src/bridge.zig"), "utf8");
  for (const method of ["text", "snapshot"]) {
    const start = cli.indexOf(`std.mem.eql(u8, command, "${method}")`);
    const end = cli.indexOf("} else if", start);
    assert.ok(start >= 0 && end > start);
    assert.match(cli.slice(start, end), new RegExp(`sendBrowserRequest\\(allocator, "${method}"`));
  }
});
