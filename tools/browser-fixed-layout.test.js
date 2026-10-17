const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = require('./app-source').readAppSource();

function functionBody(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf("\nfn ", start + 1);
  assert.notEqual(end, -1, `could not find the end of ${name}`);
  return source.slice(start, end);
}


test("one pure predicate reserves the slot from browser_enabled, not the live HWND", () => {
  const pure = functionBody("browserSlotReservedPure");
  assert.match(pure, /has_active_shell and \(browser_enabled or webview2_owns\)/);
  const wrapper = functionBody("browserSlotReserved");
  assert.match(wrapper, /browserSlotReservedPure\(/);
  assert.match(wrapper, /shells\[active_shell\]\.browser_enabled/);
  assert.doesNotMatch(wrapper, /browser_hwnd|IsWindow/, "the reserved predicate must not need a live window");
  assert.match(source, /test "browserSlotReservedPure/, "predicate must be unit-tested");
});

test("the live-HWND layout predicate is gone so no geometry site can regress to it", () => {
  assert.doesNotMatch(source, /browserLayoutActive\(/);
});

test("console and Chat View reserve the same slot before a browser is visible", () => {
  const rep = functionBody("repositionActive");
  assert.doesNotMatch(rep, /browserLayoutActive/);
  assert.equal((rep.match(/browserSlotReserved\(\)/g) || []).length, 2, "chat branch + console branch");
  assert.match(functionBody("chatViewLayout"), /if \(browserSlotReserved\(\)\)/);
  assert.doesNotMatch(functionBody("chatViewLayout"), /chatBrowserVisible|centeredConsoleColumn/);
  assert.match(functionBody("threadTitleBandRightFor"), /browserSlotReserved\(\)/);
  assert.match(functionBody("browserSplitterHit"), /browserSlotReserved\(\)/);
  assert.match(functionBody("paintBrowserSplitter"), /browserSlotReserved\(\)/);
});

test("live-window consumers keep the live predicate", () => {
  assert.match(functionBody("activePaneBorderOn"), /browserPaneActive\(\)/);
  assert.match(functionBody("positionActiveBrowser"), /browser_hwnd/);
});

test("placeholder paints the slot, is overlay-aware, and is wired into WM_PAINT", () => {
  const paint = functionBody("paintBrowserPlaceholder");
  assert.match(paint, /g_inbox_active/, "skips under overlays");
  assert.match(paint, /themeConsoleBg\(\)/, "fills with the theme background");
  assert.match(paint, /Opening browser/);
  assert.match(paint, /Browser not open/);
  assert.match(functionBody("browserPlaceholderPure"), /BROWSER_PLACEHOLDER_NOT_OPEN_MS/);
  assert.match(source, /test "browserPlaceholderPure/);
  assert.equal((source.match(/paintBrowserPlaceholder\(/g) || []).length, 3, "definition + both WM_PAINT paths");
  assert.match(functionBody("browserPaneCoversSlot"), /BROWSER_PARK_X/, "a parked pane does not count as covering");
});
