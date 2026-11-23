const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

function matchRank(text, query) {
  const hay = text.toLowerCase();
  const needle = query.toLowerCase();
  if (hay === needle) return 4;
  if (hay.startsWith(needle)) return 3;
  let start = 0;
  while (start < hay.length) {
    while (start < hay.length && !/[a-z0-9]/i.test(hay[start])) start += 1;
    if (start >= hay.length) break;
    if (hay.slice(start).startsWith(needle)) return 2;
    while (start < hay.length && /[a-z0-9]/i.test(hay[start])) start += 1;
  }
  return hay.includes(needle) ? 1 : 0;
}

function prefersDeleteSession(query) {
  const label = 'delete session';
  const q = query.toLowerCase();
  return q.length >= 3 && q.length <= label.length && label.startsWith(q);
}

test('SOFT-2355 typing del ranks Delete session first and Ctrl+Shift+W deletes the session', () => {
  const palette = read('src/command_palette.zig');
  const shortcuts = read('src/shortcuts.zig');
  const table = palette.slice(palette.indexOf('pub const chat_actions ='), palette.indexOf('pub fn chatActionLabel('));
  const labels = [...table.matchAll(/SEARCH_TABCTX_END_TMUX, \.label = "([^"]+)"/g)].map(match => match[1]);
  assert.deepEqual(labels, ['Delete chat']);
  assert.equal(matchRank('Delete session', 'del'), matchRank('delete workspace', 'del'));
  assert.equal(matchRank('Delete session', 'del'), 3);
  assert.ok(prefersDeleteSession('del'));
  assert.ok(!prefersDeleteSession('delete w'));
  const outranks = palette.slice(palette.indexOf('fn paletteResultOutranks('), palette.indexOf('fn sortSearchResultsByRank('));
  assert.match(outranks, /const key_delete = paletteQueryPrefersDeleteSession\(key\);/);
  assert.match(outranks, /const prev_delete = paletteQueryPrefersDeleteSession\(prev\);/);
  assert.match(outranks, /if \(key_delete != prev_delete\) return key_delete;/);
  const prefer = palette.slice(palette.indexOf('fn paletteQueryPrefersDeleteSession('), palette.indexOf('fn paletteResultOutranks('));
  assert.match(prefer, /target != SEARCH_TABCTX_END_TMUX/);
  assert.match(prefer, /"delete session"/);
  assert.match(prefer, /query\.len < 3/);

  const shortcut = shortcuts.slice(shortcuts.indexOf('pub fn sessionCloseShortcut('), shortcuts.indexOf('fn noteJumpBadgeKey('));
  assert.match(shortcut, /return \.delete_session;/);
  assert.doesNotMatch(shortcut, /return \.quit;/);
  const hookAt = shortcuts.indexOf('if (sessionCloseShortcut(');
  const hook = shortcuts.slice(hookAt, shortcuts.indexOf('if (@import("settings_panel.zig")', hookAt));
  assert.match(hook, /\.delete_session =>[^\n]*WM_APP_CLOSE_SESSION/);
  assert.doesNotMatch(hook, /WM_APP_QUIT_ALL/);
  assert.match(shortcuts, /\.a = "Ctrl\+Shift\+W", \.b = "Delete the current session/);
  assert.match(shortcuts, /\.a = "Ctrl\+K -> Delete chat"/);
  assert.match(shortcuts, /\.a = "Ctrl\+K -> Quit Multi Bot", \.b = "Quit the app/);
  assert.doesNotMatch(shortcuts, /Ctrl\+Shift\+W", \.b = "Quit the app/);

  const main = read('src/main.zig');
  const quit = main.slice(main.indexOf('if (target == SEARCH_QUIT_OFFSET)'), main.indexOf('if (target == SEARCH_UPDATE_OFFSET)'));
  assert.match(quit, /quitAllZigShellWindows\(hwnd\)/);
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /result_idx == SEARCH_TABCTX_END_TMUX[\s\S]{0,500}L\("Ctrl\+Shift\+W"\)/);
  assert.match(read('src/ui_words.zon'), /\.palette_quit = "Quit Multi Bot"/);
});
