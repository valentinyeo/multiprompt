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
  assert.match(bridge, /launchBrowserForAgentRequest\(ti\)/);
  assert.match(bridge, /last_active_event = now/);
});

function paneFunctionBody(name) {
  const start = browserPane.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = browserPane.indexOf("\nfn ", start + 1);
  assert.notEqual(end, -1, `could not find the end of ${name}`);
  return browserPane.slice(start, end);
}

test("IGSH-1935 an agent request clears a pane the app gave up on", () => {
  const bridge = fs.readFileSync(path.join(root, "src/browser_bridge.zig"), "utf8");
  const bind = bridge.slice(bridge.indexOf("fn handleZsbBindRequest("), bridge.indexOf("fn scanPaneWinCandidates("));
  assert.match(bind, /clearFailedBrowserPaneForRequest\(ti\)/, "the bind request, not only the Retry button, must clear the latch");
  assert.ok(bind.indexOf("clearFailedBrowserPaneForRequest(ti)") < bind.indexOf("launchBrowserForAgentRequest(ti)"));
  const clear = paneFunctionBody("clearFailedBrowserPaneForRequest");
  assert.match(clear, /if \(!app_state\.shells\[idx\]\.browser_open_failed\) return false;/, "only a failed pane is cleared");
  assert.match(clear, /resetBrowserConnection\(&app_state\.shells\[idx\]\);/);
  assert.match(clear, /app_state\.shells\[idx\]\.browser_enabled = true;/);
  assert.doesNotMatch(clear, /launchBrowserForShell\(/, "clearing never launches a user pane");
});

test("IGSH-1935 a reopened pane for a hidden tab stays a request launch", () => {
  const launch = paneFunctionBody("launchBrowserForShellEx");
  assert.match(launch, /browser_launch_tick != 0 or app_state\.shells\[idx\]\.browser_open_failed\) return;/, "only the request path clears the latch before launching");
  assert.match(launch, /shellExecuteEdgeUrl\(nonce_url, true, /, "a request launch is off screen");
  const adopt = paneFunctionBody("adoptBrowserTick");
  assert.match(adopt, /if \(target == app_state\.active_shell\) \{/, "only the visible tab gets repositioned and focused");
  assert.doesNotMatch(adopt, /switchToWorkspace|switchToShell|focusActiveShell/, "an adopted hidden pane never changes workspace or focus");
  assert.match(adopt, /dockBrowserWindow\(target, ctx\.found_hwnd, foreground_launch\);/);
});

test("IGSH-1935 an agent request opens its pane while the chat view is open", () => {
  const idle = fs.readFileSync(path.join(root, "src/idle_footprint.zig"), "utf8");
  assert.match(idle, /pub fn agentRequestBrowserLaunchAllowed\(shell_idx: u32\) bool \{/);
  const allowed = idle.slice(idle.indexOf("pub fn agentRequestBrowserLaunchAllowed("), idle.indexOf("test \"an agent browser request"));
  assert.doesNotMatch(allowed, /g_chat_active/, "an agent request is not blocked by the open chat view");
  assert.match(allowed, /if \(!g_startup_settled\) return false;/);
  assert.match(allowed, /return app_state\.shells\[shell_idx\]\.browser_enabled;/);
  const launch = paneFunctionBody("launchBrowserForShellEx");
  assert.match(launch, /\.agent_request => \{/);
  assert.match(launch, /agentRequestBrowserLaunchAllowed\(idx\)/);
  assert.match(launch, /const user_initiated = mode == \.user;/, "an agent launch never takes the user path");
  assert.match(launch, /shellExecuteEdgeUrl\(nonce_url, true, /, "an agent launch stays off screen");
  assert.match(browserPane, /pub fn launchBrowserForAgentRequest\(idx: u32\) void \{\s*launchBrowserForShellEx\(idx, \.agent_request\);\s*\}/);
});
