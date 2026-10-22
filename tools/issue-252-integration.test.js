const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
function body(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
function audit(state, desktop, main) {
  assert.match(state, /g_account_sync_enabled = false;/);
  const publish = body(desktop, 'publishSessionLayout');
  assert.match(publish, /if \(!app_state\.g_account_sync_enabled or/);
  assert.match(publish, /account-layout-pending\.json/);
  assert.match(publish, /\.saved_at = syncNow\(\)/);
  assert.match(publish, /writeFileAtomicW\(path, pending\)/);
  assert.match(body(desktop, 'accountArmTimer'), /if \(app_state\.g_account_sync_enabled and !app_state\.g_account_bypass\)/);
  assert.match(body(desktop, 'pullSessionLayout'), /if \(!app_state\.g_account_sync_enabled or app_state\.g_account_bypass\) return;/);
  assert.match(body(desktop, 'accountToggleSync'), /writeFileAtomicW\(path, if \(enabled\)/);
  assert.match(body(desktop, 'accountBootstrap'), /account-sync\.json/);
  assert.match(body(desktop, 'accountBootstrap'), /startAccountJob\(\.\{ \.kind = \.startup \}\)/);
  const request = body(desktop, 'accountRequest');
  const disabled = request.indexOf('if (!job.sync or job.edited == null) return;');
  assert.ok(disabled > 0);
  assert.ok(disabled < request.indexOf('accountSyncHosts('));
  assert.ok(disabled < request.indexOf('"/v1/sync-records"'));
  assert.doesNotMatch(request.slice(disabled), /accountSyncDeviceKeys|known_hosts|host_keys|IdentityFile|\/v1\/layout/);
  assert.match(request, /if \(std\.mem\.eql\(u8, parsed\.value\.account, &scope\)\) state = parsed\.value/);
  assert.ok(request.indexOf('writeFileAtomicW(path, pending)') < request.indexOf('account_client.request("GET", "/v1/sync-records"'));
  const put = request.indexOf('account_client.request("PUT", "/v1/sync-records"');
  const get = request.indexOf('account_client.request("GET", "/v1/sync-records"', put);
  const proof = request.indexOf('account_records.roundTrip(');
  assert.ok(put > 0 && get > put && proof > get);
  assert.ok(request.indexOf('accountApplyHosts(') > proof);
  assert.ok(request.lastIndexOf('reply.bytes =') > proof);
  assert.doesNotMatch(request, /state\.local = desired/);
  assert.match(body(desktop, 'accountApplyHosts'), /if \(!std\.mem\.eql\(u8, current orelse "", original\)\) return error.HostConfigChanged/);
  assert.match(body(desktop, 'accountSyncHosts'), /const output = try accountSshOutput/);
  assert.doesNotMatch(body(desktop, 'accountSyncHosts'), /host_keys|known_hosts|keygen|readKeys/);
  assert.doesNotMatch(state + desktop + main, /TIMER_ACCOUNT_SAVE/);
  assert.match(main, /wp == TIMER_ACCOUNT\) \{\s*_ = KillTimer\(hwnd, TIMER_ACCOUNT\);\s*pullSessionLayout\(\)/);
  assert.match(body(desktop, 'handleLayoutReply'), /accountArmTimer\(if \(app_state\.g_account_retry\.notified\)/);
}

test('ISSUE-252 opt in privacy durable journal readback and single disabled-safe timer contracts', () => {
  const state = read('src/app_state.zig'), desktop = read('src/account_desktop.zig'), main = read('src/main.zig');
  audit(state, desktop, main);
  assert.throws(() => audit(state.replace('g_account_sync_enabled = false;', 'g_account_sync_enabled = true;'), desktop, main));
  for (const [before, after] of [
    ['if (!job.sync or job.edited == null) return;', ''],
    ['try account_records.roundTrip(alloc, state.records, documents.value.records);', ''],
    ['if (std.mem.eql(u8, parsed.value.account, &scope)) state = parsed.value;', 'state = parsed.value;'],
    ['if (app_state.g_account_sync_enabled and !app_state.g_account_bypass)', 'if (true)'],
    ['const output = try accountSshOutput', 'const output = accountSshOutput'],
  ]) {
    assert.ok(desktop.includes(before), before);
    assert.throws(() => audit(state, desktop.replace(before, after), main), before);
  }
});

test('ISSUE-252 original implementation fails the opt-in and privacy contract', () => {
  const original = file => execFileSync('git', ['show', `daf2435:${file}`], { encoding: 'utf8', cwd: path.join(__dirname, '..') });
  assert.throws(() => audit(original('src/app_state.zig'), original('src/account_desktop.zig'), original('src/main.zig')), /g_account_sync_enabled/);
  const old = body(original('src/account_desktop.zig'), 'accountSyncHosts');
  assert.match(old, /host_keys/);
  assert.throws(() => assert.doesNotMatch(old, /host_keys|known_hosts/));
});

test('ISSUE-252 palette F1 documentation and changelog expose the same opt-in action', () => {
  for (const file of ['src/command_palette.zig', 'src/sidebar.zig', 'src/shortcuts.zig', 'openwiki/operations/keyboard-shortcuts.md']) assert.ok(read(file).includes('Sync between laptops'), file);
  assert.match(read('src/main.zig'), /target == SEARCH_LAPTOP_SYNC_OFFSET[\s\S]*?accountToggleSync\(\)/);
  assert.match(read('src/sidebar.zig'), /L\("Sync between laptops: ON"\).*L\("Sync between laptops: OFF"\)/);
  assert.match(read('src/shortcuts.zig'), /off by default/);
  assert.ok(read('changelog.d/IGSH-252-laptop-sync.md').includes('SSH keys, passwords and window positions'));
  const core = read('src/account_records.zig');
  assert.match(core, /pub const poll_ms = 180000;/);
  assert.match(core, /\.device_id, b\.device_id\) == \.gt/);
  assert.match(core, /\.deleted = true/);
  assert.match(read('service/worker.js'), /ON CONFLICT\(account,kind,id\) DO UPDATE/);
  assert.match(read('service/schema.sql'), /PRIMARY KEY \(account,kind,id\)/);
});
