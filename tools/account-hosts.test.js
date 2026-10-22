const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const read = file => fs.readFileSync(new URL('../' + file, 'file://' + __filename), 'utf8');

function section(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}
function audit(desktop) {
  const request = section(desktop, 'accountRequest');
  const discovery = section(desktop, 'accountSyncHosts');
  assert.match(request, /if \(!job.sync or job.edited == null\) return;/);
  assert.equal((request.match(/accountSyncHosts\(/g) || []).length, 1);
  assert.match(desktop, /if \(app_state.g_account_busy or app_state.g_account_bypass\)/);
  assert.match(desktop, /std.Thread.spawn\(\.\{\}, layoutSyncWorker/);
  assert.match(discovery, /app_state\.SSH_TARGET_DE, app_state\.SSH_TARGET_UK, app_state\.SSH_TARGET_INNE/);
  assert.match(discovery, /appendSshExe\(/);
  assert.match(discovery, /-G \{s\}/);
  assert.match(discovery, /const output = try accountSshOutput\(a, command, 5000\)/);
  assert.match(discovery, /parseSshConfig\(output\) orelse return error.HostDiscovery/);
  assert.match(discovery, /if \(account_hosts.shouldImport\(alias, resolved\)\) continue/);
  assert.doesNotMatch(discovery, /host_keys|known_hosts|readKeys|keygen/);
  assert.match(desktop, /CreateProcessW\(null, cmd_z.ptr, null, null, 1, 0x08000000/);
  assert.match(desktop, /GetTickCount64\(\) \+ timeout_ms/);
  const apply = section(desktop, 'accountApplyHosts');
  assert.match(apply, /return error.HostConfigChanged/);
  assert.match(apply, /account_records.rewriteHost/);
  assert.match(apply, /writeFileAtomicW\(path, config\)/);
  assert.ok(request.indexOf('account_records.roundTrip(') < request.indexOf('accountApplyHosts('));
  assert.ok(request.indexOf('accountSyncHosts(') < request.indexOf('"PUT", "/v1/sync-records"'));
}

test('ISSUE-252 host discovery is worker-serialized bounded key-free and failed resolution is not deletion', () => {
  const desktop = read('src/account_desktop.zig');
  audit(desktop);
  for (const [before, after] of [
    ['const output = try accountSshOutput(a, command, 5000)', 'const output = accountSshOutput(a, command, 5000)'],
    ['parseSshConfig(output) orelse return error.HostDiscovery', 'parseSshConfig(output) orelse continue'],
    ['if (account_hosts.shouldImport(alias, resolved)) continue', 'if (false) continue'],
    ['1, 0x08000000, null, null, &si, &pi', '1, 0, null, null, &si, &pi'],
    ['return error.HostConfigChanged', 'return'],
    ['writeFileAtomicW(path, config)', 'true'],
  ]) {
    assert.ok(desktop.includes(before), before);
    assert.throws(() => audit(desktop.replace(before, after)), before);
  }
});

test('ISSUE-252 legacy host feature negotiation remains fail-closed for other API clients', () => {
  const client = read('src/account_client.zig');
  assert.match(client, /hosts_supported: bool = false/);
  assert.match(client, /hosts_supported = layoutSupportsHosts\(raw\);/);
  assert.match(client, /X-Layout-Features: favorite,used,visits,input,settings,hosts\\r\\n/);
  const worker = read('service/worker.js');
  assert.match(worker, /url.pathname === '\/v1\/layout'/);
  assert.match(worker, /layoutFeature\(request, 'hosts'\)/);
});
