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
  for (const reason of ['account locked', 'session already open', 'no shell id', 'no title id', 'native shell', 'command line']) {
    assert.match(body, new RegExp(`spawnShell refused: ${reason}`), reason);
  }
});
