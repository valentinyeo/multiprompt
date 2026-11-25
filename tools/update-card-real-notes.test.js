const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const offer = '0.28.1985';
const installed = '0.28.1984';
const seeAllUrl = `https://github.com/valentinyeo/multiprompt/releases/tag/v${offer}`;
const zig = process.env.ZIG_EXE || 'zig';
const published = 'MUBO-243 Poteto tab points at its chat from before a clear';
const painted = 'Poteto tab points at its chat from before a clear';

test('the branch app names the real offered release change and its See all opens the matching notes', {
  skip: process.platform !== 'win32' || process.env.GITHUB_ACTIONS !== 'true',
  timeout: 1500000,
}, async t => {
  const unit = spawnSync(zig, ['test', 'src/update_notes.zig'], { cwd: root, encoding: 'utf8', timeout: 240000, maxBuffer: 16 * 1024 * 1024 });
  assert.equal(unit.status, 0, unit.stdout + unit.stderr);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'real-offer-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const build = spawnSync(zig, ['build', `-Dversion=${installed}`, '--prefix', path.join(directory, 'app')], {
    cwd: root, encoding: 'utf8', timeout: 1200000, maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(build.status, 0, build.stdout + build.stderr);
  const exe = path.join(directory, 'app/bin/multiprompt.exe');
  assert.ok(fs.existsSync(exe), 'Installed earlier branch build is missing');
  const api = async endpoint => {
    const response = await fetch(`https://api.github.com/repos/valentinyeo/multiprompt/${endpoint}`);
    assert.equal(response.status, 200, endpoint);
    return response.json();
  };
  const downloadAsset = async (release, name, destination) => {
    const asset = release.assets.find(item => item.name === name);
    assert.ok(asset, name);
    const response = await fetch(asset.browser_download_url);
    assert.equal(response.status, 200, name);
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.equal(`sha256:${createHash('sha256').update(bytes).digest('hex')}`, asset.digest, `${name} does not match its published digest`);
    fs.writeFileSync(destination, bytes);
    return bytes;
  };
  const release = await api(`releases/tags/v${offer}`);
  const notesPath = path.join(directory, 'release-notes.json');
  const bytes = await downloadAsset(release, 'release-notes.json', notesPath);
  const notes = JSON.parse(bytes);
  assert.equal(notes.version, offer);
  const entry = notes.releases.find(item => item.version === offer);
  assert.deepEqual(entry.changes, [published]);
  assert.deepEqual(entry.tickets, ['https://app.hypertask.ai/detail/project-13734/243']);
  const pinned = JSON.parse(read('src/testdata/mubo-577-release-notes.json'));
  for (const fixture of pinned.releases) {
    assert.deepEqual(notes.releases.find(item => item.version === fixture.version), fixture, `Pinned fixture drifted for ${fixture.version}`);
  }
  assert.ok(release.body.includes(`[MUBO-243](https://app.hypertask.ai/detail/project-13734/243) ${painted}`));
  const page = await fetch(seeAllUrl);
  assert.equal(page.status, 200, seeAllUrl);
  assert.ok((await page.text()).includes(`v${offer}`));
  const report = path.join(root, 'tools/update-card-real-release-proof.ps1');
  const proof = (binary, evidence, extra) => spawnSync('pwsh', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', report,
    '-Exe', binary, '-Notes', notesPath, '-Offer', offer, '-Evidence', evidence, ...extra],
  { encoding: 'utf8', timeout: 600000, maxBuffer: 64 * 1024 * 1024 });
  const released = await api(`releases/tags/v${installed}`);
  const releasedExe = path.join(directory, 'released-installed.exe');
  const installedBytes = await downloadAsset(released, 'multiprompt-x64.exe', releasedExe);
  assert.ok(installedBytes.length > 1000000, 'Released installed app is not the real executable');
  const beforeEvidence = path.join(root, 'evidence/update-card-real-notes/before');
  fs.rmSync(beforeEvidence, { recursive: true, force: true });
  const before = proof(releasedExe, beforeEvidence, ['-Before']);
  assert.equal(before.status, 0, before.stdout + before.stderr);
  assert.match(before.stdout, /BEFORE_CARD_RECEIPT=/);
  assert.match(before.stdout, /BEFORE_CARD_PNG=/);
  const beforeReceipt = JSON.parse(fs.readFileSync(path.join(beforeEvidence, 'before-card.json'), 'utf8'));
  assert.equal(beforeReceipt.released, `v${installed}`);
  assert.equal(beforeReceipt.offered, offer);
  assert.equal(beforeReceipt.notesSha256, createHash('sha256').update(bytes).digest('hex'));
  assert.equal(beforeReceipt.binarySha256, createHash('sha256').update(installedBytes).digest('hex'));
  assert.deepEqual(beforeReceipt.painted, []);
  assert.equal(beforeReceipt.seeAll, false);
  assert.ok(fs.statSync(path.join(beforeEvidence, 'before-card.png')).size > 20000, 'before-card.png is not a real screenshot');
  const evidence = path.join(root, 'evidence/update-card-real-notes/after');
  fs.rmSync(evidence, { recursive: true, force: true });
  const after = proof(exe, evidence, []);
  assert.equal(after.status, 0, after.stdout + after.stderr);
  assert.match(after.stdout, /REAL_CARD_RECEIPT=/);
  assert.match(after.stdout, /REAL_CARD_PNG=/);
  assert.match(after.stdout, /SEE_ALL_PNG=/);
  const receipt = JSON.parse(fs.readFileSync(path.join(evidence, 'released-card.json'), 'utf8'));
  assert.equal(receipt.installed, installed);
  assert.equal(receipt.offered, offer);
  assert.equal(receipt.notesVersion, offer);
  assert.equal(receipt.notesSha256, createHash('sha256').update(bytes).digest('hex'));
  assert.deepEqual(receipt.published, [published]);
  assert.deepEqual(receipt.painted, [painted]);
  assert.deepEqual(receipt.ids, ['MUBO-243']);
  assert.equal(receipt.seeAllUrl, seeAllUrl);
  assert.ok(receipt.seeAllOpened > 32, `See all shell open failed: ${receipt.seeAllOpened}`);
  assert.match(receipt.browserTitle, /v0\.28\.1985/);
  assert.match(fs.readFileSync(path.join(evidence, 'debug.log'), 'utf8'), /\[update\] card view=collapsed n=1 /);
  for (const name of ['released-card.png', 'see-all-release.png']) {
    assert.ok(fs.statSync(path.join(evidence, name)).size > 20000, `${name} is not a real screenshot`);
  }
  console.log(`REAL_RELEASE_CARD notes=${receipt.notesSha256} before=${path.join(beforeEvidence, 'before-card.png')} after=${path.join(evidence, 'released-card.png')} release=${path.join(evidence, 'see-all-release.png')}`);
});
