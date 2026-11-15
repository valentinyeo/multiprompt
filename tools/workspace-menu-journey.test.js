const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { discoverFeatures } = require('./verify-features.cjs');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('SOFT-2374 the verifier can run the contested-registry menu and hover journey', () => {
  assert.ok(discoverFeatures().available.includes('workspace-menu'));
  const driver = read('.claude/skills/verify-multiprompt/control.ps1');
  assert.match(driver, /'workspace-menu' \{ \. \(Join-Path \$PSScriptRoot 'workspace-menu.ps1'\) \}/);
  const journey = read('.claude/skills/verify-multiprompt/workspace-menu.ps1');
  assert.match(journey, /HoldRegistry/);
  assert.match(journey, /AssertResponsive/);
  assert.match(journey, /AssertHighlight/);
  assert.match(journey, /Read-Session/);
});

test('SOFT-2374 hosted clicks send an absolute mouse move before button input', () => {
  const native = read('.claude/skills/verify-multiprompt/control-native.cs');
  const click = native.slice(native.indexOf('public static void ClickClient('), native.indexOf('public static void RightClickTranscript('));
  assert.match(click, /MouseAt\(point.X, point.Y, 0\)/);
  assert.doesNotMatch(click, /SetCursorPos/);
  assert.ok(click.indexOf('MouseAt(') < click.indexOf('foreach (uint flags'));
});

test('SOFT-2374 group-rail opens the current command prompt action by its stable target', () => {
  const group = read('.claude/skills/verify-multiprompt/control-feature-group-rail.ps1');
  assert.doesNotMatch(group, /Palette 'new cmd'/);
  assert.match(group, /Palette 'command prompt' '5100'/);
});
