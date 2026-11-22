const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/IGSH-997/sample.json'), 'utf8'));

function capture(edit = () => {}) {
  const snapshot = structuredClone(fixture);
  snapshot.ts = Date.now() / 1000;
  edit(snapshot);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'usage-pace-'));
  try {
    const source = path.join(directory, 'status.json');
    fs.writeFileSync(source, JSON.stringify(snapshot));
    return spawnSync(process.platform === 'win32' ? 'python' : 'python3', [path.join(root, 'tools/capture-usage-pace.py'), source], { encoding: 'utf8' });
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

test('live pace capture keeps numeric windows but never account identity or credentials', () => {
  const result = capture(snapshot => {
    snapshot.accounts[0].label = 'private@example.test';
    snapshot.accounts[0].id = 'private-identity';
    snapshot.accounts[0].email = 'private@example.test';
    snapshot.accounts[0].host = 'private-host';
    snapshot.accounts[0].credential = 'not-a-secret';
    snapshot.accounts[0].week.pace.credential = 'not-a-secret';
  });
  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stdout, /private|credential|not-a-secret/);
  const value = JSON.parse(result.stdout);
  assert.equal(value.accounts[0].label, 'Claude 1');
  assert.equal(value.accounts[0].week.pace.per_hour, 2);
  assert.equal(value.accounts[0].five_hour.pace.per_day, 283);
  assert.equal(value.accounts[1].week.pace.empty_hours, 180);
});

test('live capture preserves unknown versus measured zero burn', () => {
  const result = capture(snapshot => {
    snapshot.accounts[0].week.pace.per_hour = null;
    snapshot.accounts[0].week.pace.per_day = 0;
  });
  assert.equal(result.status, 0, result.stderr);
  const value = JSON.parse(result.stdout);
  assert.equal(value.accounts[0].week.pace.per_hour, null);
  assert.equal(value.accounts[0].week.pace.per_day, 0);
});

test('the original status shape without pace is rejected before publication', () => {
  const result = capture(snapshot => { delete snapshot.accounts[0].week.pace; });
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /Missing pace block/);
});

test('stale snapshots and nonnumeric metrics cannot enter public evidence', () => {
  for (const edit of [snapshot => { snapshot.ts -= 2000; }, snapshot => { snapshot.accounts[0].week.pace.per_hour = 'not-a-number'; }]) {
    const result = capture(edit);
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
  }
});
