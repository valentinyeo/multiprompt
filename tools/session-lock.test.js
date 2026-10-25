const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const jsonReader = fs.readFileSync(path.join(__dirname, "..", "src", "json_reader.zig"), "utf8");
const source = require('./app-source').readAppSource();

function bodyOf(signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `missing ${signature}`);
  const nextFn = source.indexOf("\nfn ", start + signature.length);
  return source.slice(start, nextFn === -1 ? source.length : nextFn);
}

test("IGSH-820 pinned protection uses one guard and no session lock state", () => {
  const reject = bodyOf("fn rejectPinnedSessionClose(i: usize) bool {");
  assert.match(reject, /!shells\[i\]\.pinned_top/);
  assert.match(reject, /unpin it before closing or archiving/);
  assert.doesNotMatch(source, /\blocked: (?:bool|u8)|drawSessionLockIcon|SEARCH_LOCK_SESSION_OFFSET|SEARCH_TABCTX_LOCK/);
  assert.doesNotMatch(jsonReader, /"locked"|"chat_view_lock"/);
  for (const name of ["closeShell", "archiveTabAt", "endTmuxSessionAt", "closeNonTmuxTabAt", "archiveArmOrCommit"]) {
    assert.match(bodyOf(`fn ${name}(`), /rejectPinnedSessionClose/);
  }
  for (const name of ["rejectPinnedWorkspaceClose", "rejectPinnedGroupClose", "rejectPinnedCloseAll"]) {
    assert.match(bodyOf(`fn ${name}(`), /rejectPinnedSessionClose/);
  }
  assert.match(bodyOf("fn closeMyWorkspaceSlot(slot: u8) void {"), /rejectPinnedWorkspaceClose\(slot\)[\s\S]*?exportSlotSessionFile/);
  assert.match(bodyOf("fn deleteMyWorkspaceSlot(slot: u8) void {"), /rejectPinnedWorkspaceClose/);
  assert.match(bodyOf("fn runGroupPaletteAction("), /rejectPinnedGroupClose\(gid\)/);
  assert.match(bodyOf("fn quitAllZigShellWindows("), /rejectPinnedCloseAll\(\)/);
  assert.match(source, /WM_APP_CLOSE => \{\s*if \(shell_count > 0\) \{\s*closeShell\(active_shell\)/);
});

test("IGSH-820 pinned rows retain the normal close cross without a pin-specific drawing", () => {
  const paint = bodyOf("fn paintSidebar(");
  assert.doesNotMatch(paint, /drawSessionLockIcon|shells\[i\]\.pinned_top/);
  assert.match(paint, /if \(is_act\) \{[\s\S]*?uiFontClose\(\)/);
  assert.match(paint, /if \(i == active_shell\) \{\s*const font_close = uiFontClose\(\)/);
  assert.match(source, /if \(!g_sidebar_collapsed and mx > SIDEBAR_W\(\) - 30\) \{\s*closeShell\(tab_idx\)/);
});

test("empty workspace closes atomically and can be absorbed again", () => {
  const exported = bodyOf("fn exportSlotSessionFile(slot: u8) bool {");
  assert.doesNotMatch(exported, /exported == 0/,
    "an empty tabs array is still a valid workspace export");
  assert.match(exported, /writeFileAtomicW\(path, json_buf\[0\.\.pos\]\)/);

  const close = bodyOf("fn closeMyWorkspaceSlot(slot: u8) void {");
  assert.match(close, /removeWorkspaceSlot\(slot\)/,
    "closing one empty workspace must remove that exact pill");

  const absorb = bodyOf("fn absorbWorkspaceIntoSlots(id: \[\]const u8, fallback_name: \[\]const u8) bool {");
  assert.match(absorb, /empty_workspace[\s\S]*?g_lws_count \+= 1/,
    "a saved empty workspace must reopen as an empty pill");
  assert.match(absorb, /spawned == 0 and !empty_workspace/);
});

test("custom groups stay stable and sort pinned members before recent members", () => {
  const sort = bodyOf("fn buildSortedOrder(out: *[MAX_SHELLS]u32, out_n: *u32) void {");
  assert.match(sort, /tmp\.is_group and !b\.is_group/,
    "custom groups should remain above ungrouped sections");
  assert.match(sort, /tmp\.is_group and b\.is_group and tmp\.pos < b\.pos/,
    "group blocks should not jump with tab activity");
  assert.match(sort, /@intFromEnum\(tm_tier\) > @intFromEnum\(bm_tier\)/,
    "pinned members should sort before recent members inside their group");
  assert.doesNotMatch(sort, /tier == \.locked/);
  assert.match(source, /drag_pending_materialize = false;\s+drag_section_only = false/);
});

test("workspace snapshot rows cannot impersonate live tabs in All Sessions", () => {
  const rows = bodyOf("fn buildSessionOverviewRows() void {");
  assert.match(rows, /sessionOverviewAdd\(\.reminder, 0, @intCast\(marker_idx\)/);
  assert.match(rows, /row\.snapshot_order = @intCast\(order\)/);
  const action = bodyOf("fn activateSessionOverviewRow(");
  assert.match(action, /row\.snapshot_order != null and row\.ref_idx < g_reminder_count/);
  const refresh = source;
  assert.match(refresh, /row\.snapshot_order == sel_snapshot_order/);
});

test("workspace wake replays partial restores by durable ID without reclaiming a dead PID", () => {
  const wake = bodyOf("fn wakeSnapshotWorkspace(");
  assert.match(wake, /shells\[si\]\.workspace == slot and shells\[si\]\.wake_id == tab\.wake_id/);
  assert.match(wake, /tab\.pid = 0;[\s\S]*?spawnSavedTab\(tab, mode\)/);
  assert.match(wake, /saveSession\(\);/);
  assert.match(bodyOf("fn checkDueReminders() void {"), /g_reminders\[i\]\.waking or workspace_snooze\.due/);
});
