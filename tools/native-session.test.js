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
  const gate = spawn.indexOf('if (isRemoteShellKind(kind) and app_state.g_shared_server_connection) return spawnNativeShell(');
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

test('remote typing path has no Windows console to answer device attributes', () => {
  const start = body(read('src/chat_transport.zig'), 'start');
  assert.match(start, /"-T -o BatchMode=yes /);
  assert.match(start, /si\.hStdInput = child_input;/);
  assert.match(start, /si\.hStdOutput = child_output;/);
  assert.match(start, /CreateProcessW\(null, @ptrCast\(&cmd\), null, null, 1, 0x08000000,/);
  const vendored = 'src/terminal/vendor/libvterm/src/state.c';
  assert.ok(fs.existsSync(path.join(root, vendored)), vendored);
  const state = read(vendored);
  assert.match(state, /C1_CSI, "\?1;2c"\)/);
  assert.match(state, /C1_CSI, ">%d;%d;%dc", 0, 100, 0\)/);
  const native = read('src/native_session.zig');
  assert.match(body(native, 'onOutput'), /emitInput\(slot, bytes\[0\.\.length\]\)/);
  console.log('remote typing path has no Windows console to answer device attributes');
});

test('shared server connection is a switch that defaults off and persists', () => {
  assert.match(read('src/app_state.zig'), /pub var g_shared_server_connection: bool = false;/);
  const session = read('src/session.zig');
  assert.match(session, /if \(app_state\.g_shared_server_connection and pos \+ 36 < json_buf\.len\) \{\s*const setting = ",\\"shared_server_connection\\":true";/);
  assert.match(session, /app_state\.g_shared_server_connection = json_reader\.boolTrue\(json, "shared_server_connection"\);/);
  assert.match(read('src/main.zig'), /target == SEARCH_SHARED_SERVER_CONNECTION_OFFSET\) \{\s*app_state\.g_shared_server_connection = !app_state\.g_shared_server_connection;\s*saveSession\(\);/);
  assert.match(read('src/command_palette.zig'), /"Remote Tabs: Share One Server Connection"/);
  assert.match(read('src/shortcuts.zig'), /Ctrl\+K -> Remote Tabs: Share One Server Connection/);
});
