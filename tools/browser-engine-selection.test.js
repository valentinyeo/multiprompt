const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const source = require('./app-source').readAppSource();

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf(`fn ${nextName}(`, start);
  assert.notEqual(end, -1, `${nextName} must follow ${name}`);
  return source.slice(start, end);
}

test("Edge and Chrome use distinct dedicated profile process boundaries", () => {
  assert.match(source, /const BrowserEngine = enum \{ edge, chrome \}/);
  assert.match(source, /\\EdgeUserData/);
  assert.match(source, /\\ChromeUserData/);
  const selector = functionBody("browserUserDataDir", "browserEngineToken");
  assert.match(selector, /\.edge => edgeUserDataDir\(\)/);
  assert.match(selector, /\.chrome => chromeUserDataDir\(\)/);
  assert.match(source, /browser-engine\.txt/);
});

test("the selected engine owns executable, profile, extension, and bridge routing", () => {
  const launch = functionBody("shellExecuteEdgeUrl", "spawnBrowserCliHidden");
  assert.match(launch, /const user_data_dir = browserUserDataDir\(\)/);
  assert.match(launch, /browserProfile\(\)/);
  assert.match(launch, /browserExePath\(\)/);
  assert.match(launch, /appendEdgeExtensionLoadPaths/);
  assert.match(source, /Google\\\\Chrome\\\\Application\\\\chrome\.exe/);
  assert.match(source, /Software\\\\Google\\\\Chrome\\\\NativeMessagingHosts\\\\com\.zigshell\.bridge/);
  assert.match(source, /RegSetValueExA\(key, null, 0, REG_SZ/);
});

test("one global switch closes every old-engine pane before delayed relaunch", () => {
  const sw = functionBody("switchBrowserEngine", "discardBrowserUrlBarEdit");
  assert.match(sw, /g_browser_engine = next/);
  assert.match(sw, /saveBrowserEngineConfig\(\)/);
  assert.match(sw, /while \(i < shell_count\)/);
  assert.match(sw, /if \(shells\[i\]\.browser_enabled\) closeBrowserForShell\(i\)/);
  assert.match(sw, /SetTimer\(hwnd, TIMER_BROWSER_ENGINE_SWITCH, 1800/);
  assert.match(source, /WM_APP_BROWSER_ENGINE_TOGGLE => \{\s+switchBrowserEngine\(hwnd\)/);
  assert.match(source, /TIMER_BROWSER_ENGINE_SWITCH[\s\S]{0,180}?finishBrowserEngineSwitch\(hwnd\)/);
});

test("Ctrl+K exposes the global dedicated-browser choice", () => {
  assert.match(source, /SEARCH_BROWSER_ENGINE_OFFSET/);
  assert.match(source, /Browser Engine: Switch every pane to dedicated Chrome/);
  assert.match(source, /Browser Engine: Switch every pane to dedicated Edge/);
  assert.match(source, /target == SEARCH_BROWSER_ENGINE_OFFSET[\s\S]{0,260}?WM_APP_BROWSER_ENGINE_TOGGLE/);
});

test("Ctrl+K has an explicit browser-pane recovery command", () => {
  assert.match(
    functionBody("palettePrimaryLabel", "asciiStartsWithCI"),
    /SEARCH_BROWSER_TOGGLE_OFFSET => if \(active_shell < shell_count and shells\[active_shell\]\.browser_open_failed\) "retry browser pane" else if \(active_shell < shell_count and shells\[active_shell\]\.browser_hwnd == null and shells\[active_shell\]\.browser_launch_tick != 0\) "close browser pane" else "open browser pane"/,
  );
  assert.match(source, /L\("Open Browser Pane"\)/);
  assert.match(
    source,
    /target == SEARCH_BROWSER_TOGGLE_OFFSET[\s\S]{0,900}?if \(!browser_hwnd_live\)[\s\S]{0,260}?closeBrowserForShell\(active_shell\)[\s\S]{0,260}?openBrowserPaneForShell\(active_shell, ""\)/,
  );
});
