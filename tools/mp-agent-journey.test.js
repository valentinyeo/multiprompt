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

test('the hosted journey cannot inherit the runner configuration or install directory', t => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-environment-'));
  t.after(() => fs.rmSync(home, { recursive: true, force: true }));
  fs.writeFileSync(path.join(home, 'verify-agent-sync.py'), 'import json, os\nprint(json.dumps({key: os.environ.get(key) for key in ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "MP_TALK_BIN")}))\n');
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/verify.yml'), 'utf8');
  const launch = workflow.match(/sudo -u mp-agent-journey (env [^\n]+)/)?.[1];
  assert.ok(launch, 'the Linux journey must launch with its own environment');
  const result = spawnSync('/bin/bash', ['-c', launch.replaceAll('/home/mp-agent-journey', home)], {
    env: { ...process.env, HOME: '/blocked-runner', XDG_CONFIG_HOME: '/blocked-runner/config', XDG_DATA_HOME: '/blocked-runner/data', MP_TALK_BIN: '/blocked-runner/bin', uid: '12345' },
    encoding: 'utf8', timeout: 10000,
  });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { HOME: home, XDG_CONFIG_HOME: path.join(home, '.config'), XDG_DATA_HOME: path.join(home, '.local/share'), MP_TALK_BIN: null });
});
