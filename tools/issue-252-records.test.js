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

test('ISSUE-252 record polling adds no timer or competing host writer', () => {
  const source = fs.readFileSync(path.join(root, 'src/account_desktop.zig'), 'utf8');
  const start = source.indexOf('fn accountSyncRecords(');
  const records = source.slice(start, source.indexOf('\n}', start));
  assert.match(records, /GetTickCount64\(\) -\| records_checked.\? < account_records.poll_ms/);
  assert.doesNotMatch(records, /SetTimer|KillTimer|accountSyncHosts|rewriteHost|materialize/);
  assert.match(source, /SetTimer\(hwnd, TIMER_ACCOUNT, 20000, null\)/);
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
