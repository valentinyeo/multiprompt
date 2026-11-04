const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const rename = read('src/rename.zig');
const main = read('src/main.zig');
const send = read('src/chat_send.zig');


test('inline editor keeps the stable shell identity and commits canonically', () => {
  assert.match(rename, /g_edit_sid = app_state\.shells\[idx\]\.shell_id/);
  assert.match(rename, /findShellById\(renamed_sid\)/);
  assert.match(rename, /applyCanonicalSessionRename\(app_state\.g_edit_tab, buf\[0\.\.ulen\], sync_remote\)/);
  assert.match(rename, /WS_CHILD \| WS_VISIBLE \| ES_AUTOHSCROLL/);
  assert.match(rename, /uiFontTitle\(\).*uiFontThreadTitle\(\).*uiFontBot\(\.pinned\).*uiFontBot\(\.name\)/s);
  assert.match(rename, /SendMessageW\(app_state\.g_edit_hwnd, 0x00B1, 0, @bitCast\(@as\(isize, -1\)\)\)/);
  assert.match(main, /WM_APP_COMMIT_RENAME => \{\s*if \(lp != 0/);
  assert.match(rename, /if \(wp == 0x1B\) \{\s*app_state\.g_focus_user_action_tick = renameCommitActionTick/);
  assert.match(rename, /in_title and !app_state\.g_chat_active\) name_rc\.bottom - name_rc\.top/);
  assert.match(main, /if \(tab_idx != app_state\.active_shell or @import\("room_frontend\.zig"\)\.isActive\(\)\) @import\("console\.zig"\)\.switchToShellByUser\(tab_idx\)/);
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
  const file = '.claude/skills/verify-multiprompt/control-inline-rename.ps1';
  assert.ok(fs.existsSync(path.join(__dirname, '..', file)), 'hosted rename journey exists');
  const driver = read(file);
  for (const action of ['title-before', 'title-edit', 'title-after', 'sidebar-before', 'sidebar-edit', 'sidebar-after', '/rename Command name', 'Restart-ChatView 1']) assert.ok(driver.includes(action), action);
  assert.match(driver, /@\('light', 'amoled'\)/);
  assert.match(driver, /graphite2 = 'unavailable in shipped themes'/);
  assert.match(driver, /Read-Inbox/);
  assert.match(driver, /function Rename-Snapshot\([\s\S]*?Rename-WaitChatView\s+Snapshot \$Name/);
  assert.match(driver, /tabs\[\$state\.active_tab\]\.cv/);
  assert.match(driver, /ZigShellChatTranscript/);
  assert.match(driver, /Click the first sidebar session name/);
  assert.doesNotMatch(driver, /Alt\+C:.*shell view/);
  assert.doesNotMatch(driver, /^\s+Snapshot ["']rename-/m);
});
