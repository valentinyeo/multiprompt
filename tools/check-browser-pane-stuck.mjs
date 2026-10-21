import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const directory = '.claude/skills/verify-multiprompt';
const driver = read(`${directory}/control.ps1`);
const workflow = read('.github/workflows/verify.yml');
const map = read(`${directory}/features/browser-pane-stuck.md`);

for (const [file, names] of [
  ['src/browser_pane.zig', [
    'IGSH-523 opening close keeps URL, reopen isolates replies, timeout permits retry',
    'IGSH-523 connected pane stays visible without an extension past the opening deadline',
    'IGSH-523 cancelled launches reuse expired slots and evict oldest when full',
    'browserPlaceholderPure applies the deadline only to uncovered slots',
  ]],
  ['src/shortcuts.zig', [
    'Alt browser open guard rejects a delayed complete second chord',
    'Alt browser shortcut recovers an enabled pane with no live window',
  ]],
]) {
  assert.ok(read('src/main.zig').includes(`_ = @import("${path.basename(file)}");`), `${file} is in the desktop unit suite`);
  for (const name of names) assert.ok(read(file).includes(`test "${name}"`), `behavior unit exists: ${name}`);
}

function prMatrixContract(source) {
  assert.match(source, /feature:.*github\.event_name == 'pull_request'.*fromJSON\('\["appearance", "browser-pane-stuck"\]'\)/);
  assert.ok(source.includes('FEATURE: ${{ matrix.feature }}'));
  for (const trigger of ['src/**', 'tools/check-browser-pane-stuck.mjs']) assert.ok(source.includes(`      - ${trigger}`));
}
prMatrixContract(workflow);
assert.throws(() => prMatrixContract(workflow.replace('["appearance", "browser-pane-stuck"]', '["appearance"]')));

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
for (const step of ['initial-open', 'shortcut-close', 'reopen-after-shortcut', 'palette-close-all', 'reopen-after-close-all', 'palette-close-pane', 'reopen-after-close-pane', 'connected-pane-docked', 'connected-pane-stays-visible', 'shift-a-toggle', 'shift-b-toggle', 'final-close']) {
  assert.ok(driver.includes(`'${step}'`), `journey asserts ${step}`);
}
for (const observation of ['GetProp(hwnd, "ZigShellPaneOwner")', 'IsWindowVisible(hwnd)', 'GetWindowRect(hwnd, out pane)', 'AddSeconds(21)', 'Assert-ConnectedPaneStaysVisible $fourth.browser_connection_id']) {
  assert.ok(driver.includes(observation), `connected journey observes ${observation}`);
}
for (const input of ['Press @(0x12, 0x41)', "Palette 'close all browser panes'", 'Press @(0x12, 0x10, 0x41)', 'Press @(0x12, 0x10, 0x42)']) {
  assert.ok(driver.includes(input), `real input: ${input}`);
}
function inboxPrivacyContract(source) {
  assert.ok(!source.includes('browser_url'), 'inbox must not publish pane URLs');
}
const inbox = read('src/inbox.zig');
const inboxEnd = inbox.indexOf('const tail = "]}";');
assert.ok(inboxEnd > 0, 'inbox serialization boundary exists');
inboxPrivacyContract(inbox.slice(0, inboxEnd));
assert.throws(() => inboxPrivacyContract('const pane_url = "browser_url";'));
assert.ok(!driver.includes('browser_url'), 'journey must not require URL disclosure');
assert.ok(workflow.includes('node tools/check-browser-pane-stuck.mjs'));
assert.ok(read(`${directory}/SKILL.md`).includes('node tools/check-browser-pane-stuck.mjs'));
console.log('browser-pane-stuck checks passed (static wiring only; behavior units and desktop journey require Windows CI)');
