const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const extension = fs.readFileSync(path.join(root, "extension", "bridge.js"), "utf8");
const nativeHost = fs.readFileSync(path.join(root, "src", "bridge.zig"), "utf8");
const app = require('./app-source').readAppSource();

function functionBody(source, name, nextName) {
  const jsStart = source.indexOf(`function ${name}(`);
  const zigStart = source.indexOf(`fn ${name}(`);
  const start = jsStart >= 0 ? jsStart : zigStart;
  const jsEnd = source.indexOf(`function ${nextName}(`, start + 1);
  const zigEnd = source.indexOf(`fn ${nextName}(`, start + 1);
  const ends = [jsEnd, zigEnd].filter((value) => value >= 0);
  const end = ends.length ? Math.min(...ends) : -1;
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing boundary ${nextName}`);
  return source.slice(start, end);
}

test("click dispatches a complete trusted mouse sequence", () => {
  const click = functionBody(extension, "clickAction", "typeAction");
  assert.match(click, /locateSelectorAcrossFrames/);
  assert.match(click, /withCdpSession\(tab\.id/);
  assert.match(click, /dispatchTrustedClick/);
  assert.match(click, /frame-dom-fallback/);

  const dispatch = functionBody(extension, "dispatchTrustedClick", "dispatchSelectAll");
  assert.match(dispatch, /"Input\.dispatchMouseEvent"/);
  assert.match(dispatch, /type: "mouseMoved"/);
  assert.match(dispatch, /type: "mousePressed"/);
  assert.match(dispatch, /type: "mouseReleased"/);
});

test("read and click commands traverse every frame", () => {
  for (const [name, next] of [
    ["getSnapshot", "getCompactSnapshot"],
    ["textAction", "errorText"],
    ["linksAction", "findAction"],
    ["findAction", "dispatchTrustedClick"],
  ]) {
    assert.match(functionBody(extension, name, next), /runInAllFrames/);
  }

  const locate = functionBody(extension, "locateSelectorAcrossFrames", "frameViewportOffset");
  assert.match(locate, /runInAllFrames/);
  assert.match(locate, /selector matches more than one frame/);
  assert.doesNotMatch(functionBody(extension, "locateSelectorForTrustedInput", "locateChildFrameRect"), /requestAnimationFrame/,
    "an inactive addressed tab must not wait forever for a throttled animation frame");
  const offset = functionBody(extension, "frameViewportOffset", "insertAction");
  assert.match(offset, /chrome\.webNavigation\.getAllFrames/);
  assert.match(offset, /locateChildFrameRect/);
});

test("tab-targeted reads and tab closing are available from the CLI", () => {
  assert.match(nativeHost, /std\.mem\.eql\(u8, command, "close-tab"\)/);
  assert.match(nativeHost, /std\.mem\.eql\(u8, command, "tab"\)/);
  assert.match(nativeHost, /std\.mem\.eql\(u8, arg, "--tab"\)/);
  assert.match(extension, /case "closeTab":\s+return closeTabAction/);
  assert.match(extension, /async function resolveExplicitTargetTab/);
  assert.match(extension, /tab match is ambiguous/);
});

test("dialogs, CDP timeouts, and page errors fail in controlled ways", () => {
  const host = functionBody(extension, "handleHostMessage", "dispatch");
  assert.match(host, /withTimeout\(dispatch\(message\), actionTimeoutMs/);
  assert.match(host, /15000/);
  const navigate = functionBody(extension, "navigate", "historyNav");
  assert.match(navigate, /acceptPendingDialog/);
  const screenshot = functionBody(extension, "captureScreenshotViaCdp", "sendCdp");
  assert.match(screenshot, /tryAcceptPendingDialog/);
  const session = functionBody(extension, "withCdpSession", "captureScreenshotViaCdp");
  assert.match(session, /CDP operation timed out/);
  assert.match(extension, /result\?\.error === "page_error"/);
  assert.match(extension, /ok: false, error: "page_error"/);
  const runInTab = functionBody(extension, "runInTab", "runInFrame");
  assert.match(runInTab, /entry\?\.error/);
});

test("compact snapshots retain visible menus, list rows, and icon controls", () => {
  const compact = functionBody(extension, "getCompactSnapshot", "findText");
  assert.match(compact, /\[role='menuitem'\]/);
  assert.match(compact, /\[role='option'\]/);
  assert.match(compact, /"button", "a", "input"/);
  assert.match(compact, /filter\(visible\)/);
  assert.match(compact, /slice\(0, 160\)/);
});

test("remote requests and signed URLs are carried without silent truncation", () => {
  assert.match(app, /const ZSB_WIRE_CAP: usize = 64 \* 1024/);
  assert.match(app, /const ZSB_DECODED_CAP: usize = 48 \* 1024/);
  assert.match(app, /const BROWSER_PENDING_URL_CAP: usize = 8 \* 1024/);
  assert.match(app, /const WIN32_COMMAND_LINE_CAP: usize = 32_760/);

  const queuedOpen = functionBody(app, "queueZsbOpenRequest", "finishZsbOpenRequest");
  assert.match(queuedOpen, /if \(url\.len >= g_zsb_open_url\.len\) return null/);
  assert.doesNotMatch(queuedOpen, /@min\(url\.len/);

  const navigate = functionBody(app, "navigateBrowserPaneWithActivation", "openBrowserPaneForShell");
  assert.match(navigate, /browser_pending_url\[0\.\.url\.len\]/);
  assert.match(navigate, /\[WIN32_COMMAND_LINE_CAP\]u8/);
  assert.doesNotMatch(navigate, /safe_url_buf/);

  assert.match(app, /page_allocator\.alloc\(u8, decoded_size\)/);
  assert.match(app, /var buf: \[ZSB_WIRE_CAP\]u8/);
});

test("type supports focused text and selector replacement through trusted input", () => {
  assert.match(nativeHost, /const second = args\.next\(\);/);
  assert.match(nativeHost, /second orelse first/);
  assert.match(nativeHost, /if \(second != null\)/);
  assert.match(nativeHost, /type <text>\s+Type trusted text/);

  const type = functionBody(extension, "typeAction", "insertAction");
  assert.match(type, /if \(selector\)/);
  assert.match(type, /dispatchTrustedClick/);
  assert.match(type, /dispatchSelectAll/);
  assert.match(type, /dispatchTrustedText/);
  assert.match(type, /trusted: true/);
});

test("key down and key up share one extension-side debugger session", () => {
  const nativeKey = functionBody(nativeHost, "sendKeyChord", "sendCdpKeyEvent");
  assert.match(nativeKey, /sendBrowserRequest\(allocator, "key"/);
  assert.doesNotMatch(nativeKey, /sendCdpKeyEvent/);

  const extensionKey = functionBody(extension, "keyAction", "parseKeyCombo");
  assert.match(extensionKey, /withCdpSession\(tab\.id/);
  assert.match(extensionKey, /type: "rawKeyDown"/);
  assert.match(extensionKey, /type: "keyUp"/);
});

test("all CDP users serialize ownership and screenshots retry fresh sessions", () => {
  const session = functionBody(extension, "withCdpSession", "captureScreenshotViaCdp");
  assert.match(session, /cdpOperationChains\.get\(tabId\)/);
  assert.match(session, /chrome\.debugger\.attach/);
  assert.match(session, /chrome\.debugger\.detach/);

  const screenshot = functionBody(extension, "captureScreenshotViaCdp", "sendCdp");
  assert.match(screenshot, /const maxAttempts = 3/);
  assert.match(screenshot, /withCdpSession\(tabId/);
  assert.match(screenshot, /startsWith\("iVBOR"\)/);
  assert.match(screenshot, /failed after \$\{maxAttempts\} attempts/);

  const result = functionBody(extension, "captureScreenshotResult", "screenshot");
  assert.doesNotMatch(result, /error: "screenshot_failed"/);
});

test("URL and console commands expose the active page diagnostics", () => {
  assert.match(nativeHost, /command, "url"[\s\S]{0,500}sendBrowserRequest\(allocator, "url"/);
  assert.match(nativeHost, /command, "console"[\s\S]{0,500}"--clear"/);
  assert.match(extension, /case "url":\s+return urlAction/);
  assert.match(extension, /case "console":\s+return consoleAction/);

  const consoleAction = functionBody(extension, "consoleAction", "normalizeConsoleEvent");
  assert.match(consoleAction, /"Runtime\.enable"/);
  assert.match(consoleAction, /"Log\.enable"/);
  assert.match(consoleAction, /entries: entries\.slice\(-limit\)/);
  assert.match(extension, /Runtime\.consoleAPICalled/);
  assert.match(extension, /Log\.entryAdded/);
});
