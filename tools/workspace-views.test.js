const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

const switcher = read('src/workspace_switcher.zig');
const palette = read('src/command_palette.zig');
const sidebar = read('src/sidebar.zig');
const main = read('src/main.zig');
const shortcuts = read('src/shortcuts.zig');
const wiki = read('openwiki/operations/keyboard-shortcuts.md');

function between(source, start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} ... ${end}`);
  return source.slice(a, b);
}

test('SOFT-2380 workspace menu shows All Frequent and Favorites above the real workspaces', () => {
  assert.match(switcher, /const view_rows: usize = 3;/);
  assert.match(switcher, /fn rowCount\(\) usize \{\n    return entry_count \+ view_rows \+ 1;/);
  const mapping = between(switcher, 'fn viewSplitAt(', 'fn viewRowForSplit(');
  assert.match(mapping, /0 => frequent\.all_split/);
  assert.match(mapping, /1 => frequent\.frequent_split/);
  assert.match(mapping, /frequent\.favorites_split/);
  assert.match(mapping, /0 => workspace_view\.all_view/);
  assert.match(mapping, /1 => workspace_view\.frequent_view/);
  assert.match(mapping, /workspace_view\.starred/);
  const activate = between(switcher, 'fn activate(', 'pub fn headerClick(');
  assert.match(activate, /if \(index < view_rows\) \{\n        workspaces\.switchToWorkspace\(viewEntryAt\(index\)\);/);
  const paint = between(switcher, '        const name = if (index < view_rows)', '        drawName(dc, name, &label, flags);');
  assert.match(paint, /workspace_view\.viewName\(viewSplitAt\(index\)\)/);
  const header = between(switcher, 'pub fn paintHeader(', 'fn rowCount()');
  assert.match(header, /if \(app_state\.g_starred_workspace\) workspace_view\.viewName\(app_state\.g_view_split\)/);
  const journey = read('.claude/skills/verify-multiprompt/workspace-switcher.ps1');
  assert.match(journey, /function Get-WorkspaceViewRows/);
  assert.match(journey, /\$target = \$index \+ \$views/);
  assert.doesNotMatch(journey, /\$target = \$index \+ 1/);
});

test('SOFT-2380 the three views reuse the inbox membership rule instead of copying it', () => {
  const view = read('src/workspace_view.zig');
  assert.match(view, /pub fn includes\(tab: u32, ws: u32, favorite: bool, visits: \[\]const u64, input: u64, now_ms: u64\) bool \{\n    return switch \(frequent\.splitKind\(tab\)\) \{\n        \.frequent => frequent\.inFrequent\(/);
  const inbox = read('src/inbox.zig');
  assert.match(inbox, /fn inboxFrequent\(row: InboxRow, now_ms: u64\) bool \{\n    return @import\("workspace_view\.zig"\)\.includes\(frequent\.frequent_split/);
  assert.match(inbox, /favoriteSplitMatches\(app_state\.g_inbox_tab, r\.ws, r\.favorite\)/);
  assert.match(inbox, /if \(ka != kb\) return frequent\.newestFirst\(ka, kb\);/);
  assert.match(inbox, /return view\.newer\(app_state\.g_inbox_tab/);
  assert.match(read('src/workspaces.zig'), /@import\("workspace_view\.zig"\)\.includes\(app_state\.g_view_split, shell\.workspace, shell\.favorite/);
  assert.match(sidebar, /@import\("workspace_view\.zig"\)\.includes\(app_state\.g_view_split, row\.ws, row\.favorite/);
  assert.match(sidebar, /view\.includes\(app_state\.g_view_split, row\.ws, row\.favorite, view\.visitSlice/);
  assert.doesNotMatch(sidebar, /frequent\.inFrequent\(/);
  assert.doesNotMatch(switcher, /frequent\.inFrequent\(/);
});

test('SOFT-2380 All and Frequent list every matching session newest first', () => {
  assert.match(sidebar, /frequent\.splitKind\(app_state\.g_view_split\) != \.favorites/);
  assert.match(sidebar, /view\.newer\(app_state\.g_view_split, flatViewOrder/);
  assert.match(read('src/workspace_view.zig'), /pub fn recencyKey\(tab: u32, la: u64, lv: u64/);
  assert.match(read('src/workspace_view.zig'), /\.frequent => frequent\.orderKey/);
  assert.match(read('src/workspace_view.zig'), /else => @max\(la, lv\)/);
  assert.match(read('src/drawing.zig'), /if \(app_state\.g_starred_workspace\) app_state\.g_view_split else @import\("frequent\.zig"\)\.favorites_split/);
  assert.match(switcher, /shell\.inbox_archived and !shell\.needs_attention/);
});

test('SOFT-2380 every view has a Ctrl+K row and a shortcut row', () => {
  for (const offset of ['SEARCH_VIEW_ALL_OFFSET', 'SEARCH_VIEW_FREQUENT_OFFSET', 'SEARCH_STARRED_OFFSET']) {
    assert.match(palette, new RegExp(`g_search_results\\[app_state\\.g_search_result_count\\] = ${offset};`));
    assert.match(sidebar, new RegExp(`result_idx == ${offset}`));
    assert.match(main, new RegExp(`target == ${offset}`));
  }
  for (const label of ['Workspace view: All sessions', 'Workspace view: Favorites', 'Workspace view: Frequent']) {
    assert.ok(shortcuts.includes(`Ctrl+K -> ${label}`), label);
    assert.ok(wiki.includes(`Ctrl+K -&gt; ${label}`), label);
  }
});

test('SOFT-2380 opening any view keeps single-window workspace switching intact', () => {
  const switchTo = between(read('src/workspaces.zig'), 'pub fn switchToWorkspace(', 'app_state.g_active_workspace = ws;');
  assert.match(switchTo, /const view = @import\("workspace_view\.zig"\)\.isView\(ws_target\);\n    if \(view\) app_state\.g_view_split = @import\("workspace_view\.zig"\)\.viewSplit\(ws_target\);/);
  assert.match(switchTo, /if \(ws_in == @import\("workspace_view\.zig"\)\.starred\) \{/);
  assert.match(switchTo, /if \(ws_in >= app_state\.g_lws_count or app_state\.g_ws_snoozed\[ws_in\]\) return;/);
});
