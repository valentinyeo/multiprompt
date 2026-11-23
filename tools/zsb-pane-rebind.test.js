const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const app = fs.readFileSync(process.env.ZSB_APP_ZIG || path.join(root, "src", "browser_bridge.zig"), "utf8");
const wrapper = fs.readFileSync(process.env.ZSB_WRAPPER_SH || path.join(root, "src", "mp_zsb.sh"), "utf8");

function functionText(name) {
  const start = app.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist in the app's browser bridge`);
  const end = app.indexOf("\n}\n", start);
  assert.ok(end > start, `${name} must be a complete function`);
  return app.slice(start, end + 2);
}

function functionValue(name, params, args) {
  const text = functionText(name);
  const open = text.indexOf("{");
  const body = text.slice(open + 1, text.lastIndexOf("}"))
    .replace(/\bor\b/g, "||")
    .replace(/\band\b/g, "&&");
  const declared = app.match(/const ZSB_PANE_LAUNCH_WAIT_MS: u64 = ([\d_]+);/);
  assert.ok(declared, "the pane wait budget must be a single named constant");
  const budget = Number(declared[1].replace(/_/g, ""));
  const fn = vm.runInNewContext(`(function (${params.join(",")}) {${body}})`, { ZSB_PANE_LAUNCH_WAIT_MS: budget });
  return fn(...args);
}

function clientDeadlineSeconds(verb) {
  const from = wrapper.indexOf("default_timeout = {");
  const to = wrapper.indexOf("if script_mode:", from);
  assert.ok(from >= 0 && to > from, "the CLI reply deadlines must stay where the app's callers can read them");
  const table = wrapper.slice(from, to);
  const named = {};
  for (const match of table.matchAll(/"([a-z-]+)": (\d+)/g)) named[match[1]] = Number(match[2]);
  const fallback = table.match(/\}\.get\(args\[0\], (\d+)\)/);
  assert.ok(fallback, "the CLI needs a default reply deadline");
  assert.ok(named.status > 0, "status keeps the tightest reply deadline");
  return verb in named ? named[verb] : Number(fallback[1]);
}

const appRoundTripMs = 1000;

test("a session whose bound pane window is gone answers inside the reply deadline", () => {
  const gone = functionValue("zsbBindWaitMs", ["pane_coming"], [false]);
  const relaunching = functionValue("zsbBindWaitMs", ["pane_coming"], [true]);
  const status = clientDeadlineSeconds("status");
  const tabs = clientDeadlineSeconds("tabs");

  assert.equal(gone, 0, "a closed pane window must not wait 5-15s for a rebind that the app cannot finish in time");
  assert.ok(relaunching > 0, "a pane that is still launching gets one short wait");
  assert.ok(gone + appRoundTripMs <= status * 1000, `a gone window must answer inside the ${status}s status deadline`);
  assert.ok(relaunching + appRoundTripMs <= status * 1000, `even a launching pane must answer inside the ${status}s status deadline`);
  assert.ok(relaunching + appRoundTripMs <= tabs * 1000, "and inside the default tab deadline");

  for (const name of ["zsbStatusPaneWindowId", "zsbResolvePaneWindowId", "zsbRetryAfterStaleBinding", "zsbVerifyOpenRequest"]) {
    const text = functionText(name);
    assert.match(text, /zsbBindWaitMs\(true\)/, `${name} must wait on the named budget`);
    assert.doesNotMatch(text, /zsbPollPaneWindowIdSilent\(session, \d/, `${name} must not poll on a fixed multi-second timer`);
    assert.doesNotMatch(text, /Sleep\(500\)/, `${name} must not spin on a half-second sleep`);
  }

  const resolve = functionText("zsbResolvePaneWindowId");
  assert.match(resolve, /zsbSendPaneNotReady\(client, session\)/,
    "a pane that did not come back in the budget must answer, not hang up");
  assert.match(resolve, /zsbSendNoPaneForSession\(client, session\)/,
    "a session with no pane binding fails at once instead of polling");
  assert.match(functionText("zsbSendPaneNotReady"), /"pane_not_ready"/);
});

test("a session whose tab is recreated keeps its previous pane window and tabs", () => {
  const stored = 1813568040;
  const keep = (force, current, cached) => functionValue("zsbKeepStoredPaneWindow", ["force", "current", "stored"], [force, current, cached]);
  assert.equal(keep(false, 0, stored), stored,
    "a recreated tab re-adopts the pane window its session still has");
  assert.equal(keep(false, 7, stored), 7, "a live binding always wins over the stored one");
  assert.equal(keep(true, 0, stored), 0, "a forced rebind must not resurrect the window Chrome already refused");
  assert.equal(keep(false, 0, 0), 0);

  const launch = (bound, missing, wanted) => functionValue("zsbPaneLaunchNeeded", ["bound_window_id", "pane_missing", "pane_wanted"], [bound, missing, wanted]);
  assert.equal(launch(stored, true, true), false,
    "a kept pane window must not be replaced by a fresh empty one");
  assert.equal(launch(0, true, true), true, "a session with no pane window at all still opens one");
  assert.equal(launch(0, false, true), false, "a live hosted pane needs no launch");
  assert.equal(launch(0, true, false), false, "a session that never wanted a pane stays closed");

  const storedText = functionText("zsbStoredPaneWindowId");
  assert.match(storedText, /zsbPrimarySessionToken\(session\)/);
  assert.match(storedText, /zsbReadPaneWindowIdForTokenSilent\(token\)/,
    "the stored pane window is found by session token, so a new shell id still finds it");

  const handler = functionText("handleZsbBindRequest");
  assert.match(handler, /zsbStoredPaneWindowId\(session\)/);
  assert.match(handler, /zsbKeepStoredPaneWindow\(force, app_state\.shells\[ti\]\.browser_window_id, stored\)/);
  assert.match(handler, /zsbPaneLaunchNeeded\(app_state\.shells\[ti\]\.browser_window_id, pane_missing, pane_wanted\)/);
  assert.match(handler, /if \(app_state\.shells\[ti\]\.browser_window_id != 0\) writePaneSessionFileForShell\(ti\)/,
    "the re-adopted window must be published for the status fast path");
  assert.match(handler, /removePaneSessionFilesForShell\(ti\)/,
    "a forced rebind clears the stored window so the dead id cannot come back");
});
