const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('SOFT-3003 zsb shell-open is a workspace command with attach and run flags', () => {
  const zsb = read('src/mp_zsb.sh');
  assert.match(zsb, /shell-open --workspace NAME/);
  assert.match(zsb, /"shell-open"/);
  assert.match(zsb, /--attach SESSION\] \[--run CMD\]/);
  assert.match(read('src/browser_bridge.zig'), /"shell-open"/);
  assert.match(read('src/browser_bridge.zig'), /fn zsbShellOpen\(/);
  assert.match(read('src/mp_shell.py'), /shell-open/);
  assert.match(read('src/chat_history_reader.py'), /publish_named_tool\('mp-shell'/);
  assert.match(read('src/chat_session.zig'), /MP_SHELL_SOURCE = '\{s\}'/);
});

test('SOFT-3003 background spawns preserve target, folder and pending launch state', () => {
  const source = read('src/console.zig');
  const body = name => {
    const start = source.indexOf(`pub fn ${name}(`);
    assert.ok(start >= 0, name);
    return source.slice(start, source.indexOf('\n}', start) + 2);
  };
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'background-spawn-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, `const std = @import("std");
const ShellKind = enum { tmux, vps };
const app_state = @This();
var g_pending_tmux_host: u8 = 2;
var g_pending_background_workspace: ?u8 = null;
var g_pending_tmux_cmd_len: usize = 7;
var g_pending_resurrect_len: usize = 9;
var admitted = true;
var seen_kind: ShellKind = .tmux;
var seen_session: ?[]const u8 = null;
var seen_cwd: ?[]const u8 = null;
var seen_host: u8 = 0;
var seen_workspace: ?u8 = null;
var seen_cmd: usize = 0;
var seen_resurrect: usize = 0;
fn spawnShellWithSession(kind: ShellKind, session: ?[]const u8, cwd: ?[]const u8, _: ?usize) bool {
    seen_kind = kind;
    seen_session = session;
    seen_cwd = cwd;
    seen_host = g_pending_tmux_host;
    seen_workspace = g_pending_background_workspace;
    seen_cmd = g_pending_tmux_cmd_len;
    seen_resurrect = g_pending_resurrect_len;
    return admitted;
}
${body('spawnBackgroundTmuxSession')}
${body('spawnBackgroundRemoteShell')}
test "background spawn preserves folder and restores state even on refusal" {
    for ([_]bool{ true, false }) |accept| {
        admitted = accept;
        try std.testing.expectEqual(accept, spawnBackgroundRemoteShell(1, 3, .vps, null, "/work/project"));
        try std.testing.expectEqual(ShellKind.vps, seen_kind);
        try std.testing.expect(seen_session == null);
        try std.testing.expectEqualStrings("/work/project", seen_cwd.?);
        try std.testing.expectEqual(@as(u8, 1), seen_host);
        try std.testing.expectEqual(@as(?u8, 3), seen_workspace);
        try std.testing.expectEqual(@as(usize, 0), seen_cmd);
        try std.testing.expectEqual(@as(usize, 0), seen_resurrect);
        try std.testing.expectEqual(accept, spawnBackgroundTmuxSession(0, "retained", 4));
        try std.testing.expectEqual(ShellKind.tmux, seen_kind);
        try std.testing.expectEqualStrings("retained", seen_session.?);
        try std.testing.expect(seen_cwd == null);
        try std.testing.expectEqual(@as(u8, 0), seen_host);
        try std.testing.expectEqual(@as(?u8, 4), seen_workspace);
        try std.testing.expectEqual(@as(usize, 0), seen_cmd);
        try std.testing.expectEqual(@as(usize, 0), seen_resurrect);
        try std.testing.expectEqual(@as(u8, 2), g_pending_tmux_host);
        try std.testing.expect(g_pending_background_workspace == null);
        try std.testing.expectEqual(@as(usize, 7), g_pending_tmux_cmd_len);
        try std.testing.expectEqual(@as(usize, 9), g_pending_resurrect_len);
    }
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
