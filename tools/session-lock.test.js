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

test("session lock is durable across save, restore, reconnect, and tab transfer", () => {
  assert.match(source, /locked: bool = false,/);
  assert.match(bodyOf("fn saveSessionTo(path: []const u8, workspace_filter: ?u8) bool {"), /if \(shells\[i\]\.locked\)[\s\S]*?\\\"locked\\\":true/);
  assert.match(jsonReader, /"locked"/);
  assert.match(jsonReader, /@field\(tab, key\) = boolTrue\(obj, key\)/);
  assert.match(bodyOf("fn spawnSavedTab(tab: *const SavedTab, claude_resume: workspace_snooze.ClaudeResume) bool {"), /shells\[idx\]\.locked = tabs\[t\]\.locked/);
  assert.match(bodyOf("fn respawnShellInPlace(idx: u32, terminate_existing: bool) bool {"), /saved_locked[\s\S]*?\.locked = saved_locked/);
  assert.match(source, /transfer\.locked = if \(shell\.locked\) 1 else 0/);
  assert.match(source, /new_shell\.locked = transfer\.locked != 0/);
  assert.match(source, /new_shell\.locked = g_adopt_locked/);
});

test("ordinary and destructive close paths reject a locked live session", () => {
  const reject = bodyOf("fn rejectLockedSessionClose(i: usize) bool {");
  assert.match(reject, /!shells\[i\]\.locked/);
  assert.match(reject, /unlock it before closing/);
  assert.match(bodyOf("fn closeShell(idx: u32) void {"), /rejectLockedSessionClose/);
  assert.match(bodyOf("fn archiveTabAt(i: usize) void {"), /rejectLockedSessionClose/);
  assert.match(bodyOf("fn endTmuxSessionAt(i: usize) void {"), /rejectLockedSessionClose/);
  assert.match(bodyOf("fn deleteMyWorkspaceSlot(slot: u8) void {"), /workspaceHasLockedSession/);
  assert.match(source, /groupHasLockedSession\(gid\)[\s\S]*?Group contains a locked session/);
});

test("workspace close hibernates locked sessions and restores their lock", () => {
  const exported = bodyOf("fn exportSlotSessionFile(slot: u8) bool {");
  assert.match(exported, /if \(shells\[i\]\.locked\)[\s\S]*?\\\"locked\\\":true/);

  const hibernate = bodyOf("fn hibernateWorkspaceShell(idx: u32) void {");
  assert.match(hibernate, /closeShellRemember\(idx, false\)/);
  assert.doesNotMatch(hibernate, /rejectLockedSessionClose/);

  const close = bodyOf("fn closeMyWorkspaceSlot(slot: u8) void {");
  assert.doesNotMatch(close, /workspaceHasLockedSession/);
  assert.match(close, /if \(!exported\)[\s\S]*?tabs left open[\s\S]*?return/);
  assert.match(close, /hibernateWorkspaceShell\(i\)/);
  assert.match(source, /shells\[idx\]\.locked = tabs\[t\]\.locked/g);
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

test("locked sessions keep their close guard and padlock without becoming a sidebar tier", () => {
  const lockIcon = bodyOf("fn drawSessionLockIcon(hdc: HANDLE, cx: i32, cy: i32, color: DWORD) void {");
  const tier = bodyOf("inline fn shellSidebarTier(i: usize) SidebarTier {");
  assert.match(source, /const SidebarTier = enum\(u1\) \{ recent = 0, pinned = 1 \}/);
  assert.doesNotMatch(tier, /locked/,
    "locking is a safety state and must not move the tab out of its group");
  assert.match(source, /fn drawSessionLockIcon\(/);
  assert.match(lockIcon, /CreatePen\(0, 1, color\)/, "the compact lock should use a crisp one-pixel stroke");
  assert.match(lockIcon, /GetStockObject\(NULL_BRUSH\)/, "the lock body should remain hollow");
  assert.doesNotMatch(lockIcon, /CreateSolidBrush/, "the lock must not regress to the solid shopping-bag shape");
  assert.match(lockIcon, /RoundRect/, "the outlined body should retain soft corners");
  assert.match(source, /if \(shells\[i\]\.locked\) \{\s*drawSessionLockIcon/);
  assert.match(source, /\.section => \|tier\| \{\s*toggleSidebarSectionCollapsed\(tier\)/);
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

test("lock and unlock are available from Ctrl+K, right-click, and the row padlock", () => {
  assert.match(source, /SEARCH_LOCK_SESSION_OFFSET/);
  assert.match(source, /SEARCH_TABCTX_LOCK/);
  assert.match(source, /if \(target == SEARCH_LOCK_SESSION_OFFSET\)[\s\S]*?\.locked = !shells\[active_shell\]\.locked/);
  assert.match(source, /target == SEARCH_TABCTX_LOCK[\s\S]*?shells\[ti\]\.locked = !shells\[ti\]\.locked/);
  assert.match(source, /if \(shells\[tab_idx\]\.locked\)[\s\S]*?shells\[tab_idx\]\.locked = false/);
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
