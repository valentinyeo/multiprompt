const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || process.cwd();
const shortcuts = fs.readFileSync(path.join(root, 'src/shortcuts.zig'), 'utf8');
const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');

test('new chat traces entry before locked and focus guards', () => {
  const hook = shortcuts.slice(shortcuts.indexOf('pub fn keyboardHookProc'));
  assert.ok(hook.indexOf('new-chat key entry') < hook.indexOf('if (app_state.g_account_locked)'));
  assert.match(hook, /new-chat key entry/);
  assert.match(hook, /if \(activeBrowserSurfaceHasForegroundFocus\(\)\)\s*\{\s*debugLog\("new-chat browser owns Ctrl\+T"\)/);
  assert.match(hook, /new-chat key post failed/);
});

test('new chat receipt distinguishes launch failures from folder picker', () => {
  const handler = main.slice(main.indexOf('WM_APP_NEW_TAB_DEFAULT => {'), main.indexOf('WM_APP_UI_BIGGER => {'));
  assert.ok(main.indexOf('new-chat message received') < main.indexOf('if (app_state.g_account_locked) {', main.indexOf('fn wndProc(')));
  assert.match(handler, /g_start_fail/);
  assert.doesNotMatch(handler, /Workspace folder unavailable/);
  assert.match(handler, /\.capacity/);
  assert.match(handler, /\.launch_command/);
  assert.match(handler, /\.spawn_shell/);
  assert.match(palette.slice(palette.indexOf('fn spawnWorkspaceSession(')), /g_start_fail = \.none/);
});

test('failed live identity cannot silently become a terminal', () => {
  const start = palette.slice(palette.indexOf('fn spawnWorkspaceSessionAt('), palette.indexOf('fn workspaceFolderForNewChat('));
  assert.match(start, /newTabOpensChatView\(program\).*host_sid == null/s);
  assert.match(start, /g_start_fail = \.launch_command/);
  assert.match(start, /shell\.chat_view_on = true/);
  assert.match(start, /live\.starting\(/);
});
