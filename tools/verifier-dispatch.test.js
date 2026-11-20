const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const read = name => fs.readFileSync(path.join(__dirname, '..', '.github', 'workflows', name), 'utf8');

test('verify runs for different revisions never share a concurrency group', () => {
  const group = read('verify.yml').match(/^concurrency:\n  group: (.+)$/m)[1];
  assert.match(group, /inputs\.revision/);
});

test('a dispatched verdict is recorded as a check run on the pull request head', () => {
  const workflow = read('pr-verifier.yml');
  assert.match(workflow, /checks: write/);
  assert.match(workflow, /repos\/\$REPO\/check-runs/);
  assert.match(workflow, /head_sha="\$HEAD_SHA"/);
});
