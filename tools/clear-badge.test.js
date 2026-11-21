const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const send = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
const vps = fs.readFileSync(path.join(root, 'src/vps.zig'), 'utf8');
const list = fs.readFileSync(path.join(root, 'tools/tmux-list.sh'), 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} is missing`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('SOFT-2420 a refused restart and a finished clear do not paint AI stopped', () => {
  const apply = body(send, 'chatRestartAiApplyRefusal');
  assert.match(apply, /ai_restart_busy = true/);
  assert.match(apply, /ai_stopped = false/);
  assert.doesNotMatch(apply, /ai_stopped = true/);
  const finish = body(send, 'chatTmuxSendFinish');
  assert.match(finish, /needs_restart/);
  assert.match(finish, /ai_stopped = false/);
  assert.match(finish, /ai_restart_tick = 0/);
});

test('SOFT-2420 a later poll line for a live AI clears the shell flag on that session', () => {
  const note = body(vps, 'noteLiveAgent');
  assert.match(note, /pane_shell = false/);
  assert.match(body(vps, 'parseHostOutputIntoCache'), /noteLiveAgent\(/);
});

test('SOFT-2420 the pane list reports claude when that process is in the pane', () => {
  assert.match(list, /base == "claude"/);
  assert.match(list, /cursor-agent/);
});
