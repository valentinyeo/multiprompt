const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const fixture = path.join(root, 'src/testdata/mubo-577-release-notes.json');
const proof = path.join(root, 'tools/update-card-release-proof.ps1');
const zig = process.env.ZIG_EXE || 'zig';

test('the real published release paints its change lines on the update card', {
  skip: process.platform !== 'win32' || process.env.GITHUB_ACTIONS !== 'true',
  timeout: 300000,
}, t => {
  const model = spawnSync(zig, ['test', 'src/update_notes.zig'], { cwd: root, encoding: 'utf8', timeout: 240000, maxBuffer: 16 * 1024 * 1024 });
  assert.equal(model.status, 0, model.stdout + model.stderr);
  const published = JSON.parse(fs.readFileSync(fixture, 'utf8'));
  const release = published.releases.find(item => item.version === '0.28.1961');
  assert.ok(release, 'Published release snapshot is missing');
  assert.equal(release.changes.length, 4);
  const exe = path.join(root, 'zig-out/bin/multiprompt.exe');
  assert.ok(fs.existsSync(exe), 'Branch build is missing');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'real-card-notes-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const notes = path.join(directory, 'release-notes.json');
  fs.writeFileSync(notes, JSON.stringify({ version: release.version, releases: [release] }));
  const evidence = path.join(root, 'evidence/update-card-real-notes');
  fs.rmSync(evidence, { recursive: true, force: true });
  const run = spawnSync('pwsh', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', proof, '-Exe', exe, '-Notes', notes, '-Evidence', evidence], { encoding: 'utf8', timeout: 240000, maxBuffer: 32 * 1024 * 1024 });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  const receipt = JSON.parse(fs.readFileSync(path.join(evidence, 'released-card.json'), 'utf8'));
  assert.deepEqual(receipt.changes, release.changes);
  assert.match(run.stdout, /RELEASE_CARD_RECEIPT=/);
  assert.match(run.stdout, /RELEASE_CARD_PNG=/);
  const log = fs.readFileSync(path.join(evidence, 'debug.log'), 'utf8');
  assert.match(log, /\[update\] card view=collapsed n=3 first=MUBO-194 /);
  assert.match(log, /\[update\] card note 0=MUBO-194 /);
  assert.match(log, /\[update\] card note 2=MUBO-292 /);
  assert.match(log, /\[update\] card remaining=See all/);
});
