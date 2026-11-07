const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = fs.readFileSync(path.join(__dirname, '../src/workspaces.zig'), 'utf8');
const start = source.indexOf('pub fn openWorkspaceByIndex(');
assert.ok(start >= 0, 'workspace menu activation must exist');
const activate = source.slice(start, source.indexOf('\n}', start) + 2);

test('IGSH-1774 a local workspace resolves before the containing window identity', () => {
  const local = activate.indexOf('app_state.g_single_window and findMyWorkspaceSlot(id) != null');
  const window = activate.indexOf('std.mem.eql(u8, id, getInstanceName())');
  assert.ok(local >= 0 && window > local, 'the window identity must not swallow a real local workspace switch');
});

test('IGSH-1774 real workspace activation switches a same-name local slot and preserves standalone routing', { skip: process.env.GITHUB_ACTIONS !== 'true' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-menu-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const Entry = struct { id: [64]u8 = @splat(0), id_len: u32 = 0, name: [64]u8 = @splat(0), name_len: u32 = 0, host: [64]u8 = @splat(0), host_len: u32 = 0, archived: bool = false };
const app_state = struct {
    var g_workspace_count: u32 = 2;
    var g_workspaces: [2]Entry = @splat(.{});
    var g_single_window = true;
};
var switched: ?u32 = null;
var opened = false;
var local_home = true;
fn getInstanceName() []const u8 { return "default"; }
fn findMyWorkspaceSlot(id: []const u8) ?u8 {
    if (local_home and std.mem.eql(u8, id, "default")) return 0;
    if (std.mem.eql(u8, id, "other")) return 1;
    return null;
}
fn switchToWorkspace(slot: u32) void { switched = slot; }
fn findAndFocusWorkspaceWindow(_: []const u8, _: []const u8) bool { return false; }
fn absorbWorkspaceIntoSlots(_: []const u8, _: []const u8) bool { opened = true; return false; }
fn newWorkspace() void { opened = true; }
fn setWorkspaceRestoreAndSave(_: []const u8, _: []const u8, _: bool) void { opened = true; }
fn spawnWorkspaceWindow(_: []const u8) void { opened = true; }
${activate}
test "home slot wins over window id while standalone self remains a no-op" {
    @memcpy(app_state.g_workspaces[0].id[0..7], "default");
    app_state.g_workspaces[0].id_len = 7;
    @memcpy(app_state.g_workspaces[1].id[0..5], "other");
    app_state.g_workspaces[1].id_len = 5;
    openWorkspaceByIndex(0);
    try std.testing.expectEqual(@as(?u32, 0), switched);
    try std.testing.expect(!opened);
    openWorkspaceByIndex(1);
    try std.testing.expectEqual(@as(?u32, 1), switched);
    switched = null;
    app_state.g_single_window = false;
    openWorkspaceByIndex(0);
    try std.testing.expect(switched == null and !opened);
    app_state.g_single_window = true;
    local_home = false;
    openWorkspaceByIndex(0);
    try std.testing.expect(switched == null and !opened);
    openWorkspaceByIndex(2);
    try std.testing.expect(switched == null and !opened);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
