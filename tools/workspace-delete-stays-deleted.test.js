const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const workspaces = read('src/workspaces.zig');
const desktop = read('src/account_desktop.zig');
const accountLayout = read('src/account_layout.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  return source.slice(start, source.indexOf('\n}\n', start) + 2);
}

function publicBody(source, name) {
  const start = source.indexOf(`pub fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  return source.slice(start, source.indexOf('\n}\n', start) + 2);
}

test('SOFT-2936 deleting a workspace records the name so a later layout cannot recreate it', () => {
  const remove = publicBody(workspaces, 'deleteWorkspaceByIndex');
  assert.match(remove, /rememberRemovedWorkspace\(name_copy\[0\.\.name_len\]\)/);
  assert.ok(remove.indexOf('removeWorkspaceEntryAt(cur)') < remove.indexOf('rememberRemovedWorkspace('));
  assert.match(workspaces, /\\ZigShell\\\\removed-workspaces\.json/);
  assert.match(workspaces, /removed-workspaces-dev\.json/);
});

test('SOFT-2936 the account layout drops a deleted workspace instead of bringing it back', () => {
  const apply = publicBody(desktop, 'applyServerLayout');
  assert.match(apply, /account_layout\.withoutRemovedWorkspaces\(a, desired, removedWorkspaceNames\(&removed_storage\)\)/);
  const restore = body(desktop, 'accountPrepareRestore');
  assert.match(restore, /account_layout\.withoutRemovedWorkspaces\(a, restored, removedWorkspaceNames\(&removed_storage\)\)/);
  const filter = publicBody(accountLayout, 'withoutRemovedWorkspaces');
  assert.match(filter, /containsName\(removed, workspace\.name\)/);
  assert.match(filter, /containsName\(removed, tab\.workspace\)/);
});

test('SOFT-2936 a deleted name stops being blocked as soon as a workspace uses it again', () => {
  const upsert = body(workspaces, 'upsertMySlotEntries');
  assert.match(upsert, /forgetRemovedWorkspacesInUse\(\)/);
  const forget = body(workspaces, 'forgetRemovedWorkspacesInUse');
  assert.match(forget, /workspaceNameInUse\(name_buf\[0\.\.name\.len\]\)/);
  assert.match(forget, /removeRemovedWorkspaceAt\(wi\)/);
  const inUse = body(workspaces, 'workspaceNameInUse');
  assert.match(inUse, /app_state\.g_lws_count/);
  assert.match(inUse, /!e\.archived/);
  assert.match(body(workspaces, 'migrateWorkspacesFromSessionFiles'), /if \(!workspaceNameRemoved\(name\)\) addOrUpdateWorkspace/);
});

test('SOFT-2936 a refused delete says why instead of doing nothing', () => {
  const remove = publicBody(workspaces, 'deleteWorkspaceByIndex');
  assert.match(remove, /Archive this workspace before deleting it\./);
  assert.match(remove, /This workspace is open in another window\. Delete it from that window\./);
  assert.match(remove, /At least one workspace must stay open\./);
  assert.doesNotMatch(remove, /if \(!workspaceCanDelete\(wi\)\) \{\s*return false;/);
});

test('SOFT-2936 hosted: a stored layout drops the deleted workspace and its sessions', { skip: process.env.GITHUB_ACTIONS !== 'true' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-removed-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const Allocator = std.mem.Allocator;
const eq = std.mem.eql;
const layout = struct {
    pub const Workspace = struct { name: []const u8, color: ?u8 = null };
    pub const Tab = struct { name: []const u8 = "", tmux_session: []const u8 = "s", tmux_host: u8 = 0, workspace: []const u8 };
};
const Layout = struct { workspaces: []const layout.Workspace, tabs: []const layout.Tab };
const Tab = layout.Tab;
pub const MAX_REMOVED_WORKSPACES: usize = 4;
var removed_workspace_names: [MAX_REMOVED_WORKSPACES][64]u8 = std.mem.zeroes([MAX_REMOVED_WORKSPACES][64]u8);
var removed_workspace_name_len: [MAX_REMOVED_WORKSPACES]u32 = [_]u32{0} ** MAX_REMOVED_WORKSPACES;
var removed_workspace_count: usize = 0;
${body(accountLayout, 'containsName')}
${body(workspaces, 'removedWorkspaceNameAt')}
${body(workspaces, 'findRemovedWorkspace')}
${body(workspaces, 'removeRemovedWorkspaceAt')}
${body(workspaces, 'addRemovedWorkspaceName')}
${publicBody(accountLayout, 'withoutRemovedWorkspaces')}
const none: []const []const u8 = &.{};
fn seed(names: []const []const u8) !Layout {
    const stored_workspaces = try std.testing.allocator.alloc(layout.Workspace, names.len);
    const tabs = try std.testing.allocator.alloc(layout.Tab, names.len);
    for (names, 0..) |name, i| {
        stored_workspaces[i] = .{ .name = name };
        tabs[i] = .{ .name = name, .tmux_session = name, .workspace = name };
    }
    return .{ .workspaces = stored_workspaces, .tabs = tabs };
}
test "a workspace the server still lists survives until its deletion is recorded" {
    const stored = try seed(&[_][]const u8{ "Other", "CEO Runners" });
    defer {
        std.testing.allocator.free(stored.workspaces);
        std.testing.allocator.free(stored.tabs);
    }
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const kept = try withoutRemovedWorkspaces(arena.allocator(), stored, none);
    try std.testing.expectEqual(@as(usize, 2), kept.workspaces.len);
    try std.testing.expectEqual(@as(usize, 2), kept.tabs.len);
    try std.testing.expect(addRemovedWorkspaceName("CEO Runners"));
    try std.testing.expectEqual(@as(usize, 1), removed_workspace_count);
    try std.testing.expect(!addRemovedWorkspaceName("CEO Runners"));
    const removed = [_][]const u8{removedWorkspaceNameAt(0)};
    const pruned = try withoutRemovedWorkspaces(arena.allocator(), stored, &removed);
    try std.testing.expectEqual(@as(usize, 1), pruned.workspaces.len);
    try std.testing.expectEqualStrings("Other", pruned.workspaces[0].name);
    try std.testing.expectEqual(@as(usize, 1), pruned.tabs.len);
    try std.testing.expect(findRemovedWorkspace("CEO Runners") != null);
    removeRemovedWorkspaceAt(0);
    try std.testing.expectEqual(@as(usize, 0), removed_workspace_count);
    try std.testing.expect(findRemovedWorkspace("CEO Runners") == null);
    const again = try withoutRemovedWorkspaces(arena.allocator(), stored, none);
    try std.testing.expectEqual(@as(usize, 2), again.workspaces.len);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
