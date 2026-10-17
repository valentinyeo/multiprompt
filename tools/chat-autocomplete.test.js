const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const src = require('./app-source').readAppSource();
const docs = fs.readFileSync('openwiki/operations/keyboard-shortcuts.md', 'utf8');
test('command browse is reachable from keyboard, palette, and F1', () => {
  assert.match(src, /SEARCH_CHAT_AC_OFFSET: usize = 6356/);
  assert.match(src, /CHAT_AC_ENTER_SENDS = false/);
  assert.match(src, /0xBF => true/);
  assert.match(src, /chatAcOpenBrowse\(\)/);
  assert.match(src, /Chat View: Insert Command or Skill\.\.\./);
  assert.match(src, /\.a = "Ctrl\+\/ in Chat View"/);
  assert.match(docs, /Ctrl\+\/ in Chat View/);
});
test('popup is hidden on send, tab switch, close and overlay', () => {
  for (const fn of ['sendChatPrompt', 'switchToShell', 'closeChatView', 'hideShellsForOverlay']) {
    assert.match(src, new RegExp(`fn ${fn}\\([^]*?\\) void \\{\\s*chatAcClose\\(\\);`));
  }
  assert.match(src, /endsInTriggerToken\(send_text/);
  assert.match(src, /g_chat_ac_mru_count/);
  assert.match(src, /chat_ac_\{s\}_\{d\}/);
  assert.match(src, /WM_APP_CHAT_AC_READY: u32 = WM_APP \+ 143/);
});
