const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const workspaces = read('src/workspaces.zig');
const palette = read('src/command_palette.zig');
const sidebar = read('src/sidebar.zig');
const main = read('src/main.zig');
const switcher = read('src/workspace_switcher.zig');
const mb = read('tools/mb.mjs');

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

test('MUBO-251 an empty workspace is removed at once instead of waiting to be archived', () => {
  const canDelete = publicBody(workspaces, 'workspaceCanDelete');
  assert.doesNotMatch(canDelete, /!e\.archived/);
  assert.match(canDelete, /return e\.host_len == 0;/);
  const remove = publicBody(workspaces, 'deleteWorkspaceByIndex');
  assert.doesNotMatch(remove, /Archive this workspace before deleting it\./);
  assert.match(remove, /workspaceChats\(id\) > 0/);
});

test('MUBO-251 a workspace that still holds chats asks where they go before it is removed', () => {
  assert.match(main, /app_state\.g_search_workspace_move_source = workspace_idx;/);
  assert.match(main, /deleteWorkspaceMovingChats\(source, workspace_idx\)/);
  assert.match(palette, /g_search_workspace_move_source\) \|source\|/);
  assert.match(sidebar, /Where should the chats go\?/);
  assert.match(sidebar, /Move Chats To: /);
  const move = publicBody(workspaces, 'deleteWorkspaceMovingChats');
  assert.match(move, /absorbWorkspaceIntoSlots\(id, name_copy\[0\.\.name_len\]\)/);
  assert.ok(move.indexOf('shell.workspace = target') < move.indexOf('deleteWorkspaceByIndex(current)'));
});

test('MUBO-251 the workspace menu can remove the highlighted workspace', () => {
  assert.match(switcher, /0x2E => deleteSelected\(\)/);
  assert.match(switcher, /workspaces\.requestWorkspaceDelete\(entry\.id\[0\.\.entry\.id_len\]\)/);
  assert.match(switcher, /PostMessageW\(app_state\.g_main_hwnd, w\.WM_APP_SEARCH_OPEN, 0, 0\)/);
  assert.match(main, /takeRequestedWorkspaceDelete\(&requested_delete_buf\)/);
  assert.match(main, /app_state\.g_search_workspace_delete_mode = true;/);
});

test('MUBO-251 a removed empty workspace is remembered so account sync cannot bring it back', () => {
  const remove = publicBody(workspaces, 'deleteWorkspaceByIndex');
  assert.match(remove, /rememberRemovedWorkspace\(name_copy\[0\.\.name_len\]\)/);
  assert.match(read('src/account_desktop.zig'), /account_layout\.withoutRemovedWorkspaces\(a, desired, removedWorkspaceNames\(&removed_storage\)\)/);
  assert.match(read('src/account_layout.zig'), /containsName\(removed, tab\.workspace\)/);
});

test('MUBO-251 mb workspace delete removes an empty workspace it did not create and repeats harmlessly', () => {
  const start = mb.indexOf("if (sub === 'delete')");
  assert.ok(start >= 0, 'missing workspace delete');
  const remove = mb.slice(start, mb.indexOf("if (sub === 'color')", start));
  assert.match(remove, /already deleted workspace/);
  assert.match(remove, /const chats = seen\.data\.layout\.tabs\.filter\(tab => tab\.workspace === name\)/);
  assert.match(remove, /flags\['move-to'\]/);
  assert.match(remove, /has \$\{chats\.length\} chat\$\{chats\.length === 1 \? '' : 's'\}; give --move-to <workspace>/);
  assert.ok(remove.indexOf('const chats =') < remove.indexOf("owners.workspaces[name]?.owner !== 'mb'"), 'an empty workspace needs no mb ownership');
  assert.match(mb, /workspace delete <name> \[--move-to <workspace>\]/);
});

test('MUBO-251 empty workspaces stay deletable after the workspace menu lists them', { skip: process.env.GITHUB_ACTIONS !== 'true' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'empty-workspace-remove-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const Entry = struct { id: [64]u8 = @splat(0), id_len: u32 = 0, name: [64]u8 = @splat(0), name_len: u32 = 0, host: [64]u8 = @splat(0), host_len: u32 = 0, archived: bool = false };
const app_state = struct {
    var g_workspace_count: u32 = 0;
    var g_workspaces: [4]Entry = @splat(.{});
    var g_single_window = true;
    var g_lws_count: u8 = 0;
};
fn getInstanceName() []const u8 { return "default"; }
fn findMyWorkspaceSlot(id: []const u8) ?u8 {
    if (std.mem.eql(u8, id, "ws-1")) return 0;
    if (std.mem.eql(u8, id, "ws-2")) return 1;
    return null;
}
${publicBody(workspaces, 'workspaceCanDelete')}
fn seed(id: []const u8, host: []const u8, archived: bool) void {
    app_state.g_workspaces[0] = .{ .archived = archived };
    @memcpy(app_state.g_workspaces[0].id[0..id.len], id);
    app_state.g_workspaces[0].id_len = @intCast(id.len);
    @memcpy(app_state.g_workspaces[0].host[0..host.len], host);
    app_state.g_workspaces[0].host_len = @intCast(host.len);
    app_state.g_workspace_count = 1;
}
test "an empty workspace is deletable without archiving" {
    app_state.g_lws_count = 2;
    seed("ws-1", "", false);
    try std.testing.expect(workspaceCanDelete(0));
    seed("ws-1", "", true);
    try std.testing.expect(workspaceCanDelete(0));
    seed("ws-1", "other-window", false);
    try std.testing.expect(!workspaceCanDelete(0));
    seed("ws-2", "", false);
    app_state.g_lws_count = 1;
    try std.testing.expect(!workspaceCanDelete(0));
    app_state.g_lws_count = 2;
    try std.testing.expect(workspaceCanDelete(0));
    seed("default", "", false);
    try std.testing.expect(!workspaceCanDelete(0));
    seed("", "", false);
    try std.testing.expect(!workspaceCanDelete(0));
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
