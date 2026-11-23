const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('SOFT-3003 zsb shell-open is a workspace command with attach and run flags', () => {
  const zsb = read('src/mp_zsb.sh');
  assert.match(zsb, /shell-open --workspace NAME/);
  assert.match(zsb, /"shell-open"/);
  assert.match(zsb, /--attach SESSION\] \[--run CMD\]/);
  assert.match(read('src/browser_bridge.zig'), /"shell-open"/);
  assert.match(read('src/browser_bridge.zig'), /fn zsbShellOpen\(/);
  assert.match(read('src/mp_shell.py'), /shell-open/);
  assert.match(read('src/chat_history_reader.py'), /'mp-shell': 'MP_SHELL_SOURCE'/);
  assert.match(read('src/chat_session.zig'), /MP_SHELL_SOURCE = '\{s\}'/);
});

test('SOFT-3003 spawnBackgroundRemoteShell stays the shared background spawn path', () => {
  const console = read('src/console.zig');
  assert.match(console, /pub fn spawnBackgroundRemoteShell\(/);
  assert.match(console, /pub fn spawnBackgroundTmuxSession\(/);
  assert.match(console, /spawnBackgroundRemoteShell\(host, workspace, \.tmux, session\)/);
});