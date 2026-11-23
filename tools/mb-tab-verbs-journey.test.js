const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const root = path.join(__dirname, '..');
const skill = '.claude/skills/verify-multiprompt/';
const stems = [
  'mb-tab-open', 'mb-tab-close', 'mb-tab-move', 'mb-tab-pin', 'mb-tab-unpin',
  'mb-tab-archive', 'mb-tab-unarchive', 'mb-tab-wait', 'mb-tab-restore',
  'mb-tab-layout-sync', 'mb-tab-idempotent',
];

test('SOFT-3142 every mb tab stem is registered and mapped', () => {
  const control = fs.readFileSync(path.join(root, skill, 'control.ps1'), 'utf8');
  const driver = fs.readFileSync(path.join(root, skill, 'control-feature-mb-tab-verbs.ps1'), 'utf8');
  const { discoverFeatures } = require('./verify-features.cjs');
  const available = discoverFeatures(path.join(root, skill, 'features')).available;
  for (const stem of stems) {
    assert.match(control, new RegExp(`'${stem}'`), `${stem} must be in control.ps1 ValidateSet`);
    assert.ok(available.includes(stem), `${stem} must be an available journey`);
    const map = fs.readFileSync(path.join(root, skill, 'features', `${stem}.md`), 'utf8');
    assert.match(map, /^Source files: /m);
    assert.match(map, /tools\/mp-layout\.mjs/);
    if (stem === 'mb-tab-layout-sync') assert.match(map, /session_layout_sync\.zig/);
    assert.match(map, /control-feature-mb-tab-verbs\.ps1/);
    assert.match(map, /^## Driving it with control\.ps1$/m);
  }
  assert.match(control, /if \(\$Feature -match '\^mb-tab-'\) \{[\s\S]*control-feature-mb-tab-verbs\.ps1/);
  assert.match(driver, /throw "Journey condition not met:/);
  assert.match(driver, /Join-Path \$Evidence 'result\.json'/);
  assert.match(driver, /Join-Path \$Evidence 'before\.png'/);
  assert.match(driver, /Join-Path \$Evidence 'after\.png'/);
  assert.match(driver, /function Assert-MbTabVerbLine/);
  assert.match(driver, /@\('pin', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('unpin', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('wait', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('restore', \$MbTabSession, '--host', '0'\)/);
  assert.match(driver, /@\('archive', \$MbTabSession, '--host', '0'\)/);
  assert.doesNotMatch(driver, /'pin', \$MbTabSession, 'on'/);
  assert.doesNotMatch(driver, /'wait', \$MbTabSession, 'on'/);
  assert.doesNotMatch(driver, /--no-tmux/);
  const { touchedJourneys } = require('./touched-journeys.cjs');
  const picked = touchedJourneys(['src/session_layout_sync.zig'], path.join(root, skill, 'features'));
  assert.deepEqual(picked.features, ['mb-tab-layout-sync']);
});