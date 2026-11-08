const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');

test('bypass sticks after a restart and answers helper approvals by itself', () => {
  const run = spawnSync('python3', ['tools/chat-history-reader-test.py', '-v',
    '-k', 'test_a_chosen_permission_mode_survives_an_agent_restart',
    '-k', 'test_bypass_answers_helper_approvals_without_asking',
    '-k', 'test_bypass_still_asks_questions'], { encoding: 'utf8', timeout: 120000 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.match(run.stderr, /Ran 3 tests/);
});
