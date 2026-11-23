const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.argv[2];
const text = name => fs.readFileSync(path.join(root, name), 'utf8').replace(/^\uFEFF/, '');
const json = name => JSON.parse(text(name));
const result = json('result.json');
assert.equal(result.status, 'passed');
assert.deepEqual(result.cases.map(row => row.name), ['before-restart', 'mp-sessions-close-restart', 'after-app-restart']);
assert.ok(text('first-send-copied.txt').includes('Server received: restart journey proof one'));
assert.ok(text('second-send-copied.txt').includes('Server received: restart journey proof two'));
for (const stage of ['before-restart', 'after-mp-sessions-restart', 'after-app-restart']) {
  const saved = json(`${stage}.session.json`);
  assert.equal(saved.tab.cv, true, `${stage} must keep Chat View on`);
  assert.equal(saved.workspace, result.workspace);
  assert.equal(saved.group, result.group);
}
for (const shot of ['before-restart', 'after-mp-sessions-restart', 'after-app-restart', 'after-restart']) {
  assert.ok(fs.statSync(path.join(root, `${shot}.png`)).size > 1000, shot);
}
assert.equal(result.cleanup.activeAfterStop, 0);
assert.equal(result.keyRemoved, true);
assert.match(text('ssh-preflight.txt'), /Linux[\s\S]*tmux[\s\S]*Python/);
for (const name of ['mp-sessions-start', 'mp-sessions-close', 'mp-sessions-restart', 'prepare-mp-talk', 'relay-ready']) {
  assert.equal(text(`${name}.exit-code.txt`).trim(), '0', name);
}
console.log('Session-restart chat tab kind, placement, screenshots and mp-sessions receipts passed');