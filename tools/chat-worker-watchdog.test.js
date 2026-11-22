const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');

for (const name of [
  'test_stuck_discovery_releases_the_shared_writer',
  'test_server_answers_chat_b_before_stuck_chat_a',
  'test_worker_watchdog_fails_only_its_chat_and_logs_once',
  'test_worker_watchdog_detects_repeated_busy_without_progress',
  'test_idle_accepted_chat_is_not_a_watchdog_jam',
]) {
  test(name, () => {
    const result = spawnSync('python3', ['tools/chat-history-reader-test.py', `IGSH_1266_SharedMessageHostTest.${name}`], {
      encoding: 'utf8', timeout: 15000,
      env: {...process.env, HISTORY_READER_SHARD: ''},
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  });
}
