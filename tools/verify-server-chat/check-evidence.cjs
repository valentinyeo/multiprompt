const assert = require('node:assert/strict');
const fs = require('node:fs');
const { createHash } = require('node:crypto');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.argv[2];
const text = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
const json = name => JSON.parse(text(name));
const result = json('result.json');
assert.equal(result.status, 'passed');
assert.deepEqual(result.cases.map(row => [row.name, row.passed]), [['open', true], ['send', true], ['clear', true], ['after-clear', true]]);
assert.equal(result.cleanup.activeAfterStop, 0);
assert.equal(result.keyRemoved, true);
assert.equal(result.videoExit, 0);
assert.ok(text('open-copied.txt').includes('Server received: server seed'));
const fixture = json('server-chat-fixture.json');
assert.equal(fixture.version, 1);
assert.equal(fixture.synthetic, true);
assert.equal(fixture.messages, 2400);
assert.equal(result.seed.sha256, fixture.sha256);
assert.equal(json('fixture-manifest.json').sessions, 64);
assert.equal(json('open-server.json').fixture.messages, 2400);
assert.ok(json('open-server.json').fixture.transcriptMessages >= 2402);
assert.ok(text('open-copied.txt').includes('Synthetic chat 00 answer 1199.'));
const seeded = text(`linux-host/${fixture.sid}.jsonl`).split('\n').slice(0, 2400);
assert.equal(seeded.length, 2400);
assert.equal(createHash('sha256').update(seeded.join('\n') + '\n').digest('hex'), fixture.sha256);
for (const [index, line] of seeded.entries()) {
  const row = JSON.parse(line);
  assert.equal(row.sessionId, fixture.sid);
  assert.equal(row.uuid, `fixture-0-${index % 2 ? 'assistant' : 'user'}-${Math.floor(index / 2)}`);
}
assert.ok(JSON.parse(seeded[0]).message.content.some(block => block.type === 'image'));
assert.match(JSON.parse(seeded[1]).message.content[0].text, /\| Check \|[\s\S]*```python/);
for (const [name, message] of [['send', 'windows send proof'], ['clear', '/clear'], ['after-clear', 'windows after clear']]) {
  const wireText = name === 'clear' ? '/clear ' : message;
  assert.equal(json(`${name}-server.json`).inputs.filter(row => row.text === wireText).length, 1);
  assert.ok(text(`${name}-copied.txt`).includes(`Server received: ${message}`));
  assert.ok(fs.statSync(path.join(root, `${name}.png`)).size > 1000);
}
const acl = json('key-acl.json');
assert.equal(acl.protected, true);
assert.equal(acl.rules.length, 1);
assert.equal(acl.rules[0].sid, acl.owner);
const locks = JSON.parse(text('server-start.stdout.log').split(/\r?\n/).find(line => line.includes('"blockedWriter"')));
assert.match(locks.kernel, /WSL2/i);
assert.equal(locks.blockedWriter, 'SQLITE_BUSY');
assert.equal(locks.integrity, 'ok');
assert.equal(locks.writes, 2);
assert.match(text('ssh-preflight.txt'), /Linux[\s\S]*tmux[\s\S]*Python/);
assert.match(text('sshd.log'), /Accepted publickey for mpverify/);
const nativeLogs = fs.readdirSync(root).filter(name => name.endsWith('.exit-code.txt'));
for (const name of ['ssh-keygen', 'driver-repo-path', 'start-repo-path', 'public-key-path', 'server-start', 'ssh-keyscan', 'ssh-preflight', 'evidence-path', 'server-stop', 'wsl-terminate']) {
  assert.ok(nativeLogs.includes(`${name}.exit-code.txt`), `Missing native command evidence: ${name}`);
}
for (const name of nativeLogs) {
  assert.equal(text(name).trim(), '0', `Native command failed: ${name}`);
  assert.ok(fs.existsSync(path.join(root, name.replace('.exit-code.txt', '.stderr.log'))));
}
const probe = spawnSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', path.join(root, 'journey.mp4')], { encoding: 'utf8' });
fs.writeFileSync(path.join(root, 'ffprobe.stdout.log'), probe.stdout ?? '');
fs.writeFileSync(path.join(root, 'ffprobe.stderr.log'), probe.stderr ?? String(probe.error ?? ''));
fs.writeFileSync(path.join(root, 'ffprobe.exit-code.txt'), String(probe.status));
assert.equal(probe.status, 0, `Video probe failed; see ${path.join(root, 'ffprobe.stderr.log')}`);
const video = JSON.parse(probe.stdout);
assert.ok(video.streams.some(stream => stream.codec_type === 'video' && Number(stream.nb_frames) > 0));
assert.ok(Number(video.format.duration) > 1);
assert.equal(json('doctor.json').sha256.toLowerCase(), json('build.json').sha256.toLowerCase());
console.log('Real SSH server chat receipts, copied replies, key ACL, cleanup and video passed');
