const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}`);
  const end = source.indexOf(`fn ${nextName}`, start);
  assert.notStrictEqual(start, -1, `missing ${name}`);
  assert.notStrictEqual(end, -1, `missing ${nextName}`);
  return source.slice(start, end);
}

test("Other is a named permanent workspace slot", () => {
  assert.match(source, /const OTHER_WORKSPACE_NAME = "Other"/);
  const ensure = functionBody("ensureOtherWorkspaceSlot", "switchToWorkspace");
  assert.match(ensure, /if \(!g_single_window\) return/);
  assert.match(ensure, /if \(isOtherWorkspaceSlot\(ws\)\) return/);
  assert.match(ensure, /g_lws_count == 1 and g_ws_name_len\[0\] == 0/,
    "a fresh anonymous workspace must become Other");
  assert.match(ensure, /if \(g_lws_count >= MAX_LWS\) return/);
  assert.match(ensure, /g_lws_count \+= 1/,
    "an existing named workspace set must gain a separate Other slot");
});

test("empty-slot compaction preserves and repairs Other", () => {
  const compact = functionBody("compactWorkspaceSlots", "swapWorkspaceSlots");
  assert.match(compact, /keep_slot\[keep_ws\] = has_tab\[keep_ws\] or isOtherWorkspaceSlot\(keep_ws\)/,
    "the empty Other catch-all must not be compacted away");
  assert.match(compact, /g_ws_id_len\[keep_ws\] > 0 or g_ws_name_len\[keep_ws\] > 0/,
    "an identified empty workspace must survive restart compaction");
  assert.match(compact, /ensureOtherWorkspaceSlot\(\)/,
    "sessions saved without Other must be repaired during restore compaction");
});

test("removing one workspace does not compact unrelated empty workspaces", () => {
  const remove = functionBody("removeWorkspaceSlot", "swapWorkspaceSlots");
  assert.match(remove, /while \(ws \+ 1 < g_lws_count\)/);
  assert.doesNotMatch(remove, /has_tab|compactWorkspaceSlots/);

  const close = functionBody("closeMyWorkspaceSlot", "deleteMyWorkspaceSlot");
  assert.match(close, /removeWorkspaceSlot\(slot\)/);
  assert.doesNotMatch(close, /compactWorkspaceSlots\(\)/);
});

test("startup and runtime mode entry establish the catch-all", () => {
  const restore = functionBody("restoreSession", "enumWindowsCallback");
  const ensurePos = restore.indexOf("ensureOtherWorkspaceSlot();");
  const savePos = restore.indexOf("saveSession();");
  assert.ok(ensurePos >= 0 && ensurePos < savePos,
    "startup must repair Other before persisting the restored session");

  const toggle = functionBody("toggleSingleWindowMode", "newWorkspace");
  assert.match(toggle, /ensureOtherWorkspaceSlot\(\)/,
    "enabling single-window mode must establish Other immediately");
});

test("leaving single-window mode preserves the active identity and remembered workspaces", () => {
  const toggle = functionBody("toggleSingleWindowMode", "newWorkspace");
  assert.match(toggle, /if \(!leaveSingleWindowMode\(\)\)[\s\S]*?return/,
    "a failed split must keep single-window mode active");

  const leave = functionBody("leaveSingleWindowMode", "newWorkspace");
  const exportPos = leave.indexOf("if (!exportSlotSessionFile(ws)) return false;");
  const detachPos = leave.indexOf("hibernateWorkspaceShell(si)");
  assert.ok(exportPos >= 0 && detachPos > exportPos,
    "every workspace export must finish before any live shell is detached");
  assert.match(leave, /setWindowDisplayNameUtf8\(active_name_buf\[0\.\.active_name_len\]\)/,
    "the standalone frame must inherit the active workspace name");
  assert.match(leave, /addOrUpdateWorkspaceHosted\([\s\S]*?true, ""\)/,
    "split slots must become standalone remembered registry entries");
  assert.match(leave, /g_ws_ids\[0\][\s\S]*?getInstanceName\(\)/,
    "the remaining current workspace must use the window's stable identity");
});

test("standalone workspace exports keep groups without forcing single-window mode", () => {
  const exported = functionBody("exportSlotSessionFile", "hibernateWorkspaceShell");
  assert.match(exported, /,\\"group_id\\":/,
    "tab group membership must survive a workspace split");
  assert.match(exported, /,\\"groups\\":\[/,
    "referenced group definitions must survive a workspace split");
  assert.doesNotMatch(exported, /single_window\\":true/,
    "opening an exported workspace as a window must not collapse back to single-window mode");
});

test("mode switches reopen every validated export and preserve empty workspaces", () => {
  const exported = functionBody("exportSlotSessionFile", "hibernateWorkspaceShell");
  assert.match(exported, /hide_pills/);
  assert.ok(exported.indexOf("sessionFileIsValid(json_buf[0..pos])") < exported.indexOf("return writeFileAtomicW(path"));
  assert.match(exported, /pos >= json_buf.len - 4096\) return false/);
  const leave = functionBody("leaveSingleWindowMode", "newWorkspace");
  assert.ok(leave.indexOf("saveSession();") < leave.indexOf("spawnWorkspaceWindow(entry.id"));
  assert.ok(leave.indexOf("publishInboxState();") < leave.indexOf("spawnWorkspaceWindow(entry.id"));
  assert.match(leave, /g_ws_ids\[ws\]\[0\.\.g_ws_id_len\[ws\]\], getInstanceName\(\)/);
  assert.match(leave, /g_ws_id_len\[ws\] = 0/);
  assert.match(leave, /for \(0\.\.split_count\) \|i\|/);
  assert.ok(leave.indexOf('saveWorkspaceModeOrder(active_slot)') < leave.indexOf('hibernateWorkspaceShell(si)'));
  const toggle = functionBody('toggleSingleWindowMode','newWorkspace');
  assert.ok(toggle.indexOf('collapseOtherWindowsIntoThis();') < toggle.indexOf('restoreWorkspaceModeOrder();'));
  assert.match(source, /restored == 0 and !g_restored_valid_session/);
});

test("workspace registry reads and writes share a process-wide transaction lock", () => {
  for (const name of ['loadWorkspaceRegistry','mergeWorkspaceRegistryFromDisk','saveWorkspaceRegistry','syncInProcessWorkspacesToRegistry','reconcileWorkspaceRegistry']) {
    const start = source.indexOf(`fn ${name}(`);
    const body = source.slice(start, source.indexOf('\nfn ', start + 3));
    assert.match(body, /lockWorkspaceRegistry\(\)/, name);
    assert.match(body, /defer unlockWorkspaceRegistry/, name);
  }
  const absorb = functionBody('absorbWorkspaceIntoSlots','collapseOtherWindowsIntoThis');
  assert.match(absorb, /importWorkspaceGroups\(json, tabs\[0\.\.tab_count\]\)/);
  assert.match(absorb, /shells\[idx\]\.group_id = tabs\[t\]\.group_id/);
  assert.match(absorb, /shells\[idx\]\.inbox_archived = tabs\[t\]\.inbox_archived/);
});

test("unmatched session routing uses the permanent Other slot", () => {
  const ensure = functionBody("ensureOtherWorkspace", "resolveOverviewSpawnWorkspace");
  assert.match(ensure, /ensureOtherWorkspaceSlot\(\)/,
    "automatic unattached-session routing must reuse the permanent invariant");
  assert.match(ensure, /otherPillSlot\(\) orelse return g_active_workspace/);

  const resolve = functionBody("resolveOverviewSpawnWorkspace", "localTmuxSessionAlreadyOpen");
  assert.match(resolve, /return ensureOtherWorkspace\(\)/,
    "a session without a matching product repository must land in Other");
});

test("the catch-all cannot be removed or renamed", () => {
  const close = functionBody("closeMyWorkspaceSlot", "deleteMyWorkspaceSlot");
  const remove = functionBody("deleteMyWorkspaceSlot", "absorbWorkspaceIntoSlots");
  assert.match(close, /if \(isOtherWorkspaceSlot\(slot\)\)[\s\S]*?return/);
  assert.match(remove, /if \(isOtherWorkspaceSlot\(slot\)\)[\s\S]*?return/);

  const rename = functionBody("commitRename", "appendWorkspaceMoveMenuItems");
  assert.match(rename, /if \(isOtherWorkspaceSlot\(ws\)[\s\S]*?Other is the permanent catch-all/,
    "F2 must not rename away the reserved catch-all");
});

test("duplicate reserved workspaces merge sessions before removing their slots", () => {
  const compact = functionBody("compactWorkspaceSlots", "mergeDuplicateOtherWorkspaces");
  assert.match(compact, /mergeDuplicateOtherWorkspaces\(\)/);
  const merge = functionBody("mergeDuplicateOtherWorkspaces", "removeWorkspaceSlot");
  assert.match(merge, /const keep = otherPillSlot\(\)/);
  assert.ok(merge.indexOf("shells[si].workspace = keep") < merge.indexOf("removeWorkspaceSlot(ws)"));
  assert.doesNotMatch(merge, /closeShell\(|hibernateWorkspaceShell\(/);
  const rename = functionBody("commitRename", "appendWorkspaceMoveMenuItems");
  assert.match(rename, /paletteWideTextMatchRank\(buf\[0\.\.ulen\], L\("Other"\)\[0\.\.5\]\) == 4/);
});
