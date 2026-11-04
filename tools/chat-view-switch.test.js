const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1509 Alt+C and the Ctrl+K row only switch the view and never move Claude out of the shell', () => {
  const main = read('src/main.zig');
  const toggle = main.slice(main.indexOf('WM_APP_CHAT_TOGGLE => {'), main.indexOf('WM_APP_CHAT_HANDOVER => {'));
  assert.match(toggle, /toggleChatView\(\);/);
  assert.doesNotMatch(main, /startMoveChat\(/, 'the view switch must not start a chat move');
  const row = main.slice(main.indexOf('if (target == SEARCH_TABCTX_CHAT_VIEW) {'));
  assert.match(row.slice(0, row.indexOf('return 0;')), /toggleChatView\(\);/);
  const composer = read('src/chat_composer.zig');
  const body = composer.slice(composer.indexOf('pub fn toggleChatView() void {'), composer.indexOf('pub const ChatViewMove'));
  assert.doesNotMatch(body, /startMoveChat|host_/);
  const words = read('src/ui_words.zon');
  assert.match(words, /\.tab_context_switch_to_live_chat = "Switch to chat view"/);
  assert.match(words, /\.tab_context_switch_to_terminal = "Switch to shell"/);
});

test('IGSH-1655 live-chat toggles stop before changing any view state', () => {
  const composer = read('src/chat_composer.zig');
  const body = composer.slice(composer.indexOf('pub fn toggleChatView() void {'), composer.indexOf('pub const ChatViewMove'));
  const guard = body.indexOf('if (!@import("chat_view.zig").canToggle(shell.tmux_session[0..shell.tmux_session_len])) return;');
  assert.ok(guard >= 0 && guard < body.indexOf('shell.chat_view_on ='), 'live chat must return before touching the saved or visible view');
  const native = read('tools/chat-view-console-return.test.js');
  assert.match(native, /test "IGSH-1655 Alt\+C leaves a live chat open/);
  assert.match(native, /test "IGSH-1655 Alt\+C still toggles terminal tabs both ways/);
});

test('IGSH-1655 both palette toggle entries exclude live parking tabs', () => {
  const palette = read('src/command_palette.zig');
  const context = palette.slice(palette.indexOf('const chat_str: []const u8'), palette.indexOf('const chat_str: []const u8') + 650);
  assert.match(context, /canToggle\(app_state\.shells\[ti\]\.tmux_session\[0\.\.app_state\.shells\[ti\]\.tmux_session_len\]\)/);
  const global = palette.slice(palette.indexOf('if (show_chat_view and'), palette.indexOf('if (show_chat_view and') + 600);
  assert.match(global, /canToggle\(app_state\.shells\[app_state\.active_shell\]\.tmux_session\[0\.\.app_state\.shells\[app_state\.active_shell\]\.tmux_session_len\]\)/);
});
