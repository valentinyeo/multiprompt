const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(name);
}

test('native session spawn keeps remote tabs off per-tab ssh', () => {
  const consoleSource = read('src/console.zig');
  const spawn = body(consoleSource, 'spawnShellWithSession');
  const gate = spawn.indexOf('if (isRemoteShellKind(kind)) return spawnNativeShell(');
  const created = spawn.indexOf('CreateProcessW');
  assert.ok(gate >= 0 && created > gate);
  assert.doesNotMatch(body(consoleSource, 'spawnNativeShell'), /CreateProcessW|ssh\.exe/);
  assert.doesNotMatch(read('src/native_session.zig'), /CreateProcessW|ssh\.exe/);
  const build = read('build.zig');
  assert.match(build, /terminal_window\.c/);
  assert.match(build, /terminal_model\.c/);
  assert.match(build, /libvterm/);
  assert.match(body(consoleSource, 'respawnShellInPlace'), /native_terminal\) return @import\("native_session\.zig"\)\.reconnect/);
  assert.match(body(consoleSource, 'spawnNativeShell'), /chat_view_on or app_state\.g_chat_active/);
  assert.match(body(read('src/chat_composer.zig'), 'showShellConsole'), /native_terminal and !@import\("native_session\.zig"\)\.alive/);
  console.log('native session spawn keeps remote tabs off per-tab ssh');
});
