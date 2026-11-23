const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.join(__dirname, '..');
const fixtureDir = 'tools/fixtures/SOFT-3144/';
const sample = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-3144/pr-1269.json'), 'utf8'));
assert.ok(sample.title && fixtureDir);

function gatePresent(root) {
  const file = path.join(root, 'tools/regression-fixture.cjs');
  return fs.existsSync(file) && fs.readFileSync(file, 'utf8').includes('checkBugFixtureErrors');
}

test('SOFT-3144 requires the bug-fix fixture gate on head', () => {
  assert.equal(gatePresent(repoRoot), true, 'bug-fix fixture gate missing');
  const { checkBugFixtureErrors } = require('./regression-fixture.cjs');
  assert.ok(Array.isArray(sample.files) && sample.files.length, 'fixture must ship the captured PR file list');
  const errors = checkBugFixtureErrors({
    base: sample.base,
    root: repoRoot,
    pr: { title: sample.title, body: sample.body, labels: [] },
    files: sample.files,
  });
  assert.ok(errors.length, errors.join('; '));
  assert.match(errors.join('\n'), /tools\/fixtures\/IGSH-3097/);
});