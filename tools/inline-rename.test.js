const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const rename = read('src/rename.zig');
const main = read('src/main.zig');
const send = read('src/chat_send.zig');
const archive = read('src/archive.zig');

test('canonical rename rejects blank input before mutation and syncs the trimmed name', () => {
  const start = archive.indexOf('pub fn applyCanonicalSessionRename(');
  const body = archive.slice(start, archive.indexOf('\ntest ', start));
  assert.match(body, /const name = std\.mem\.trim\(u16, raw_name, &\.\{ ' ', '\\t', '\\r', '\\n' \}\);\s*if \(name\.len == 0\) return false;/);
  assert.ok(body.indexOf('if (name.len == 0) return false;') < body.indexOf('if (sync_remote)'));
  assert.match(body, /@memcpy\(app_state\.shells\[idx\]\.name\[0\.\.name_len\], name\[0\.\.name_len\]\)/);
  assert.match(body, /shellNameFromU16AsciiTrimmed\(name\[0\.\.name_len\], &sync_buf\)/);
  assert.doesNotMatch(body, /setDefaultName/);
});


test('inline editor keeps the stable shell identity and commits canonically', () => {
  assert.match(rename, /g_edit_sid = app_state\.shells\[idx\]\.shell_id/);
  assert.match(rename, /findShellById\(renamed_sid\)/);
  assert.match(rename, /applyCanonicalSessionRename\(app_state\.g_edit_tab, buf\[0\.\.ulen\], sync_remote\)/);
  assert.match(rename, /WS_CHILD \| WS_VISIBLE \| ES_AUTOHSCROLL/);
  assert.match(rename, /uiFontTitle\(\).*uiFontThreadTitle\(\).*uiFontBot\(\.pinned\).*uiFontBot\(\.name\)/s);
  assert.match(rename, /SendMessageW\(app_state\.g_edit_hwnd, 0x00B1, 0, @bitCast\(@as\(isize, -1\)\)\)/);
  assert.match(main, /WM_APP_COMMIT_RENAME => \{\s*if \(lp != 0/);
  assert.match(rename, /if \(wp == 0x1B\) \{\s*app_state\.g_focus_user_action_tick = renameCommitActionTick/);
  assert.match(rename, /fn startRenameInternal[^]*?g_focus_user_action_tick = renameCommitActionTick\(app_state\.g_focus_user_action_tick, GetTickCount64\(\), foregroundIsOurs\(\)\);\s*if \(!focusGuard/);
  assert.match(rename, /in_title and !app_state\.g_chat_active\) name_rc\.bottom - name_rc\.top/);
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
  for (const action of ['retain name after empty title', 'retain name after whitespace sidebar name', 'trim surrounding spaces']) assert.ok(driver.includes(action), action);
  assert.match(driver, /@\('light', 'amoled'\)/);
  assert.match(driver, /graphite2 = 'unavailable in shipped themes'/);
  assert.match(driver, /Read-Inbox/);
  assert.match(driver, /Restart-ChatView 1[^]*?Restart did not retain the renamed session[^]*?\$sid = \$restored\.tabs\[\$restored\.active_tab\]\.shell_id\s+Rename-WaitSaved \$current/);
  assert.match(driver, /function Rename-Snapshot\([\s\S]*?Rename-WaitChatView\s+Snapshot \$Name/);
  assert.match(driver, /tabs\[\$state\.active_tab\]\.cv/);
  assert.match(driver, /ZigShellChatTranscript/);
  assert.match(driver, /Rename-ClickNoEdit[^]*?'the first sidebar session name'/);
  assert.match(driver, /Rename-ClickNoEdit \$titlePoint\[0\] \$titlePoint\[1\] 'the chat title'/);
  assert.doesNotMatch(driver, /Alt\+C:.*shell view/);
  assert.doesNotMatch(driver, /^\s+Snapshot ["']rename-(?!inbox-)/m);
});

test('mouse clicks on a session or title never start a rename', () => {
  for (const handler of ['WM_LBUTTONDOWN =>', 'WM_LBUTTONDBLCLK =>']) {
    const start = main.indexOf(handler);
    assert.ok(start >= 0, handler);
    const body = main.slice(start, main.indexOf('\n        WM_', start + handler.length));
    assert.doesNotMatch(body, /startRename\(|startThreadTitleRename\(/, handler);
  }
});

test('F2 and palette route by visible context', () => {
  const route = main.slice(main.indexOf('WM_APP_RENAME_TAB =>'), main.indexOf('WM_APP_RENAME_WINDOW =>'));
  assert.match(route, /g_inbox_active[^]*?startInboxRename\(\)[^]*?startRename\(app_state\.active_shell\)/);
  assert.match(rename, /const in_title = thread_title or app_state\.g_hide_sidebar or app_state\.g_sidebar_collapsed/);
  assert.match(rename, /pub fn beginPaletteRenameInput[^]*?startRename\(idx\)/);
});

test('Inbox rename uses selected row colors and name geometry', () => {
  const inbox = read('src/inbox.zig');
  const editor = inbox.slice(inbox.indexOf('pub fn startInboxRename()'), inbox.indexOf('pub fn inboxRelTime'));
  assert.match(editor, /row\.att[^]*?600[^]*?uiFontBot\(\.name\)/);
  assert.match(editor, /setInlineColors\(if \(app_state\.g_light_theme\) RGB\(225, 225, 225\) else RGB\(53, 53, 53\)/);
  assert.match(editor, /y \+ uiScaled\(8\), edit_w, edit_h/);
  assert.doesNotMatch(editor, /WS_BORDER|uiFontInboxTitle/);
  assert.match(main, /child == app_state\.g_edit_hwnd and !app_state\.g_edit_is_group and !app_state\.g_edit_is_window and !app_state\.g_edit_is_browser_urlbar\)/);
  const driver = read('.claude/skills/verify-multiprompt/control-inline-rename.ps1');
  assert.match(driver, /Rename-Sidebar \$true[^]*?F2: locate the live title editor/);
  assert.match(driver, /Rename-Sidebar \$false[^]*?F2: edit sidebar name/);
  assert.match(driver, /F2: edit selected Inbox row/);
  assert.match(driver, /Click the session avatar outside the sidebar editor to save/);
  assert.doesNotMatch(driver, /\$sidePoint\[0\] - 50/);
});
