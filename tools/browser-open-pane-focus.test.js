const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { readControlSource } = require('./app-source');

const control = readControlSource();
const journey = control.slice(control.indexOf("        'browser-switch-speed' {"), control.indexOf("        'browser-pane-locked' {"));
const snapshot = fs.readFileSync(path.join(__dirname, 'fixtures', 'HYCI-158', 'open-pane-before.ps1'), 'utf8');
const foreground = "if ([VerifyNative]::GetForegroundWindow() -ne $browser) { throw 'Opening the pane did not focus its browser' }";
const space = "if (-not [VerifyNative]::Title($browser).StartsWith(($pageTitle + ' keys ' + $pageKeys + ' '), [StringComparison]::Ordinal)) { throw 'IGSH-724 opening a pane sent Space to browser chrome' }";

function assertsOpenPaneHopSync(driver) {
  const palette = driver.indexOf("Palette 'open browser'");
  const offset = driver.indexOf("$hopStart = (Read-SharedText $hopLog).Length", palette);
  const press = driver.indexOf("Press @(0x0D) 'IGSH-724: opening an existing pane focuses its page'", palette);
  const wait = driver.indexOf("-match 'pane_hop result bh_fg=true' } 'IGSH-998 app finished the open-pane hop to its browser'", palette);
  const foreground = driver.indexOf("throw 'Opening the pane did not focus its browser'", palette);
  const space = driver.indexOf("throw 'IGSH-724 opening a pane sent Space to browser chrome'", palette);
  assert.ok(palette >= 0 && palette < offset && offset < press && press < wait && wait < foreground && foreground < space);
}

function assertsFocusChecks(driver) {
  assert.ok(driver.includes(foreground));
  assert.ok(driver.includes(space));
}

test('HYCI-158 rejects the original open-pane sequence and accepts the repaired journey', () => {
  assertsFocusChecks(snapshot);
  assertsFocusChecks(journey);
  assert.throws(() => assertsOpenPaneHopSync(snapshot), assert.AssertionError);
  assertsOpenPaneHopSync(journey);
});

test('HYCI-158 detects a missing completion wait and weakened focus checks', () => {
  const wait = /^ *Wait-Until \{ \(Read-SharedText \$hopLog\)[^\n]*\r?\n/m;
  assert.match(journey, wait);
  assert.throws(() => assertsOpenPaneHopSync(journey.replace(wait, '')), assert.AssertionError);
  assert.throws(() => assertsFocusChecks(journey.replace(foreground, foreground.replace('-ne', '-eq'))), assert.AssertionError);
  assert.throws(() => assertsFocusChecks(journey.replace(space, space.replace('-not ', ''))), assert.AssertionError);
});
