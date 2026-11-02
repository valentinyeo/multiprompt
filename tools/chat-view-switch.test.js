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
