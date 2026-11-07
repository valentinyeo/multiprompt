const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
const browser = fs.readFileSync(path.join(root, 'src/browser_pane.zig'), 'utf8');
const telemetry = fs.readFileSync(path.join(root, 'src/telemetry_panel.zig'), 'utf8');
const power = fs.readFileSync(path.join(root, 'src/power.zig'), 'utf8');
function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('startup defers telemetry collector and browser chrome until the usage panel or pane is needed', () => {
  const footprint = fs.readFileSync(path.join(root, 'src/idle_footprint.zig'), 'utf8');
  assert.match(footprint, /pub fn passiveBrowserLaunchAllowed/);
  assert.match(footprint, /pub fn usageCollectorWanted/);
  const deferred = body(main, 'initializeDeferred');
  assert.doesNotMatch(deferred, /\.telemetry => \{[\s\S]*?ensureUsageTelemetryCollector/);
  assert.match(telemetry, /pub fn syncUsageTelemetryCollector/);
  assert.match(telemetry, /usageCollectorWanted/);
  assert.doesNotMatch(deferred, /relaunchActiveRestoredBrowserPane\(\)/);
  assert.match(browser, /passiveBrowserLaunchAllowed/);
  assert.match(body(browser, 'launchBrowserForShellEx'), /!user_initiated and !@import\("idle_footprint\.zig"\)\.passiveBrowserLaunchAllowed/);
});

test('deep idle stops chat refresh polling', () => {
  assert.match(power, /KillTimer\(hwnd, @import\("win32\.zig"\)\.TIMER_CHAT_REFRESH\)/);
});

test('status card hover syncs the usage collector', () => {
  assert.match(main, /card_hover != app_state\.g_status_card_hover[\s\S]*?syncUsageTelemetryCollector/);
});
