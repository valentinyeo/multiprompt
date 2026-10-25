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
  assert.match(publish, /else if \(!has_public\) return error.MissingPublicKey/);
  assert.match(publish, /readFileAllocWin32\(public_path, 4096\)/);
  assert.doesNotMatch(publish, /readFileAllocWin32\(private_path/);
  assert.match(publish, /account_keys.parsePublicKey\(a, bytes\)/);
  assert.match(publish, /\.\{ \.public_key = key \}/);
  assert.match(publish, /request\("PUT", "\/v1\/device-key", access, body\)/);
  const sync = section(source, 'accountSyncDeviceKeys');
  assert.ok(sync.indexOf('accountPublishDeviceKey(') < sync.indexOf('request("GET", "/v1/device-keys"'));
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
  assert.match(section(source, 'handleLayoutReply'), /accountPromptDeviceKeys\(bytes, reply.job.kind == \.device_keys\)/);
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

function auditBackground(source) {
  const errors = section(source, 'accountDeviceKeyError');
  assert.match(errors, /if \(!account_keys\.syncPolicy\(reply\.job\.kind, 0, null, null, null\)\.show_error or reply\.key_error != null\) return;/);
  const sync = section(source, 'accountSyncDeviceKeys');
  assert.match(sync, /const policy = account_keys\.syncPolicy\(job\.kind, now, g_account_keys_cache\.last_check_ms, null, null\);/);
  assert.match(sync, /if \(policy\.check\) g_account_keys_cache\.last_check_ms = now;/);
  assert.match(sync, /if \(!policy\.check\) return;/);
  assert.ok(sync.indexOf('g_account_keys_cache.last_check_ms = now') < sync.indexOf('accountPublishDeviceKey('));
  assert.ok(sync.indexOf('if (!policy.check) return;') < sync.indexOf('request("GET", "/v1/device-keys"'));
  assert.ok(sync.indexOf('if (!policy.check) return;') < sync.indexOf('accountKnownKeyHosts('));
  assert.match(sync, /if \(err == error\.MissingPublicKey\) accountDeviceKeyError\(reply, "The public key file id_ed25519.pub is missing next to your private key\."\);/);
  const publish = section(source, 'accountPublishDeviceKey');
  assert.match(publish, /if \(!account_keys\.syncPolicy\(job_kind, 0, null, g_account_keys_cache\.published_key, key\)\.publish\) return;/);
  assert.ok(publish.indexOf('.publish) return;') < publish.indexOf('request("PUT"'));
  assert.match(publish, /if \(result\.status != 200\) return error\.PublishKey;/);
  assert.match(publish, /g_account_keys_cache\.published_key = published;/);
  assert.ok(publish.indexOf('if (result.status != 200) return error.PublishKey;') < publish.indexOf('g_account_keys_cache.published_key = published;'));
  assert.match(publish, /else if \(!has_public\) return error\.MissingPublicKey;/);
  const prompt = section(source, 'accountPromptDeviceKeys');
  assert.match(prompt, /if \(g_account_key_prompt_active or app_state\.g_account_busy\) return;/);
  assert.match(prompt, /g_account_key_prompt_active = true;/);
  assert.ok(prompt.indexOf('g_account_key_prompt_active = true;') < prompt.indexOf('MessageBoxW('));
  assert.match(prompt, /defer if \(!submitted\) \{\s*g_account_key_prompt_active = false;\s*app_state\.g_account_busy = false;/);
  assert.match(prompt, /submitted = app_state\.g_account_busy;/);
  assert.match(section(source, 'startAccountJob'), /if \(g_account_key_prompt_active and job\.kind != \.decide_keys\)/);
  const reply = section(source, 'handleLayoutReply');
  assert.match(reply, /if \(lp == 0\) \{\s*g_account_key_prompt_active = false;/);
  assert.match(reply, /if \(reply\.job\.kind == \.decide_keys\) g_account_key_prompt_active = false;/);
}

test('background keys throttle failed attempts, publish only on change or explicit request, and serialize Cancel/decision rounds', () => {
  auditBackground(desktop);
  for (const [before, after] of [
    ['!account_keys.syncPolicy(reply.job.kind, 0, null, null, null).show_error or ', ''],
    ['if (policy.check) g_account_keys_cache.last_check_ms = now;', ''],
    ['if (!policy.check) return;', ''],
    ['if (!account_keys.syncPolicy(job_kind, 0, null, g_account_keys_cache.published_key, key).publish) return;', ''],
    ['if (result.status != 200) return error.PublishKey;', ''],
    ['else if (!has_public) return error.MissingPublicKey;', ''],
    ['if (err == error.MissingPublicKey) accountDeviceKeyError', 'if (false) accountDeviceKeyError'],
    ['if (g_account_key_prompt_active or app_state.g_account_busy) return;', ''],
    ['g_account_key_prompt_active = true;', ''],
    ['submitted = app_state.g_account_busy;', 'submitted = true;'],
    ['g_account_key_prompt_active and job.kind != .decide_keys', 'false'],
    ['if (reply.job.kind == .decide_keys) g_account_key_prompt_active = false;', ''],
  ]) {
    assert.ok(desktop.includes(before), before);
    assert.throws(() => auditBackground(desktop.replace(before, after)), before);
  }
});

test('ISSUE-451 executed production replies keep background approvals non-modal and explicit Cancel quiet', () => {
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'account-device-keys-'));
  try {
    require('./zig-copy').copyZig(['account_keys.zig'], dir);
    const prompt = section(desktop, 'accountPromptDeviceKeys');
    const reply = section(desktop, 'handleLayoutReply');
    const begin = reply.indexOf('    defer {\n        if (reply.key_error)');
    const end = reply.indexOf('    if (reply.signed_out)', begin);
    assert.ok(begin >= 0 && end > begin);
    const dispatch = reply.slice(begin, end);
    assert.match(dispatch, /accountPromptDeviceKeys\(bytes, reply.job.kind == \.device_keys\)/);
    const fixture = `const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
` + read('tools/account-device-keys-fixture.zig');
    const deliver = `fn deliver(kind: AccountJobKind, payload: []const u8, unauthorized: bool, cancelled: bool) void {
    g_account_busy = false;
    if (kind == .decide_keys) g_account_key_prompt_active = false;
    const reply: LayoutReply = .{ .job = .{ .kind = kind }, .device_keys = payload, .unauthorized = unauthorized, .cancelled = cancelled };
    ${dispatch}
}`;
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, (fixture + '\n' + (prompt + '\n' + deliver).replaceAll('app_state.', '')).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'ISSUE-451'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
    const backgroundModal = dispatch.replace('reply.job.kind == .device_keys', 'true');
    assert.notEqual(backgroundModal, dispatch);
    fs.writeFileSync(file, (fixture + '\n' + (prompt + '\n' + deliver.replace(dispatch, backgroundModal)).replaceAll('app_state.', '')).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const negative = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'ISSUE-451'], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0);
    assert.match(negative.stderr, /background pending device replies[^]*FAIL/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
