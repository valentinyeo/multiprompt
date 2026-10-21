import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const directory = '.claude/skills/verify-multiprompt';
const pane = read('src/browser_pane.zig');
const shortcuts = read('src/shortcuts.zig');
const main = read('src/main.zig');
const state = read('src/app_state.zig');
const driver = read(`${directory}/control.ps1`);
const workflow = read('.github/workflows/verify.yml');
const map = read(`${directory}/features/browser-pane-stuck.md`);

function openingCloseContract(source) {
  assert.match(source, /pub fn physicalBrowserShortcutMayClose\([^]*?if \(launch_tick != 0\) return true;/);
}

function openingTimeoutContract(source) {
  const body = source.match(/fn browserPlaceholderPure\([^]*?\n\}/)?.[0];
  assert.ok(body, 'placeholder state logic must exist');
  assert.match(body, /if \(shown_ms >= BROWSER_PLACEHOLDER_NOT_OPEN_MS\) return \.failed;/);
}

openingCloseContract(shortcuts);
openingTimeoutContract(pane);
assert.throws(() => openingCloseContract(shortcuts.replace('if (launch_tick != 0) return true;', 'if (launch_tick != 0) return false;')));
assert.throws(() => openingTimeoutContract(pane.replace('if (shown_ms >= BROWSER_PLACEHOLDER_NOT_OPEN_MS)', 'if (shown_ms >= BROWSER_PLACEHOLDER_NOT_OPEN_MS and !launch_in_flight)')));
assert.match(state, /BROWSER_PLACEHOLDER_NOT_OPEN_MS: u64 = 20_000;/);
assert.match(pane, /test "IGSH-523 opening close keeps URL, reopen isolates replies, timeout permits retry"/);
for (const outcome of ['closed', 'opening', 'failed', 'connected']) {
  assert.ok(pane.includes(`expectEqualStrings("${outcome}", browserConnectionState(&sh))`), `unit regression asserts ${outcome}`);
}
assert.match(pane, /expectEqualStrings\(url, sh\.browser_url\[0\.\.sh\.browser_url_len\]\)/);
assert.match(pane, /expect\(!browserConnectionMatches\(&sh, 1\)\)/);
assert.match(pane, /expect\(browserOpeningExpired\(&sh, 22_000\)\)/);
assert.match(pane, /job\.\* = \.\{ \.shell_id = shell_id, \.connection_id = app_state\.shells\[idx\]\.browser_connection_id \};/);
assert.match(pane, /if \(!browserConnectionMatches\(&app_state\.shells\[idx\], job\.connection_id\) or job\.window_id <= 0\) return;/);
const reset = pane.match(/fn resetBrowserConnection\([^]*?\n\}/)?.[0];
assert.ok(reset);
assert.doesNotMatch(reset, /sh\.browser_url(?:_len)?\s*=/);
assert.throws(() => assert.doesNotMatch(`${reset}\nsh.browser_url_len = 0;`, /sh\.browser_url(?:_len)?\s*=/));
for (const field of ['browser_connection_id', 'browser_launch_tick', 'browser_bind_nonce_len', 'browser_pending_url_len', 'browser_window_id']) {
  assert.ok(reset.includes(`sh.${field} = 0;`), `teardown clears ${field}`);
}
assert.match(pane, /if \(browserOpeningExpired\(&app_state\.shells\[i\], now\)\) \{[^]*?closeBrowserForShell\(@intCast\(i\)\);[^]*?browser_open_failed = true;/);
assert.match(pane, /L\("Browser could not connect\."\)/);
assert.match(pane, /if \(retry\) L\("Retry"\) else L\("Close"\)/);
assert.match(shortcuts, /\.a = "Alt\+Shift\+A"/);
assert.match(read('src/command_palette.zig'), /"retry browser pane"/);
assert.match(read('src/sidebar.zig'), /L\("Retry Browser Pane"\)/);
assert.match(main, /if \(wp == 2\) \{[^]*?browser_open_failed\)[^]*?openBrowserPaneForShell\(app_state\.active_shell, ""\);/);
assert.match(main, /target == SEARCH_CLOSE_ALL_BROWSER_PANES_OFFSET[^]*?browser_enabled = false;[^]*?closeBrowserForShell\(@intCast\(i\)\);/);

const featureFiles = fs.readdirSync(path.join(root, directory, 'features')).filter(name => name.endsWith('.md') && name !== 'README.md');
const index = read(`${directory}/features/README.md`);
const allowed = driver.match(/ValidateSet\(([^)]*)\)/)?.[1].match(/'([^']+)'/g).map(value => value.slice(1, -1));
assert.deepEqual([...allowed].sort(), featureFiles.map(file => file.slice(0, -3)).sort());
for (const file of featureFiles) {
  const name = file.slice(0, -3);
  assert.ok(index.includes(`](${file})`), `index lists ${name}`);
  assert.ok(workflow.includes(`'${name}'`), `workflow allows ${name}`);
  assert.ok(driver.includes(`        '${name}' {`), `driver implements ${name}`);
}
for (const section of ['Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas']) {
  assert.ok(map.includes(`## ${section}`), `feature map has ${section}`);
}
const recipe = driver.match(/        'browser-pane-stuck' \{([^]*?)\n        \}/)?.[1];
assert.ok(recipe);
for (const step of ['initial-opening', 'shortcut-close', 'reopen-after-shortcut', 'palette-close-all', 'reopen-after-close-all', 'palette-close-pane', 'reopen-after-close-pane', 'opening-timeout', 'shortcut-retry', 'final-close']) {
  assert.ok(recipe.includes(`'${step}'`), `journey asserts ${step}`);
}
for (const input of ["Press @(0x12, 0x43)", "Press @(0x12, 0x41)", "Palette 'close all browser panes'", "Press @(0x12, 0x10, 0x41)"]) {
  assert.ok(recipe.includes(input), `real input: ${input}`);
}
const observer = driver.match(/function Assert-BrowserPane\([^]*?\n\}/)?.[0];
assert.ok(observer);
for (const condition of ['Read-BrowserPane', '$pane.browser_state -eq $State', '$pane.browser_connection_id -gt $PreviousId', '$pane.browser_connection_id -eq 0', '$pane.browser_url -eq $Url', '$pane.browser_window_id -ne 0', 'throw', 'Write-Host "browser-pane-stuck $Step PASS"']) {
  assert.ok(observer.includes(condition), `state oracle requires ${condition}`);
}
assert.ok(observer.indexOf('Wait-Until') < observer.indexOf('Write-Host'));
assert.match(driver, /throw "Missing precondition or resulting state:/);
assert.match(driver, /\$result\.status = 'passed'[^]*?catch \{[^]*?\$result\.error = \$_\.Exception\.Message/);
assert.match(driver, /if \(\$result\.status -ne 'passed'\)/);
for (const field of ['browser_state', 'browser_connection_id', 'browser_window_id', 'browser_url']) {
  assert.ok(read('src/inbox.zig').includes(`\\"${field}\\"`), `app publishes ${field}`);
}
assert.ok(workflow.includes('node tools/check-browser-pane-stuck.mjs'));
assert.ok(read(`${directory}/SKILL.md`).includes('node tools/check-browser-pane-stuck.mjs'));
console.log('browser-pane-stuck static contracts PASS (including old-guard and old-timeout negative controls)');
