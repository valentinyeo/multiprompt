const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

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
for (const [name, message] of [['send', 'windows send proof'], ['clear', '/clear'], ['after-clear', 'windows after clear']]) {
  assert.equal(json(`${name}-server.json`).inputs.filter(row => row.text === message).length, 1);
  assert.ok(text(`${name}-copied.txt`).includes(`Server received: ${message}`));
  assert.ok(fs.statSync(path.join(root, `${name}.png`)).size > 1000);
}
const acl = json('key-acl.json');
assert.equal(acl.protected, true);
assert.equal(acl.rules.length, 1);
assert.equal(acl.rules[0].sid, acl.owner);
assert.match(text('ssh-preflight.txt'), /Linux[\s\S]*tmux[\s\S]*Python/);
assert.match(text('sshd.log'), /Accepted publickey for mpverify/);
const video = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_streams', '-show_format', '-of', 'json', path.join(root, 'journey.mp4')], { encoding: 'utf8' }));
assert.ok(video.streams.some(stream => stream.codec_type === 'video' && Number(stream.nb_frames) > 0));
assert.ok(Number(video.format.duration) > 1);
assert.equal(json('doctor.json').sha256.toLowerCase(), json('build.json').sha256.toLowerCase());
console.log('Real SSH server chat receipts, copied replies, key ACL, cleanup and video passed');
