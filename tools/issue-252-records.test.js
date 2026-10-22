const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const root = path.join(__dirname, '..');

function execute(mutate = text => text, harness) {
  assert.ok(process.env.CI, 'ISSUE-252 compiled tests run on GitHub, not on the shared development server');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-record-sync-'));
  try {
    copyZig(['account_records.zig'], dir);
    const source = path.join(dir, 'account_records.zig');
    fs.writeFileSync(source, mutate(fs.readFileSync(source, 'utf8')));
    let target = source;
    if (harness) {
      target = path.join(dir, 'scheduler.zig');
      fs.writeFileSync(target, harness);
    }
    return spawnSync(process.env.ZIG || 'zig', ['test', '-j1', target, '--test-filter', 'ISSUE-252'], { encoding: 'utf8', timeout: 120000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('ISSUE-252 production two-device protocol executes add edit delete conflict round trip offline and privacy cases', () => {
  const result = execute();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All \d+ tests passed/);
});

test('ISSUE-252 conflict tombstone and readback mutations fail executable scenarios', () => {
  for (const mutate of [
    text => text.replace('a.device_id, b.device_id) == .gt', 'a.device_id, b.device_id) == .lt'),
    text => text.replace('.device_id = device, .deleted = true', '.device_id = device, .deleted = false'),
    text => text.replace('const i = find(received, record) orelse return error.UnprovenRoundTrip;', 'const i = find(received, record) orelse continue;'),
    text => text.replace('user: []const u8 };', 'user: []const u8, host_keys: ?[]const []const u8 = null };').replace('.port = host.port, .user = host.user }', '.port = host.port, .user = host.user, .host_keys = host.host_keys }'),
  ]) {
    const result = execute(mutate);
    assert.notEqual(result.status, 0, 'regression must fail');
    assert.match(result.stderr, /FAIL/, result.stdout + result.stderr);
  }
});

function body(name) {
  const text = fs.readFileSync(path.join(root, 'src/account_desktop.zig'), 'utf8');
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2).replaceAll('app_state.', '');
}

test('ISSUE-252 actual scheduler arms only one timer and off means no wakeups', () => {
  const harness = `const std = @import("std");
const account_records = @import("account_records.zig");
const TIMER_ACCOUNT: usize = 170;
var g_main_hwnd: usize = 1;
var g_account_sync_enabled = false;
var g_account_bypass = false;
var armed: usize = 0;
var last_delay: u32 = 0;
fn KillTimer(_: usize, id: usize) i32 { std.debug.assert(id == TIMER_ACCOUNT); armed = 0; return 1; }
fn SetTimer(_: usize, id: usize, delay: u32, _: ?*anyopaque) usize { std.debug.assert(id == TIMER_ACCOUNT); armed += 1; last_delay = delay; return id; }
${body('accountArmTimer')}
test "ISSUE-252 disabled startup repeated saves toggle and backoff share a single bounded timer" {
    accountArmTimer(2000);
    try std.testing.expectEqual(@as(usize, 0), armed);
    g_account_sync_enabled = true;
    accountArmTimer(account_records.poll_ms);
    try std.testing.expectEqual(@as(usize, 1), armed);
    try std.testing.expectEqual(@as(u32, 180000), last_delay);
    accountArmTimer(2000);
    accountArmTimer(40000);
    try std.testing.expectEqual(@as(usize, 1), armed);
    try std.testing.expectEqual(@as(u32, 40000), last_delay);
    g_account_sync_enabled = false;
    accountArmTimer(2000);
    try std.testing.expectEqual(@as(usize, 0), armed);
    g_account_sync_enabled = true;
    g_account_bypass = true;
    accountArmTimer(2000);
    try std.testing.expectEqual(@as(usize, 0), armed);
}
`;
  const result = execute(text => text, harness);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('ISSUE-252 real original host deletion and key privacy regressions fail before this change', () => {
  assert.ok(process.env.CI, 'compiled baseline runs on GitHub only');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-sync-baseline-'));
  try {
    fs.writeFileSync(path.join(dir, 'account_hosts.zig'), execFileSync('git', ['show', 'daf2435:src/account_hosts.zig'], { cwd: root }));
    const source = `const std = @import("std");
const hosts = @import("account_hosts.zig");
const host = hosts.Host{ .slot = 0, .name = "One", .hostname = "one.example.com", .port = 22, .user = "owner", .host_keys = &.{"ssh-ed25519 AAAA=="} };
test "ISSUE-252 original deletion must publish" {
    try std.testing.expect(hosts.needsPublish(&.{}, &.{host}));
}
test "ISSUE-252 original host document must not carry SSH keys" {
    const wire = try std.json.Stringify.valueAlloc(std.testing.allocator, host, .{ .emit_null_optional_fields = false });
    defer std.testing.allocator.free(wire);
    try std.testing.expect(std.mem.indexOf(u8, wire, "host_keys") == null);
}
`;
    const target = path.join(dir, 'baseline.zig');
    fs.writeFileSync(target, source);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', target, '--test-filter', 'ISSUE-252'], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /original deletion must publish[^]*FAIL/);
    assert.match(result.stderr, /original host document must not carry SSH keys[^]*FAIL/);
    console.log('ISSUE-252 original baseline rejected: host deletion and key privacy');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('ISSUE-252 actual SSH watcher blocks rearms before posting and releases its notification on stop or failure', () => {
  const watcher = body('accountHostWatchThread').replace('const w = @import("win32.zig");', '').replaceAll('w.', '');
  const harness = `const std = @import("std");
const HANDLE = usize;
const WM_APP_ACCOUNT_HOST_CHANGED = 1206;
var waits: []const u32 = &.{1, 1, 0};
var at: usize = 0;
var posts: usize = 0;
var rearms: usize = 0;
var closes: usize = 0;
var rearm_ok = true;
fn WaitForMultipleObjects(n: u32, handles: [*]const HANDLE, all: i32, delay: u32) u32 {
    std.debug.assert(n == 2 and handles[0] == 7 and handles[1] == 8 and all == 0 and delay == 0xFFFFFFFF);
    const result = waits[at]; at += 1; return result;
}
fn FindCloseChangeNotification(_: HANDLE) i32 { closes += 1; return 1; }
fn FindNextChangeNotification(_: HANDLE) i32 { rearms += 1; return @intFromBool(rearm_ok); }
fn PostMessageW(hwnd: HANDLE, message: u32, wp: usize, lp: isize) i32 {
    std.debug.assert(hwnd == 9 and message == WM_APP_ACCOUNT_HOST_CHANGED and wp == 0 and lp == 0);
    posts += 1; std.debug.assert(rearms >= posts); return 1;
}
${watcher}
test "ISSUE-252 watcher change change stop and failure" {
    accountHostWatchThread(8, 7, 9);
    try std.testing.expectEqual(@as(usize, 2), posts);
    try std.testing.expectEqual(@as(usize, 1), closes);
    at = 0; rearm_ok = false; waits = &.{1};
    accountHostWatchThread(8, 7, 9);
    try std.testing.expectEqual(@as(usize, 2), posts);
    try std.testing.expectEqual(@as(usize, 2), closes);
}
`;
  const result = execute(text => text, harness);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
