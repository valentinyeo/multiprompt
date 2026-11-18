const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

function terminalHandler(main) {
  const start = main.indexOf('if (target == SEARCH_NEW_TERMINAL_OFFSET) {');
  assert.ok(start >= 0, 'New terminal confirm handler must exist');
  const end = main.indexOf('if (target == SEARCH_OPEN_SESSION_MENU_OFFSET', start);
  assert.ok(end > start, 'handler must end before the next palette action');
  return main.slice(start, end);
}

test('SOFT-2460 New terminal asks for a folder before it closes the palette', () => {
  const body = terminalHandler(read('src/main.zig'));
  const spawn = body.indexOf('spawnWorkspaceTerminalSession()');
  const close = body.indexOf('g_search_active = false');
  assert.ok(spawn >= 0 && close > spawn, 'the palette must stay open until the folder is known');
  const pick = body.indexOf('g_search_pick_repo_mode');
  const refresh = body.indexOf('requestAllRepoRefresh()');
  const paint = body.indexOf('updateSearchResults()');
  const show = body.indexOf('showActiveShellAfterOverlay()');
  assert.ok(pick >= 0 && refresh > pick && paint > refresh, 'a missing folder must refresh the repo list in the open palette');
  const pickReturn = body.indexOf('return 0;', paint);
  assert.ok(pickReturn > paint && (show < 0 || pickReturn < show), 'a missing folder must not dismiss the palette');
});

test('SOFT-2460 a missing workspace folder is logged before the picker opens', () => {
  const palette = read('src/command_palette.zig');
  const start = palette.indexOf('fn spawnWorkspaceSession(with_agent: bool, plain_claude: bool) bool {');
  assert.ok(start >= 0);
  const body = palette.slice(start, palette.indexOf('\nfn ', start + 10));
  const pick = body.indexOf('pickRepoOpen(');
  const log = body.lastIndexOf('debugLog(', pick);
  assert.ok(pick > 0 && log >= 0 && log < pick, 'the missing-folder return must log before it opens the picker');
});

test('SOFT-2460 a plain shell spawn logs each silent refusal', () => {
  const consoleSrc = read('src/console.zig');
  const start = consoleSrc.indexOf('pub fn spawnShellWithSession(');
  assert.ok(start >= 0);
  const body = consoleSrc.slice(start, consoleSrc.indexOf('\nfn tmuxHostForMenuIndex', start));
  assert.match(body, /if \(app_state\.g_account_locked\) return false;/);
  assert.match(body, /if \(isRemoteShellKind\(kind\) and app_state\.g_shared_server_connection\) return spawnNativeShell\(/);
  for (const reason of ['session already open', 'no shell id', 'no title id', 'command line']) {
    assert.match(body, new RegExp(`spawnShell refused: ${reason}`), reason);
  }
  const native = consoleSrc.slice(consoleSrc.indexOf('fn spawnNativeShell('), start);
  assert.match(native, /spawnShell refused: native open/);
});

test('SOFT-2460 Ctrl+K lists Open shell on VPS 1 and VPS 2', () => {
  const palette = read('src/command_palette.zig');
  const rows = palette.slice(palette.indexOf('const SHELL_ROWS'), palette.indexOf('pub const PICK_REPO_LABEL'));
  assert.match(rows, /SEARCH_NEW_OFFSET \+ 3, \.keywords = "open shell on vps 1/);
  assert.match(rows, /SEARCH_NEW_OFFSET \+ 4, \.keywords = "open shell on vps 2/);
  assert.match(palette, /"Open shell on VPS 1"/);
  assert.match(palette, /"Open shell on VPS 2"/);
  const empty = palette.slice(palette.indexOf('keywordsMatchAll("new terminal shell plain"'), palette.indexOf('keywordsMatchAll("pick repo'));
  assert.match(empty, /SEARCH_NEW_OFFSET \+ 3/);
  assert.match(empty, /SEARCH_NEW_OFFSET \+ 4/);
  const main = read('src/main.zig');
  const menu = main.slice(main.indexOf('if (target == SEARCH_OPEN_SESSION_MENU_OFFSET or target == SEARCH_SHELLS_MENU_OFFSET)'), main.indexOf('if (target == SEARCH_REOPEN_OFFSET)'));
  assert.match(menu, /g_search_shells_mode = !open_session/);
  assert.doesNotMatch(menu, /g_search_shells_mode = false/);
  assert.doesNotMatch(menu, /g_search_open_session_mode = false/);
  assert.match(read('src/sidebar.zig'), /L\("Open shell on VPS 1"\)/);
  assert.match(read('src/sidebar.zig'), /L\("Open shell on VPS 2"\)/);
});

test('SOFT-2460 a shell tab reports its real size and the console font override', () => {
  const native = read('src/native_session.zig');
  const height = native.slice(native.indexOf('fn shellFontHeight()'), native.indexOf('fn shellFont('));
  assert.match(height, /g_console_font_override > 0/);
  assert.match(height, /mainWindowDpi\(\)/);
  const ready = native.slice(native.indexOf('pub fn ready('), native.indexOf('pub fn alive('));
  assert.match(ready, /repositionActive\(\)[\s\S]*mp_terminal_window_report\(/);
  const restyle = native.slice(native.indexOf('pub fn restyle('), native.indexOf('pub fn copy('));
  assert.match(restyle, /mp_terminal_window_style\([\s\S]*mp_terminal_window_report\(/);
  const window = read('src/terminal_window.c');
  assert.match(window, /void mp_terminal_window_report\(HWND hwnd\)/);
  assert.match(window, /if \(\(changed \|\| force\) && t->resize\) t->resize\(rows, cols, t->user\)/);
});
