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


test("one overlay-aware helper decides whether a pane may occupy the visible layout", () => {
  const pure = functionBody("browserPaneOccupiesLayoutPure");
  assert.match(pure, /if \(closing or monitor_transition\) return false;/, "closing/monitor transition always park");
  assert.match(pure, /if \(!is_active_shell or !enabled or webview2_owned or iconic\) return false;/, "background/disabled/webview2/minimized always park");
  assert.match(pure, /return !overlay_active;/, "an open overlay always parks");

  const runtime = functionBody("browserPaneMayOccupyLayout");
  assert.match(runtime, /browserPaneOccupiesLayoutPure\(/, "runtime gate wraps the pure decision");
  assert.match(runtime, /idx == active_shell/, "a non-active shell's pane can never occupy the layout");
  assert.match(runtime, /browserChromeHiddenForOverlay\(\)/, "the overlay check is part of the gate");
});

test("the launch beacon never starts on-screen over an overlay or for a background shell", () => {
  const launch = functionBody("shellExecuteEdgeUrl");
  assert.match(launch, /if \(browserPaneMayOccupyLayout\(li\)\)/, "the pane-rect placement is gated by the overlay-aware helper");
  assert.doesNotMatch(launch, /--window-position=90,90/, "no generic on-screen fallback may paint a fresh pane before adoption");
  assert.match(launch, /--window-position=-32000,-32000 --window-size=400,400/, "the fallback parks the beacon off-screen");
});

test("adoption completion parks instead of showing while an overlay is open", () => {
  const dock = functionBody("finishBrowserDock");
  assert.match(dock, /const frame_ready = browserPaneMayOccupyLayout\(idx\);/, "the adoption show gate is the overlay-aware helper");
  assert.match(dock, /parkBrowserWindow\(hwnd\);/, "the forbidden case parks the pane");
});

test("reposition and the delayed re-show settle both park during an overlay", () => {
  const pos = functionBody("positionActiveBrowser");
  assert.match(pos, /if \(browserChromeHiddenForOverlay\(\)\) \{\s*parkBrowserWindow\(bh\);/, "positionActiveBrowser parks the active pane while an overlay is open");
  const arm = functionBody("armBrowserVisibilitySettle");
  assert.match(arm, /if \(browserChromeHiddenForOverlay\(\)\) \{\s*cancelBrowserVisibilitySettle\(\);\s*return;/, "a delayed re-show is never armed while an overlay is open");
});

test("closing the Inbox re-shows the active pane through updateBrowserVisibility", () => {
  const close = functionBody("closeInbox");
  const refreshes = close.match(/updateBrowserVisibility\(\);/g) || [];
  assert.ok(refreshes.length >= 2, "both Inbox close branches re-show the pane");
  assert.match(close, /g_inbox_active = false;/);
});

test("every pane re-entry path re-runs the overlay-aware visibility pass or parks", () => {
  for (const name of ["browserHealthTick", "finishBrowserEngineSwitch", "relaunchActiveRestoredBrowserPane"]) {
    const body = functionBody(name);
    assert.match(body, /updateBrowserVisibility\(\);/, `${name} must re-run overlay-aware visibility`);
  }
  const zsb = functionBody("handleZsbBindRequest");
  assert.match(zsb, /launchBrowserForShellFromRequest\(ti\);/, "zsb bind relaunch goes through the gated launcher (issue: as a request)");
  const park = functionBody("parkBrowserForMonitorTransition");
  assert.match(park, /parkBrowserWindow\(bh\);/, "a monitor transition parks the active pane");
  const open = functionBody("openInbox");
  assert.match(open, /hideActiveBrowser\(\);/, "opening the Inbox parks the active pane");
  assert.match(open, /updateBrowserVisibility\(\);/, "opening the Inbox re-runs overlay-aware visibility");
});
