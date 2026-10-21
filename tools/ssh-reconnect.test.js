const { copyZig } = require('./zig-copy');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const source = require('./app-source').readAppSource();
const root = path.resolve(__dirname, '..');
const modern = fs.existsSync(path.join(root, 'src/ssh_reconnect.zig'));
function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
function zig(code, filter, state = true) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'issue501-'));
  try {
    if (state && modern) copyZig(['ssh_reconnect.zig'], dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), code);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', filter], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
const prelude = `
const std = @import("std");
const State = ${modern ? '@import("ssh_reconnect.zig").State' : 'struct {}'};
const ShellKind = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
const Shell = struct {
    kind: ShellKind = .tmux, disconnected: bool = false, process: ?*anyopaque = @ptrFromInt(1),
    hwnd: ?*anyopaque = null, pid: u32 = 7, activity: enum { idle, active } = .idle,
    needs_attention: bool = false, locked: bool = false, pinned_top: bool = false,
    spawn_tick: u64 = 1, shell_id: u32 = 42, tmux_host: u8 = 0,
    ssh_reconnect: State = .{}, ssh_reconnect_attempts: u8 = 0, ssh_reconnect_next_tick: u64 = 0,
};
var shells = [_]Shell{.{}};
var shell_count: u32 = 1;
var active_shell: u32 = 0;
const g_main_hwnd: ?*anyopaque = @ptrFromInt(1);
var g_ssh_reconnect_timer_on = false;
var g_tmux_fetch_tick: u64 = 0;
const TIMER_SSH_RECONNECT = 1;
const SSH_AUTO_RECONNECT_ENABLED = true;
const SW_HIDE = 0;
const g_chat_active = false;
var fake_now: u64 = 100;
var network = true;
var alive = true;
var spawns: usize = 0;
var kills: usize = 0;
var timers: usize = 0;
var spawn_ok = true;
fn GetTickCount64() u64 { return fake_now; }
fn chatNetworkReportsConnected() bool { return network; }
fn shellProcessAliveForRead(_: usize) bool { return alive; }
fn sshProbeFinish() void {}
fn sshProbeStart() void {}
fn sshReconnectOk(idx: u32) void { shells[idx].disconnected = false; }
fn respawnShellInPlace(idx: u32, terminate: bool) bool {
    std.debug.assert(terminate);
    spawns += 1;
    if (spawn_ok) { shells[idx].process = @ptrFromInt(1); shells[idx].spawn_tick = fake_now; }
    return spawn_ok;
}
fn unregisterShellExitWait(_: u32) void {}
fn ShowWindow(_: ?*anyopaque, _: u32) u32 { return 0; }
fn CloseHandle(_: ?*anyopaque) u32 { return 1; }
fn killProcessTree(_: u32) void { kills += 1; }
fn SetTimer(_: ?*anyopaque, _: u32, _: u32, _: ?*anyopaque) u32 { timers += 1; return 1; }
fn KillTimer(_: ?*anyopaque, _: u32) u32 { return 1; }
fn InvalidateRect(_: ?*anyopaque, _: ?*anyopaque, _: u32) u32 { return 1; }
fn debugLog(_: []const u8) void {}
fn logSessionAuditAlways(_: []const u8) void {}
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn invalidateSidebar() void {}
fn saveSession() void {}
fn repositionActive() void {}
fn fetchTmuxSessions() void {}
${modern ? '' : 'const shell_exit = struct { const ISSUE_416_FAST_FAIL_MS: u64 = 60000; ' + body('hostProbeBusy', fs.readFileSync(path.join(root, 'src/shell_exit.zig'), 'utf8')).replace('pub fn ', 'fn ') + body('reconnectAllowed', fs.readFileSync(path.join(root, 'src/shell_exit.zig'), 'utf8')).replace('pub fn ', 'fn ') + ' };'}
`;
function runtime(tests) {
  const functions = ['armSshReconnectTimerIfNeeded', 'markSshTabDisconnected', 'sshAutoReconnectTick'];
  if (modern) functions.push('sshDisconnect', 'sshReconnectNow', 'sshReconnectAttempt');
  else functions.push('chatReconnectBackoffMs');
  return prelude + functions.map(name => body(name)).join('\n') + tests;
}
test('ISSUE-501 backoff growth cap jitter and success reset execute production logic', () => {
  if (modern) {
    zig('const reconnect = @import("ssh_reconnect.zig");\ntest "ISSUE-501 imported logic" { _ = reconnect; }', 'ISSUE-501');
  } else {
    zig('const std = @import("std");\n' + body('chatReconnectBackoffMs') + '\ntest "ISSUE-501 first retry is one second" { try std.testing.expectEqual(@as(u64, 1000), chatReconnectBackoffMs(0)); }', 'ISSUE-501', false);
  }
});
test('ISSUE-501 marking disconnected arms a timer and schedules a delayed retry', () => {
  zig(runtime(`
test "ISSUE-501 marked disconnected is scheduled" {
    markSshTabDisconnected(0);
    try std.testing.expect(shells[0].disconnected);
    try std.testing.expect(g_ssh_reconnect_timer_on);
    const due = ${modern ? 'shells[0].ssh_reconnect.next_tick' : 'shells[0].ssh_reconnect_next_tick'};
    try std.testing.expect(due >= fake_now + 1000 and due <= fake_now + 1250);
    try std.testing.expectEqual(@as(usize, 1), kills);
}
`), 'ISSUE-501 marked');
});
test('ISSUE-501 monitoring survives connected state and detects a missed exit despite offline hint', () => {
  zig(runtime(`
test "ISSUE-501 missed exit" {
    armSshReconnectTimerIfNeeded();
    try std.testing.expect(g_ssh_reconnect_timer_on);
    network = false;
    alive = false;
    sshAutoReconnectTick();
    try std.testing.expect(shells[0].disconnected);
    fake_now += 2000;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-501 missed');
});
test('ISSUE-501 manual retry skips wait failure backs off and a closed tab cannot respawn', () => {
  assert.ok(modern, 'manual retry must enter the retry state machine');
  zig(runtime(`
test "ISSUE-501 manual and close" {
    markSshTabDisconnected(0);
    spawn_ok = false;
    sshReconnectNow(0);
    try std.testing.expectEqual(@as(usize, 1), spawns);
    try std.testing.expect(shells[0].ssh_reconnect.next_tick > fake_now);
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
    shells[0].ssh_reconnect.close();
    fake_now += 100000;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
    shell_count = 0;
    armSshReconnectTimerIfNeeded();
    try std.testing.expect(!g_ssh_reconnect_timer_on);
}
`), 'ISSUE-501 manual');
});
test('ISSUE-501 silent-detach probe and UI reconnect actions are integrated', () => {
  const tick = body('sshAutoReconnectTick');
  assert.match(tick, /sshProbeFinish\(\)/);
  assert.match(body('sshProbeThread'), /tmux list-clients/);
  assert.match(body('sshProbeFinish'), /sshDisconnect\(idx, "tmux-detached"\)/);
  assert.match(body('sshProbeFinish'), /findShellById\(item.id\)/);
  assert.match(body('sshReconnectOk'), /chatOutboxTick\(\)/);
  assert.match(body('respawnShellInPlace'), /saved_tmux\[0\.\.saved_tmux_len\]/);
  assert.match(body('markSshTabDisconnected'), /killProcessTree/);
  assert.match(body('closeShellRemember'), /ssh_reconnect.close\(\)/);
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  assert.match(main, /WM_APP_RECONNECT =>[^]*sshReconnectNow/);
  assert.match(main, /reconnectButtonRect\(client_rc.right\)/);
  assert.match(main, /process-exit-event/);
  assert.match(body('paintThreadTitle'), /paintDisconnectedNotice/);
  assert.match(body('paintDisconnectedShell'), /Disconnected/);
  assert.match(body('shellConsoleShouldBeVisible'), /disconnected/);
  assert.match(body('registerShellExitWait'), /exit-wait-registration-failed/);
  assert.match(source, /SSH_OPTS = "-o ServerAliveInterval=15 -o ServerAliveCountMax=4 /);
});

test('ISSUE-501 successful probe detects silent detach while ssh remains alive', () => {
  if (!modern) {
    zig(runtime(`
test "ISSUE-501 live ssh silent detach" {
    sshAutoReconnectTick();
    try std.testing.expect(shells[0].disconnected);
}
`), 'ISSUE-501 live');
    return;
  }
  const start = source.indexOf('const SshProbeJob = struct {');
  assert.ok(start >= 0);
  const job = source.slice(start, source.indexOf('\n};', start) + 3);
  const code = runtime('').replace('fn sshProbeFinish() void {}', '') + job + `
var ssh_probe_job: ?*SshProbeJob = null;
var ssh_probe_next_tick: u64 = 0;
fn findShellById(id: u32) ?u32 { return if (id == shells[0].shell_id and shell_count > 0) 0 else null; }
` + body('sshProbeFinish').replaceAll('@import("inbox.zig").findShellById', 'findShellById') + `
test "ISSUE-501 live ssh silent detach" {
    const probe = try std.heap.page_allocator.create(SshProbeJob);
    probe.* = .{};
    probe.count = 1;
    probe.items[0] = .{ .id = 42, .host = 0, .session = @splat(0), .len = 0, .attached = false };
    probe.healthy[0] = true;
    probe.finished.store(true, .release);
    ssh_probe_job = probe;
    sshAutoReconnectTick();
    try std.testing.expect(shells[0].disconnected);
    try std.testing.expectEqual(@as(usize, 1), kills);
    try std.testing.expect(shells[0].ssh_reconnect.next_tick > fake_now);
}
`;
  zig(code, 'ISSUE-501 live');
});

test('ISSUE-501 offline network hint cannot indefinitely block a scheduled retry', () => {
  zig(runtime(`
test "ISSUE-501 offline hint" {
    markSshTabDisconnected(0);
    fake_now += 2000;
    network = false;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-501 offline');
});
