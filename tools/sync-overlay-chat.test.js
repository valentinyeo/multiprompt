const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const src = (name) => fs.readFileSync(path.join(__dirname, '..', 'src', name), 'utf8');

test('account sync never reopens chat over Ctrl+K, Ctrl+T or another overlay', () => {
  const account = src('account_desktop.zig');
  const start = account.indexOf('pane guard: account sync kept user on active tab');
  assert.ok(start >= 0, 'kept-active sync branch');
  const branch = account.slice(start, account.indexOf('} else {', start));
  assert.match(branch, /if \(!@import\("chat_composer\.zig"\)\.overlayOpen\(\)\) @import\("chat_composer\.zig"\)\.applySessionView\(\);/);
});

test('overlayOpen covers the palette, pickers and Inbox', () => {
  const composer = src('chat_composer.zig');
  const start = composer.indexOf('pub fn overlayOpen() bool {');
  assert.ok(start >= 0, 'overlayOpen exists');
  const body = composer.slice(start, composer.indexOf('\n}\n', start));
  for (const flag of ['g_search_active', 'g_shortcuts_active', 'g_changelog_active', 'g_url_picker_active', 'g_snippet_create_active', 'g_inbox_active', 'g_all_sessions_active']) {
    assert.ok(body.includes(`app_state.${flag}`), flag);
  }
});
