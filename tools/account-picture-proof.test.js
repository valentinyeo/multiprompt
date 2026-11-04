const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const checker = path.join(__dirname, 'check-account-picture-proof.mjs');
const desktop = { status: 'passed', cleanup: 0, uploaded_at: '2026-01-01T00:00:00.000Z', photo_revision: 2, account_picture_sha256: '1'.repeat(64), app_sha256: '2'.repeat(64) };
const phone = { status: 'passed', rendered_at: '2026-01-01T00:00:05.000Z' };
function run(t, left = desktop, right = phone) {
  assert.ok(fs.existsSync(checker), 'Live picture proof must have a receipt verifier');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'picture-proof-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.writeFileSync(path.join(dir, 'desktop.json'), JSON.stringify(left));
  fs.writeFileSync(path.join(dir, 'phone.json'), JSON.stringify(right));
  return spawnSync(process.execPath, [checker, path.join(dir, 'desktop.json'), path.join(dir, 'phone.json')], { encoding: 'utf8' });
}

test('shared Windows verification uses a portable CPU target', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/verify.yml'), 'utf8');
  const command = workflow.slice(workflow.indexOf('- name: Build the Windows app once for this push')).split('\n').find(line => line.includes('run: zig build'));
  assert.match(command, /-Dtarget=x86_64-windows-gnu\b/);
  assert.match(command, /-Dcpu=baseline\b/);
});

test('live picture proof measures the actual upload-to-render interval', t => {
  const result = run(t);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { status: 'passed', seconds: 5, photo_revision: 2 });
});

test('late or backwards phone pictures cannot pass', t => {
  for (const rendered_at of ['2026-01-01T00:01:00.001Z', '2025-12-31T23:59:59Z']) {
    assert.equal(run(t, desktop, { ...phone, rendered_at }).status, 1);
  }
});

test('failed journeys, missing account evidence and ambiguous clocks cannot pass', t => {
  for (const left of [{ ...desktop, status: 'failed' }, { ...desktop, cleanup: 1 }, { ...desktop, photo_revision: 0 }, { ...desktop, account_picture_sha256: null }, { ...desktop, app_sha256: '' }, { ...desktop, uploaded_at: '2026-01-01T00:00:00' }]) {
    assert.equal(run(t, left).status, 1);
  }
  for (const right of [{ ...phone, status: 'failed' }, { ...phone, rendered_at: null }, { ...phone, rendered_at: 'not a timestamp' }]) {
    assert.equal(run(t, desktop, right).status, 1);
  }
});
