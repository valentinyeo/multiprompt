const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const workflow = name => fs.readFileSync(path.join(root, '.github/workflows', name), 'utf8');

test('automerge stays disabled without automatic triggers', () => {
  const text = workflow('automerge.yml');
  const events = text.split('\non:\n')[1].split('\npermissions:')[0];
  assert.match(events, /^  workflow_dispatch:/m);
  assert.doesNotMatch(events, /^  (?:pull_request|push|schedule|workflow_run):/m);
  assert.match(text, /^  automerge:\n    if: \$\{\{ false \}\}/m);
});

test('appearance verification runs manually and nightly, not on pushes or PRs', () => {
  const text = workflow('verify.yml');
  const events = text.split('\non:\n')[1].split('\npermissions:')[0];
  assert.match(events, /^  workflow_dispatch:/m);
  assert.match(events, /^  schedule:/m);
  assert.match(events, /default: appearance/);
  assert.doesNotMatch(events, /^  (?:pull_request|push|workflow_run):/m);
});

for (const name of ['chat-bench-ab.yml', 'chat-table-bench.yml', 'probe-chrome-frameless.yml']) {
  test(`${name} starts manually or nightly`, () => {
    const events = workflow(name).split('\non:\n')[1].split('\npermissions:')[0];
    assert.match(events, /^  workflow_dispatch:/m);
    assert.match(events, /^  schedule:/m);
    assert.doesNotMatch(events, /^  (?:pull_request|push|workflow_run):/m);
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
