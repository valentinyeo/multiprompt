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
  const boot = body(read('src/chat_transport.zig'), 'bootHost');
  assert.match(boot, /"-T -o BatchMode=yes /);
  assert.match(boot, /si\.hStdInput = child_input;/);
  assert.match(boot, /si\.hStdOutput = child_output;/);
  assert.match(boot, /CreateProcessW\(null, @ptrCast\(&cmd\), null, null, 1, console\.SSH_HELPER_FLAGS,/);
  assert.match(read('src/console.zig'), /pub const SSH_HELPER_FLAGS: u32 = 0x00000008;/);
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
  assert.doesNotMatch(read('src/command_palette.zig'), /g_search_results\[[^\]]+\] = SEARCH_SHARED_SERVER_CONNECTION_OFFSET/);
  assert.doesNotMatch(read('src/shortcuts.zig'), /Share One Server Connection/);
});

test('MUBO-598 a server shell opens at the full pane height and re-applies it once the channel is open', () => {
  const native = read('src/native_session.zig');
  const layout = read('src/window_layout.zig');
  const main = read('src/main.zig');

  const counts = body(layout, 'cellCounts');
  assert.match(counts, /@divTrunc\(height, cell_h\)/, 'rows come from the pane height and one cell height');
  assert.match(counts, /@divTrunc\(width, cell_w\)/, 'columns come from the pane width and one cell width');
  assert.match(counts, /if \(rows < 8 or cols < 20\) return null;/, 'a squeezed pane never becomes the opening size');
  const pane = body(layout, 'shellPaneCellCounts');
  assert.match(pane, /activePaneContentRect\(rc\)/, 'the opening size reads the real shell pane');
  assert.match(pane, /pane\.bottom - \(pane\.top \+ threadTitleHeight\(\)\)/, 'the opening size uses the console height inside the pane');

  const open = body(native, 'open');
  assert.match(open, /shellPaneCellCounts\(shellFontHeight\(\)\)/, 'the opening request carries the pane size, not a fixed 24 by 80');

  const attach = body(native, 'attachWindow');
  assert.match(attach, /if \(idx == app_state\.active_shell\) @import\("window_layout\.zig"\)\.repositionActive\(\);/, 'a new console window is sized to its pane before the channel opens');

  const worker = body(native, 'connectWorker');
  const opened = worker.indexOf('slot.opened = true;');
  assert.ok(opened >= 0, 'the worker marks the channel open');
  assert.ok(worker.indexOf('sendSize(slot, current_rows, current_cols);', opened) > opened, 'the current size leaves once the channel is open, whatever the opening carried');
  assert.ok(worker.indexOf('postSizeReport(shell_id);', opened) > opened, 'the sized window reports itself after the channel opens');
  assert.doesNotMatch(worker, /current_rows != rows/, 'the size no longer depends on a race with the first resize');

  const ready = body(native, 'ready');
  const gate = ready.indexOf('if (idx == app_state.active_shell and !app_state.g_chat_active and shell.hwnd != null)');
  assert.ok(gate >= 0, 'showing the console stays limited to the active tab');
  assert.ok(ready.indexOf('if (shell.hwnd) |hwnd| mp_terminal_window_report(hwnd);', gate) > gate, 'a ready shell reports its size even when another tab or the chat view is on screen');

  assert.match(main, /WM_APP_NATIVE_SIZE\) \{\s*@import\("native_session\.zig"\)\.reportSize/, 'the frame forwards the size report to the native session');
  console.log('server shells open at the full pane height');
});
