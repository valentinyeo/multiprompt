const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('Ctrl+Shift+W deletes the current session and does not quit the app', () => {
  const shortcuts = read('src/shortcuts.zig');
  const route = shortcuts.match(/\.delete_session =>([^\n]+)/);
  assert.ok(route);
  assert.match(route[1], /PostMessageW\(app_state\.g_main_hwnd, WM_APP_CLOSE_SESSION, 0, 0\)/);
  assert.doesNotMatch(route[1], /WM_APP_QUIT_ALL/);
  const main = read('src/main.zig');
  const close = main.slice(main.indexOf('        WM_APP_CLOSE_SESSION => {'), main.indexOf('        WM_APP_MORE_MENU_ACTION => {'));
  assert.match(close, /endActiveTmuxSession\(\)/);
  assert.match(close, /closeNonTmuxTabAt\(app_state\.active_shell\)/);
  const quit = main.slice(main.indexOf('if (target == SEARCH_QUIT_OFFSET)'), main.indexOf('if (target == SEARCH_UPDATE_OFFSET)'));
  assert.match(quit, /quitAllZigShellWindows\(hwnd\)/);
});

test('Ctrl+W is left for the browser pane and only Ctrl+Shift+W deletes the session', () => {
  const shortcuts = read('src/shortcuts.zig');
  const fn = shortcuts.slice(shortcuts.indexOf('pub fn sessionCloseShortcut('), shortcuts.indexOf('test "SOFT-2355'));
  assert.match(fn, /!shift/);
  assert.match(fn, /return \.delete_session/);
  assert.doesNotMatch(fn, /return \.quit/);
  assert.match(shortcuts, /\.a = "Ctrl\+Shift\+W", \.b = "Delete the current session/);
  assert.doesNotMatch(shortcuts, /\.a = "Ctrl\+W",/);
  const drive = read('tools/verify-session-actions/drive.ps1');
  assert.match(drive, /Check 'ctrl-w-does-not-quit'/);
  assert.doesNotMatch(drive, /Ctrl\+Shift\+W quits/);
});

test('Alt+X no longer has an archive binding or shortcut row', () => {
  const shortcuts = read('src/shortcuts.zig');
  assert.doesNotMatch(shortcuts, /\.a = "Alt\+X"|WM_APP_ARCHIVE_ARM/);
  assert.doesNotMatch(shortcuts, /kb\.vkCode == 0x45 or kb\.vkCode == 0x58/);
  assert.doesNotMatch(read('openwiki/operations/keyboard-shortcuts.md'), /\| Alt\+X \|/);
});

test('both palettes use the approved seven action names in fixed context order', () => {
  const source = read('src/command_palette.zig');
  const table = source.slice(source.indexOf('pub const chat_actions ='), source.indexOf('pub fn chatActionLabel('));
  assert.deepEqual([...table.matchAll(/\.label = "([^"]+)"/g)].map(match => match[1]), ['Pin', 'Move to workspace', 'Mark as unread', 'Rename', 'Copy chat ID', 'Archive chat', 'Delete session']);
  const context = source.slice(source.indexOf('    if (app_state.g_search_tabctx_mode) {\n        app_state.g_search_result_count = 0;'), source.indexOf('    if (app_state.g_search_workspace_mode) {', source.indexOf('    if (app_state.g_search_tabctx_mode) {\n        app_state.g_search_result_count = 0;')));
  assert.match(context, /appendChatActions\(index\)/);
  assert.doesNotMatch(context, /SEARCH_TABCTX_BACK|preferFirstFilteredResultAfterBack/);
  assert.match(source, /appendChatActions\(app_state.active_shell\)/);
});

test('deletion saves a history record before either remote stop or local removal', () => {
  const source = read('src/archive.zig');
  const end = source.slice(source.indexOf('pub fn endTmuxSessionAt('), source.indexOf('pub fn endActiveTmuxSession('));
  assert.ok(end.indexOf('rememberArchivedTab(i) orelse return') < end.indexOf('killRemoteTmuxSession('));
  assert.ok(end.indexOf('rememberArchivedTab(i) orelse return') < end.indexOf('closeShellRemember('));
  const history = source.slice(source.indexOf('fn rememberArchivedTab('), source.indexOf('pub fn archiveTabAt('));
  assert.match(history, /entry.claude_sid/);
  assert.match(history, /if \(!saveArchive\(\)\)/);
});
