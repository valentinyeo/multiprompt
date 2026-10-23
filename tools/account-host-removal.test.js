const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const read = path => fs.readFileSync(new URL('../' + path, 'file://' + __filename), 'utf8');
const worker = read('service/worker.js');
const desktop = read('src/account_desktop.zig');
const features = 'hosts,host_removal';
const hosts = [0, 1, 2].map(slot => ({ slot, name: `Server ${slot + 1}`, hostname: `server${slot + 1}.example`, port: 22, user: 'owner' }));
const layout = { schema: 1, revision: 1, workspaces: [], tabs: [], hosts };

function merge(source, previous, incoming, tokens) {
  const start = source.indexOf("        if (!layoutFeature(request, 'settings'))");
  const end = source.indexOf('        const stored = new Map(', start);
  assert.ok(start >= 0 && end > start);
  const context = { previousLayout: structuredClone(previous), layout: structuredClone(incoming), request: new Request('https://example.com', { headers: { 'X-Layout-Features': tokens } }) };
  vm.runInNewContext(source.slice(source.indexOf('const layoutFeature ='), source.indexOf('function layoutResponse')) + source.slice(start, end), context);
  return JSON.parse(JSON.stringify(context.layout));
}

function removalJourney(source) {
  const removed = merge(source, layout, { ...layout, hosts: [], removed_hosts: [2] }, features);
  assert.deepEqual(removed.hosts, hosts.slice(0, 2));
  assert.deepEqual(removed.removed_hosts, [2]);
  const stale = merge(source, removed, layout, 'hosts');
  assert.deepEqual(stale.hosts, hosts.slice(0, 2));
  assert.deepEqual(stale.removed_hosts, [2]);
  const aware = merge(source, stale, layout, features);
  assert.deepEqual(aware.hosts, hosts.slice(0, 2));
  assert.deepEqual(aware.removed_hosts, [2]);
}

test('IGSH-600 production Worker merge prevents resurrection by old and current clients', () => {
  removalJourney(worker);
  const baseline = execFileSync('git', ['show', '12dfb00fe22bb6deb388c7226ae4741351593c55:service/worker.js'], { encoding: 'utf8' });
  assert.throws(() => removalJourney(baseline));
  const stored = { ...layout, hosts: hosts.slice(0, 2), removed_hosts: [2] };
  assert.deepEqual(merge(worker, stored, { ...layout, removed_hosts: [0] }, 'hosts').removed_hosts, [2]);
  assert.deepEqual(merge(worker, stored, { ...layout, removed_hosts: [1, 0] }, features).removed_hosts, [0, 1, 2]);
  assert.deepEqual(merge(worker, stored, layout, '').hosts, hosts.slice(0, 2));
  assert.ok(!Object.hasOwn(merge(worker, layout, { ...layout, removed_hosts: [] }, features), 'removed_hosts'));
});

test('IGSH-600 production validation and response projection enforce the removal schema and capability', async () => {
  const start = worker.indexOf('export function validateLayout(');
  const end = worker.indexOf('\nfunction validateCrashReport', start);
  const source = worker.slice(worker.indexOf('const json ='), worker.indexOf('export function validateLayout')) + worker.slice(start, end).replace('export ', '');
  const context = { Response, validate: null, respond: null };
  vm.runInNewContext(source + '\nvalidate = validateLayout; respond = layoutResponse;', context);
  for (const removed_hosts of [null, {}, '2', [2, 2], [-1], [3], [0.5], ['2'], [true], [0, 1, 2, 0]]) {
    assert.throws(() => context.validate({ ...layout, removed_hosts }), { status: 400, message: 'invalid_hosts' });
  }
  for (const removed_hosts of [[], [2], [2, 0, 1]]) assert.equal(context.validate({ ...layout, removed_hosts }).removed_hosts, removed_hosts);
  for (const tokens of ['', 'hosts', features, 'hosts,host_removal-extra']) {
    const request = new Request('https://example.com', { headers: { 'X-Layout-Features': tokens } });
    for (const status of [200, 409]) {
      const response = context.respond(request, { layout: { ...layout, removed_hosts: [2] } }, status);
      assert.equal(response.status, status);
      assert.ok(response.headers.get('X-Layout-Features').split(',').includes('host_removal'));
      assert.equal(Object.hasOwn((await response.json()).layout, 'removed_hosts'), tokens === features);
    }
  }
});

function audit(source) {
  const sync = source.slice(source.indexOf('fn accountSyncHosts('), source.indexOf('fn accountDeviceKeyError('));
  assert.equal((sync.match(/if \(account_hosts\.isRemoved\(removed, @intCast\(slot\)\)\) continue;/g) || []).length, 2);
  assert.match(source, /accountSyncHosts\(host_arena\.allocator\(\), initial\.value\.hosts orelse &\.\{\}, removed\)/);
  assert.match(source, /g_account_hosts_cache\.hosts = try account_hosts\.withoutRemoved\(cache_arena\.allocator\(\), g_account_hosts_cache\.hosts, removed\)/);
  assert.match(source, /const merged_hosts = try account_hosts\.withoutRemoved\(alloc, hosts, removed\)/);
  assert.match(source, /synced_hosts = try account_hosts\.withoutRemoved\(alloc, if \(hosts_ready\) synced_hosts else host_base, removed\)/);
  assert.match(source, /if \(job\.kind == \.remove_host and !remote\.removal_supported\) return error\.RemovalUnsupported/);
  assert.match(source, /if \(hosts_ready and job\.kind != \.remove_host\) try accountApplyHostAddresses/);
  const action = source.slice(source.indexOf('pub fn accountRemoveServer('), source.indexOf('fn accountDeletePending('));
  assert.match(action, /host\.name, host\.hostname/);
  assert.match(action, /MessageBoxW\([^;]+!= 6\) return;/);
  assert.ok(action.indexOf('MessageBoxW(') < action.indexOf('startAccountJob('));
  assert.match(action, /startAccountJob\(\.\{ \.kind = \.remove_host, \.slot = slot, \.base = base, \.edited = edited \}\)/);
}

test('IGSH-600 desktop filters all publish paths and confirms before queuing removal', () => {
  audit(desktop);
  for (const before of [
    'if (account_hosts.isRemoved(removed, @intCast(slot))) continue;',
    'g_account_hosts_cache.hosts = try account_hosts.withoutRemoved(cache_arena.allocator(), g_account_hosts_cache.hosts, removed);',
    'const merged_hosts = try account_hosts.withoutRemoved(alloc, hosts, removed);',
    'if (hosts_ready and job.kind != .remove_host) try accountApplyHostAddresses',
    'if (MessageBoxW(app_state.g_main_hwnd, wide.ptr, L("Account: Remove server"), 4 | 0x20 | 0x100) != 6) return;',
  ]) {
    assert.ok(desktop.includes(before));
    assert.throws(() => audit(desktop.replaceAll(before, '')));
  }
});

test('IGSH-600 removal journey is wired into Test with production Zig sync and host tests', () => {
  assert.match(read('.github/workflows/test.yml'), /node --test service\/test\/infra\.test\.js service\/test\/worker\.test\.js/);
  assert.match(read('service/test/worker.test.js'), /IGSH-600 remove slot 2[^]*hostClient\.run\([^]*removal_journey: true/);
  assert.match(read('tools/account-hosts.test.js'), /--test-filter', 'IGSH-600'/);
  assert.match(read('build.zig'), /"src\/account_hosts\.zig"/);
  assert.match(read('build.zig'), /vps_test_step\.dependOn\(account_test_step\)/);
  assert.match(read('.claude/skills/verify-multiprompt/features/account-hosts.md'), /remove[^]*sync twice[^]*restart/i);
  const layoutSource = read('src/session_layout.zig');
  assert.match(layoutSource, /pub fn jsonStringify\(self: Layout/);
  assert.match(layoutSource, /for \(slots\) \|slot\| try json\.write\(slot\)/);
  assert.match(read('src/account_layout.zig'), /if \(!eq\(u8, a\.removed_hosts orelse &\.\{\}, b\.removed_hosts orelse &\.\{\}\)\) return false/);
});
