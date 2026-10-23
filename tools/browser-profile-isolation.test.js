const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();
const bridgeSource = fs.readFileSync(path.join(__dirname, "..", "src", "bridge.zig"), "utf8");
const launchStart = source.indexOf("fn shellExecuteEdgeUrl(");
const launchEnd = source.indexOf("\nfn spawnBrowserCliHidden(", launchStart);
assert.notStrictEqual(launchStart, -1, "Edge launch function is missing");
assert.notStrictEqual(launchEnd, -1, "could not isolate Edge launch function");
const launch = source.slice(launchStart, launchEnd);

test("native Edge and Chrome panes use process boundaries from normal browsers and PWAs", () => {
  assert.match(source, /GetEnvironmentVariableA\("LOCALAPPDATA"[\s\S]{0,900}?\\\\EdgeUserData/,
    "multiprompt needs a dedicated local Edge user-data directory");
  assert.match(source, /GetEnvironmentVariableA\("LOCALAPPDATA"[\s\S]{0,900}?\\\\ChromeUserData/,
    "multiprompt needs a separate dedicated local Chrome user-data directory");
  assert.match(launch, /--user-data-dir=\\"/,
    "every native Edge launch must select the isolated user-data directory");
  assert.match(launch, /--profile-directory=/,
    "the pane profile must be selected inside the isolated user-data directory");
  assert.ok(launch.indexOf("--user-data-dir=") < launch.indexOf("--profile-directory="),
    "the process boundary must be established before selecting its internal profile");
});

test("each isolated full-browser profile retains extension support without becoming a notification client", () => {
  assert.match(launch, /--load-extension=\\"/,
    "the path-stable native bridge extension must bootstrap in the isolated profile");
  assert.match(launch, /--disable-notifications/,
    "the isolated pane profile must not register its own Windows web notifications");
  assert.match(launch, /--disable-background-mode/,
    "theme restarts must end the isolated Edge process after its last window closes");
  assert.doesNotMatch(launch, /CreateCoreWebView2|WebView2/,
    "profile isolation must keep the full Edge backend rather than switching to WebView2");
});

test("same-sized painted chat browsers are uncovered before draft binding without focus, resize or visibility changes", () => {
  const pane = fs.readFileSync(path.join(__dirname, '..', 'src', 'browser_pane.zig'), 'utf8');
  const switching = fs.readFileSync(path.join(__dirname, '..', 'src', 'console.zig'), 'utf8');
  const reveal = pane.slice(pane.indexOf('pub fn revealPaintedChatBrowser('), pane.indexOf('pub fn positionActiveBrowser('));
  for (const guard of ['!app_state.g_chat_active', '!app_state.g_chat_switch_preparing', 'app_state.active_shell >= app_state.shell_count', 'app_state.g_chat_browser_swap.shell_id != app_state.shells[app_state.active_shell].shell_id', 'app_state.g_monitor_transition.active', 'app_state.g_app_closing', '!foregroundIsOurs()', 'browserChromeHiddenForOverlay()', 'webView2OwnsActiveShell()', '!sh.browser_enabled', '!sh.browser_native', 'sh.browser_docking', 'sh.browser_frozen', 'sh.browser_lifecycle_pending', 'IsWindow(bh) == 0', 'IsWindowVisible(bh) == 0', 'GetWindowRect(bh, &actual) == 0', 'actual.right - actual.left != target.right - target.left', 'actual.bottom - actual.top != target.bottom - target.top']) {
    assert.ok(reveal.includes(guard), guard);
    assert.ok(reveal.indexOf(guard) < reveal.indexOf('setBrowserWindowPosAsync('), guard);
  }
  assert.match(reveal, /setBrowserWindowPosAsync\(bh, null, target.left, target.top, 0, 0, SWP_NOSIZE \| SWP_NOZORDER \| SWP_NOACTIVATE \| SWP_NOREDRAW\)/);
  assert.match(reveal, /defer switch_timing.record\(\.position, timing_started\)/);
  assert.doesNotMatch(reveal, /ShowWindow|SWP_SHOWWINDOW|SetFocus|SetForegroundWindow|SetTimer|Sleep|WaitFor|launchBrowser|navigateBrowser/);
  const order = /app_state.active_shell = idx;\s+parkStrayBrowserPanes\([^;]+;\s+if \(defer_browser and defer_native_browser\) @import\("browser_pane.zig"\).revealPaintedChatBrowser\(\);\s+chatDraftBindToActive\(\);/;
  assert.match(switching, order);
  assert.doesNotMatch(switching.replace('.revealPaintedChatBrowser();', '.positionActiveBrowser();'), order);
  const park = pane.slice(pane.indexOf('pub fn parkBrowserWindow('), pane.indexOf('fn hideBrowserWindowHard('));
  assert.match(park, /BROWSER_PARK_X, BROWSER_PARK_Y, 0, 0, SWP_NOSIZE \| SWP_NOZORDER \| SWP_NOACTIVATE/);
  assert.match(park, /showBrowserWindowAsync\(hwnd, SW_SHOWNOACTIVATE\)/);
  const extension = fs.readFileSync(path.join(__dirname, '..', 'extension', 'bridge.js'), 'utf8');
  assert.match(extension, /async function setPageLifecycle\(debuggee, state\) \{[^]*Page\.setWebLifecycleState", \{ state \}/);
  assert.match(pane, /pub fn browserHibernationTick\(/);
  assert.match(pane, /pub fn wakeBrowserPaneFromFreeze\(/);
});

test("selected isolated Chromium and ordinary Edge cannot share the native command channel", () => {
  assert.match(source, /\\Documents\\\\GitHub\\\\zigshell\\\\extension/,
    "the isolated Edge process must load the repository extension copy");
  assert.doesNotMatch(source.slice(source.indexOf("fn defaultEdgeExtensionPath"), source.indexOf("fn loadEdgeExtensionPathConfig")),
    /zigshell-browser-pane/,
    "the isolated profile default must not reuse the ordinary Edge extension path");
  assert.match(bridgeSource, /const legacy_pipe_name = "\\\\\\\\\.\\\\pipe\\\\zigshell-browser"/,
    "ordinary Edge needs a compatibility-only pipe");
  assert.match(bridgeSource, /const isolated_pipe_name = "\\\\\\\\\.\\\\pipe\\\\multiprompt-browser-isolated"/,
    "multiprompt Edge or Chrome needs one private selected-engine command pipe");
  assert.match(bridgeSource, /return requestBrowserForWindow\(allocator, g_window_id, g_profile_token, method, fields_json, deadline\)/,
    "browser CLI commands must preserve their selected profile and window");
  assert.match(bridgeSource, /const command_pipe_name = try isolatedPipeName\(&pipe_name_buf, profile_token\);\s+const command_pipe = blk: \{[\s\S]*?const pipe = CreateFileA\(\s+command_pipe_name\.ptr/,
    "browser CLI and lifecycle commands must target only the isolated host");
  assert.match(bridgeSource, /runPipeServer,[\s\S]{0,120}?command_pipe_name/,
    "each native host must serve only the pipe selected by its extension origin");
});
