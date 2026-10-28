const { copyZig } = require('./zig-copy');
const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const source = require('./app-source').readAppSource();
const main = fs.readFileSync(path.join(__dirname, '../src/main.zig'), 'utf8');
const root = path.resolve(__dirname, '..');
const modern = fs.existsSync(path.join(root, 'src/ssh_reconnect.zig'));
function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
async function zig(code, filter, files = modern ? ['ssh_reconnect.zig'] : []) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'issue501-'));
  try {
    if (files.length) copyZig(files, dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), code.replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = await new Promise((resolve, reject) => {
      const child = spawn(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '--test-filter', filter], { timeout: 120000 });
      let stdout = '';
      let stderr = '';
      child.stdout.setEncoding('utf8').on('data', chunk => { stdout += chunk; });
      child.stderr.setEncoding('utf8').on('data', chunk => { stderr += chunk; });
      child.once('error', reject);
      child.once('close', status => resolve({ status, stdout, stderr }));
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}
const prelude = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const State = ${modern ? '@import("ssh_reconnect.zig").State' : 'struct {}'};
const ShellKind = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
const Shell = struct {
    kind: ShellKind = .tmux, console_inflight: bool = false, disconnected: bool = false, process: ?*anyopaque = @ptrFromInt(1),
    hwnd: ?*anyopaque = null, pid: u32 = 7, activity: enum { idle, active } = .idle,
    needs_attention: bool = false, locked: bool = false, pinned_top: bool = false,
    tmux_identity_len: u32 = 0,
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
var ssh_probe_pending_request = false;
fn sshRequestSessionProbe() void { ssh_probe_pending_request = true; ssh_probe_next_tick = 0; armSshReconnectTimerIfNeeded(); }
fn invalidateReconnectContent(_: u32) void {}
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
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
fn chatBenchEnabled() bool { return false; }
fn GetClientRect(_: ?*anyopaque, rc: *RECT) u32 { rc.* = .{ .left = 0, .top = 0, .right = 1920, .bottom = 1032 }; return 1; }
fn reconnectTabVisible(_: u32) bool { return true; }
fn threadTitleTop() i32 { return 10; }
fn threadTitleHeight() i32 { return 44; }
var veto_logs: usize = 0;
var spawn_ok = true;
var fake_exit_code: u32 = 0;
const STILL_ACTIVE: u32 = 259;
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
fn SetTimer(_: ?*anyopaque, _: u32, _: u32, _: ?*anyopaque) u32 { timers += 1; return 1; }
fn KillTimer(_: ?*anyopaque, _: u32) u32 { return 1; }
fn InvalidateRect(_: ?*anyopaque, _: ?*const RECT, _: u32) u32 { return 1; }
fn debugLog(line: []const u8) void { if (std.mem.indexOf(u8, line, "veto reason=windows-network-offline id=42") != null) veto_logs += 1; }
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
  if (modern) functions.push('sshDisconnect', 'sshReconnectNow', 'sshReconnectAttempt', 'sshReconnectArm', 'sshNetworkVeto', 'sshSessionEnded');
  else functions.push('chatReconnectBackoffMs');
  return prelude + functions.map(name => body(name).replaceAll('@import("chat_send.zig").sshReconnectArm', 'sshReconnectArm').replaceAll('@import("drawing.zig").invalidateReconnectContent', 'invalidateReconnectContent').replaceAll('@import("drawing.zig").reconnectTabVisible', 'reconnectTabVisible').replaceAll('@import("workspaces.zig").unregisterShellExitWait', 'unregisterShellExitWait').replaceAll('@import("console.zig").killProcessTree', 'killProcessTree').replaceAll('@import("focus.zig").ShowWindow', 'ShowWindow').replaceAll('@import("win32.zig").SW_HIDE', 'SW_HIDE')).join('\n') + tests;
}

function armRuntime(tests) {
  assert.ok(modern, 'reconnect state and single arm must exist');
  return runtime(tests);
}

describe('SSH clock and standby', { concurrency: os.availableParallelism() }, () => {
  for (const kind of ['tmux', 'vps', 'vps2']) {
    test(`ISSUE-501 ${kind} link exit routes to single reconnect arm`, async () => {
      assert.match(body('markSshTabDisconnected'), /sshReconnectArm\(idx,/);
      assert.match(main, /if \(is_ssh_kind\) \{\s*@import\("chat_send.zig"\).sshDisconnect\(idx, "process-exit-event"\)/);
      await zig(armRuntime(`
test "ISSUE-501 link exit" {
    shells[0].kind = .${kind};
    markSshTabDisconnected(0);
    const due = shells[0].ssh_reconnect.next_tick;
    fake_now += 100;
    markSshTabDisconnected(0);
    try std.testing.expectEqual(due, shells[0].ssh_reconnect.next_tick);
    try std.testing.expect(g_ssh_reconnect_timer_ms != 0);
    fake_now = due;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-501 link exit');
    });
  }

  function dispatchRuntime() {
    assert.ok(modern, 'reconnect state and single arm must exist');
    const time = main.slice(main.indexOf('        @import("win32.zig").WM_TIMECHANGE => {'), main.indexOf('        WM_POWERBROADCAST => {'));
    assert.match(time, /sshReconnectArm\(null, "time-change"\)/);
    const power = main.slice(main.indexOf('        WM_POWERBROADCAST => {'), main.indexOf('        WM_ACTIVATEAPP => {'));
    const dispatch = (time + power).replaceAll('app_state.', '').replaceAll('@import("win32.zig").WM_TIMECHANGE', 'WM_TIMECHANGE').replaceAll('@import("chat_send.zig").sshReconnectArm', 'sshReconnectArm');
    return armRuntime('') + `
const win = @import("win32.zig");
const WM_TIMECHANGE = win.WM_TIMECHANGE;
const WM_POWERBROADCAST = win.WM_POWERBROADCAST;
const PBT_APMSUSPEND = win.PBT_APMSUSPEND;
const PBT_APMRESUMESUSPEND = win.PBT_APMRESUMESUSPEND;
const PBT_APMRESUMEAUTOMATIC = win.PBT_APMRESUMEAUTOMATIC;
const PBT_POWERSETTINGCHANGE = win.PBT_POWERSETTINGCHANGE;
const POWERBROADCAST_SETTING = win.POWERBROADCAST_SETTING;
const GUID_ACDC_POWER_SOURCE = win.GUID_ACDC_POWER_SOURCE;
const GUID_POWER_SAVING_STATUS = win.GUID_POWER_SAVING_STATUS;
const GUID_CONSOLE_DISPLAY_STATE = win.GUID_CONSOLE_DISPLAY_STATE;
const TIMER_RESUME_RECONNECT = 6;
const RESUME_RESPAWN_WINDOW_MS = 60000;
var g_resume_until_tick: u64 = 0;
var g_last_kb_hook_tick: u64 = 0;
var g_last_mouse_hook_tick: u64 = 0;
var g_power_on_battery = false;
var g_power_energy_saver = false;
var g_power_display_off = true;
fn uninstallHook() void {}
fn installHook() void {}
fn syncMouseHookForUrlClicks() void {}
fn refreshPowerStatusFromSystem() void {}
fn applyPowerProfile(_: ?*anyopaque) void {}
fn exitDeepIdleNow(_: ?*anyopaque) void {}
fn guidEql(a: win.GUID, b: win.GUID) bool { return std.mem.eql(u8, std.mem.asBytes(&a), std.mem.asBytes(&b)); }
fn SetWindowTextW(_: ?*anyopaque, _: [*:0]const u16) u32 { return 1; }
fn buildWindowTitle(buf: *[256]u16) [*:0]const u16 { buf[0] = 0; return @ptrCast(buf); }
fn dispatch(hwnd: ?*anyopaque, msg: u32, wp: usize, lp: isize) isize {
    switch (msg) {
${dispatch}
        else => return 0,
    }
}
`;
  }

  for (const trigger of [
    ['time change clock', '_ = dispatch(g_main_hwnd, WM_TIMECHANGE, 0, 0);'],
    ['standby power-setting display-on', `var setting = std.mem.zeroes(POWERBROADCAST_SETTING); setting.PowerSetting = GUID_CONSOLE_DISPLAY_STATE; setting.DataLength = 4; setting.Data[0] = 1; _ = dispatch(g_main_hwnd, WM_POWERBROADCAST, PBT_POWERSETTINGCHANGE, @intCast(@intFromPtr(&setting)));`],
    ['standby PBT automatic resume', '_ = dispatch(g_main_hwnd, WM_POWERBROADCAST, PBT_APMRESUMEAUTOMATIC, 0);'],
    ['standby PBT suspend resume', '_ = dispatch(g_main_hwnd, WM_POWERBROADCAST, PBT_APMRESUMESUSPEND, 0);'],
  ]) {
    test(`ISSUE-501 ${trigger[0]} routes to single reconnect arm without killing healthy tabs`, async () => {
      const handler = trigger[0].startsWith('time') ? main.slice(main.indexOf('WM_TIMECHANGE'), main.indexOf('        WM_POWERBROADCAST => {')) : main.slice(main.indexOf('        WM_POWERBROADCAST => {'), main.indexOf('        WM_ACTIVATEAPP => {'));
      assert.match(handler, trigger[0].includes('display-on') ? /sshReconnectArm\(null, "standby-display-on"\)/ : trigger[0].startsWith('time') ? /sshReconnectArm\(null, "time-change"\)/ : /sshReconnectArm\(null, "power-resume"\)/);
      const power = fs.readFileSync(path.join(root, 'src/power.zig'), 'utf8');
      assert.match(power, /RegisterPowerSettingNotification\(hwnd, &GUID_CONSOLE_DISPLAY_STATE, DEVICE_NOTIFY_WINDOW_HANDLE\)/);
      await copyDispatch(`
test "ISSUE-501 ${trigger[0]}" {
    ssh_probe_next_tick = 90000;
    ${trigger[1]}
    try std.testing.expectEqual(@as(usize, 0), kills);
    try std.testing.expect(!shells[0].disconnected);
    try std.testing.expectEqual(@as(u64, 0), ssh_probe_next_tick);
    try std.testing.expect(g_ssh_reconnect_timer_ms != 0);
    alive = false;
    ${trigger[1].replace('var setting =', 'setting =')}
    try std.testing.expect(shells[0].disconnected);
    const due = shells[0].ssh_reconnect.next_tick;
    fake_now += 100;
    ${trigger[1].replace('var setting =', 'setting =')}
    try std.testing.expectEqual(due, shells[0].ssh_reconnect.next_tick);
    fake_now = due;
    alive = true;
    sshAutoReconnectTick();
    ${trigger[1].replace('var setting =', 'setting =')}
    sshReconnectNow(0);
    try std.testing.expectEqual(@as(usize, 1), spawns);
    try std.testing.expectEqual(@as(u8, 1), shells[0].ssh_reconnect.attempts);
}
`);
    });
  }

  async function copyDispatch(tests) {
    await zig(dispatchRuntime() + tests, 'ISSUE-501', ['ssh_reconnect.zig', 'win32.zig']);
  }

  test('ISSUE-501 duplicate link and manual triggers do not multiply attempts or children', async () => {
    if (!modern) {
      await zig(runtime('') + body('reconnectSshTabsAfterResume') + `
var g_refocus_remaining: u32 = 0;
const TIMER_REFOCUS = 2;
fn appendDecimal(_: []u8, _: *usize, _: anytype) void {}
test "ISSUE-501 duplicate baseline resume" {
    for (0..10) |_| reconnectSshTabsAfterResume();
    try std.testing.expect(spawns <= 1);
}
`, 'ISSUE-501 duplicate');
      return;
    }
    await zig(armRuntime(`
test "ISSUE-501 duplicate triggers" {
    markSshTabDisconnected(0);
    fake_now = shells[0].ssh_reconnect.next_tick;
    sshAutoReconnectTick();
    for (0..10) |_| {
        sshReconnectArm(null, "time-change");
        sshReconnectArm(null, "standby-display-on");
        sshReconnectNow(0);
        sshAutoReconnectTick();
    }
    try std.testing.expectEqual(@as(usize, 1), spawns);
    try std.testing.expectEqual(@as(u8, 1), shells[0].ssh_reconnect.attempts);
}
`), 'ISSUE-501 duplicate');
  });

  test('ISSUE-501 stale Windows network veto logs tab reason and expires within one backoff step', async () => {
    await zig(runtime(`
test "ISSUE-501 stale network veto" {
    markSshTabDisconnected(0);
    fake_now = ${modern ? 'shells[0].ssh_reconnect.next_tick' : '10000'};
    network = false;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 0), spawns);
    try std.testing.expectEqual(@as(usize, 1), veto_logs);
    const first = fake_now;
    fake_now += ${modern ? 'shells[0].ssh_reconnect.delay_ms' : '1000'} - 1;
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 2), veto_logs);
    try std.testing.expectEqual(@as(usize, 0), spawns);
    fake_now = first + ${modern ? 'shells[0].ssh_reconnect.delay_ms' : '1000'};
    sshAutoReconnectTick();
    try std.testing.expectEqual(@as(usize, 1), spawns);
}
`), 'ISSUE-501 stale');
  });

  for (const jump of [-3_600_000, 3_600_000]) {
    test(`ISSUE-501 clock jump ${jump} leaves monotonic outbox timeout unchanged`, async () => {
      const code = `
const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const chat_echo = @import("chat_echo.zig");
const Entry = struct {
    state: chat_echo.OutboxState = .delivered, host_held: bool = false, id: u64 = 1, channel_pending: bool = false,
    transcript_queued: bool = false, retryable: bool = false, left_box_ms: u64 = 0,
    key: [1]u8 = .{0}, key_len: usize = 0, delivery_watch: chat_echo.DeliveryWatch = .{},
    anchor: chat_echo.Anchor = .{ .sent_ms = 8_000_000 }, sent_tick_ms: i64 = 100_000,
};
var storage = [_]Entry{.{}};
var g_chat_outbox = struct { items: []Entry }{ .items = &storage };
var fake_tick: u64 = 100_000;
var fake_wall: i64 = 8_000_000;
const g_chat_verify_echo_id: u64 = 0;
const ISSUE_349_FULL_SETTLE = false;
const g_chat_active = false;
const active_shell = 0;
const g_chat_screen_working = false;
const shells = [_]struct { activity: enum { idle, active } = .idle }{.{}};
fn GetTickCount64() u64 { return fake_tick; }
fn nowFileTime() u64 { return @as(u64, @intCast(fake_wall)) * 10000 + 116444736000000000; }
fn chatTmuxSendFinish() void {}
fn chatCancelFinish() void {}
fn chatFullSettleFinish() void {}
fn chatTmuxSettle() void {}
fn saveChatOutbox() bool { return true; }
fn chatOutboxChanged() void {}
fn chatOutboxShellForKey(_: []const u8) ?u32 { return 0; }
fn chatEchoMatchActive() void {}
fn chatOutboxFindSending(_: anytype) ?usize { return 0; }
fn chatLinkLooksDown(_: u32) bool { return false; }
fn chatOutboxTrySendEntry(_: u32, _: usize) bool { return false; }
fn sshOutboxFlushed(_: u32) void {}
fn chatFullSettleStart() void {}
fn armChatOutboxTimerIfNeeded() void {}
${body('chatOutboxTick')}
test "ISSUE-501 injected clock jump" {
    fake_wall += ${jump};
    fake_tick += 599999;
    chatOutboxTick();
    try std.testing.expectEqual(chat_echo.OutboxState.delivered, storage[0].state);
    fake_tick += 1;
    chatOutboxTick();
    try std.testing.expectEqual(chat_echo.OutboxState.not_sent, storage[0].state);
}
`;
      await zig(code, 'ISSUE-501 injected', ['chat_echo.zig']);
    });
  }

  test('ISSUE-501 clock audit keeps confirmation and VPS deadlines monotonic', () => {
    const send = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
    const history = fs.readFileSync(path.join(root, 'src/chat_session.zig'), 'utf8');
    const vps = fs.readFileSync(path.join(root, 'src/vps.zig'), 'utf8');
    for (const name of ['chatOutboxTick', 'chatEchoMatchActive', 'chatTmuxSettle', 'chatFullSettleStart', 'sshAutoReconnectTick']) {
      assert.match(body(name), /GetTickCount64\(\)/, name);
      assert.doesNotMatch(body(name), /nowFileTime\(\)/, name);
    }
    assert.match(history, /entry.loaded_ms = @intCast\(GetTickCount64\(\)\)/);
    assert.doesNotMatch(body('chatSendVerifyTick'), /nowFileTime\(\)/);
    assert.doesNotMatch(body('chatEchoSendAgain'), /nowFileTime\(\)/);
    assert.doesNotMatch(vps, /GetSystemTimeAsFileTime/);
    assert.match(vps, /GetTickCount64\(\) - last_activity >= timeout_ms/);
    assert.match(send, /entry.sent_tick_ms = @intCast\(GetTickCount64\(\)\)/);
  });
});
