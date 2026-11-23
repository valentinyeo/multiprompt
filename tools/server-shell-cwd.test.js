const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const { copyZig } = require('./zig-copy');

const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
function body(file, name) {
  const source = read(file);
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  return source.slice(start, source.indexOf('\n}', start) + 2).replace(/^fn /, 'pub fn ');
}

test('SOFT-3003 palette and shortcut share the server shell spawn path', () => {
  const main = read('src/main.zig');
  assert.match(main, /spawnShellFromMenuIndex\(wp\)/);
  assert.match(main, /const kind_idx = target - SEARCH_NEW_OFFSET;[\s\S]*?spawnShellFromMenuIndex\(kind_idx\)/);
  const palette = read('src/command_palette.zig');
  assert.match(palette, /SEARCH_NEW_OFFSET \+ 3, .keywords = "open shell on vps 1/);
  assert.match(palette, /SEARCH_NEW_OFFSET \+ 4, .keywords = "open shell on vps 2/);
});

test('SOFT-3003 server shells start in the chat cwd, including before the first poll', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'server-shell-cwd-'));
  try {
    copyZig(['tmux_identity.zig'], dir);
    const functions = [
      body('src/console.zig', 'tmuxHostForMenuIndex'),
      body('src/console.zig', 'spawnShellFromMenuIndex'),
      body('src/capacity.zig', 'remoteHostForShell'),
      body('src/vps.zig', 'shellKnownRemotePath'),
      body('src/vps.zig', 'tmuxCachePathForShell'),
    ].join('\n').replaceAll('@import("capacity.zig").remoteHostForShell', 'remoteHostForShell')
      .replaceAll('@import("vps.zig").shellKnownRemotePath', 'shellKnownRemotePath');
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const app_state = @This();
const ShellKind = enum { cmd, tmux, vps, vps2, pwsh, bash, gitbash };
const NUM_BUTTONS = 8;
const MENU_KIND_ORDER = [NUM_BUTTONS]ShellKind{ .cmd, .tmux, .tmux, .vps, .vps2, .pwsh, .bash, .gitbash };
const Shell = struct {
    kind: ShellKind = .tmux, tmux_host: u8 = 0, ai_agent: u8 = 1,
    cached_cwd: [512]u8 = @splat(0), cached_cwd_len: u32 = 0,
    claude_cwd: [192]u8 = @splat(0), claude_cwd_len: u32 = 0,
    tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0,
};
var shells = [_]Shell{.{}};
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var g_pending_tmux_host: u8 = 0;
var g_pending_tmux_cmd: [2048]u8 = @splat(0);
var g_pending_tmux_cmd_len: u32 = 0;
var g_pending_chat_view = false;
var g_pending_resurrect_len: u32 = 0;
var g_pending_tmux_identity: ?[]const u8 = null;
var g_tmux_cache_count: u32 = 0;
const Entry = struct { name: [64]u8 = @splat(0), name_len: u32 = 0, host: u8 = 0, path: [256]u8 = @splat(0), path_len: u32 = 0 };
var g_tmux_cache = [_]Entry{.{}};
fn GetTickCount64() u64 { return 42; }
var opened_host: u8 = 255;
var opened_kind: ShellKind = .cmd;
var command: [2048]u8 = @splat(0);
var command_len: usize = 0;
fn spawnShell(kind: ShellKind) bool { return spawnShellWithSession(kind, null, null, null); }
fn spawnShellWithSession(kind: ShellKind, _: ?[]const u8, _: ?[]const u8, _: ?[]const u8) bool {
    opened_kind = kind;
    opened_host = if (kind == .vps) 0 else if (kind == .vps2) 1 else g_pending_tmux_host;
    command_len = g_pending_tmux_cmd_len;
    @memcpy(command[0..command_len], g_pending_tmux_cmd[0..command_len]);
    g_pending_tmux_cmd_len = 0;
    return true;
}
${functions}
test "server shell uses chat cwd on both hosts without waiting for tmux polling" {
    for ([_]u8{0, 1}) |host| {
        for ([_][]const u8{ "/work/chat", "/work/chat folder", "~/chat folder", "/work/literal~folder" }) |cwd| {
            shells[0] = .{ .tmux_host = host };
            @memcpy(shells[0].cached_cwd[0..cwd.len], cwd);
            shells[0].cached_cwd_len = @intCast(cwd.len);
            g_tmux_cache_count = 0;
            command_len = 0;
            try std.testing.expect(spawnShellFromMenuIndex(3 + @as(usize, host)));
            try std.testing.expectEqual(host, opened_host);
            var expected_buf: [1024]u8 = undefined;
            const expected = if (std.mem.startsWith(u8, cwd, "~/"))
                try std.fmt.bufPrint(&expected_buf, "tmux new-session -s 'shell-2a' -c ~/'{s}'", .{cwd[2..]})
            else try std.fmt.bufPrint(&expected_buf, "tmux new-session -s 'shell-2a' -c '{s}'", .{cwd});
            try std.testing.expectEqualStrings(expected, command[0..command_len]);
        }
    }
}
test "provider cwd wins over the host tmux pane home folder" {
    shells[0] = .{};
    const cwd = "/work/reported chat";
    @memcpy(shells[0].claude_cwd[0..cwd.len], cwd);
    shells[0].claude_cwd_len = cwd.len;
    @memcpy(shells[0].cached_cwd[0..10], "/work/seed");
    shells[0].cached_cwd_len = 10;
    @memcpy(shells[0].tmux_session[0..9], "live-chat");
    shells[0].tmux_session_len = 9;
    g_tmux_cache[0] = .{ .name_len = 9, .path_len = 10 };
    @memcpy(g_tmux_cache[0].name[0..9], "live-chat");
    @memcpy(g_tmux_cache[0].path[0..10], "/home/user");
    g_tmux_cache_count = 1;
    try std.testing.expect(spawnShellFromMenuIndex(3));
    try std.testing.expectEqualStrings("tmux new-session -s 'shell-2a' -c '/work/reported chat'", command[0..command_len]);
}
test "explicit other server and local shell do not inherit the chat folder" {
    shells[0] = .{};
    const cwd = "/work/chat";
    @memcpy(shells[0].cached_cwd[0..cwd.len], cwd);
    shells[0].cached_cwd_len = cwd.len;
    try std.testing.expect(spawnShellFromMenuIndex(4));
    try std.testing.expectEqual(@as(u8, 1), opened_host);
    try std.testing.expectEqual(@as(usize, 0), command_len);
    try std.testing.expect(spawnShellFromMenuIndex(0));
    try std.testing.expectEqual(ShellKind.cmd, opened_kind);
    try std.testing.expect(!spawnShellFromMenuIndex(99));
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const current = body('src/console.zig', 'spawnShellFromMenuIndex')
      .replaceAll('@import("capacity.zig").remoteHostForShell', 'remoteHostForShell')
      .replaceAll('@import("vps.zig").shellKnownRemotePath', 'shellKnownRemotePath');
    const file = path.join(dir, 'test.zig');
    const positive = fs.readFileSync(file, 'utf8');
    const negative = positive.replace(current, body('tools/fixtures/SOFT-3003/console.zig', 'spawnShellFromMenuIndex'));
    assert.notEqual(negative, positive);
    fs.writeFileSync(file, negative);
    const baseline = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(baseline.status, 0, 'The master snapshot must reproduce the missing chat directory');
    assert.match(baseline.stderr, /server shell uses chat cwd[^\n]*FAIL/);
    assert.match(baseline.stderr, /provider cwd wins[^\n]*FAIL/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
