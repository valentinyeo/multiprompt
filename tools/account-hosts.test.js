const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const read = file => fs.readFileSync(new URL('../' + file, 'file://' + __filename), 'utf8');

function audit(desktop, client) {
  const request = desktop.slice(desktop.indexOf('fn accountRequest('), desktop.indexOf('fn layoutSyncWorker('));
  const discovery = desktop.slice(desktop.indexOf('fn accountSyncHosts('), desktop.indexOf('fn accountRequest('));
  assert.equal((request.match(/accountSyncHosts\(/g) || []).length, 1);
  assert.ok(request.indexOf('accountSyncHosts(') < request.indexOf('while (attempts < 3)'));
  assert.match(request, /if \(remote\.hosts_supported and account_hosts\.shouldRefresh\(GetTickCount64\(\), g_account_hosts_cache\.refreshed_at, job\.kind == \.login or job\.kind == \.startup, g_account_hosts_cache\.hosts, initial\.value\.hosts orelse &\.\{\}\)\) \{/);
  assert.match(request, /const discovered: \?\[\]const account_hosts\.Host = accountSyncHosts\(host_arena\.allocator\(\), initial\.value\.hosts orelse &\.\{\}\) catch null;/);
  assert.match(request, /if \(g_account_hosts_cache\.arena\) \|\*old\| old\.deinit\(\);/);
  assert.match(request, /g_account_hosts_cache = \.\{ \.arena = host_arena, \.hosts = found, \.refreshed_at = GetTickCount64\(\) \};/);
  assert.match(request, /const hosts = g_account_hosts_cache\.hosts;/);
  assert.match(desktop, /if \(app_state\.g_account_busy or app_state\.g_account_bypass\)/);
  assert.match(desktop, /app_state\.g_account_busy = true;/);
  assert.match(discovery, /host\.hostname = try a\.dupe\(u8, host\.hostname\);/);
  assert.match(discovery, /host\.user = try a\.dupe\(u8, host\.user\);/);
  assert.match(discovery, /for \(incoming_keys, owned_keys\) \|key, \*owned\| owned\.\* = try a\.dupe\(u8, key\);/);
  assert.match(discovery, /host\.host_keys = owned_keys;/);
  assert.match(request, /rebased\.hosts = if \(remote\.hosts_supported\) \(if \(hosts_ready\) synced_hosts else server\.value\.hosts\) else null;/);
  assert.match(request, /remote\.hosts_supported and hosts_ready and account_hosts\.needsPublish\(synced_hosts, server.value.hosts orelse &\.\{\}\)/);
  assert.match(discovery, /app_state\.SSH_TARGET_DE, app_state\.SSH_TARGET_UK, app_state\.SSH_TARGET_INNE/);
  assert.match(discovery, /appendSshExe\(/);
  assert.match(discovery, /-G \{s\}/);
  assert.match(discovery, /-F \\"\{s\}\\" -f/);
  assert.match(discovery, /const missing = account_hosts.shouldImport\(alias, resolved\)/);
  assert.match(discovery, /if \(incoming == null\) continue/);
  assert.match(discovery, /accountAppendSshFile\(config, block\)/);
  assert.match(discovery, /account_hosts\.knownHostLine/);
  assert.match(client, /hosts_supported: bool = false/);
  assert.match(client, /WinHttpQueryHeaders\(req, 22, null, &header_buf, &size, null\)/);
  assert.match(client, /hosts_supported = layoutSupportsHosts\(raw\);/);
  assert.match(client, /\.hosts_supported = hosts_supported/);
  assert.match(client.slice(client.indexOf('pub fn request('), client.indexOf('pub fn field(')), /X-Layout-Features: favorite,used,visits,input,settings,hosts\\r\\n/);
  const worker = desktop.slice(desktop.indexOf('fn layoutSyncWorker('), desktop.indexOf('fn layoutSyncWorker(') + 700);
  assert.match(worker, /accountRequest\(job, reply\)/);
  assert.match(desktop, /std.Thread.spawn\(\.\{\}, layoutSyncWorker/);
  assert.match(desktop, /CreateProcessW\(null, cmd_z.ptr, null, null, 1, 0x08000000/);
  assert.match(discovery, /accountSshOutput\(a, command, 5000\)/);
  assert.match(desktop, /GetTickCount64\(\) \+ timeout_ms/);
}

test('hosts sync discovery is worker-serialized, cached with owned data, bounded and reused on conflict retries', () => {
  const desktop = read('src/account_desktop.zig'), client = read('src/account_client.zig');
  audit(desktop, client);
  for (const [before, after] of [
    ['rebased.hosts = if (remote.hosts_supported) (if (hosts_ready) synced_hosts else server.value.hosts) else null;', 'rebased.hosts = hosts;'],
    ['remote.hosts_supported and account_hosts.shouldRefresh', 'account_hosts.shouldRefresh'],
    ['remote.hosts_supported and hosts_ready and account_hosts.needsPublish', 'account_hosts.needsPublish'],
    ['const hosts = g_account_hosts_cache.hosts;', ''],
    ['account_hosts.shouldRefresh(GetTickCount64()', 'true or account_hosts.shouldRefresh(GetTickCount64()'],
    ['job.kind == .login or job.kind == .startup', 'false'],
    ['host_arena.allocator()', 'alloc'],
    ['.refreshed_at = GetTickCount64()', '.refreshed_at = null'],
    ['host.hostname = try a.dupe(u8, host.hostname);', ''],
    ['host.user = try a.dupe(u8, host.user);', ''],
    ['owned.* = try a.dupe(u8, key)', 'owned.* = key'],
    ['account_hosts.shouldImport(alias, resolved)', 'true'],
    ['1, 0x08000000, null, null, &si, &pi', '1, 0, null, null, &si, &pi'],
    ['accountAppendSshFile(config, block)', 'writeFileAtomicW(config, block)'],
  ]) {
    assert.ok(desktop.includes(before));
    assert.throws(() => audit(desktop.replace(before, after), client));
  }
  assert.throws(() => audit(desktop, client.replace(',settings,hosts', ',settings')));
});

test('hosts support is fail-closed and rechecked from the latest reply after conflicts', () => {
  const desktop = read('src/account_desktop.zig'), client = read('src/account_client.zig');
  audit(desktop, client);
  const request = desktop.slice(desktop.indexOf('fn accountRequest('), desktop.indexOf('fn layoutSyncWorker('));
  const loop = request.slice(request.indexOf('while (attempts < 3)'));
  assert.match(loop, /rebased\.hosts = if \(remote\.hosts_supported\) \(if \(hosts_ready\) synced_hosts else server\.value\.hosts\) else null;/);
  assert.match(loop, /\.emit_null_optional_fields = false/);
  assert.match(loop, /remote = put;/);
  assert.ok(loop.indexOf('rebased.hosts =') < loop.indexOf('account_client.request("PUT"'));
  for (const [before, after] of [
    ['hosts_supported: bool = false', 'hosts_supported: bool = true'],
    ['hosts_supported = layoutSupportsHosts(raw);', 'hosts_supported = true;'],
    ['.hosts_supported = hosts_supported', '.hosts_supported = true'],
  ]) {
    assert.ok(client.includes(before));
    assert.throws(() => audit(desktop, client.replace(before, after)));
  }
  assert.throws(() => audit(desktop.replaceAll('remote.hosts_supported', 'initial_hosts_supported'), client));
});


test('ISSUE-252 production two-laptop host sync regressions and master negative control', () => {
  const { spawnSync } = require('node:child_process');
  const { prepare } = require('./account-hosts-fixture');
  const desktop = read('src/account_desktop.zig');
  const fixture = prepare(desktop);
  try {
    const result = spawnSync(process.env.ZIG || 'zig', ['test', fixture.file, '--test-filter', 'ISSUE-252'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally { fixture.cleanup(); }
  const master = spawnSync('git', ['show', '935601223eedc310039eb9d2508eb4141a7adb96:src/account_desktop.zig'], { encoding: 'utf8' });
  assert.equal(master.status, 0, master.stderr);
  const negative = prepare(master.stdout);
  try {
    const hosts = spawnSync('git', ['show', '935601223eedc310039eb9d2508eb4141a7adb96:src/account_hosts.zig'], { encoding: 'utf8' });
    assert.equal(hosts.status, 0, hosts.stderr);
    fs.writeFileSync(require('node:path').join(negative.dir, 'account_hosts.zig'), hosts.stdout);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', negative.file, '--test-filter', 'ISSUE-252 remote hostname'], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /ISSUE-252 remote hostname port and user changes reach laptop B[^]*FAIL/);
  } finally { negative.cleanup(); }
});
