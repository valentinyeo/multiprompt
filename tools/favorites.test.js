const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
const jsonReader = fs.readFileSync(path.join(__dirname, "../src/json_reader.zig"), "utf8");
const wiki = fs.readFileSync(path.join(__dirname, '../openwiki/operations/keyboard-shortcuts.md'), 'utf8');
function between(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `missing source boundary ${start} / ${end}`);
  return source.slice(a, b);
}

test('favorite toggle, split filter and JSON parser execute as native Zig unit tests', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-favorite-test-'));
  try {
    for (const name of ['json_reader.zig', 'archive_rules.zig', 'voice_filter.zig']) fs.copyFileSync(path.join(__dirname, '../src', name), path.join(tmp, name));
    const pure = 'const std = @import("std");\nconst json_reader = @import("json_reader.zig");\n' +
      between('fn toggledFavorite(', 'fn toggleFavorite(') +
      between('test "favorite toggle', 'fn inboxRowVisible(');
    const file = path.join(tmp, 'favorites.zig');
    fs.writeFileSync(file, pure);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'favorite'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 2 tests passed/);
  } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
});

test('both initializers and every persisted restore/reconnect path retain favorites', () => {
  assert.match(between('const empty_shell', 'var shells'), /\.favorite = false/);
  assert.match(between('fn spawnShellWithSession(', 'fn respawnShellInPlace('), /\.favorite = false/);
  assert.match(between('fn saveSessionTo(', 'fn saveSession('), /shells\[i\]\.favorite[\s\S]*?\\"favorite\\":true/);
  assert.match(between('fn parseSessionTabs(', 'fn restoreBrowserStateFromSavedTab('), /json_reader\.sessionTabs/);
  assert.match(jsonReader, /"favorite"/);
  assert.match(jsonReader, /@field\(tab, key\) = boolTrue\(obj, key\)/);
  assert.match(between('fn preserveFailedRemoteSavedTab(', 'fn parseSessionTabs('), /shell\.favorite = tab\.favorite/);
  assert.match(between('fn spawnSavedTab(', 'fn restoreSession('), /shells\[idx\]\.favorite = tabs\[t\]\.favorite/);
  assert.match(between('fn respawnShellInPlace(', 'fn faviconHostForShell('), /\.favorite = saved_favorite/);
  assert.equal((source.match(/shells\[idx\]\.favorite = tabs\[t\]\.favorite/g) || []).length, 2);
});

test('tab moves carry favorites over COPYDATA and new-window adoption', () => {
  for (const literal of ['favorite: u8,', 'transfer.favorite = if (shell.favorite) 1 else 0;', 'new_shell.favorite = transfer.favorite != 0;', 'g_adopt_favorite = haystack[cur] ==', 'new_shell.favorite = g_adopt_favorite;', "cmd_buf[pos] = if (shell.favorite) '1' else '0';"]) assert.ok(source.includes(literal), literal);
  const adoption = between('fn pollShellNames(', 'fn ');
  assert.doesNotMatch(adoption, /\.favorite\s*=/);
});

test('favorite action saves and immediately publishes both true and false states', () => {
  const action = between('fn toggleFavorite(', 'test "favorite toggle');
  for (const call of ['toggledFavorite(shells[idx].favorite)', 'publishInboxStateNow()', 'saveSession()', 'invalidateSidebar()', 'loadInboxModel()']) assert.ok(action.includes(call), call);
  const publisher = between('fn publishInboxStateNow(', 'fn deleteInboxStateFile(');
  assert.ok(publisher.includes('if (shells[i].favorite) ",\\"favorite\\":true" else ",\\"favorite\\":false"'));
  assert.match(between('fn loadInboxFile(', 'fn inboxRowLess('), /\.favorite = json_reader\.boolTrue\(o, "favorite"\)/);
  assert.match(between('fn inboxRowVisible(', 'fn inboxListTop('), /favoriteSplitMatches\(g_inbox_tab, r.ws, r.favorite\)/);
});

test('Favorites split follows ALL and shares ALL ordering, rows and navigation', () => {
  const paint = between('fn paintInbox(', 'fn openInbox(');
  assert.ok(paint.indexOf('"All"') < paint.indexOf('"Favorites"'));
  assert.ok(paint.indexOf('"Favorites"') < paint.indexOf('for (0..g_inbox_ws_count)'));
  assert.match(paint, /if \(g_unread_only\) unread else total/);
  assert.match(paint, /No favorites yet\. Press Alt\+S on a session to add it\./);
  assert.match(between('fn handleInboxKey(', 'fn '), /while \(t < g_inbox_ws_count \+ 1\)/);
  assert.equal((source.match(/const splits = g_inbox_ws_count \+ 2/g) || []).length, 2);
  assert.match(source, /const INBOX_MAX_SPLIT_TABS: usize = INBOX_MAX_WS \+ 2/);
  assert.match(source, /g_inbox_step_context_tab > g_inbox_ws_count \+ 1/);
});

test('keyboard, palette, context, F1 and wiki expose the same favorite action', () => {
  for (const literal of ['WM_APP_FAVORITE_TOGGLE', 'SEARCH_FAVORITE_OFFSET', 'SEARCH_TABCTX_FAVORITE', 'L("Favorite: Toggle")', 'L("Unfavorite")', 'L("on  Alt+S")', 'L("off  Alt+S")', 'toggleFavorite(ti);', '.a = "Alt+S", .b = "Favorite or unfavorite this session"']) assert.ok(source.includes(literal), literal);
  assert.match(source, /target >= SEARCH_TABCTX_RECONNECT and target <= SEARCH_TABCTX_FAVORITE/);
  const hook = between('fn keyboardHookProc(', 'fn pointOverActiveShell(');
  assert.ok(hook.indexOf("kb.vkCode == 0x53 and foregroundIsOurs()") < hook.indexOf('if (g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus())'));
  assert.match(hook, /claimBrowserFocusPress\(true, &g_favorite_chord_held\)/);
  assert.match(hook, /WM_APP_TOGGLE_INBOX/);
  assert.doesNotMatch(hook, /PostMessageW\(g_main_hwnd, WM_APP_WEBVIEW2_TOGGLE/);
  assert.ok(wiki.includes('`Favorite: Toggle`') && wiki.includes('`Favorite` / `Unfavorite`') && wiki.includes('`★ Favorites`'));
});


test('favorite stars use native gold geometry rather than a font-dependent glyph', () => {
  const draw = between('fn drawFavoriteStar(', 'fn drawSessionLockIcon(');
  assert.match(draw, /RGB\(240, 196, 75\)/);
  assert.match(draw, /Polygon\(hdc, &points, points.len\)/);
  assert.equal((source.match(/drawFavoriteStar\(hdc, &star_rc\)/g) || []).length, 4);
});
