const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const read = file => fs.readFileSync(new URL('../' + file, 'file://' + __filename), 'utf8');
const desktop = read('src/account_desktop.zig');

function section(source, name) {
  const start = source.indexOf('fn ' + name + '(');
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\nfn ', start + 3);
  const publicEnd = source.indexOf('\npub fn ', start + 3);
  return source.slice(start, Math.min(...[end, publicEnd, source.length].filter(x => x >= 0)));
}

function audit(source) {
  const publish = section(source, 'accountPublishDeviceKey');
  assert.match(publish, /GetEnvironmentVariableA\("USERPROFILE"/);
  assert.match(publish, /ssh-keygen\.exe\\" -t ed25519 -N \\"\\" -q -C multiprompt -f/);
  assert.match(publish, /GetFileAttributesW\(private_w\.ptr\)/);
  assert.match(publish, /else if \(!has_public\) return error.IncompleteKeyPair/);
  assert.match(publish, /readFileAllocWin32\(public_path, 4096\)/);
  assert.doesNotMatch(publish, /readFileAllocWin32\(private_path/);
  assert.match(publish, /account_keys.parsePublicKey\(a, bytes\)/);
  assert.match(publish, /\.\{ \.public_key = key \}/);
  assert.match(publish, /request\("PUT", "\/v1\/device-key", access, body\)/);
  const sync = section(source, 'accountSyncDeviceKeys');
  assert.ok(sync.indexOf('try accountPublishDeviceKey(') < sync.indexOf('request("GET", "/v1/device-keys"'));
  assert.match(sync, /key.status == \.pending and std.mem.eql\(u8, key.device_id, decision.device_id\) and std.mem.eql\(u8, key.public_key, decision.public_key\)/);
  assert.match(sync, /if \(!current\) return error.DeviceChanged/);
  assert.match(sync, /if \(aliases.len == 0\)/);
  assert.match(sync, /try accountRunKeyCommand\(a, ssh, aliases, try account_keys.addCommand/);
  assert.ok(sync.indexOf('try accountRunKeyCommand(a, ssh, aliases, try account_keys.addCommand(') < sync.indexOf('request("POST", path'));
  assert.match(sync, /"\/v1\/device-keys\/\{s\}\/\{s\}"/);
  assert.match(sync, /if \(decision.approve\) "approve" else "deny"/);
  assert.match(sync, /key.status != \.revoked or account_keys.isCleaned\(state.items, key.public_key\)/);
  assert.ok(sync.indexOf('account_keys.removeCommand(') < sync.indexOf('writeDpapiFile("account-keys-cleaned.dat"'));
  assert.match(sync, /try accountRunKeyCommand\(a, ssh, aliases, try account_keys.removeCommand/);
  const remote = section(source, 'accountRunKeyCommand');
  assert.match(remote, /-o BatchMode=yes -o ConnectTimeout=10/);
  assert.match(remote, /accountSshOutput\(a, command, 30000\) catch \|err\|/);
  assert.match(remote, /Could not update SSH access on \{s\}/);
  assert.match(remote, /return err/);
  const prompt = section(source, 'accountPromptDeviceKeys');
  assert.match(prompt, /key.status != \.pending or std.mem.eql\(u8, key.device_id, listing.value.device_id\)/);
  assert.match(prompt, /Approve this device\? \{s\} asks to reach your servers\./);
  assert.match(prompt, /app_state.g_account_busy = true/);
  assert.match(prompt, /if \(answer != 6 and answer != 7\) continue/);
  assert.match(prompt, /\.approve = answer == 6/);
  assert.match(prompt, /startAccountJob\(\.\{ \.kind = \.decide_keys, \.edited = encoded \}\)/);
  assert.doesNotMatch(prompt, /accountSshOutput|account_client.request/);
  assert.doesNotMatch(section(source, 'accountRequest'), /MessageBoxW/);
  assert.match(section(source, 'handleLayoutReply'), /accountPromptDeviceKeys\(bytes\)/);
  assert.match(section(source, 'accountRequest'), /accountSyncDeviceKeys\(access, job, reply\)/);
  assert.match(section(source, 'layoutSyncWorker'), /accountRequest\(job, reply\)/);
  assert.match(section(source, 'startAccountJob'), /std.Thread.spawn\(\.\{\}, layoutSyncWorker/);
}

test('device-key transport, worker SSH, UI decisions and durable cleanup fail closed', () => {
  audit(desktop);
  for (const [before, after] of [
    ['readFileAllocWin32(public_path, 4096)', 'readFileAllocWin32(private_path, 4096)'],
    ['"PUT", "/v1/device-key"', '"PUT", "/v1/device-keys"'],
    ['if (!current) return error.DeviceChanged;', ''],
    ['try accountRunKeyCommand(a, ssh, aliases, try account_keys.addCommand', 'accountRunKeyCommand(a, ssh, aliases, try account_keys.addCommand'],
    ['try accountRunKeyCommand(a, ssh, aliases, try account_keys.removeCommand', 'accountRunKeyCommand(a, ssh, aliases, try account_keys.removeCommand'],
    ['if (answer != 6 and answer != 7) continue;', ''],
    ['key.status != .pending or std.mem.eql(u8, key.device_id, listing.value.device_id)', 'false'],
    ['key.status != .revoked or account_keys.isCleaned(state.items, key.public_key)', 'false'],
    ['-o BatchMode=yes -o ConnectTimeout=10', '-o ConnectTimeout=1'],
  ]) {
    assert.ok(desktop.includes(before), before);
    assert.throws(() => audit(desktop.replace(before, after)), before);
  }
});
