const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const workspaces = read('src/workspaces.zig');
const palette = read('src/command_palette.zig');
const state = read('src/app_state.zig');
const main = read('src/main.zig');
function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, `unterminated ${name}`);
  return source.slice(start, end + 2);
}

test('IGSH-1664 archive survives registry reload without changing old workspace defaults', () => {
  assert.match(state, /archived: bool = false/);
  assert.match(body(workspaces, 'addOrUpdateWorkspace'), /g_workspaces\[ni\]\.archived = false/);
  assert.match(body(workspaces, 'parseWorkspaceRegistryJson'), /archived = json_reader\.boolTrue\(obj, "archived"\)/);
  assert.match(body(workspaces, 'writeWorkspaceRegistryFile'), /if \(e\.archived\)[\s\S]*archived/);
  assert.match(body(workspaces, 'reconcileWorkspaceRegistry'), /if \(e\.archived\) \{\s*wi \+= 1;\s*continue;/);
});

test('IGSH-1664 archive snapshots before detaching, preserves unnamed saves, and leaves servers alone', () => {
  const close = body(workspaces, 'closeMyWorkspaceSlot');
  assert.ok(close.indexOf('exportSlotSessionFile(slot)') < close.indexOf('hibernateWorkspaceShell(i)'));
  assert.match(close, /addOrUpdateWorkspaceHosted\(id, name, false, ""\)/);
  assert.match(close, /g_workspaces\[wi\]\.archived = true/);
  assert.doesNotMatch(close, /workspaceNameIsDefault|archiveWorkspaceFile|closeShell\(|endTmux|killRemote/);
  assert.match(body(workspaces, 'hibernateWorkspaceShell'), /closeShellRemember\(idx, false\)/);
  assert.match(close, /rejectPinnedWorkspaceClose\(slot\)/);
  assert.match(close, /isOtherWorkspaceSlot\(slot\)/);
});

test('IGSH-1664 normal navigation excludes archives; restoration must succeed before unarchiving', () => {
  for (const name of ['workspaceCanOpen', 'workspaceCanMoveIntoClosedStandalone', 'openWorkspaceByIndex']) {
    assert.match(body(workspaces, name), /if \(e\.archived\) return/);
  }
  assert.match(read('src/workspace_switcher.zig'), /if \(entry\.archived\) continue/);
  assert.match(palette, /if \(e\.archived != archived\) continue/);
  assert.match(palette, /if \(e\.archived\) continue/);
  const restore = body(workspaces, 'restoreArchivedWorkspaceByIndex');
  assert.ok(restore.indexOf('!absorbWorkspaceIntoSlots') < restore.indexOf('.archived = false'));
  assert.match(restore, /!absorbWorkspaceIntoSlots\(id, name\)\) return false/);
  assert.match(restore, /switchToWorkspace\(slot\)/);
});

test('IGSH-1664 archive and restore are reachable while deletion requires an archived workspace', () => {
  assert.match(body(workspaces, 'workspaceCanDelete'), /if \(!e\.archived\) return false/);
  assert.match(read('src/ui_words.zon'), /palette_close_workspace = "Archive workspace"/);
  assert.match(palette, /"Archived workspaces", "restore workspace"/);
  assert.match(palette, /g_remind_ws_id_len > 0 and labelsMatchQuery\(&\.\{"Archive workspace"\}/);
  assert.match(main, /g_search_workspace_action == \.archive[\s\S]*archiveWorkspaceByIndex/);
  assert.match(main, /g_search_workspace_action == \.restore[\s\S]*restoreArchivedWorkspaceByIndex/);
  assert.match(main, /confirm_idx == workspace_idx[\s\S]*deleteWorkspaceByIndex/);
  for (const label of ['Archive workspace', 'Archived workspaces', 'Delete workspace']) {
    assert.ok(read('src/shortcuts.zig').includes(`Ctrl+K -> ${label}`));
  }
});

test('IGSH-1664 journey treats an omitted workspace field as workspace 0', () => {
  const journey = read('.claude/skills/verify-multiprompt/workspace-switcher.ps1');
  assert.match(journey, /function Get-SavedTabWorkspace/);
  assert.match(journey, /PSObject\.Properties\['workspace'\]/);
  assert.match(journey, /return 0/);
  assert.doesNotMatch(journey, /\$_\.workspace -eq/);
  assert.match(read('src/session.zig'), /if \(app_state\.shells\[i\]\.workspace != 0\)/);
});

test('IGSH-1664 native registry reload distinguishes archived, active and legacy rows', { skip: process.env.GITHUB_ACTIONS !== 'true' }, () => {
  assert.match(state, /archived: bool = false/);
  const type = state.slice(state.indexOf('pub const WorkspaceEntry = struct {'), state.indexOf('pub var g_workspaces:'));
  const functions = ['defaultWorkspaceName', 'workspaceIdEql', 'findWorkspace', 'addOrUpdateWorkspace', 'addOrUpdateWorkspaceHosted', 'parseWorkspaceRegistryJson', 'entryHostedBy', 'workspaceCanArchive', 'workspaceCanDelete'].map(name => body(workspaces, name)).join('\n');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-archive-'));
  try {
    copyZig(['json_reader.zig'], dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const json_reader = @import("json_reader.zig");
const MAX_WORKSPACES = 64;
${type}
const app_state = struct {
    var g_workspaces: [MAX_WORKSPACES]WorkspaceEntry = undefined;
    var g_workspace_count: u32 = 0;
    var g_single_window = true;
    var g_lws_count: u8 = 2;
    var g_ws_snoozed = [_]bool{false, false};
};
fn getInstanceName() []const u8 { return "default"; }
fn findMyWorkspaceSlot(id: []const u8) ?u8 {
    if (std.mem.eql(u8, id, "live")) return 0;
    if (std.mem.eql(u8, id, "other")) return 1;
    return null;
}
fn isOtherWorkspaceSlot(slot: u8) bool { return slot == 1; }
${functions}
test "archive flags survive reload and absent flags remain visible" {
    parseWorkspaceRegistryJson("{\\\"windows\\\":[{\\\"id\\\":\\\"legacy\\\",\\\"name\\\":\\\"Legacy\\\"},{\\\"id\\\":\\\"old\\\",\\\"name\\\":\\\"Old\\\",\\\"restore\\\":false,\\\"archived\\\":true},{\\\"id\\\":\\\"current\\\",\\\"name\\\":\\\"Current\\\",\\\"archived\\\":false}]}");
    try std.testing.expectEqual(@as(u32, 3), app_state.g_workspace_count);
    try std.testing.expect(!app_state.g_workspaces[0].archived);
    try std.testing.expect(app_state.g_workspaces[1].archived);
    try std.testing.expect(!app_state.g_workspaces[1].restore);
    try std.testing.expect(!app_state.g_workspaces[2].archived);
    try std.testing.expect(workspaceCanArchive(0));
    try std.testing.expect(!workspaceCanDelete(0));
    try std.testing.expect(!workspaceCanArchive(1));
    try std.testing.expect(workspaceCanDelete(1));
    addOrUpdateWorkspace("live", "Live", false);
    addOrUpdateWorkspace("other", "Other", false);
    try std.testing.expect(workspaceCanArchive(3));
    try std.testing.expect(!workspaceCanArchive(4));
    app_state.g_ws_snoozed[0] = true;
    try std.testing.expect(!workspaceCanArchive(3));
    addOrUpdateWorkspace("old", "Old renamed", true);
    try std.testing.expect(app_state.g_workspaces[1].archived);
    app_state.g_workspace_count = 0;
    parseWorkspaceRegistryJson("{\\\"windows\\\":[{\\\"id\\\":\\\"old\\\",\\\"name\\\":\\\"Restored\\\"}]}");
    try std.testing.expect(!app_state.g_workspaces[0].archived);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
