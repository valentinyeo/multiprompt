const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { discoverFeatures } = require('./verify-features.cjs');
const { validateSelection } = require('./pr-verifier.cjs');

const root = path.resolve(__dirname, '..');

test('the PR verifier can select the journey that proves All sessions states and server counts', () => {
  const available = discoverFeatures().available;
  const selected = validateSelection({ features: ['all-sessions'], compare_base: true }, available);
  assert.deepEqual(selected.features, ['all-sessions']);
  assert.deepEqual(selected.dropped, []);
  const control = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control.ps1'), 'utf8');
  assert.match(control, /'all-sessions'/);
  assert.match(control, /control-feature-all-sessions\.ps1/);
  const driver = fs.readFileSync(path.join(root, '.claude/skills/verify-multiprompt/control-feature-all-sessions.ps1'), 'utf8');
  for (const check of ['summary', 'server-chips', 'state-tabs', 'row-fields', 'server-key', 'server-palette', 'existing-actions']) {
    assert.ok(driver.includes(`name = '${check}'`), `missing Done-when check ${check}`);
  }
});
