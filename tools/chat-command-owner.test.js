const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_composer.zig'), 'utf8');
function fn(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('SOFT-2584 an inne-account tab loads its own catalog on both transports', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'command-owner-'));
  try {
    fs.copyFileSync(path.join(root, 'src/chat_complete.zig'), path.join(dir, 'chat_complete.zig'));
    const program = `const std = @import("std");
const chat_complete = @import("chat_complete.zig");
const Slot = struct {
    host: u8 = 255, agent: chat_complete.Agent = .other, mode: chat_complete.Mode = .slash,
    session: [64]u8 = @splat(0), cwd: [192]u8 = @splat(0), pending: u32 = 0, fetched: u64 = 0,
    pending_len: usize = 0, bytes: [2][128 * 1024]u8 = undefined, active: usize = 0,
};
const Shell = struct {
    kind: enum { tmux, vps, vps2 } = .tmux, tmux_host: u8 = 0,
    tmux_session: [64]u8 = @splat(0), tmux_session_len: usize = 0,
    claude_cwd: [192]u8 = @splat(0), claude_cwd_len: usize = 0,
};
const Mutex = struct { fn tryLock(_: *@This()) bool { return true; } fn unlock(_: *@This()) void {} };
const app_state = struct {
    var shells: [1]Shell = .{.{}};
    var shell_count: usize = 1;
    var active_shell: usize = 0;
    var g_chat_ac_slots: [2]Slot = .{.{}, .{}};
    var g_chat_ac_mutex: Mutex = .{};
    const g_main_hwnd: ?usize = null;
    const TMUX_HOST_DE: u8 = 0;
    const TMUX_HOST_INNE: u8 = 2;
};
const ChatAcRequest = struct { slot: usize, id: u32, host: u8, agent: chat_complete.Agent, mode: chat_complete.Mode, session: [64]u8, cwd: [192]u8 };
const TMUX_HOST_DE: u8 = 0;
const TMUX_HOST_INNE: u8 = 2;
const WM_APP_CHAT_AC_READY = 1;
var fallback = false;
var received_host: u8 = 255;
var known_cwd: ?[]const u8 = null;
var command_bytes: [2048]u8 = undefined;
var command_len: usize = 0;
fn chatAcAgent() chat_complete.Agent { return .claude; }
fn isRemoteShellKind(_: anytype) bool { return true; }
fn shellKnownRemotePath(_: anytype, _: u8) ?[]const u8 { return known_cwd; }
fn tmuxSshTarget(host: u8) []const u8 { return switch (host) { 2 => "remote-3", 1 => "remote-2", else => "remote-1" }; }
fn GetTickCount64() u64 { return 1; }
fn Sleep(_: u32) void {}
fn PostMessageW(_: anytype, _: anytype, _: anytype, _: anytype) i32 { return 1; }
fn debugLog(_: []const u8) void {}
fn appendSshExe(buf: []u8, pos: *usize) bool { @memcpy(buf[0..4], "ssh "); pos.* = 4; return true; }
fn fetchAcPersistent(host: u8, request: []const u8, buf: []u8) ?usize {
    received_host = host;
    tryRequest(request);
    if (fallback) return null;
    const answer = "@mp\\t7\\tslash\\tok\\t/home/inne/projects/sample\\t1\\nS\\towner-only\\t\\tOwner skill\\n@@MP_END@@\\n";
    @memcpy(buf[0..answer.len], answer);
    return answer.len;
}
fn tryRequest(request: []const u8) void { std.debug.assert(std.mem.indexOf(u8, request, "~/") == null); }
fn sshOneShotCapture(command: []const u8, _: []u8) usize { @memcpy(command_bytes[0..command.len], command); command_len = command.len; return 0; }
fn sshOneShotCaptureInput(command: []const u8, buf: []u8, _: anytype, _: u32) struct { len: usize, success: bool, exit_code: u32 } {
    return .{ .len = sshOneShotCapture(command, buf), .success = false, .exit_code = 255 };
}
${fn('chatAcCatalog')}
${fn('chatAcFetchThread')}
test "owner catalog routing" {
    const cwd = "/home/inne/projects/sample";
    @memcpy(app_state.shells[0].claude_cwd[0..cwd.len], cwd);
    app_state.shells[0].claude_cwd_len = cwd.len;
    const index = chatAcCatalog(.slash).?;
    const slot = &app_state.g_chat_ac_slots[index];
    try std.testing.expectEqual(@as(u8, 2), slot.host);
    slot.pending = 7;
    const req = ChatAcRequest{ .slot = index, .id = 7, .host = slot.host, .agent = slot.agent, .mode = slot.mode, .session = slot.session, .cwd = slot.cwd };
    chatAcFetchThread(req);
    try std.testing.expectEqual(@as(u8, 2), received_host);
    var entries: [512]chat_complete.Entry = undefined;
    const parsed = chat_complete.parseResponse(slot.bytes[1][0..slot.pending_len], &entries).?;
    try std.testing.expectEqual(@as(usize, 1), parsed.n);
    try std.testing.expectEqualStrings("owner-only", entries[0].name);
    fallback = true;
    chatAcFetchThread(req);
    try std.testing.expect(std.mem.indexOf(u8, command_bytes[0..command_len], "remote-3 python3") != null);
    slot.pending = 0;
    app_state.shells[0].tmux_host = 1;
    try std.testing.expectEqual(@as(u8, 1), app_state.g_chat_ac_slots[chatAcCatalog(.slash).?].host);
    app_state.g_chat_ac_slots = .{.{}, .{}};
    app_state.shells[0].tmux_host = 0;
    const configured = "~/projects/sample";
    @memcpy(app_state.shells[0].claude_cwd[0..configured.len], configured);
    app_state.shells[0].claude_cwd_len = configured.len;
    known_cwd = cwd;
    const resolved = &app_state.g_chat_ac_slots[chatAcCatalog(.slash).?];
    try std.testing.expectEqual(@as(u8, 2), resolved.host);
    try std.testing.expectEqualStrings(cwd, std.mem.sliceTo(&resolved.cwd, 0));
}
`;
    fs.writeFileSync(path.join(dir, 'owner.zig'), program);
    const run = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'owner.zig')], { encoding: 'utf8', timeout: 60000 });
    assert.equal(run.status, 0, run.stdout + run.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
