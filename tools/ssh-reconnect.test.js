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
function zig(code, filter, state = true, expected = 0) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'issue501-'));
  try {
    if (state && modern) copyZig(['ssh_reconnect.zig'], dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), code);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', filter], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, expected, result.stdout + result.stderr);
    if (expected === 0) assert.match(result.stderr, /All \d+ tests passed/);
    else assert.match(result.stderr, /expected 15000, found 1000/);
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
    tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 1,
    spawn_tick: u64 = 1, shell_id: u32 = 42, tmux_host: u8 = 0,
    ssh_reconnect: State = .{}, ssh_reconnect_attempts: u8 = 0, ssh_reconnect_next_tick: u64 = 0,
};
var shells = [_]Shell{.{}};
var shell_count: u32 = 1;
var active_shell: u32 = 0;
const g_main_hwnd: ?*anyopaque = @ptrFromInt(1);
var g_ssh_reconnect_timer_ms: u32 = 0;
var ssh_probe_job: ?*anyopaque = null;
const UINT = u32;
var g_tmux_fetch_tick: u64 = 0;
var ssh_probe_next_tick: u64 = 0;
const TIMER_SSH_RECONNECT = 1;
const SSH_AUTO_RECONNECT_ENABLED = true;
const DWORD = u32;
const SW_HIDE = 0;
const g_chat_active = false;
var fake_now: u64 = 100;
var network = true;
var alive = true;
var spawns: usize = 0;
var kills: usize = 0;
var timers: usize = 0;
var timer_ms: u32 = 0;
var timer_kills: usize = 0;
var fixture = false;
var repaints: usize = 0;
var full_repaints: usize = 0;
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
var last_paint: RECT = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
fn chatBenchEnabled() bool { return fixture; }
fn GetClientRect(_: ?*anyopaque, rc: *RECT) u32 { rc.* = .{ .left = 0, .top = 0, .right = 1920, .bottom = 1032 }; return 1; }
fn threadTitleTop() i32 { return 10; }
fn threadTitleHeight() i32 { return 44; }
var spawn_ok = true;
var fake_exit_code: u32 = 0;
fn GetExitCodeProcess(_: ?*anyopaque, code: *u32) u32 { code.* = fake_exit_code; return 1; }
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
fn SetTimer(_: ?*anyopaque, _: u32, ms: u32, _: ?*anyopaque) u32 { timers += 1; timer_ms = ms; return 1; }
fn KillTimer(_: ?*anyopaque, _: u32) u32 { timer_ms = 0; timer_kills += 1; return 1; }
fn InvalidateRect(_: ?*anyopaque, rc: ?*const RECT, _: u32) u32 {
    repaints += 1;
    if (rc) |rect| { last_paint = rect.*; } else { full_repaints += 1; }
    return 1;
}
var exit_logs: usize = 0;
var timeout_logs: usize = 0;
fn debugLog(line: []const u8) void {
    if (std.mem.indexOf(u8, line, "exit_code=0 known=true") != null) exit_logs += 1;
    if (std.mem.indexOf(u8, line, "reason=timeout") != null) timeout_logs += 1;
}
fn logSessionAuditAlways(_: []const u8) void {}
var header_notices: usize = 0;
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void { header_notices += 1; }
fn invalidateSidebar() void {}
fn saveSession() void {}
fn repositionActive() void {}
fn fetchTmuxSessions() void {}
${modern ? '' : 'const shell_exit = struct { const ISSUE_416_FAST_FAIL_MS: u64 = 60000; ' + body('hostProbeBusy', fs.readFileSync(path.join(root, 'src/shell_exit.zig'), 'utf8')).replace('pub fn ', 'fn ') + body('reconnectAllowed', fs.readFileSync(path.join(root, 'src/shell_exit.zig'), 'utf8')).replace('pub fn ', 'fn ') + ' };'}
`;
function runtime(tests) {
  const functions = ['armSshReconnectTimerIfNeeded', 'markSshTabDisconnected', 'sshAutoReconnectTick'];
  if (modern) functions.push('sshDisconnect', 'sshReconnectNow', 'sshReconnectAttempt', 'sshReconnectArm', 'sshNetworkVeto');
  else functions.push('chatReconnectBackoffMs');
  return prelude + functions.map(name => body(name).replaceAll('@import("chat_send.zig").sshReconnectArm', 'sshReconnectArm')).join('\n') + tests;
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
    try std.testing.expect(g_ssh_reconnect_timer_ms != 0);
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
    try std.testing.expect(g_ssh_reconnect_timer_ms != 0);
    network = false;
    alive = false;
    sshAutoReconnectTick();
    try std.testing.expect(shells[0].disconnected);
    fake_now += 2000;
    sshAutoReconnectTick();
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
    try std.testing.expect(g_ssh_reconnect_timer_ms == 0);
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
  const code = runtime('').replace('var ssh_probe_job: ?*anyopaque = null;', '').replace('fn sshProbeFinish() void {}', '') + job + `
var ssh_probe_job: ?*SshProbeJob = null;
fn findShellById(id: u32) ?u32 { return if (id == shells[0].shell_id and shell_count > 0) 0 else null; }
` + body('sshProbeFinish').replaceAll('@import("inbox.zig").findShellById', 'findShellById') + `
test "ISSUE-501 live ssh silent detach" {
    const probe = try std.heap.page_allocator.create(SshProbeJob);
    probe.* = .{};
    probe.count = 1;
    probe.items[0] = .{ .id = 42, .host = 0, .session = @splat(0), .len = 0, .attached = false };
    probe.healthy[0] = true;
    probe.finished.store(true, .release);
    ${body('sshProbeFinish').includes('owners.fetchSub') ? '_ = probe.owners.fetchSub(1, .acq_rel);' : ''}
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
    fake_now += 2000;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-501 offline');
});

function probeRuntime(tests) {
  const start = source.indexOf('const SshProbeJob = struct {');
  const job = source.slice(start, source.indexOf('\n};', start) + 3);
  return runtime('').replace('var ssh_probe_job: ?*anyopaque = null;', '').replace('fn sshProbeFinish() void {}', '').replace('fn sshProbeStart() void {}', '') + job + `
var ssh_probe_job: ?*SshProbeJob = null;
var probe_starts: usize = 0;
fn findShellById(id: u32) ?u32 { return if (id == shells[0].shell_id and shell_count > 0) 0 else null; }
const FakeThread = struct { fn detach(_: FakeThread) void {} };
fn spawnProbe(_: anytype, _: anytype, args: anytype) !FakeThread { _ = args; probe_starts += 1; return .{}; }
fn sshProbeThread(_: *SshProbeJob) void {}
` + body('sshProbeStart').replace('std.Thread.spawn', 'spawnProbe') + '\n' +
    body('sshProbeFinish').replaceAll('@import("inbox.zig").findShellById', 'findShellById') + tests;
}

function startupRuntime(tests) {
  const spawn = body('spawnShellWithSession');
  const start = spawn.indexOf('    if (CreateProcessW(');
  const end = spawn.indexOf('    var style = GetWindowLongPtrW(', start);
  assert.ok(start >= 0 && end > start);
  const acquisition = spawn.slice(start, end).replace('    if (cmd_hwnd != null) {\n', '');
  const registrationStart = spawn.indexOf('    registerShellExitWait(idx);');
  const registrationEnd = spawn.indexOf('\n\n    if (!', registrationStart);
  assert.ok(registrationStart >= 0 && registrationEnd > registrationStart);
  const registration = spawn.slice(registrationStart, registrationEnd).replaceAll('@import("chat_send.zig").sshDisconnect', 'sshDisconnect');
  return runtime('') + `
const HANDLE = ?*anyopaque;
const STARTUPINFOW = struct { cb: u32 = 0 };
const PROCESS_INFORMATION = struct { hProcess: HANDLE = @ptrFromInt(1), hThread: HANDLE = @ptrFromInt(2), dwProcessId: u32 = 7 };
const CREATE_NEW_CONSOLE = 1;
const SPAWN_TITLES = [_]?*anyopaque{null};
const g_job = null;
var next_shell_id: u32 = 0;
var registered: usize = 0;
fn CreateProcessW(_: anytype, _: anytype, _: anytype, _: anytype, _: anytype, _: anytype, _: anytype, _: anytype, _: anytype, _: anytype) u32 { return 1; }
fn AssignProcessToJobObject(_: anytype, _: anytype) u32 { return 1; }
fn Sleep(_: u32) void {}
fn FindWindowW(_: anytype, _: anytype) HANDLE { return null; }
fn findWindowByClassAndPid(_: u32, _: []const u8) HANDLE { return null; }
fn findConsoleWindowByPid(_: u32) HANDLE { return null; }
fn TerminateProcess(_: HANDLE, _: u32) u32 { return 1; }
fn applyBlackConsoleBackground(_: u32) void {}
fn SetParent(_: HANDLE, _: HANDLE) u32 { return 1; }
fn isRemoteShellKind(kind: ShellKind) bool { return kind == .tmux or kind == .vps or kind == .vps2; }
fn sshSpawnFailed() void {}
fn registerShellExitWait(_: u32) void { registered += 1; }
fn spawnStartup(kind: ShellKind) bool {
    const idx: u32 = 0;
    const title_id: usize = 0;
    const cmd_ptr = null;
    const cwd_ptr = null;
    var si: STARTUPINFOW = .{};
    var pi: PROCESS_INFORMATION = .{};
${acquisition}
    shells[idx].kind = kind;
    shells[idx].process = pi.hProcess;
    shells[idx].hwnd = cmd_hwnd;
${registration}
    return true;
}
` + tests;
}

test('ISSUE-501 exit code 0 after attach routes to reconnect even without a console', () => {
  zig(startupRuntime(`
test "ISSUE-501 clean attach exit" {
    fake_exit_code = 0;
    try std.testing.expect(spawnStartup(.tmux));
    try std.testing.expectEqual(@as(usize, 1), registered);
    try std.testing.expect(shells[0].disconnected);
    try std.testing.expectEqual(@as(usize, 1), exit_logs);
    fake_now = shells[0].ssh_reconnect.next_tick;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-501 clean attach');
});

test('ISSUE-501 exit during startup routes every remote kind to reconnect', () => {
  zig(startupRuntime(`
test "ISSUE-501 startup exit" {
    for ([_]ShellKind{ .tmux, .vps, .vps2 }) |kind| {
        shells[0] = .{};
        fake_exit_code = 255;
        try std.testing.expect(spawnStartup(kind));
        try std.testing.expect(shells[0].disconnected);
        try std.testing.expect(shells[0].ssh_reconnect.next_tick > fake_now);
        fake_now = shells[0].ssh_reconnect.next_tick;
        sshAutoReconnectTick();
    }
    try std.testing.expectEqual(@as(usize, 3), spawns);
}
`), 'ISSUE-501 startup exit');
  assert.match(body('preserveFailedRemoteSavedTab'), /sshDisconnect\(idx, "restore-spawn-failed"\)/);
});

test('ISSUE-501 a null-process unclosed tab is probed and reconnected even if another client is attached', () => {
  zig(probeRuntime(`
test "ISSUE-501 null child probe" {
    fake_now = 10000;
    shells[0].process = null;
    shells[0].tmux_host = 1;
    sshProbeStart();
    try std.testing.expectEqual(@as(usize, 1), probe_starts);
    const job = ssh_probe_job orelse return error.MissingProbe;
    try std.testing.expectEqual(@as(u8, 1), job.items[0].host);
    job.healthy[1] = true;
    job.items[0].attached = true;
    job.finished.store(true, .release);
    ${body('sshProbeFinish').includes('owners.fetchSub') ? '_ = job.owners.fetchSub(1, .acq_rel);' : ''}
    sshProbeFinish();
    try std.testing.expect(ssh_probe_job == null);
    try std.testing.expect(shells[0].disconnected);
    fake_now = shells[0].ssh_reconnect.next_tick;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
test "ISSUE-501 null child poll" {
    shells[0] = .{ .process = null };
    spawns = 0;
    sshAutoReconnectTick();
    try std.testing.expect(shells[0].disconnected);
    fake_now = shells[0].ssh_reconnect.next_tick;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-501 null child');
});

test('ISSUE-501 a stuck probe is abandoned after timeout and the next probe runs', () => {
  const bounded = body('sshProbeFinish').includes('owners.fetchSub');
  zig(probeRuntime(`
test "ISSUE-501 stuck probe turnover" {
    fake_now = 10000;
    sshProbeStart();
    const old = ssh_probe_job orelse return error.MissingProbe;
    fake_now += 44999;
    sshProbeFinish();
    try std.testing.expect(ssh_probe_job == old);
    fake_now += 1;
    sshProbeFinish();
    try std.testing.expect(ssh_probe_job == null);
    try std.testing.expectEqual(@as(usize, 1), timeout_logs);
    sshProbeStart();
    try std.testing.expectEqual(@as(usize, 2), probe_starts);
    const next = ssh_probe_job orelse return error.MissingReplacement;
    try std.testing.expect(next != old);
    ${bounded ? 'try std.testing.expect(old.abandoned.load(.acquire));\n    try std.testing.expectEqual(@as(u32, 1), old.owners.load(.acquire));' : ''}
    old.items[0].attached = false;
    old.finished.store(true, .release);
    ${bounded ? 'if (old.owners.fetchSub(1, .acq_rel) == 1) std.heap.page_allocator.destroy(old);' : 'std.heap.page_allocator.destroy(old);'}
    next.items[0].attached = true;
    next.healthy[0] = true;
    next.finished.store(true, .release);
    ${bounded ? '_ = next.owners.fetchSub(1, .acq_rel);' : ''}
    sshProbeFinish();
    try std.testing.expect(!shells[0].disconnected);
    try std.testing.expect(ssh_probe_job == null);
}
`), 'ISSUE-501 stuck');
});

test('ISSUE-501 user close does not reconnect or probe on late exit or missing child', () => {
  zig(probeRuntime(`
test "ISSUE-501 user close" {
    fake_now = 10000;
    shells[0].ssh_reconnect.close();
    shells[0].process = null;
    markSshTabDisconnected(0);
    sshDisconnect(0, "late-exit");
    sshAutoReconnectTick();
    sshReconnectNow(0);
    try std.testing.expect(!shells[0].disconnected);
    try std.testing.expectEqual(@as(usize, 0), kills);
    try std.testing.expectEqual(@as(usize, 0), spawns);
    try std.testing.expectEqual(@as(usize, 0), probe_starts);
    shell_count = 0;
    sshProbeStart();
    try std.testing.expect(ssh_probe_job == null);
}
`), 'ISSUE-501 user close');
  assert.match(body('closeShellRemember'), /ssh_reconnect.close\(\)/);
  for (const name of ['detachTabToNewWindow', 'detachTabToExistingWindow']) {
    assert.match(body(name), /unregisterShellExitWait\(idx\)/);
    assert.match(body(name), /shell_count -= 1/);
  }
});

test('ISSUE-501 exit events reconnect every remote kind for clean and failed exits in every phase', () => {
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const start = main.indexOf('        WM_APP_SHELL_EXITED => {');
  const end = main.indexOf('        @import("win32.zig").WM_TIMECHANGE => {', start);
  assert.ok(start >= 0 && end > start);
  const handler = main.slice(start, end).replace('WM_APP_SHELL_EXITED => {', 'fn dispatchExit(wp: usize) u32 {')
    .replace(/},\s*$/, '}').replaceAll('app_state.', '').replaceAll('@import("chat_send.zig").sshDisconnect', 'sshDisconnect');
  zig(runtime('') + `
const ISSUE_350_KEEP_TMUX_TABS = true;
const g_resume_until_tick: u64 = 0;
fn sshSpawnFailed() void {}
fn appendDecimal(_: []u8, _: *usize, _: anytype) void {}
fn decideShellExit(_: ShellKind, _: bool, _: u32, _: bool, _: bool, _: bool, _: u64) enum { respawn, preserve, close } { return .close; }
fn markPinnedLocalTabDisconnected(_: u32) void { @panic("remote tab routed to local exit"); }
fn closeShell(_: u32) void { @panic("remote exit closed a tab"); }
${handler}
test "ISSUE-501 event exits" {
    for ([_]ShellKind{ .tmux, .vps, .vps2 }) |kind| {
        for ([_]u32{ 0, 1, 255, 0xC0000139 }) |code| {
            for ([_]bool{ false, true }) |starting| {
                shells[0] = .{ .kind = kind };
                if (starting) shells[0].ssh_reconnect.phase = .reconnecting;
                fake_exit_code = code;
                _ = dispatchExit(42);
                try std.testing.expect(shells[0].disconnected);
                try std.testing.expect(shells[0].ssh_reconnect.next_tick > fake_now);
                const attempts_before = spawns;
                fake_now = shells[0].ssh_reconnect.next_tick;
                sshAutoReconnectTick();
                try std.testing.expectEqual(attempts_before + 1, spawns);
                shells[0].ssh_reconnect.close();
                _ = dispatchExit(42);
                sshAutoReconnectTick();
                try std.testing.expectEqual(attempts_before + 1, spawns);
            }
        }
    }
}
`, 'ISSUE-501 event');
});

test('ISSUE-501 production probe worker handles host indices BatchMode failure and abandoned ownership', () => {
  const worker = body('sshProbeThread').replaceAll('@import("console.zig")', 'probeConsole').replaceAll('@import("vps.zig")', 'probeVps');
  const code = probeRuntime('').replace('fn sshProbeThread(_: *SshProbeJob) void {}', worker) + `
var capture_count: usize = 0;
var capture_ok = true;
const probeConsole = struct {
    fn appendSshExe(buf: anytype, pos: *usize) bool { return appendWideAscii(buf, pos, "ssh "); }
    fn appendWideAscii(buf: anytype, pos: *usize, text: []const u8) bool {
        for (text) |c| { buf[pos.*] = c; pos.* += 1; }
        return true;
    }
    fn tmuxSshTarget(host: u8) []const u8 { return if (host == 1) "1" else "0"; }
};
const probeVps = struct {
    fn sshOneShotCaptureInput(cmd: []const u8, output: []u8, _: ?*anyopaque, timeout: u32) struct { len: usize, success: bool } {
        std.debug.assert(std.mem.indexOf(u8, cmd, "-o BatchMode=yes") != null);
        std.debug.assert(std.mem.indexOf(u8, cmd, "-o ConnectTimeout=5") != null);
        std.debug.assert(timeout == 10000);
        capture_count += 1;
        const result = if (capture_ok) "session\\n@@MP_LIVE@@\\n" else "Permission denied";
        @memcpy(output[0..result.len], result);
        return .{ .len = result.len, .success = capture_ok };
    }
};
fn workerJob() !*SshProbeJob {
    const job = try std.heap.page_allocator.create(SshProbeJob);
    job.* = .{};
    job.count = 2;
    job.items[0] = .{ .id = 42, .host = 1, .session = @splat(0), .len = 7 };
    @memcpy(job.items[0].session[0..7], "session");
    job.items[1] = job.items[0];
    ssh_probe_job = job;
    return job;
}
test "ISSUE-501 worker hosts and failure" {
    fake_now = 10000;
    shells[0].tmux_host = 1;
    const good = try workerJob();
    sshProbeThread(good);
    try std.testing.expect(good.finished.load(.acquire));
    try std.testing.expectEqual(@as(usize, 1), capture_count);
    try std.testing.expect(good.healthy[1]);
    try std.testing.expect(!good.healthy[0]);
    try std.testing.expect(good.items[0].attached);
    sshProbeFinish();
    try std.testing.expect(!shells[0].disconnected);
    capture_ok = false;
    const bad = try workerJob();
    sshProbeThread(bad);
    sshProbeFinish();
    try std.testing.expect(shells[0].disconnected);
    try std.testing.expect(ssh_probe_job == null);
    try std.testing.expect(shells[0].ssh_reconnect.next_tick > fake_now);
}
test "ISSUE-501 worker releases abandoned allocation" {
    const old = try workerJob();
    fake_now += 45000;
    sshProbeFinish();
    try std.testing.expect(ssh_probe_job == null);
    try std.testing.expectEqual(@as(u32, 1), old.owners.load(.acquire));
    const before = capture_count;
    sshProbeThread(old);
    try std.testing.expectEqual(before, capture_count);
}
`;
  zig(code, 'ISSUE-501 worker');
});


test('ISSUE-512 a locked background disconnect never leaves a global warning after recovery', () => {
  zig(runtime(`
test "ISSUE-512 recovered tab has no stale global notice" {
    shells[0].locked = true;
    markSshTabDisconnected(0);
    try std.testing.expectEqual(@as(usize, 0), header_notices);
    shells[0].ssh_reconnect.ok();
    shells[0].disconnected = false;
    try std.testing.expectEqual(@as(usize, 0), header_notices);
}
`), 'ISSUE-512');
});

test('ISSUE-512 pure notice policy and active-tab rendering use recovery state instead of global messages', () => {
  zig('const reconnect = @import("ssh_reconnect.zig");\ntest "ISSUE-512 imported notice logic" { _ = reconnect; }', 'ISSUE-512');
  const drawing = fs.readFileSync(path.join(root, 'src/drawing.zig'), 'utf8');
  const paint = body('paintDisconnectedNotice', drawing);
  assert.match(paint, /shells\[app_state\.active_shell\]/);
  assert.match(paint, /ssh_reconnect\.noticeReason\(now, shell\.disconnected\)/);
  assert.match(paint, /disconnected: \{s\} - Ctrl\+Shift\+R to reconnect/);
  assert.doesNotMatch(body('markSshTabDisconnected'), /showHeaderNoticeAscii/);
});

test('ISSUE-513 synthetic chat tabs never enter SSH recovery or repaint while idle', () => {
  zig(runtime(`
test "ISSUE-513 fixture recovery isolation" {
    fixture = true;
    shells[0].process = null;
    markSshTabDisconnected(0);
    try std.testing.expect(!shells[0].disconnected);
    try std.testing.expectEqual(@as(usize, 0), kills);
    armSshReconnectTimerIfNeeded();
    try std.testing.expect(g_ssh_reconnect_timer_ms == 0);
    for (0..120) |_| {
        fake_now += 1000;
        sshAutoReconnectTick();
    }
    try std.testing.expect(!shells[0].disconnected);
    try std.testing.expectEqual(@as(usize, 0), spawns);
    try std.testing.expectEqual(@as(usize, 0), repaints);
    try std.testing.expectEqual(@as(usize, 0), timers);
}
`), 'ISSUE-513 fixture');
});

test('ISSUE-513 disconnected countdown repaints only its header and respects backoff', () => {
  zig(runtime(`
test "ISSUE-513 bounded countdown repaint" {
    shells[0].process = null;
    shells[0].disconnected = true;
    shells[0].ssh_reconnect.phase = .disconnected;
    shells[0].ssh_reconnect.next_tick = fake_now + 30000;
    for (0..29) |_| {
        fake_now += 1000;
        sshAutoReconnectTick();
    }
    try std.testing.expectEqual(@as(usize, 0), spawns);
    try std.testing.expectEqual(@as(usize, 29), repaints);
    try std.testing.expectEqual(@as(usize, 0), full_repaints);
    try std.testing.expectEqual(@as(i32, 0), last_paint.left);
    try std.testing.expectEqual(@as(i32, 1920), last_paint.right);
    try std.testing.expectEqual(threadTitleTop(), last_paint.top);
    try std.testing.expectEqual(threadTitleTop() + threadTitleHeight(), last_paint.bottom);
    fake_now += 1000;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-513 bounded');
});

test('ISSUE-513 connected idle monitoring does not respawn or repaint', () => {
  zig(runtime(`
test "ISSUE-513 connected idle" {
    for (0..120) |_| {
        fake_now += 1000;
        sshAutoReconnectTick();
    }
    try std.testing.expectEqual(@as(usize, 0), spawns);
    try std.testing.expectEqual(@as(usize, 0), repaints);
    try std.testing.expect(!shells[0].disconnected);
}
`), 'ISSUE-513 connected');
});

const idleTimerChecks = `
test "ISSUE-513 healthy remote monitoring wakes four times per minute without resetting unchanged timers" {
    for ([_]ShellKind{.tmux, .vps, .vps2}) |kind| {
        shells[0].kind = kind;
        armSshReconnectTimerIfNeeded();
        try std.testing.expectEqual(@as(u32, 15000), timer_ms);
        const before = timers;
        var wakes: usize = 0;
        var elapsed: u64 = 0;
        while (elapsed < 60000) {
            elapsed += timer_ms;
            fake_now += timer_ms;
            sshAutoReconnectTick();
            wakes += 1;
        }
        try std.testing.expectEqual(@as(usize, 4), wakes);
        try std.testing.expectEqual(before, timers);
    }
}
test "ISSUE-513 pending probes and reconnects keep one-second monitoring and closed tabs stop it" {
    armSshReconnectTimerIfNeeded();
    ssh_probe_job = @ptrFromInt(1);
    armSshReconnectTimerIfNeeded();
    try std.testing.expectEqual(@as(u32, 1000), timer_ms);
    ssh_probe_job = null;
    armSshReconnectTimerIfNeeded();
    try std.testing.expectEqual(@as(u32, 15000), timer_ms);
    shells[0].ssh_reconnect.lost(fake_now, 0);
    armSshReconnectTimerIfNeeded();
    try std.testing.expectEqual(@as(u32, 1000), timer_ms);
    shells[0].ssh_reconnect.start();
    armSshReconnectTimerIfNeeded();
    try std.testing.expectEqual(@as(u32, 1000), timer_ms);
    shells[0].ssh_reconnect.ok();
    armSshReconnectTimerIfNeeded();
    try std.testing.expectEqual(@as(u32, 15000), timer_ms);
    shells[0].ssh_reconnect.close();
    armSshReconnectTimerIfNeeded();
    try std.testing.expectEqual(@as(u32, 0), timer_ms);
    try std.testing.expectEqual(@as(usize, 1), timer_kills);
}
`;

test('ISSUE-513 production idle reconnect scheduler coalesces healthy checks but keeps recovery responsive', () => {
  zig(runtime(idleTimerChecks), 'ISSUE-513 healthy');
  zig(runtime(idleTimerChecks), 'ISSUE-513 pending');
});

test('ISSUE-513 idle wakeup oracle rejects the original one-second healthy reconnect timer', () => {
  const original = body('armSshReconnectTimerIfNeeded', fs.readFileSync(path.join(__dirname, 'fixtures/issue-513-reconnect-before.zig'), 'utf8'));
  const code = runtime(idleTimerChecks).replace(body('armSshReconnectTimerIfNeeded'), original) + '\nvar g_ssh_reconnect_timer_on = false;\n';
  zig(code, 'ISSUE-513 healthy', true, 1);
});
