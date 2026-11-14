const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');

test('runner ledgers stay out of the repository', () => {
  const tracked = execFileSync('git', ['ls-files', '.unlazy'], { cwd: root, encoding: 'utf8' }).trim();
  assert.equal(tracked, '', 'no ledger file is committed');
  const ignore = fs.readFileSync(path.join(root, '.gitignore'), 'utf8').split('\n').map(line => line.trim());
  assert.ok(ignore.includes('.unlazy/'), '.unlazy/ is ignored');
});
