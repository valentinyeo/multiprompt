const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const { copyZig } = require('./zig-copy');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/archive.zig'), 'utf8');
function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('remote rename uses one SSH command and never types into chat-only sessions', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-remote-rename-'));
  try {
    copyZig(['chat_view.zig'], dir);
    const fixture = String.raw`
const std = @import("std");
const DWORD = u32;
const STARTUPINFOW = extern struct { cb: u32 = 0 };
const PROCESS_INFORMATION = struct { hProcess: usize = 1, hThread: usize = 2 };
const Shell = struct { tmux_session: [64]u8 = @splat(0), tmux_session_len: usize = 0, tmux_host: u8 = 0 };
const app_state = struct { var shell_count: u32 = 1; var shells = [_]Shell{.{}}; };
var launches: usize = 0;
var command: [1024]u16 = @splat(0);
var command_len: usize = 0;
fn appendAsciiBuf(buf: []u8, pos: *usize, text: []const u8) bool {
    if (pos.* + text.len > buf.len) return false;
    @memcpy(buf[pos.*..][0..text.len], text);
    pos.* += text.len;
    return true;
}
fn appendSshExe(buf: []u8, pos: *usize) bool { return appendAsciiBuf(buf, pos, "ssh.exe "); }
fn tmuxSshTarget(_: u8) []const u8 { return "example.invalid"; }
fn debugLog(_: []const u8) void {}
fn debugLog2(_: []const u8, _: []const u8) void {}
fn sshSpawnFailed() void {}
fn CloseHandle(_: usize) i32 { return 1; }
fn CreateProcessW(_: anytype, cmd: [*:0]const u16, _: anytype, _: anytype, _: anytype, _: DWORD, _: anytype, _: anytype, _: anytype, pi: *PROCESS_INFORMATION) i32 {
    launches += 1;
    const text = std.mem.span(cmd);
    @memcpy(command[0..text.len], text);
    command_len = text.len;
    pi.* = .{};
    return 1;
}
fn expectRename(session: []const u8, agent: bool, expected: []const u8) !void {
    app_state.shells[0] = .{};
    @memcpy(app_state.shells[0].tmux_session[0..session.len], session);
    app_state.shells[0].tmux_session_len = session.len;
    launches = 0;
    syncRemoteDisplayNameForShell(0, "New name", agent);
    try std.testing.expectEqual(@as(usize, 1), launches);
    const actual = try std.unicode.utf16LeToUtf8Alloc(std.testing.allocator, command[0..command_len]);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}
` + ['remoteNameIsSafe', 'remoteTmuxTargetIsSafe', 'appendRemoteSingleQuoted', 'syncRemoteDisplayNameForShell'].map(body).join('\n') + String.raw`
test "rename command boundaries" {
    const prefix = "ssh.exe -o ServerAliveInterval=10 -o ServerAliveCountMax=2 -o ConnectTimeout=8 example.invalid ";
    try expectRename("live-claude", true, prefix ++ "\"tmux rename-window -t live-claude: 'New name'\"");
    try expectRename("live-hax", true, prefix ++ "\"tmux rename-window -t live-hax: 'New name'\"");
    try expectRename("agent-1", true, prefix ++ "\"tmux rename-window -t agent-1: 'New name'; tmux send-keys -t agent-1 '/rename New name' Enter\"");
    try expectRename("agent-1", false, prefix ++ "\"tmux rename-window -t agent-1: 'New name'\"");
    launches = 0;
    syncRemoteDisplayNameForShell(0, "bad'name", true);
    syncRemoteDisplayNameForShell(1, "New name", true);
    try std.testing.expectEqual(@as(usize, 0), launches);
}
`;
    const file = path.join(dir, 'rename.zig');
    fs.writeFileSync(file, fixture);
    const run = () => spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'rename command boundaries'], { encoding: 'utf8', timeout: 60000 });
    const result = run();
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const original = fixture.replace('send_agent_rename and !@import("chat_view.zig").isLive(session)', 'send_agent_rename');
    assert.notEqual(original, fixture, 'negative control removes only the live-session guard');
    fs.writeFileSync(file, original);
    const negative = run();
    assert.notEqual(negative.status, 0, 'old command must fail the same behavior assertions');
    assert.match(negative.stdout + negative.stderr, /TestExpectedEqual|strings are not equal/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
