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
    copyZig(['json_reader.zig', 'archive_rules.zig', 'voice_filter.zig', 'frequent.zig', 'workspace_view.zig'], tmp);
    const pure = 'const frequent = @import("frequent.zig");\nconst std = @import("std");\nconst ReadBoundary = struct { index: ?usize = null, unknown: bool = false };\nvar g_chat_read_boundary: ReadBoundary = .{};\nvar g_chat_read_divider_y: i32 = 0;\nvar g_chat_scrolled_up = false;\nfn chatReadBoundary() ReadBoundary { return .{}; }\nfn chatReadMark(_: bool) bool { return false; }\nconst json_reader = @import("json_reader.zig");\n' +
      between('fn toggledFavorite(', 'fn toggleFavorite(') +
      between('test "favorite toggle', 'test "used JSON field');
    const file = path.join(tmp, 'favorites.zig');
    fs.writeFileSync(file, pure.replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'favorite'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
  } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
});

test('both initializers and every persisted restore/reconnect path retain favorites', () => {
  assert.match(between('const empty_shell', 'var shells'), /\.favorite = false/);
  assert.match(between('fn spawnShellWithSession(', 'fn respawnShellInPlace('), /\.favorite = g_starred_workspace and g_pending_new_tab_group != 0,/);
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
  const draw = between('fn drawFavoriteDot(', 'fn paintAllSessions(');
  assert.ok(draw.includes('drawAttentionDot(hdc, cx, cy, @divTrunc(FAVORITE_DOT_D, 2), RGB(240, 196, 75));'));
  assert.equal((source.match(/drawFavoriteDot\(hdc,/g) || []).length, 5);
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

test('IGSH-457 Starred uses shared live membership and digit mapping on every navigation surface', () => {
  const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  const inbox = read('src/inbox.zig');
  const workspaces = read('src/workspaces.zig');
  const sidebar = read('src/sidebar.zig');
  const hook = read('src/shortcuts.zig');
  const main = read('src/main.zig');
  assert.match(inbox, /const favoriteSplitMatches = @import\("workspace_view.zig"\).splitMatches/);
  assert.match(workspaces, /@import\("workspace_view.zig"\).contains\(true, 0, shell.workspace, shell.favorite\)/);
  const starredSwitch = workspaces.slice(workspaces.indexOf('if (ws_in == @import("workspace_view.zig").starred)'), workspaces.indexOf('if (ws_in >= app_state.g_lws_count'));
  assert.match(starredSwitch, /updateMainWindowTitle\(\);\s*_ = InvalidateRect\(app_state.g_main_hwnd, null, 0\);\s*if \(!app_state.g_restoring and app_state.g_chat_browser_swap.shell_id == 0\) saveSession\(\);\s*return;/);
  assert.equal((hook.match(/WM_APP_SWITCH_WORKSPACE, @import\("workspace_view.zig"\).fromDigit\(kb.vkCode - 0x30\).\?/g) || []).length, 2);
  assert.doesNotMatch(hook, /WM_APP_SWITCH_WORKSPACE, kb.vkCode - 0x31/);
  assert.match(sidebar, /if \(app_state.g_starred_workspace\) \{[\s\S]*?starredShellVisible\(i\)[\s\S]*?return count;/);
  assert.match(main, /const cur: u32 = if \(app_state.g_starred_workspace\) 0 else @as\(u32, app_state.g_active_workspace\) \+ 1/);
  assert.match(main, /target == SEARCH_STARRED_OFFSET/);
  assert.match(main, /const jumpToInboxRow = @import\("inbox.zig"\).jumpToInboxRow;/);
  assert.match(inbox, /pub fn jumpToInboxRow\(ri: u32\) void/);
  assert.match(workspaces, /const SetTimer = @import\("win32.zig"\).SetTimer;/);
  assert.match(read('src/win32.zig'), /pub extern "user32" fn SetTimer\(/);
  assert.match(sidebar, /L\("Go to Starred workspace"\)/);
  assert.match(sidebar, /No starred sessions\. Press Alt\+S on a session to star it\./);
});


test('IGSH-457 serialization coverage stays separate from the ISSUE-439 round trip', () => {
  const workspaces = fs.readFileSync(path.join(__dirname, '../src/workspaces.zig'), 'utf8');
  const roundTrip = between('test "IGSH-522 session JSON round trip keeps workspace focus and ISSUE-439 last shell"', 'test "IGSH-457 Starred is never serialized into session or synced layout"');
  assert.match(roundTrip, /parseSessionTabs\(bytes, &tabs\)/);
  assert.match(roundTrip, /swapWorkspaceSlots\(0, 1\)/);
  assert.doesNotMatch(roundTrip, /g_starred_workspace|captureSessionLayout/);
  const starred = workspaces.slice(workspaces.indexOf('test "IGSH-457 Starred is never serialized into session or synced layout"'), workspaces.indexOf('pub fn starredShellVisible('));
  assert.match(starred, /expect\(app_state.g_starred_workspace\)/);
  assert.match(starred, /saveSessionTo\(path, null\)/);
  assert.match(starred, /json_reader.uint\(parsed.value, "workspace_count"\)/);
  assert.match(starred, /json_reader.uint\(parsed.value, "active_workspace"\)/);
  assert.match(starred, /expectEqualStrings\(encoded_home, encoded_starred\)/);
  assert.match(starred, /account_layout.zig"\).rebase/);
});

test('IGSH-457 production Starred rows include other windows without duplicating local sessions', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-starred-rows-'));
  try {
    copyZig(['workspace_view.zig'], tmp);
    const sidebar = fs.readFileSync(path.join(__dirname, '../src/sidebar.zig'), 'utf8');
    const start = sidebar.indexOf('pub fn layoutRows(');
    const end = sidebar.indexOf('    const show_section_headers', start);
    assert.ok(start >= 0 && end > start);
    const groupIdStart = sidebar.indexOf('pub fn tabGroupId(');
    const groupIdEnd = sidebar.indexOf('pub fn setTabGroupId(', groupIdStart);
    const membershipStart = sidebar.indexOf('fn tabInCurrentWorkspace(');
    const membershipEnd = sidebar.indexOf('pub fn groupFirstShellIdx(', membershipStart);
    assert.ok(groupIdStart >= 0 && groupIdEnd > groupIdStart);
    assert.ok(membershipStart >= 0 && membershipEnd > membershipStart);
    const production = sidebar.slice(groupIdStart, groupIdEnd) + sidebar.slice(membershipStart, membershipEnd) +
      sidebar.slice(start, end) + '    return 0;\n}\n';
    fs.writeFileSync(path.join(tmp, 'workspaces.zig'), 'pub fn starredShellVisible(_: usize) bool { return @import("integration.zig").local_favorite; }\n');
    fs.writeFileSync(path.join(tmp, 'window_layout.zig'), 'pub fn paneOuterMargin() i32 { return 8; }\n');
    fs.writeFileSync(path.join(tmp, 'workspace_switcher.zig'), 'pub fn headerHeight() i32 { return 52; }\n');
    fs.writeFileSync(path.join(tmp, 'integration.zig'), (`const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const frequent = @import("frequent.zig");
const MAX_ROWS = 8;
const LOOK_UNIFIED = false;
const DEV_TOP_PAD = 0;
const GROUP_HEADER_H = 24;
const Row = struct { kind: enum { header, tab, inbox }, gidx: u32, shell_idx: u32, y: i32 };
const InboxRow = struct { ws: u32, favorite: bool };
pub var local_favorite = true;
pub const app_state = struct {
    var g_starred_workspace = true;
    var g_single_window = true;
    var g_active_workspace: u8 = 0;
    var shell_count: u32 = 1;
    var shells = [_]struct { group_id: u32 = 99, starred_group_id: u32 = 0, workspace: u8 = 0 }{.{}};
    var group_count: u32 = 0;
    var groups = [_]struct { id: u32, collapsed: bool }{.{ .id = 17, .collapsed = false }};
    var g_main_hwnd: ?*anyopaque = @ptrFromInt(1);
    var g_inbox_ws_count: u32 = 2;
    var g_inbox_ws = [_]struct { hwnd: usize }{ .{ .hwnd = 1 }, .{ .hwnd = 2 } };
    var g_inbox_row_count: u32 = 3;
    var g_inbox_rows = [_]InboxRow{ .{ .ws = 0, .favorite = true }, .{ .ws = 1, .favorite = true }, .{ .ws = 1, .favorite = false } };
};
fn wsStripHeight() i32 { return 40; }
fn tabRowH() i32 { return 32; }
${production}
test "IGSH-457 Starred mirrors local and other-account window favorites after star and unstar" {
    var rows: [MAX_ROWS]Row = undefined;
    try std.testing.expectEqual(@as(u32, 2), layoutRows(&rows));
    try std.testing.expectEqual(.tab, rows[0].kind);
    try std.testing.expectEqual(@as(i32, 92), rows[0].y);
    try std.testing.expectEqual(.inbox, rows[1].kind);
    try std.testing.expectEqual(@as(u32, 1), rows[1].shell_idx);
    local_favorite = false;
    app_state.g_inbox_rows[1].favorite = false;
    try std.testing.expectEqual(@as(u32, 0), layoutRows(&rows));
    app_state.g_inbox_rows[2].favorite = true;
    try std.testing.expectEqual(@as(u32, 1), layoutRows(&rows));
    try std.testing.expectEqual(@as(u32, 2), rows[0].shell_idx);
    local_favorite = true;
    app_state.group_count = 1;
    app_state.shells[0].starred_group_id = 17;
    try std.testing.expectEqual(@as(u32, 3), layoutRows(&rows));
    try std.testing.expectEqual(.header, rows[0].kind);
    try std.testing.expectEqual(.tab, rows[1].kind);
    try std.testing.expectEqual(@as(u32, 0), rows[1].shell_idx);
    try std.testing.expectEqual(.inbox, rows[2].kind);
    try std.testing.expectEqual(@as(u32, 2), rows[2].shell_idx);
    app_state.groups[0].collapsed = true;
    try std.testing.expectEqual(@as(u32, 2), layoutRows(&rows));
    try std.testing.expectEqual(.header, rows[0].kind);
    try std.testing.expectEqual(.inbox, rows[1].kind);
}
`).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(tmp, 'integration.zig'), '--test-filter', 'IGSH-457'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
});
