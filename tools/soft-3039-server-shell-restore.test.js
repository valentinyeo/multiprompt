const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `missing ${name}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(`unclosed ${name}`);
}

test('SOFT-3039 restore reattaches saved tmux sessions for VPS tabs and respawns cached placeholders', () => {
  const session = read('src/session.zig');
  assert.match(body(session, 'spawnSavedTab'), /isRemoteShellKind\(tabs\[t\]\.kind\) and tabs\[t\]\.tmux_session_len > 0/);
  assert.match(session, /fn restoreCachedSavedTab\(/);
  assert.match(body(session, 'restoreCachedSavedTab'), /resumeShellAt\(idx, tab\.kind/);
  const restore = body(session, 'restoreSession');
  assert.match(restore, /if \(restoreCachedSavedTab\(idx, &tabs\[t\]\)\)/);
  assert.doesNotMatch(restore, /avatar_local_id\) app_state\.shells\[idx\]\.avatar_local_id = tabs\[t\]\.avatar_local_id/);
  assert.match(restore, /shellConsoleReachable\(app_state\.active_shell\)/);
});

test('SOFT-3039 native restore opens transport during startup and focus can reach hosted terminals', () => {
  const consoleSource = read('src/console.zig');
  assert.match(consoleSource, /pub fn resumeShellAt\(/);
  assert.match(body(consoleSource, 'resumeNativeShellAt'), /!app_state\.g_restoring\)/);
  assert.match(body(consoleSource, 'spawnNativeShell'), /!app_state\.g_restoring\)/);
  const native = read('src/native_session.zig');
  assert.match(body(native, 'remoteShellCommand'), /tmux_session != null and \(kind == \.tmux or kind == \.vps or kind == \.vps2\)/);
  assert.match(body(read('src/console.zig'), 'makeCmdLine'), /\} else if \(\(kind == \.vps or kind == \.vps2\) and tmux_session != null\) \{/);
  const focus = body(read('src/focus.zig'), 'focusActiveShellInner');
  assert.match(focus, /ensureWindow\(app_state\.shells\[app_state\.active_shell\]\.shell_id\)/);
});