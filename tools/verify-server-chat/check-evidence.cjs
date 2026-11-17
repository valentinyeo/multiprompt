const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = process.argv[2];
const reproduction = process.argv[3] === '--repro';
const text = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
const json = name => JSON.parse(text(name));
const result = json('result.json');
assert.equal(result.status, reproduction ? 'failed' : 'passed');
const busy = result.feature === 'server-chat-busy';
assert.ok(!reproduction || busy);
const ordinary = busy ? ['open', 'send'] : ['open', 'send', 'clear', 'after-clear'];
for (const name of ordinary) assert.equal(result.cases.find(row => row.name === name)?.passed, true, name);
assert.equal(result.cleanup.activeAfterStop, 0);
assert.equal(result.cleanupError, undefined);
assert.equal(result.keyRemoved, true);
assert.equal(result.videoExit, 0);
assert.ok(text('open-copied.txt').includes('Server received: server seed'));
assert.ok(text('open-copied.txt').includes('Synthetic chat 00 answer 1199.'));
const manifest = json('fixture-manifest.json');
assert.equal(manifest.sessions, 64);
assert.equal(manifest.longChats, 8);
assert.equal(manifest.messages, 19872);
for (const [name, message] of [['send', 'windows send proof'], ...(!busy ? [['clear', '/clear'], ['after-clear', 'windows after clear']] : [])]) {
  assert.equal(json(`${name}-server.json`).inputs.filter(row => row.text === message).length, 1);
  assert.ok(text(`${name}-copied.txt`).includes(`Server received: ${message}`));
  assert.ok(fs.statSync(path.join(root, `${name}.png`)).size > 1000);
}
if (busy) {
  const before = json('busy-before-stop.json');
  const after = json('busy-after-stop.json');
  const observed = json('reproduction.json');
  assert.equal(before.provider.busy, true);
  assert.equal(before.seed.messages, 2400);
  assert.equal(after.provider.pid, before.provider.pid);
  assert.ok(observed.waitedMilliseconds >= 611000);
  assert.equal(observed.notSent, reproduction);
  assert.equal(observed.stopIneffective, reproduction);
  assert.equal(observed.matchesReport, reproduction);
  assert.ok(json('actions.json').some(action => action.input === 'click painted Stop'));
  for (const name of ['busy-before-stop.png', 'busy-after-stop.png']) assert.ok(fs.statSync(path.join(root, name)).size > 1000);
  const pending = json('busy-outbox.json').queues.flatMap(queue => queue.messages).filter(row => row.t === 'follow-up during busy turn');
  const notSent = pending.some(row => row.v1 === 1 && row.s !== 4 && (row.s === 2 || row.phase === 'failed' || (row.s !== 3 && !['accepted', 'started'].includes(row.phase))));
  assert.equal(notSent, reproduction);
  const interrupts = after.controls.filter(row => row.request.subtype === 'interrupt');
  assert.equal(after.provider.busy, reproduction);
  if (reproduction) {
    assert.ok(observed.stopMilliseconds >= 10000);
    assert.equal(interrupts.length, 0);
  } else {
    assert.ok(observed.stopMilliseconds <= 10000);
    assert.equal(interrupts.length, 1);
    assert.equal(json('busy-follow-up.json').inputs.filter(row => row.text === 'follow-up during busy turn').length, 1);
    assert.ok(text('busy-follow-up-copied.txt').includes('Server received: follow-up during busy turn'));
    for (const name of ['busy-message-kept', 'stop-interrupts', 'busy-follow-up']) assert.equal(result.cases.find(row => row.name === name)?.passed, true, name);
  }
}
const acl = json('key-acl.json');
assert.equal(acl.protected, true);
assert.equal(acl.rules.length, 1);
assert.equal(acl.rules[0].sid, acl.owner);
assert.match(text('ssh-preflight.txt'), /Linux[\s\S]*tmux[\s\S]*Python/);
assert.match(text('sshd.log'), /Accepted publickey for mpverify/);
const video = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', path.join(root, 'journey.mp4')], { encoding: 'utf8' }));
assert.ok(video.streams.some(stream => stream.codec_type === 'video' && Number(stream.nb_frames) > 0));
assert.ok(Number(video.format.duration) > (busy ? 611 : 1));
assert.equal(json('doctor.json').sha256.toLowerCase(), json('build.json').sha256.toLowerCase());
console.log(reproduction ? 'Both reported failures reproduced over real SSH with native UI evidence' : 'Real SSH server chat receipts, native controls, seed, key ACL, cleanup and video passed');
