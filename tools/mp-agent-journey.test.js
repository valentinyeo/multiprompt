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

test('the production reader accepts a chat rename over its stdin protocol', t => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-publish-'));
  t.after(() => fs.rmSync(home, { recursive: true, force: true }));
  const name = 'Renamed & "exact" café';
  const result = spawnSync('python3', ['src/chat_history_reader.py', '--serve'], {
    cwd: path.join(__dirname, '..'), env: { ...process.env, HOME: home },
    input: JSON.stringify({ id: 1, op: 'chat_names', names: [{ tmux: 'journey-chat', name }] }) + '\n',
    encoding: 'utf8', timeout: 30000,
  });
  assert.equal(result.status, 0, result.stderr);
  const reply = result.stdout.split('\n').filter(Boolean).map(line => JSON.parse(line)).find(value => value.id === 1);
  assert.equal(reply?.result?.status, 'ok');
  const stored = JSON.parse(fs.readFileSync(path.join(home, '.local/state/multiprompt/chat-names.json'), 'utf8'));
  assert.equal(stored['journey-chat'].name, name);
});
