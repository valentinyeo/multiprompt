const { copyZig } = require('./zig-copy');
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
    copyZig(['json_reader.zig', 'archive_rules.zig', 'voice_filter.zig', 'frequent.zig'], tmp);
    const pure = 'const frequent = @import("frequent.zig");\nconst std = @import("std");\nconst json_reader = @import("json_reader.zig");\n' +
      between('fn toggledFavorite(', 'fn toggleFavorite(') +
      between('test "favorite toggle', 'test "used JSON field');
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

test('Favorites split follows Frequent and ALL by default and shares configured split navigation', () => {
  const paint = between('fn paintInbox(', 'fn openInbox(');
  assert.ok(paint.indexOf('"Frequent"') < paint.indexOf('"All"'));
  assert.ok(paint.indexOf('"All"') < paint.indexOf('"Favorites"'));
  assert.ok(paint.indexOf('"Favorites"') < paint.indexOf('for (0..g_inbox_ws_count)'));
  assert.match(paint, /if \(g_unread_only\) unread else total/);
  assert.match(paint, /No favorites yet\. Press Alt\+S on a session to add it\./);
  const keys = between('fn handleInboxKey(', 'fn ');
  assert.match(keys, /moveInboxSplit\(wp == 2, false\)/);
  assert.match(keys, /moveInboxSplit\(wp == 7, true\)/);
  const navigation = between('fn moveInboxSplit(', 'fn inboxVisibleCount(');
  assert.match(navigation, /frequent\.builtinSplits\(g_layout_settings orelse \.\{\}\)/);
  assert.match(navigation, /if \(inboxSplitVisible\(tab\)\)/);
  assert.match(source, /const INBOX_MAX_SPLIT_TABS: usize = INBOX_MAX_WS \+ @import\("frequent.zig"\)\.first_ws_split/);
  assert.match(source, /g_inbox_step_context_tab > frequent\.splitCount\(g_inbox_ws_count\) - 1/);
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


test('favorite marker is one small dot everywhere', async () => {
  assert.doesNotMatch(source, /drawFavoriteStar/);
  assert.match(source, /FAVORITE_DOT_D: i32 = 6/);
  const draw = between('fn drawFavoriteDot(', 'fn drawSessionLockIcon(');
  assert.ok(draw.includes('drawAttentionDot(hdc, cx, cy, @divTrunc(FAVORITE_DOT_D, 2), RGB(240, 196, 75));'));
  assert.equal((source.match(/drawFavoriteDot\(hdc,/g) || []).length, 4);
  const sidebar = fs.readFileSync(path.join(__dirname, '../src/sidebar.zig'), 'utf8');
  assert.doesNotMatch(sidebar, /@as\(i32, 18\) else 0/);
  const shot = fs.readFileSync(path.join(__dirname, 'chat-bench/demo-shot.mjs'), 'utf8');
  const workspace = fs.readFileSync(path.join(__dirname, 'chat-bench/demo-workspace.mjs'), 'utf8');
  assert.match(shot, /tabs: sessions\.map\(s => \(\{[^}]*favorite: !!s\.favorite/);
  assert.equal((workspace.match(/favorite: true/g) || []).length, 1);
  const { sessions } = await import('./chat-bench/demo-workspace.mjs');
  assert.equal(sessions.filter(s => s.favorite).length, 1);
  assert.ok(sessions.every(s => !s.hero || !s.favorite));
});
