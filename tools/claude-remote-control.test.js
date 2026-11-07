const {test} = require('node:test');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');

for (const name of [
  'HostControlTest.test_claude_start_enables_remote_control_without_a_model_prompt',
  'HostControlTest.test_remote_control_rejection_does_not_stop_normal_chat',
  'HostRemoteControlTest.test_host_enables_remote_control_and_still_answers_the_first_message',
]) {
  test(name, () => {
    const result = spawnSync('python3', ['tools/chat-history-reader-test.py', name], {
      encoding: 'utf8', timeout: 45000,
      env: {...process.env, HISTORY_READER_SHARD: ''},
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  });
}
