const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = require('./app-source').readAppSource();

function bodyOf(signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `missing ${signature}`);
  const nextFn = source.indexOf("\nfn ", start + signature.length);
  return source.slice(start, nextFn === -1 ? source.length : nextFn);
}

test("custom groups are top-level workspace blocks with pinned-first members", () => {
  const layout = bodyOf("fn layoutRows(out: *[MAX_ROWS]Row) u32 {");
  assert.match(layout, /for \(0\.\.group_count\) \|gidx\|/);
  assert.match(layout, /member_tier_pass: i32 = @intFromEnum\(SidebarTier\.pinned\)/);
  assert.match(layout, /shells\[i\]\.group_id != gid/);
  assert.match(layout, /shells\[i\]\.workspace != g_active_workspace/,
    "group rows must be scoped to the active workspace");
});

test("creating a group immediately opens its name editor", () => {
  assert.match(source, /target == SEARCH_TABCTX_GROUP_NEW[\s\S]*?rename_group_idx = findGroupIdx\(new_gid\)/);
  assert.match(source, /if \(rename_group_idx\) \|gidx\| \{\s*startGroupRename\(gidx\)/);
});

test("Ctrl+K moves the active session through a keyboard-first group submenu", () => {
  assert.match(source, /const SEARCH_GROUPMOVE_MENU_OFFSET/);
  assert.match(source, /g_search_results\[g_search_result_count\] = SEARCH_GROUPMOVE_MENU_OFFSET/);
  assert.match(source, /if \(g_search_group_move_mode\) \{[\s\S]*?SEARCH_GROUPMOVE_BACK_OFFSET[\s\S]*?SEARCH_GROUPMOVE_GROUP_OFFSET \+ gi[\s\S]*?SEARCH_GROUPMOVE_NEW_OFFSET[\s\S]*?SEARCH_GROUPMOVE_NONE_OFFSET/);
  assert.match(source, /target == SEARCH_GROUPMOVE_MENU_OFFSET[\s\S]*?g_groupmove_tab_sid = if \(active_shell < shell_count\) shells\[active_shell\]\.shell_id/,
    "opening the submenu must capture the active session by stable ID");
  assert.match(source, /assignTabOrSelectionToGroup\(g_groupmove_tab_sid, groups\[gi\]\.id\)/);
  assert.match(source, /removeTabOrSelectionFromGroup\(g_groupmove_tab_sid\)/);
  assert.match(source, /else if \(g_search_group_move_mode\)[\s\S]*?g_groupmove_tab_sid = 0/,
    "Escape must return from the submenu without moving anything");
});

test("palette and context-menu group moves share selection semantics", () => {
  const assign = bodyOf("fn assignTabOrSelectionToGroup(captured_sid: u32, gid: u32) bool {");
  const remove = bodyOf("fn removeTabOrSelectionFromGroup(captured_sid: u32) bool {");
  assert.match(assign, /selectedTabCount\(\) > 0[\s\S]*?applyGroupToSelectedTabs\(gid\)/);
  assert.match(assign, /findShellById\(captured_sid\)/);
  assert.match(remove, /selectedTabCount\(\) > 0[\s\S]*?setTabGroupId\(si, 0\)/);
  assert.match(source, /target == SEARCH_TABCTX_GROUP_NEW[\s\S]*?assignTabOrSelectionToGroup\(tc_sid, new_gid\)/);
  assert.match(source, /target == SEARCH_TABCTX_GROUP_REMOVE[\s\S]*?removeTabOrSelectionFromGroup\(tc_sid\)/);
});

test("dragging onto a group changes membership without changing pin or lock", () => {
  const tierDrop = bodyOf("fn sidebarTierForDrop(hit: HitTarget) ?SidebarTier {");
  assert.match(tierDrop, /\.header => null/);
  assert.match(tierDrop, /tabGroupId\(idx\) == 0/);

  assert.match(source, /if \(target_gid != 0\)[\s\S]*?moveShellToIndexWithGroup/);
  assert.match(source, /\.header => \|tgidx\|[\s\S]*?moveShellToGroupStart/);
  assert.doesNotMatch(tierDrop, /locked/);
});

test("dragging a group header reorders the persisted group array in every sort mode", () => {
  const moveGroup = bodyOf("fn moveGroupToIndex(src: u32, dst: u32) bool {");
  assert.match(moveGroup, /const moved = groups\[src\]/);
  assert.match(moveGroup, /groups\[i\] = groups\[i \+ 1\]/);
  assert.match(moveGroup, /groups\[i\] = groups\[i - 1\]/);
  assert.match(moveGroup, /groups\[dst\] = moved/);
  assert.doesNotMatch(moveGroup, /shells\[/,
    "group sorting must change header order rather than shuffling session storage");

  assert.match(source, /if \(gidx < group_count\) \{\s+drag_pending_materialize = false/);
  assert.doesNotMatch(source, /Group reordering still requires explicit Manual order/);
  assert.match(source, /moveGroupToIndex\(drag_group_gidx, dst_gidx\)[\s\S]*?drag_group_gidx = dst_gidx[\s\S]*?saveSession\(\)/,
    "header drag must follow its new index and persist the reordered array");
});

test("moving tabs between workspaces keeps groups workspace-local", () => {
  const moveOne = bodyOf("fn moveTabToPill(tab_idx: u32, slot: u8) void {");
  const moveSelected = bodyOf("fn moveSelectedTabsToPill(slot: u8) void {");
  const moveGroup = bodyOf("fn moveGroupToPill(gidx: u32, slot: u8) void {");
  assert.match(moveOne, /group_id = 0;/);
  assert.match(moveSelected, /group_id = 0/);
  assert.match(moveGroup, /shells\[i\]\.workspace = slot;/);
});
