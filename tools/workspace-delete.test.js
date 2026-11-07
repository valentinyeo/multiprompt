const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const source = fs.readFileSync(path.join(__dirname, '../src/workspaces.zig'), 'utf8');
const palette = fs.readFileSync(path.join(__dirname, '../src/command_palette.zig'), 'utf8');
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('IGSH-1832 deletion resolves a real local slot before registry host metadata', () => {
  const remove = body('deleteWorkspaceByIndex');
  assert.match(remove, /if \(app_state\.g_single_window\) \{/);
  assert.match(remove, /if \(findMyWorkspaceSlot\(id\)\) \|slot\|/);
  assert.doesNotMatch(remove, /if \(entryHostedBy\(e, getInstanceName\(\)\)\)/);
  assert.match(remove, /if \(!deleteMyWorkspaceSlot\(slot\)\)/);
});

test('IGSH-1832 Main and refused rows stay reachable for a persistent explanation', () => {
  assert.doesNotMatch(palette, /g_search_workspace_delete_mode and !workspaceCanDelete/);
  assert.match(source, /Main cannot be deleted/);
  assert.match(source, /@import\("dialog\.zig"\)\.messageBox/);
  assert.match(body('deleteWorkspaceByIndex'), /workspace-delete attempt/);
  assert.match(source, /workspace-delete result=refused/);
  assert.match(body('deleteWorkspaceByIndex'), /workspace-delete result=deleted/);
});

test('IGSH-1832 Windows double-click delivery still confirms the selected delete row', () => {
  const main = fs.readFileSync(path.join(__dirname, '../src/main.zig'), 'utf8');
  const start = main.indexOf('        WM_LBUTTONDBLCLK => {');
  const handler = main.slice(start, main.indexOf('\n        WM_', start + 10));
  assert.match(handler, /if \(app_state\.g_search_active and app_state\.g_search_workspace_delete_mode\) return wndProc\(hwnd, WM_LBUTTONDOWN, wp, lp\);/);
});

test('IGSH-1832 local deletion reports refusal rather than pretending success', () => {
  const remove = body('deleteMyWorkspaceSlot');
  assert.match(remove, /fn deleteMyWorkspaceSlot\(slot: u8\) bool/);
  assert.match(remove, /isOtherWorkspaceSlot\(slot\)/);
  assert.match(remove, /rejectPinnedWorkspaceClose\(slot\)\) return workspaceDeleteFailed/);
  assert.match(remove, /return true;/);
});

test('IGSH-1832 production delete routing closes legacy and stale-host local slots and preserves refused targets', { skip: process.env.GITHUB_ACTIONS !== 'true' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-delete-'));
  try {
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const HANDLE = ?*anyopaque;
const Entry = struct { id: [64]u8 = @splat(0), id_len: u32 = 0, host: [64]u8 = @splat(0), host_len: u32 = 0 };
const app_state = struct {
    var g_workspace_count: u32 = 1;
    var g_workspaces: [1]Entry = @splat(.{});
    var g_single_window = true;
    var g_lws_count: u32 = 2;
    const Reason = enum { workspace_delete };
    fn requestAppClose(_: HANDLE, _: Reason) void { @panic("local deletion must not close another window"); }
};
var closed = false;
var removed = false;
var refuse_slot = false;
var refusal: ?[]const u8 = null;
fn getInstanceName() []const u8 { return "container"; }
fn findMyWorkspaceSlot(id: []const u8) ?u8 { return if (std.mem.eql(u8, id, "local")) 1 else null; }
fn workspaceDeleteFailed(reason: []const u8) bool { refusal = reason; return false; }
fn deleteMyWorkspaceSlot(_: u8) bool {
    if (refuse_slot) return workspaceDeleteFailed("Unpin sessions first");
    closed = true;
    return true;
}
fn debugLog(_: []const u8) void {}
fn debugLog2(_: []const u8, _: []const u8) void {}
fn scanLiveWorkspaceWindows(_: bool) void {}
const Live = struct { slot: i32, hwnd: usize };
fn findLiveWorkspaceTarget(_: []const u8) ?Live { return null; }
fn IsWindow(_: HANDLE) i32 { return 0; }
fn Sleep(_: u32) void {}
fn lockWorkspaceRegistry() ?u8 { return 1; }
fn unlockWorkspaceRegistry(_: u8) void {}
fn mergeWorkspaceRegistryFromDisk() void {}
fn findWorkspace(_: []const u8) ?u32 { return 0; }
fn removeWorkspaceEntryAt(_: u32) void { removed = true; }
fn writeWorkspaceRegistryFile() void {}
fn workspaceDeleteStamp(_: *[32]u8) []const u8 { return "stamp"; }
fn getSessionPathForWorkspace(_: *[512]u8, _: []const u8) ?[]const u8 { return null; }
fn getSessionAuditPathForWorkspace(_: *[512]u8, _: []const u8) ?[]const u8 { return null; }
fn archiveWorkspaceFile(_: []const u8, _: []const u8) void {}
${body('workspaceCanDelete')}
${body('deleteWorkspaceByIndex')}
fn seed(id: []const u8, host: []const u8) void {
    app_state.g_workspaces[0] = .{};
    @memcpy(app_state.g_workspaces[0].id[0..id.len], id);
    app_state.g_workspaces[0].id_len = @intCast(id.len);
    @memcpy(app_state.g_workspaces[0].host[0..host.len], host);
    app_state.g_workspaces[0].host_len = @intCast(host.len);
    closed = false;
    removed = false;
    refusal = null;
    refuse_slot = false;
}
test "local identity wins over missing or stale host and refusal never removes it" {
    for ([_][]const u8{ "", "container", "stale-window" }) |host| {
        seed("local", host);
        try std.testing.expect(workspaceCanDelete(0));
        try std.testing.expect(deleteWorkspaceByIndex(0));
        try std.testing.expect(closed and removed and refusal == null);
        seed("local", host);
        refuse_slot = true;
        try std.testing.expect(!deleteWorkspaceByIndex(0));
        try std.testing.expect(!closed and !removed and refusal != null);
    }
    for ([_][]const u8{ "default", "container" }) |id| {
        seed(id, "");
        try std.testing.expect(!deleteWorkspaceByIndex(0));
        try std.testing.expect(!closed and !removed and refusal != null);
    }
    seed("remote", "other-window");
    try std.testing.expect(!deleteWorkspaceByIndex(0));
    try std.testing.expect(!closed and !removed and refusal != null);
    try std.testing.expect(!deleteWorkspaceByIndex(1));
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
