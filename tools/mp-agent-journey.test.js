const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { discoverFeatures } = require('./verify-features.cjs');

test('the agent rename journey is selectable without joining desktop smoke tests', () => {
  const features = discoverFeatures();
  assert.ok(features.available.includes('agent-sync'), 'the verifier must be able to run the server rename journey');
  assert.ok(!features.pr.includes('agent-sync'));
  assert.ok(!features.full.includes('agent-sync'));
});

test('a published rename preserves its agent and reaches the agent CLI exactly once', () => {
  const result = spawnSync('python3', ['tools/mp-agent-sync-test.py'], { cwd: require('node:path').join(__dirname, '..'), encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
