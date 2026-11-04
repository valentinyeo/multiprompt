const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const rename = read('src/rename.zig');
const main = read('src/main.zig');
const send = read('src/chat_send.zig');
const driver = read('.claude/skills/verify-multiprompt/control-feature-inline-rename.ps1');

test('inline editor keeps the stable shell identity and commits canonically', () => {
  assert.match(rename, /g_edit_sid = app_state\.shells\[idx\]\.shell_id/);
  assert.match(rename, /findShellById\(renamed_sid\)/);
  assert.match(rename, /applyCanonicalSessionRename\(app_state\.g_edit_tab, buf\[0\.\.ulen\], sync_remote\)/);
  assert.match(rename, /WS_CHILD \| WS_VISIBLE \| ES_AUTOHSCROLL/);
  assert.match(rename, /uiFontTitle\(\).*uiFontThreadTitle\(\).*uiFontBot\(\.pinned\).*uiFontBot\(\.name\)/s);
  assert.match(rename, /SendMessageW\(app_state\.g_edit_hwnd, 0x00B1, 0, @bitCast\(@as\(isize, -1\)\)\)/);
  assert.match(main, /WM_APP_COMMIT_RENAME => \{\s*if \(lp != 0/);
});

test('slash rename consumes locally before normal message routing', () => {
  const start = send.indexOf('pub fn sendChatPrompt()');
  const body = send.slice(start, send.indexOf('pub fn ', start + 7));
  assert.match(body, /startsWith\(u16, text, L\("\/rename "\)\[0\.\.8\]\)/);
  assert.match(body, /applyCanonicalSessionRename\(app_state\.active_shell, name, true\)/);
  assert.ok(body.indexOf('applyCanonicalSessionRename') < body.indexOf('chat_slash.zig'));
  assert.match(body, /SetWindowTextW\(app_state\.g_chat_composer_hwnd, L\(""\)\)/);
});

test('hosted journey drives both names and records its boundaries', () => {
  for (const action of ['title-before', 'title-edit', 'title-after', 'sidebar-before', 'sidebar-edit', 'sidebar-after', '/rename Command name', 'Restart-ChatView 1']) assert.ok(driver.includes(action), action);
  assert.match(driver, /@\('light', 'amoled'\)/);
  assert.match(driver, /graphite2 = 'unavailable in shipped themes'/);
  assert.match(driver, /Read-Inbox/);
});
