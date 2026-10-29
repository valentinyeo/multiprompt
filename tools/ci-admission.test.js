const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const workflow = name => fs.readFileSync(path.join(root, '.github/workflows', name), 'utf8');

test('only completed PR checks wake automerge, without a timer', () => {
  const text = workflow('automerge.yml');
  assert.match(text, /workflows: \[Tests, Verify desktop, PR checks, Gitleaks, Ledger guard, check-red-run\]/);
  assert.match(text, /branches-ignore: \[master\]/);
  assert.doesNotMatch(text, /schedule:|cron:|concurrency:/);
});

test('IGSH-1113 required appearance covers every edit without losing native or journey coverage', () => {
  const text = workflow('verify.yml');
  const paths = text.split('  pull_request:\n')[1].split('\npermissions:')[0];
  assert.match(paths, /- ['"]?\*\*['"]?\s*$/m);
  assert.match(paths, /- src\/\*\*/);
  assert.match(paths, /- \.claude\/skills\/verify-multiprompt\/\*\*/);
});

for (const name of ['chat-bench-ab.yml', 'chat-table-bench.yml', 'probe-chrome-frameless.yml']) {
  test(`${name} starts only on explicit dispatch`, () => {
    const events = workflow(name).split('\non:\n')[1].split('\npermissions:')[0];
    assert.match(events, /^  workflow_dispatch:/m);
    assert.doesNotMatch(events, /^  (?:pull_request|push|schedule|workflow_run):/m);
  });
}

test('admission stays in the unchanged policy script', () => {
  const text = workflow('automerge.yml');
  assert.match(text, /node tools\/automerge-admit-run\.js/);
  const runnerPath = path.join(root, 'tools/automerge-admit-run.js');
  assert.ok(fs.existsSync(runnerPath), 'event-scoped runner exists');
  const runner = fs.readFileSync(runnerPath, 'utf8');
  assert.match(runner, /'automerge-admit.sh'/);
  assert.match(runner, /expectedHeadOid: \$head/);
});
