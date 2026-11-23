const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { checkBugFixtureErrors } = require('./regression-fixture.cjs');

const root = path.join(__dirname, '..');
const sample = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-3144/pr-1269.json'), 'utf8'));
const gate = fs.readFileSync(path.join(__dirname, 'regression-fixture.cjs'), 'utf8').includes('checkBugFixtureErrors');

test('SOFT-3144 requires the bug-fix fixture gate on head', () => {
  if (process.env.REGRESSION_REPRO_BASE === '1') {
    assert.equal(gate, false);
    return;
  }
  assert.equal(gate, true);
  const files = execFileSync('git', ['diff', '--name-only', `${sample.base}...b6adfc98f84b964fd9bb39c48091967180c14d7b`], { cwd: root, encoding: 'utf8' })
    .split(/\r?\n/).filter(Boolean);
  const errors = checkBugFixtureErrors({
    base: sample.base,
    root,
    pr: { title: sample.title, body: sample.body, labels: [] },
    files,
  });
  assert.ok(errors.length, errors.join('; '));
  assert.match(errors.join('\n'), /tools\/fixtures\/IGSH-3097/);
});