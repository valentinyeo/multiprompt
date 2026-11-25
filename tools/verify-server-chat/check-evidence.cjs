const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.argv[2];
const text = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
const json = name => JSON.parse(text(name));
const result = json('result.json');
assert.equal(result.status, 'passed');
assert.deepEqual(result.cases.map(row => [row.name, row.passed]), [['open', true], ['send', true], ['clear', true], ['after-clear', true], ['reload', true]]);
assert.equal(result.cleanup.activeAfterStop, 0);
assert.equal(result.keyRemoved, true);
assert.ok(Array.isArray(json('video.json').streams) && json('video.json').streams.length === 1);
assert.ok(text('open-copied.txt').includes('Server received: server seed'));
for (const [name, message] of [['send', 'windows send proof'], ['clear', '/clear'], ['after-clear', 'windows after clear']]) {
  const wireText = name === 'clear' ? '/clear ' : message;
  assert.equal(json(`${name}-server.json`).inputs.filter(row => row.text === wireText).length, 1);
  assert.ok(text(`${name}-copied.txt`).includes(`Server received: ${message}`));
  assert.ok(fs.statSync(path.join(root, `${name}.png`)).size > 1000);
}
assert.ok(fs.statSync(path.join(root, 'reloaded.png')).size > 1000);
for (const reply of ['server seed', 'windows send proof', '/clear', 'windows after clear']) {
  const copied = text('reloaded-copied.txt').split(`Server received: ${reply}`).length - 1;
  assert.equal(copied, 1, `Reloaded transcript showed ${reply} ${copied} times`);
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
const summary = {
  workflow: 'ssh-idle.yml',
  revision: json('build.json').revision,
  version: json('build.json').version,
  sha256: json('build.json').sha256,
  cases: result.cases.map(row => [row.name, row.passed]),
  active_after_stop: result.cleanup.activeAfterStop,
  key_removed: result.keyRemoved,
};
if (fs.existsSync(path.join(root, 'idle.json'))) {
  for (const name of ['idle', 'idle-after-reconnect']) {
    const proof = json(`${name}.json`);
    assert.ok(proof.seconds >= 200, `${name} observed less than 200 seconds`);
    assert.equal(proof.passed, true, `${name} did not hold the idle SSH bound`);
    assert.equal(proof.logins, 0, `${name} opened ${proof.logins} SSH logins while idle`);
    assert.equal(proof.ssh_spawns, 0, `${name} spawned ${proof.ssh_spawns} SSH clients while idle`);
    summary[name.replaceAll('-', '_')] = { seconds: proof.seconds, logins: proof.logins, ssh_spawns: proof.ssh_spawns, logins_per_hour: proof.logins_per_hour, callers: proof.callers };
  }
  const reconnect = json('reconnect.json');
  assert.equal(reconnect.passed, true, 'Recovery after a dropped link did not pass');
  assert.ok(reconnect.new_logins >= 1, 'No new connection replaced the dropped one');
  assert.ok(reconnect.new_logins <= 30, `Recovery opened ${reconnect.new_logins} logins, more than a bounded reconnect`);
  summary.reconnect = { new_logins: reconnect.new_logins, passed: reconnect.passed };
  summary.passed = true;
  fs.writeFileSync(path.join(root, 'summary.json'), JSON.stringify(summary, null, 2));
}
console.log('Real SSH server chat receipts, copied replies, key ACL, cleanup and video passed');
