const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const read = file => process.env.ISSUE_252_BEFORE ? execFileSync('git', ['show', `${process.env.ISSUE_252_BEFORE}:${file}`], { encoding: 'utf8' }) : fs.readFileSync(file, 'utf8');
const body = (text, name) => {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
};
const desktop = () => read('src/account_desktop.zig');
const service = () => {
  const code = read('service/worker.js').replace(/^import .*;\n/gm, '').replaceAll('export ', '').replace('default {', 'const worker = {');
  const context = vm.createContext({ Date, Response, TextEncoder, structuredClone, crypto: require('node:crypto').webcrypto });
  vm.runInContext(code + '\nglobalThis.api = { validateRecords, mergeRecord: typeof mergeRecord === "undefined" ? undefined : mergeRecord, worker };', context);
  return context.api;
};

test('ISSUE-252 A layout polling and device security are unconditional and values have one owner', () => {
  const source = desktop(), request = body(source, 'accountRequest');
  for (const name of ['publishSessionLayout', 'pullSessionLayout', 'accountPush']) assert.doesNotMatch(body(source, name), /!app_state.g_account_sync_enabled/);
  assert.match(body(source, 'accountBootstrap'), /SetTimer\(hwnd, TIMER_ACCOUNT, 20000, null\)/);
  assert.match(request, /"GET", "\/v1\/layout"/);
  assert.match(request, /"PUT", "\/v1\/layout"/);
  assert.match(request, /accountSyncDeviceKeys\(access, job, reply\)/);
  assert.match(body(source, 'accountSyncDeviceKeys'), /accountPublishDeviceKey[\s\S]*\.revoked[\s\S]*account_keys.removeCommand/);
  const unauthorized = body(source, 'handleLayoutReply').split('if (reply.unauthorized) {')[1].split('if (reply.has_token)')[0];
  assert.match(unauthorized, /accountLock\(\)/);
  assert.doesNotMatch(unauthorized, /if \(reply.job.kind == .startup\)/);
  const owners = JSON.parse(read('docs/sync-fields.json')).ownership;
  assert.equal(owners.layout, '/v1/layout');
  assert.deepEqual(owners.records, ['deletion_history']);
  const records = body(source, 'accountSyncRecords');
  assert.doesNotMatch(records, /accountApplyHosts|materialize|reply.bytes\s*=/);
  assert.match(records, /deletionHistory/);
});

test('ISSUE-252 B bootstrap pulls and adopts records before observing local state', () => {
  const source = desktop();
  const request = body(source, source.includes('fn accountSyncRecords(') ? 'accountSyncRecords' : 'accountRequest');
  const get = request.indexOf('"GET", "/v1/sync-records"');
  const adopt = request.indexOf('account_records.bootstrap(');
  const edit = request.indexOf('account_records.deletionHistory(');
  assert.ok(get >= 0 && adopt > get && edit > adopt);
  assert.match(read('src/account_records.zig'), /pub fn bootstrap\(/);
});

test('ISSUE-252 C SSH deletion is nondestructive and every rewrite is backed up before writing', () => {
  const rewrite = body(read('src/account_records.zig'), 'rewriteHost');
  assert.match(rewrite, /if \(host == null\) return a.dupe\(u8, config\);/);
  assert.doesNotMatch(rewrite, /if \(target and/);
  const apply = body(desktop(), 'accountSyncHosts');
  assert.ok(apply.indexOf('accountBackupHostConfig(') >= 0 && apply.indexOf('accountBackupHostConfig(') < apply.indexOf('accountAppendSshFile(config, block)'));
  const backup = body(desktop(), 'accountBackupHostConfig');
  assert.match(backup, /config.*\.bak|\.bak.*config/);
  assert.match(backup, /CREATE_NEW/);
  assert.match(body(desktop(), 'accountSyncHosts'), /const output = try accountSshOutput/);
  assert.match(body(desktop(), 'accountSyncHosts'), /parseSshConfig\(output\) orelse return error.InvalidHosts/);
});

test('ISSUE-252 D retention deltas bounded batches and capacity failures are explicit', () => {
  const source = read('src/account_records.zig'), worker = read('service/worker.js');
  assert.match(source, /pub const retention_ms = 30 \* 24 \* 60 \* 60 \* 1000;/);
  assert.match(source, /pub fn prune\(/);
  assert.match(source, /pub fn delta\(/);
  assert.match(body(desktop(), 'accountSyncRecords'), /account_records.delta\(/);
  assert.match(worker, /DELETE FROM sync_records WHERE account=\? AND updated_at</);
  assert.match(worker, /records.length > 16/);
  assert.match(worker, /fail\(409, 'record_capacity'\)/);
  assert.match(worker, /server_time: Date.now\(\)/);
});

test('ISSUE-252 E activity cannot revert independent rename or favorite', () => {
  const { mergeRecord } = service();
  const record = (name, favorite, used, input, visits, stamp, fields) => ({ kind: 'session', id: '0:one', updated_at: stamp, device_id: stamp === 200 ? 'a' : 'b', deleted: false, fields, session: { kind: 'tmux', tmux_session: 'one', tmux_host: 0, workspace: 'Work', name, manual: true, favorite, used, input, visits } });
  const stamp = (updated_at, device_id) => ({ updated_at, device_id });
  const before = record('Old', false, 10, 10, [1], 100);
  const renamed = record('Renamed', true, 10, 10, [1], 200, { name: stamp(200, 'a'), manual: stamp(200, 'a'), favorite: stamp(200, 'a'), workspace: stamp(100, 'b') });
  const active = record('Old', false, 300, 300, [2], 300, { name: stamp(100, 'b'), manual: stamp(100, 'b'), favorite: stamp(100, 'b'), workspace: stamp(100, 'b') });
  for (const merged of [mergeRecord(renamed, active), mergeRecord(active, renamed)]) {
    assert.equal(merged.session.name, 'Renamed');
    assert.equal(merged.session.favorite, true);
    assert.equal(merged.session.used, 300);
    assert.equal(merged.session.input, 300);
    assert.deepEqual(Array.from(merged.session.visits), [1, 2]);
  }
  assert.equal(mergeRecord(before, renamed).session.name, 'Renamed');
  assert.match(read('src/account_records.zig'), /mergeSession/);
});

test('ISSUE-252 N token device binding rejects forged records and clock correction is visible', () => {
  const { validateRecords } = service();
  const valid = { kind: 'host', id: '0', updated_at: Date.now(), device_id: 'a', deleted: true };
  assert.equal(validateRecords([valid], 'a').length, 1);
  assert.throws(() => validateRecords([valid], 'b'), /record_device_mismatch/);
  const source = desktop(), request = body(source, 'accountSyncRecords');
  assert.match(request, /account_records.clockOffset/);
  assert.match(request, /clock_skew/);
  assert.match(body(source, 'handleLayoutReply'), /clock differs.*server time/i);
  assert.equal((request.match(/writeFileAtomicW\(path,/g) || []).length, 1);
  assert.match(source, /g_account_hosts_cache/);
  assert.match(body(source, 'accountKnownKeyHosts'), /g_account_hosts_cache.hosts/);
});


test('ISSUE-252 CI owned browser journey refocuses the verified app before guarded input', () => {
  const source = read('.claude/skills/verify-multiprompt/control.ps1');
  const press = source.slice(source.indexOf('function Press('), source.indexOf('function Type-Text('));
  const doctor = press.indexOf('Doctor');
  const focus = press.indexOf('SetForegroundWindow($script:window)');
  const wait = press.indexOf('Wait-Until');
  const guard = press.indexOf('Assert-Foreground');
  const input = press.indexOf('[VerifyNative]::Chord($Keys)');
  assert.ok(doctor >= 0 && focus > doctor && wait > focus && guard > wait && input > guard);
  assert.match(press, /GetAncestor\(\[VerifyNative\]::GetForegroundWindow\(\), 2\) -eq \$script:window/);
  const ownership = source.slice(source.indexOf('function Doctor'), source.indexOf('function Snapshot'));
  assert.match(ownership, /window ownership mismatch/);
  assert.match(ownership, /executable identity mismatch/);
});
