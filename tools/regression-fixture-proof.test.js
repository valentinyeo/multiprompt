const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { checkBugFixtureErrors } = require('./regression-fixture.cjs');

const root = path.join(__dirname, '..');
const fixtureDir = 'tools/fixtures/SOFT-3144/';
const sample = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-3144/pr-1269.json'), 'utf8'));
assert.ok(sample.title && fixtureDir);
const gate = fs.readFileSync(path.join(__dirname, 'regression-fixture.cjs'), 'utf8').includes('checkBugFixtureErrors');

test('SOFT-3144 requires the bug-fix fixture gate on head', () => {
  if (process.env.REGRESSION_REPRO_BASE === '1') {
    assert.equal(gate, false);
    return;
  }
  assert.equal(gate, true);
  assert.ok(Array.isArray(sample.files) && sample.files.length, 'fixture must ship the captured PR file list');
  const files = sample.files;
  const errors = checkBugFixtureErrors({
    base: sample.base,
    root,
    pr: { title: sample.title, body: sample.body, labels: [] },
    files,
  });
  assert.ok(errors.length, errors.join('; '));
  assert.match(errors.join('\n'), /tools\/fixtures\/IGSH-3097/);
});