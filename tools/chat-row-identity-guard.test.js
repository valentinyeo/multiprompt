const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/test.yml'), 'utf8');
const step = workflow.split('- name: Prove hosted row regressions fail on the identity-only source')[1].split('- name:')[0];
const guard = step.match(/if ! (grep .+) \.chat-row-base\/src\/chat_echo\.zig; then/)[1];

for (const [name, source, expected] of [
  ['reverted source with the unrelated reconnect parameter', 'pub fn requeueOnReconnect(state: OutboxState, has_client_id: bool) bool {\n    return has_client_id;\n}\n', 1],
  ['identity-only pending field', 'pub const Pending = struct {\n    client_id: u64 = 0,\n};\n', 0],
]) {
  test(`SOFT-3083 hosted row proof detects ${name}`, { skip: process.platform === 'win32' }, () => {
    const result = spawnSync('sh', ['-c', guard], { input: source, encoding: 'utf8', timeout: 5000 });
    assert.equal(result.status, expected, result.stdout + result.stderr);
  });
}
