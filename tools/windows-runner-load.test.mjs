import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const root = new URL('..', import.meta.url);
const read = name => fs.readFileSync(new URL(name, root), 'utf8');
const concurrency = /^concurrency:\n  group: \$\{\{ github\.workflow \}\}-\$\{\{ github\.ref \}\}\n  cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}/m;

test('PR Windows workflows cancel only the superseded pull request', () => {
  for (const file of [
    '.github/workflows/test.yml',
    '.github/workflows/account-journey.yml',
    '.github/workflows/verify-reconnect.yml',
    '.github/workflows/verify-close-unattached.yml',
    '.github/workflows/chat-history-retention.yml',
    '.github/workflows/session-notes.yml',
  ]) assert.match(read(file), concurrency, file);
  const remote = read('.github/workflows/remote-switch.yml');
  assert.match(remote, /group: remote-switch-\$\{\{ github\.ref \}\}/);
  assert.match(remote, /cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}/);
  assert.doesNotMatch(remote, /cancel-in-progress: true/);
});

test('bench and repeat cap their inputs and refuse a second Windows job on the same ref', () => {
  const bench = read('.github/workflows/chat-table-bench.yml');
  assert.match(bench, /cancel-in-progress: false/);
  assert.match(bench, /actions: read/);
  assert.match(bench, /default: 7/);
  assert.match(bench, /GUARD_SAMPLES: \$\{\{ inputs\.samples \}\}/);
  assert.match(bench, /node tools\/same-ref-guard\.mjs/);
  assert.match(bench, /if: needs\.guard\.outputs\.run == 'true'/);
  assert.match(bench, /1\.\.7/);
  const repeat = read('.github/workflows/test-repeat.yml');
  assert.match(repeat, /default: 1/);
  assert.match(repeat, /1 to 3/);
  assert.match(repeat, /GUARD_COUNT_MAX: '3'/);
  assert.match(repeat, /max-parallel: 3/);
  assert.match(repeat, /cancel-in-progress: false/);
  assert.match(repeat, /if: needs\.plan\.outputs\.run == 'true'/);
  assert.match(repeat, /\^\[1-3\]\$/);
});

test('a pull request reports verify appearance without starting that journey when appearance files stayed', () => {
  const verify = read('.github/workflows/verify.yml');
  assert.match(verify, /features: \$\{\{ steps\.sel\.outputs\.features \}\}/);
  assert.match(verify, /node tools\/classify-verify-features\.mjs/);
  assert.match(verify, /name: \$\{\{ github\.event_name == 'pull_request' && needs\.features\.outputs\.appearance != 'true' && 'verify \(appearance\)' \|\| 'verify-appearance-hold' \}\}/);
  assert.match(verify, /Appearance files did not change/);
  assert.match(read('.github/workflows/release-gate.yml'), /feature: relaunch-saved-sessions/);
  assert.match(read('.github/workflows/gitleaks.yml'), concurrency);
  assert.match(read('.github/workflows/automerge.yml'), /workflows: \[Tests\]/);
});
