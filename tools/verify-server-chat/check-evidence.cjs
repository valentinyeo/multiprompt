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
const fresh = result.feature === 'server-chat-fresh-start';
assert.ok(!reproduction || busy || fresh);
const ordinary = busy || fresh ? ['open', 'send'] : ['open', 'send', 'clear', 'after-clear'];
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
for (const [name, message] of [['send', 'windows send proof'], ...(!busy && !fresh ? [['clear', '/clear'], ['after-clear', 'windows after clear']] : [])]) {
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
if (fresh) {
  assert.equal(result.cases.find(row => row.name === 'fresh-start-rotates')?.passed, true);
  const before = json('fresh-before.json');
  const reset = json('fresh-after.json');
  assert.notEqual(reset.provider.pid, before.provider.pid);
  assert.ok(text('fresh-copied.txt').includes('Synthetic chat 00 answer 1199.'));
  const replacement = json('replacement.json');
  assert.equal(replacement.oldHostGone, true);
  assert.notEqual(replacement.old, replacement.new);
  const previous = before.hosts.find(host => host.sid === replacement.old);
  const rotated = reset.hosts.find(host => host.sid === replacement.old && host.alive && !host.freshPhase);
  assert.ok(previous && rotated);
  assert.notEqual(rotated.native_session, previous.native_session);
  assert.equal(reset.inputs.filter(row => row.sid === rotated.native_session && row.pid === reset.provider.pid && row.text.startsWith('You are the same chat after a fresh start.')).length, 1);
  const setup = json('replacement-before.json');
  assert.ok(setup.inputs.some(row => row.sid === replacement.new && row.text === 'fresh replacement seed'));
  const after = json('replacement-after.json');
  assert.ok(!after.hosts.some(host => host.sid === replacement.old && host.alive));
  const live = after.hosts.filter(host => host.sid === replacement.new && host.alive && host.tmux === replacement.tmux);
  assert.equal(live.length, 1);
  const receipts = after.inputs.filter(row => row.text === 'after fresh replacement' && row.sid === live[0].native_session && row.pid === after.provider.pid);
  assert.equal(receipts.length, reproduction ? 0 : 1);
  assert.equal(text('replacement-copied.txt').includes('Server received: fresh replacement seed'), !reproduction);
  const tab = json('fresh-tab-after.json').tabs.find(row => row.name === 'Runner server chat');
  assert.ok(tab);
  assert.equal(tab.tmux_session, replacement.tmux);
  if (reproduction) assert.equal(tab.csid, replacement.old);
  else assert.ok(text('replacement-reply-copied.txt').includes('Server received: after fresh replacement'));
  const actions = json('actions.json');
  assert.equal(actions.filter(action => action.input === 'Enter: fresh start of this chat').length, 2);
  assert.ok(actions.some(action => action.input === 'replace ended host through production CLI in the same tmux pane'));
  for (const name of ['fresh-after.png', 'replacement-fresh-start.png', 'replacement-after.png']) assert.ok(fs.statSync(path.join(root, name)).size > 1000);
  for (const name of ['replacement-follows', 'replacement-send']) assert.equal(result.cases.find(row => row.name === name)?.passed, !reproduction);
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
console.log(reproduction ? (fresh ? 'Stale tab reproduced after real host replacement with native UI evidence' : 'Both reported failures reproduced over real SSH with native UI evidence') : 'Real SSH server chat receipts, native controls, seed, key ACL, cleanup and video passed');
