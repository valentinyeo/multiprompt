const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { webcrypto } = require("node:crypto");

const root = path.resolve(__dirname, "..");
const extension = fs.readFileSync(path.join(root, "extension", "bridge.js"), "utf8");
const nativeHost = fs.readFileSync(path.join(root, "src", "bridge.zig"), "utf8");
const app = require('./app-source').readAppSource();
const manifest = JSON.parse(fs.readFileSync(path.join(root, "extension", "manifest.json"), "utf8"));

function functionBody(source, name, nextName) {
  const start = source.indexOf(`function ${name}(`);
  const end = source.indexOf(`function ${nextName}(`, start + 1);
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing boundary ${nextName}`);
  return source.slice(start, end);
}

test("consecutive screenshots serialize the complete transaction", () => {
  const queue = functionBody(extension, "shotUrl", "runShotUrlTransaction");
  assert.match(queue, /screenshotTransactionChain/);
  assert.match(queue, /\.then\(\(\) => runShotUrlTransaction\(windowId, userInitiated\)\)/);

  const stages = functionBody(extension, "runShotUrlStages", "uploadScreenshotWithRetry");
  const captured = stages.indexOf('"captured"');
  const uploaded = stages.indexOf('"uploaded"');
  const pasteSent = stages.indexOf('"paste_sent"');
  const pasteRequest = stages.indexOf('requestHostReply("pasteUrl"');
  const acknowledged = stages.indexOf('"paste_acknowledged"');
  assert.ok(captured >= 0 && uploaded > captured);
  assert.ok(pasteSent > uploaded && pasteRequest > pasteSent);
  assert.ok(acknowledged > pasteRequest, "transaction must await native paste delivery acknowledgement");
});

test("screenshots prefer CDP and fall back only for extension-frame access refusals", () => {
  const capture = functionBody(extension, "captureScreenshotResult", "screenshot");
  assert.match(capture, /captureScreenshotViaCdp\(tab\.id, 10000\)/);
  assert.match(capture, /let via = "Page\.captureScreenshot"/);
  assert.match(capture, /if \(!isExtensionFrameAccessError\(error\)\) throw error/);
  assert.match(capture, /captureVisibleTab\(tab\.windowId, \{ format: "png" \}\)/);
  assert.match(capture, /via = "chrome\.tabs\.captureVisibleTab"/);
  assert.doesNotMatch(capture, /targetBrowserWindowIsFocused/);
});

test("screenshot upload has an abort timeout and exactly one retry", () => {
  const upload = functionBody(extension, "uploadScreenshotWithRetry", "showScreenshotFailure");
  assert.match(upload, /const maxAttempts = 2/);
  assert.match(upload, /new AbortController\(\)/);
  assert.match(upload, /setTimeout\(\(\) => controller\.abort\(\), 15000\)/);
  assert.match(upload, /signal: controller\.signal/);
});

test("native paste delivery reports failure instead of unconditional success", () => {
  assert.match(nativeHost, /fn sendShotNotify\([^)]*\) bool/);
  assert.match(nativeHost, /if \(!sendShotNotify\(window_id, url, getBool\(object.get\("userInitiated"\)\)\)\)/);
  assert.match(nativeHost, /multiprompt did not accept screenshot URL/);
});

test("native bridge and extension advance together", () => {
  assert.match(manifest.version, /^1\.0\.\d+$/);
  assert.match(nativeHost, /const version = @import\("bridge_config"\)\.extension_version;/);
});

test("the app keeps screenshot URLs in FIFO order instead of one overwrite slot", () => {
  assert.match(app, /const SHOT_PASTE_QUEUE_CAP: usize = 16/);
  assert.match(app, /g_shot_paste_tail = \(g_shot_paste_tail \+ 1\) % SHOT_PASTE_QUEUE_CAP/);
  assert.match(app, /g_shot_paste_head = \(g_shot_paste_head \+ 1\) % SHOT_PASTE_QUEUE_CAP/);
  assert.doesNotMatch(app, /g_shot_paste_shell_id/);
  assert.doesNotMatch(app, /g_shot_paste_url_len/);
});

function screenshotHarness({ rejectPasteOnce = false } = {}) {
  const events = [];
  const captures = [];
  const deliveries = [];
  let click;
  let uploadCount = 0;
  let activeTransactions = 0;
  let maximumActive = 0;
  let title = "";
  let badge = "";
  const context = vm.createContext({
    console, crypto: webcrypto, Uint8Array, Blob, FormData, AbortController,
    atob, setTimeout, clearTimeout,
    screenshotTransactionChain: Promise.resolve(),
    screenshotAuditWriteChain: Promise.resolve(),
    recordScreenshotAudit: (id, stage, detail) => events.push({ id, stage, ...detail }),
    chrome: {
      action: {
        onClicked: { addListener: (handler) => { click = handler; } },
        setBadgeText: async (value) => { badge = value.text; },
        setBadgeBackgroundColor: async () => {},
        setTitle: async (value) => { title = value.title; },
      },
      tabs: { query: async ({ windowId }) => [{ id: windowId + 1 }] },
    },
    captureScreenshotResult: async (target) => {
      captures.push(target);
      maximumActive = Math.max(maximumActive, ++activeTransactions);
      await new Promise((resolve) => setImmediate(resolve));
      return { tab: { id: target.tabId }, via: "Page.captureScreenshot", dataUrl: "data:image/png;base64,aGVsbG8=" };
    },
    requestHostReply: async (method, fields) => {
      if (method === "getUploadConfig") return { secret: "test-only", baseUrl: "https://example.invalid" };
      assert.equal(method, "pasteUrl");
      activeTransactions -= 1;
      if (rejectPasteOnce) {
        rejectPasteOnce = false;
        throw new Error("delivery refused");
      }
      deliveries.push(fields);
      return { sent: true };
    },
    fetch: async () => ({ ok: true, json: async () => ({ success: true, url: `https://example.invalid/${++uploadCount}` }) }),
  });
  const start = extension.indexOf("function shotUrl(");
  const end = extension.indexOf("function withTimeout(", start);
  vm.runInContext(extension.slice(start, end), context);
  const actionStart = extension.indexOf("chrome.action.onClicked.addListener(");
  vm.runInContext(extension.slice(actionStart, extension.indexOf("chrome.runtime.onStartup", actionStart)), context);
  return { shotUrl: context.shotUrl, click: (tab) => click(tab), events, captures, deliveries,
    state: () => ({ title, badge, maximumActive }) };
}

test("two toolbar presses each capture the visible tab and acknowledge a distinct link", async () => {
  const h = screenshotHarness();
  await Promise.all([h.click({ windowId: 40 }), h.click({ windowId: 40 })]);
  assert.equal(h.deliveries.length, 2);
  assert.ok(h.deliveries.every((delivery) => delivery.userInitiated === true));
  assert.notEqual(h.deliveries[0].url, h.deliveries[1].url);
  assert.ok(h.captures.every((target) => target.windowId === 40 && target.tabId === 41));
  assert.equal(h.events.filter((event) => event.stage === "paste_acknowledged").length, 2);
  assert.equal(h.state().maximumActive, 1);
  assert.equal(h.state().badge, "");
});

test("a failed delivery shows its reason and the next button press recovers", async () => {
  const h = screenshotHarness({ rejectPasteOnce: true });
  await h.click({ windowId: 40 });
  assert.equal(h.state().badge, "!");
  assert.match(h.state().title, /delivery refused/);
  await h.click({ windowId: 40 });
  assert.equal(h.deliveries.length, 1);
  assert.equal(h.state().badge, "");
  assert.doesNotMatch(h.state().title, /failed/);
});

test("the toolbar and extension list have packaged multiprompt icons", () => {
  for (const icons of [manifest.icons, manifest.action.default_icon]) {
    assert.ok(icons[16] && icons[32]);
    for (const file of Object.values(icons)) {
      const bytes = fs.readFileSync(path.join(root, "extension", file));
      assert.equal(bytes.subarray(1, 4).toString(), "PNG");
    }
  }
});

test("agent shoturl defaults to no focus authority, and queued user intent is not lost or leaked", async () => {
  const h = screenshotHarness();
  await Promise.all([h.shotUrl(40), h.shotUrl(40, true), h.shotUrl(40)]);
  assert.deepEqual(h.deliveries.map((delivery) => delivery.userInitiated), [false, true, false]);
  assert.equal(h.state().maximumActive, 1);
});

test("native screenshot user marker survives bridge and notify routing, not agent navigation", () => {
  assert.match(nativeHost, /if \(user_initiated\) "SHOTUSER" else "SHOT"/);
  assert.match(app, /const user_initiated = std.mem.startsWith\(u8, raw, "SHOTUSER:"\)/);
  assert.match(app, /queueShotPaste\(shells\[idx\].shell_id, url_part, user_initiated\)/);
  assert.match(app, /slot.user_initiated = user_initiated/);
  assert.match(app, /user_initiated = slot.user_initiated/);
  const dispatch = extension.slice(extension.indexOf("async function dispatch("), extension.indexOf("function messageWindowId("));
  assert.match(dispatch, /return shotUrl\(wid, message.userInitiated === true\)/);
});
