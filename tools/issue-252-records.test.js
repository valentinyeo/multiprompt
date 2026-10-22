const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
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
