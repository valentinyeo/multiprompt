const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { readAppSource } = require("./app-source");

const root = path.resolve(__dirname, "..");
const browserPane = fs.readFileSync(path.join(root, "src/browser_pane.zig"), "utf8");
const source = readAppSource();

test("IGSH-1892 agent attach blocks pane hibernation close", () => {
  assert.match(browserPane, /pub fn browserPaneAgentAttached\(i: usize\) bool \{/);
  assert.match(browserPane, /sh\.console_working\) return true;/);
  assert.match(browserPane, /g_chat_screen_working;/);
  assert.match(browserPane, /if \(activity_active or agent_attached\) return true;/);
});

test("IGSH-1892 spinner stale does not drop activity while agent attached", () => {
  assert.match(source, /if \(browserPaneAgentAttached\(i\)\) \{/);
  assert.match(source, /any_active = true;/);
});

test("IGSH-1892 zsb relaunches a missing pane for attached sessions", () => {
  const bridge = require("node:fs").readFileSync(
    require("node:path").resolve(__dirname, "../src/browser_bridge.zig"),
    "utf8",
  );
  assert.match(bridge, /browser_suspended or agent_needs_pane\)/);
  assert.match(bridge, /launchBrowserForShellFromRequest\(ti\)/);
  assert.match(bridge, /last_active_event = now/);
});
