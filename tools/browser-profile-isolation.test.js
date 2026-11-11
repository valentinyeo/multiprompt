const assert = require("node:assert/strict");
const { readControlSource } = require('./app-source');
assert.equal(typeof readControlSource, 'function', 'Control readers must follow physical feature files');
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
  for (const guard of ['!app_state.g_chat_active', '!app_state.g_chat_switch_preparing', 'app_state.active_shell >= app_state.shell_count', 'app_state.g_chat_browser_swap.shell_id != app_state.shells[app_state.active_shell].shell_id', 'app_state.g_monitor_transition.active', 'app_state.g_app_closing', '!foregroundIsOurs()', 'browserChromeHiddenForOverlay()', 'webView2OwnsActiveShell()', '!sh.browser_enabled', '!sh.browser_native', 'sh.browser_docking', 'sh.browser_frozen', 'IsWindow(bh) == 0', 'IsWindowVisible(bh) == 0', 'GetWindowRect(bh, &actual) == 0', 'actual.right - actual.left != target.right - target.left', 'actual.bottom - actual.top != target.bottom - target.top']) {
    assert.ok(reveal.includes(guard), guard);
    assert.ok(reveal.indexOf(guard) < reveal.indexOf('setBrowserWindowPosAsync('), guard);
  }
  assert.match(reveal, /setBrowserWindowPosAsync\(bh, null, target.left, target.top, 0, 0, SWP_NOSIZE \| SWP_NOZORDER \| SWP_NOACTIVATE \| SWP_NOREDRAW\)/);
  assert.match(reveal, /defer switch_timing.record\(\.position, timing_started\)/);
  assert.doesNotMatch(reveal, /ShowWindow|SWP_SHOWWINDOW|SetFocus|SetForegroundWindow|SetTimer|Sleep|WaitFor|launchBrowser|navigateBrowser/);
  const order = /app_state.active_shell = idx;\s+parkStrayBrowserPanes\([^;]+;\s+if \(defer_browser and defer_native_browser\) @import\("browser_pane.zig"\).revealPaintedChatBrowser\(\);\s+\{\s+const timing_started = switch_timing.start\(\);\s+defer switch_timing.record\(\.draft_bind, timing_started\);\s+chatDraftBindToActive\(\);\s+\}/;
  assert.match(switching, order);
  assert.doesNotMatch(switching.replace('.revealPaintedChatBrowser();', '.positionActiveBrowser();'), order);
  const park = pane.slice(pane.indexOf('pub fn parkBrowserWindow('), pane.indexOf('fn hideBrowserWindowHard('));
  assert.match(park, /target.left, target.top, 0, 0, SWP_NOSIZE \| SWP_NOZORDER \| SWP_NOACTIVATE/);
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

test("native Chrome own-profile adoption uses the opening budget and retains timeout cleanup", () => {
  const pane = fs.readFileSync(path.join(__dirname, '..', 'src', 'browser_pane.zig'), 'utf8');
  const launch = pane.slice(pane.indexOf('fn launchBrowserForShellEx('), pane.indexOf('\npub fn enumCloseStrayZspane('));
  assert.match(launch, /app_state\.g_browser_adopt_deadline = if \(app_state\.shells\[idx\]\.browser_native and app_state\.g_browser_engine == \.chrome and browserProfileToken\(idx\)\.len > 0\)\s+now \+ BROWSER_PLACEHOLDER_NOT_OPEN_MS\s+else\s+now \+ 6000;/,
    "only native Chrome own profiles must use the pane opening budget instead of six seconds");
  assert.match(launch, /SetTimer\(app_state\.g_main_hwnd, TIMER_BROWSER_ADOPT, 150, null\)/);
  const adopt = pane.slice(pane.indexOf('pub fn adoptBrowserTick('), pane.indexOf('\nfn cancelBrowserAdoptionForShell('));
  assert.ok(adopt.indexOf('if (ctx.found_hwnd != null)') < adopt.indexOf('if (now >= app_state.g_browser_adopt_deadline'));
  const timeout = adopt.slice(adopt.indexOf('if (now >= app_state.g_browser_adopt_deadline) {'));
  assert.match(timeout, /app_state\.shells\[target\]\.browser_launch_tick = 0;/);
  assert.match(timeout, /PostMessageW\(close_ctx\.found_hwnd, WM_CLOSE, 0, 0\)/);
  assert.match(timeout, /EnumWindows\(&enumCloseStrayZspane, 0\)/);
  const closeStrays = pane.slice(pane.indexOf('pub fn enumCloseStrayZspane('), pane.indexOf('\npub fn enumCloseOrphanPane('));
  assert.match(closeStrays, /PostMessageW\(hwnd, WM_CLOSE, 0, 0\)/);
});

test("branded stable Chrome journey opens a cold own-profile pane and binds its native pipe on every launch", () => {
  const control = readControlSource();
  const feature = fs.readFileSync(path.join(__dirname, '..', '.claude/skills/verify-multiprompt/features/browser-own-profile.md'), 'utf8');
  const journey = control.slice(control.indexOf("        'browser-own-profile' {"), control.indexOf("        'status-card' {"));
  for (const required of [
    "Google/Chrome/Application/chrome.exe",
    "$stableVersion.ProductName -cne 'Google Chrome'",
    '$stableVersion.ProductMajorPart -lt 137',
    "[IO.File]::WriteAllText((Join-Path $config 'chrome-exe.txt'), $stableChrome)",
    "Restart-SessionRestore 'stable-chrome-switch' $false",
    "if (Test-Path -LiteralPath $stableRoot) { throw 'Branded Chrome own profile must start empty' }",
    "Open-WorkspaceBrowser 'stable-cold-own'",
    '$stableProcess.ExecutablePath -ine $stableChrome',
    "$holder.CommandLine -notmatch 'chrome-launch'",
    "Wait-OwnProfilePipe $stableToken 'stable-cold-own'",
    '$stablePane.browser_window_id -le 0',
    "'browser-own-profile-stable.json'",
    "Restart-SessionRestore 'stable-own-restart' $false",
    "Wait-OwnProfilePipe $stableToken 'stable-restored-own'",
    "Assert-WorkspaceBrowser 'stable-restored-own' $stableRoot $stableWorkspace",
  ]) {
    assert.ok(journey.includes(required), required);
  }
  assert.ok(journey.indexOf('if (Test-Path -LiteralPath $stableRoot)') < journey.indexOf("Open-WorkspaceBrowser 'stable-cold-own'"));
  assert.match(feature, /branded Google Chrome stable/);
  assert.match(feature, /browser-own-profile-stable\.json/);
  assert.match(feature, /stable-restored-own/);
});

test("only the own-profile journey keeps USERPROFILE real while browser data and HOME stay disposable", () => {
  const control = readControlSource();
  const redirects = /\$env:APPDATA = Join-Path \$scratch 'roaming'\s+\$env:LOCALAPPDATA = Join-Path \$scratch 'local'\s+if \(\$Feature -ne 'browser-own-profile'\) \{ \$env:USERPROFILE = Join-Path \$scratch 'profile' \}\s+\$env:HOME = Join-Path \$scratch 'profile'/;
  assert.match(control, redirects);
  assert.equal(control.match(/\$env:USERPROFILE\s*=/g).length, 1);
  assert.doesNotMatch(control.replace("if ($Feature -ne 'browser-own-profile') { $env:USERPROFILE = Join-Path $scratch 'profile' }", "$env:USERPROFILE = Join-Path $scratch 'profile'"), redirects);
  assert.doesNotMatch(control.replace("$env:HOME = Join-Path $scratch 'profile'", '$env:HOME = $env:USERPROFILE'), redirects);
  assert.match(control, /\$ownBase = \[IO.Path\]::GetFullPath\(\(Join-Path \$env:LOCALAPPDATA 'ZigShell\/BrowserWorkspaces'\)\)/);
});

test("journey cleanup owns only the extension checkout created by this run at its resolved path", () => {
  const control = readControlSource();
  const setup = /\$extension = Join-Path \$env:USERPROFILE 'Documents\/GitHub\/zigshell\/extension'\s+\$extensionRoot = \[IO.Path\]::GetFullPath\(\(Split-Path \$extension\)\)\s+\$extensionRootExisted = Test-Path -LiteralPath \$extensionRoot\s+if \(-not \$extensionRootExisted\) \{\s+New-Item -ItemType Directory -Path \$extensionRoot \| Out-Null\s+\$switchExtensionRoot = \(Resolve-Path -LiteralPath \$extensionRoot\).Path\s+\}\s+Copy-Item/;
  assert.match(control, setup);
  assert.doesNotMatch(control.replace('if (-not $extensionRootExisted)', 'if ($extensionRootExisted)'), setup);
  assert.doesNotMatch(control.replace('New-Item -ItemType Directory -Path $extensionRoot', 'New-Item -ItemType Directory -Force -Path $extensionRoot'), setup);
  assert.equal(control.match(/\$switchExtensionRoot\s*=/g).length, 3);
  assert.ok(control.indexOf('$switchExtensionRoot = $null') < control.indexOf('$original = @{}'));
  const cleanup = control.slice(control.lastIndexOf('} finally {'));
  assert.match(cleanup, /if \(\$null -ne \$switchExtensionRoot\) \{\s+Remove-Item -LiteralPath \$switchExtensionRoot -Recurse -Force\s+\$switchExtensionRoot = \$null\s+\}/);
  assert.ok(cleanup.indexOf('$warmupJob.Stop()') < cleanup.indexOf('Remove-Item -LiteralPath $switchExtensionRoot'));
  assert.ok(cleanup.indexOf('Remove-Item -LiteralPath $switchExtensionRoot') < cleanup.indexOf('Remove-ScratchPath $scratch'));
});
