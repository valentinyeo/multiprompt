import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.join(path.dirname(new URL(import.meta.url).pathname), '..');

function read(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8');
}

test('SOFT-3002 remote VPS tabs are not promoted to tmux without a saved session name', () => {
  const poll = read('src/shell_poll.zig');
  const block = poll.slice(
    poll.indexOf('if ((app_state.shells[i].kind == .vps'),
    poll.indexOf('        if (app_state.shells[i].kind == .tmux) {', poll.indexOf('if ((app_state.shells[i].kind == .vps')),
  );
  assert.match(block, /extractTmuxSessionFromBottomRow/);
  const detect = poll.slice(
    poll.indexOf('} else if (!isRemoteShellKind(app_state.shells[i].kind)'),
    poll.indexOf('var title_buf: [256]u16', poll.indexOf('} else if (!isRemoteShellKind(app_state.shells[i].kind)')),
  );
  assert.doesNotMatch(detect, /kind == \.vps/);
});

test('SOFT-3002 unnamed saved tmux tabs restore instead of being dropped', () => {
  const reader = read('src/json_reader.zig');
  assert.doesNotMatch(reader, /tab\.kind == \.tmux and tab\.tmux_session_len == 0\) continue/);
  assert.match(reader, /tab\.kind = if \(tab\.tmux_host == 1\) \.vps2 else \.vps/);
  const session = read('src/session.zig');
  assert.match(session, /\.tmux => if \(app_state\.shells\[i\]\.tmux_session_len == 0\)/);
});

test('Reopen server shell uses the tmux routing band on the active tab host', () => {
  const palette = read('src/command_palette.zig');
  assert.match(palette, /SEARCH_REOPEN_SERVER_SHELL_OFFSET/);
  assert.match(palette, /g_search_reopen_server_shell_mode/);
  assert.match(palette, /appendHostDetachedTmuxRows/);
  const shortcuts = read('src/shortcuts.zig');
  assert.match(shortcuts, /Reopen server shell/);
  assert.match(shortcuts, /WM_APP_REOPEN_SERVER_SHELL_OPEN/);
});