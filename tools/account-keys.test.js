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
  assert.match(sync, /key.status == \.pending and std.mem.eql\(u8, key.device_id, decision.device_id\) and std.mem.eql\(u8, key.public_key, decision.public_key\) and !std.mem.eql\(u8, key.device_id, listing.value.device_id\)/);
  assert.match(sync, /const name = device_name orelse return error.DeviceChanged/);
  assert.match(sync, /if \(aliases.len == 0\)/);
  assert.match(sync, /const outcome = try accountRunKeyCommand\(a, ssh, aliases, try account_keys.addCommand/);
  assert.ok(sync.indexOf('try accountRunKeyCommand(a, ssh, aliases, try account_keys.addCommand(') < sync.indexOf('request("POST", path'));
  assert.match(sync, /"\/v1\/device-keys\/\{s\}\/\{s\}"/);
  assert.match(sync, /if \(decision.approve\) "approve" else "deny"/);
  assert.match(sync, /key.status != \.revoked or account_keys.isCleaned\(state.items, key.public_key\)/);
  assert.ok(sync.indexOf('account_keys.removeCommand(') < sync.indexOf('writeDpapiFile("account-keys-cleaned.dat"'));
  assert.match(sync, /const outcome = try accountRunKeyCommand\(a, ssh, aliases, try account_keys.removeCommand\(a, key.public_key\), reply\);\s*if \(!outcome.complete\) continue;/);
  const hosts = section(source, 'accountKnownKeyHosts');
  assert.match(hosts, /SSH_TARGET_DE, app_state.SSH_TARGET_UK, app_state.SSH_TARGET_INNE/);
  assert.match(hosts, /if \(!account_hosts.shouldImport\(alias, resolved\)\) try aliases.append\(a, alias\)/);
  const remote = section(source, 'accountRunKeyCommand');
  assert.match(remote, /-o BatchMode=yes -o ConnectTimeout=10/);
  assert.match(remote, /_ = try accountSshOutput\(self.a, command, 30000\)/);
  assert.match(remote, /const rollout = account_keys.applyOnHosts\(aliases, &runner\)/);
  assert.match(remote, /if \(!rollout.reachedAny\(\)\) \{\s*accountDeviceKeyError\(reply, "Could not update SSH access on any host\./);
  assert.match(remote, /complete = rollout.complete\(\)/);
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

test('confirmed partial approvals name the device and skipped servers', () => {
  const sync = section(desktop, 'accountSyncDeviceKeys');
  const confirmed = sync.indexOf('if (decided.status != 200) return error.DecideKey;');
  const notice = sync.indexOf('approved on reachable servers. Could not reach:');
  assert.ok(confirmed >= 0 && notice > confirmed, 'named partial notice must follow API confirmation');
  assert.match(sync, /\{ if \(old\) \|bytes\| bytes else "", name, skipped \}/);
  assert.match(sync, /skipped = outcome.skipped;/);
});

test('device-key transport, worker SSH, UI decisions and durable cleanup fail closed', () => {
  audit(desktop);
  for (const [before, after] of [
    ['readFileAllocWin32(public_path, 4096)', 'readFileAllocWin32(private_path, 4096)'],
    ['"PUT", "/v1/device-key"', '"PUT", "/v1/device-keys"'],
    ['const name = device_name orelse return error.DeviceChanged;', 'const name = "unknown";'],
    ['try accountRunKeyCommand(a, ssh, aliases, try account_keys.addCommand', 'accountRunKeyCommand(a, ssh, aliases, try account_keys.addCommand'],
    ['try accountRunKeyCommand(a, ssh, aliases, try account_keys.removeCommand', 'accountRunKeyCommand(a, ssh, aliases, try account_keys.removeCommand'],
    ['if (answer != 6 and answer != 7) continue;', ''],
    ['key.status != .pending or std.mem.eql(u8, key.device_id, listing.value.device_id)', 'false'],
    ['key.status != .revoked or account_keys.isCleaned(state.items, key.public_key)', 'false'],
    ['-o BatchMode=yes -o ConnectTimeout=10', '-o ConnectTimeout=1'],
    ['if (!rollout.reachedAny()) {', 'if (false) {'],
    ['complete = rollout.complete()', 'complete = true'],
    ['if (!outcome.complete) continue;', ''],
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
  assert.match(prompt, /prior.status == \.pending and std.mem.eql\(u8, prior.device_id, key.device_id\) and std.mem.eql\(u8, prior.public_key, key.public_key\)/);
  assert.match(prompt, /if \(seen\) continue;/);
  assert.match(prompt, /defer if \(previous_bytes\) \|old\| std.heap.page_allocator.free\(old\);/);
  assert.match(prompt, /g_account_key_prompt_active = true;/);
  assert.ok(prompt.indexOf('g_account_key_prompt_active = true;') < prompt.indexOf('MessageBoxW('));
  assert.match(prompt, /defer if \(!submitted\) \{\s*g_account_key_prompt_active = false;\s*app_state\.g_account_busy = false;/);
  assert.match(prompt, /submitted = app_state\.g_account_busy;/);
  assert.match(section(source, 'startAccountJob'), /if \(g_account_key_prompt_active and job\.kind != \.decide_keys\)/);
  const reply = section(source, 'handleLayoutReply');
  assert.match(reply, /if \(lp == 0\) \{\s*@import\("room_frontend\.zig"\)\.setAccount\(null\);\s*g_account_key_prompt_active = false;/);
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
    ['if (seen) continue;', ''],
    ['g_account_key_prompt_active = true;', ''],
    ['submitted = app_state.g_account_busy;', 'submitted = true;'],
    ['g_account_key_prompt_active and job.kind != .decide_keys', 'false'],
    ['if (reply.job.kind == .decide_keys) g_account_key_prompt_active = false;', ''],
  ]) {
    assert.ok(desktop.includes(before), before);
    assert.throws(() => auditBackground(desktop.replace(before, after)), before);
  }
});

test('IGSH-1635 login resets the device-key session cache', () => {
  const request = section(desktop, 'accountRequest');
  const auth = request.indexOf('if (response.status != 200) {');
  const failure = request.indexOf('return error.Authentication;', auth);
  const match = /if \(job\.kind == \.login\) \{\s*if \(g_account_keys_cache\.published_key\) \|old\| std\.heap\.page_allocator\.free\(old\);\s*g_account_keys_cache\.published_key = null;\s*g_account_keys_cache\.last_check_ms = null;\s*\}/.exec(request);
  assert.ok(match, 'login must reset the device-key cache');
  assert.ok(auth >= 0 && failure > auth && match.index > failure);
  assert.ok(match.index < request.indexOf('accountSyncDeviceKeys('));
  assert.match(request.slice(auth, match.index), /return error\.Authentication;\s*\}/);

  const js = match[0]
    .replace('job.kind == .login', "job.kind === 'login'")
    .replace('if (g_account_keys_cache.published_key) |old| std.heap.page_allocator.free(old);',
      'if (g_account_keys_cache.published_key !== null) std.heap.page_allocator.free(g_account_keys_cache.published_key);');
  const reset = new Function('job', 'g_account_keys_cache', 'std', js);
  const key = 'existing-public-key';
  const cache = { published_key: key, last_check_ms: 1000 };
  const freed = [];
  const std = { heap: { page_allocator: { free: old => freed.push(old) } } };
  const run = (kind, status) => { if (status === 200) reset({ kind }, cache, std); };
  run('pull', 200);
  run('login', 401);
  assert.deepEqual(cache, { published_key: key, last_check_ms: 1000 });
  assert.deepEqual(freed, []);
  run('login', 200);
  assert.deepEqual(cache, { published_key: null, last_check_ms: null });
  assert.deepEqual(freed, [key]);
  run('login', 200);
  assert.deepEqual(freed, [key]);

  const policy = read('src/account_keys.zig');
  assert.match(policy, /\.check = explicit or decision or last_check_ms == null or now_ms -\| last_check_ms\.\? >= 5 \* 60 \* 1000/);
  assert.match(policy, /\.publish = if \(current_key\) \|key\| explicit or last_published_key == null or !std\.mem\.eql\(u8, last_published_key\.\?, key\) else false/);
  const publish = section(desktop, 'accountPublishDeviceKey');
  assert.ok(publish.indexOf('g_account_keys_cache.published_key, key).publish) return;') >= 0);
  assert.ok(publish.indexOf('g_account_keys_cache.published_key, key).publish) return;') < publish.indexOf('request("PUT", "/v1/device-key"'));
  assert.equal(cache.last_check_ms === null, true);
  assert.equal(cache.published_key === null, true);
});

test('IGSH-1657 executed production replies prompt on discovery and allow explicit retry', () => {
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
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'IGSH-1657'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 3 tests passed/);
    const backgroundModal = dispatch.replace('reply.job.kind == .device_keys', 'true');
    assert.notEqual(backgroundModal, dispatch);
    fs.writeFileSync(file, (fixture + '\n' + (prompt + '\n' + deliver.replace(dispatch, backgroundModal)).replaceAll('app_state.', '')).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const negative = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'IGSH-1657'], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0);
    assert.match(negative.stderr, /discovery Cancel and explicit retry[^]*FAIL/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('IGSH-1635 hosted Zig session cache lifecycle', { skip: process.env.GITHUB_ACTIONS !== 'true' }, () => {
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const request = section(desktop, 'accountRequest');
  const start = request.indexOf('    if (response.status != 200) {');
  const resetStart = request.indexOf('    if (job.kind == .login) {', start);
  const end = request.indexOf('    if (@import("room_frontend.zig")', resetStart);
  assert.ok(start >= 0 && resetStart > start && end > resetStart);
  const guard = request.slice(start, resetStart);
  const reset = request.slice(resetStart, end);
  assert.match(guard, /return error\.Authentication;/);
  assert.match(reset, /g_account_keys_cache\.last_check_ms = null;/);
  const fixture = `const real = @import("std");
const account_keys = @import("account_keys.zig");
var frees: usize = 0;
const std = struct {
    const heap = struct {
        const page_allocator = struct {
            fn free(bytes: []u8) void {
                frees += 1;
                real.heap.page_allocator.free(bytes);
            }
        };
    };
};
const Kind = enum { login, pull, device_keys, decide_keys };
const account_state = struct {
    fn invalidCredential(status: u16, _: []const u8) bool { return status == 401; }
};
var g_account_keys_cache: struct { published_key: ?[]u8 = null, last_check_ms: ?u64 = null } = .{};
const Reply = struct { unauthorized: bool = false };
fn acceptedSession(job: struct { kind: Kind }, response: struct { status: u16, bytes: []const u8 }, reply: *Reply) !void {
${guard}${reset}}
var registrations: usize = 0;
fn pull(now: u64, key: ?[]const u8) !void {
    const policy = account_keys.syncPolicy(Kind.pull, now, g_account_keys_cache.last_check_ms, null, null);
    if (policy.check) g_account_keys_cache.last_check_ms = now;
    const public = key orelse return;
    if (!account_keys.syncPolicy(Kind.pull, now, null, g_account_keys_cache.published_key, public).publish) return;
    registrations += 1;
    if (g_account_keys_cache.published_key) |old| real.heap.page_allocator.free(old);
    g_account_keys_cache.published_key = try real.heap.page_allocator.dupe(u8, public);
}
test "IGSH-1635 session reset and registration" {
    const t = real.testing;
    const key = "same public bytes";
    var reply: Reply = .{};
    defer if (g_account_keys_cache.published_key) |old| real.heap.page_allocator.free(old);
    try pull(1000, key);
    try t.expectEqual(@as(usize, 1), registrations);
    try t.expectError(error.Authentication, acceptedSession(.{ .kind = .login }, .{ .status = 401, .bytes = "" }, &reply));
    try t.expect(reply.unauthorized);
    try t.expectEqual(@as(?u64, 1000), g_account_keys_cache.last_check_ms);
    try t.expectEqualStrings(key, g_account_keys_cache.published_key.?);
    try t.expectEqual(@as(usize, 0), frees);
    try acceptedSession(.{ .kind = .login }, .{ .status = 200, .bytes = "" }, &reply);
    try t.expectEqual(@as(usize, 1), frees);
    try t.expect(g_account_keys_cache.published_key == null and g_account_keys_cache.last_check_ms == null);
    try pull(1001, key);
    try t.expectEqual(@as(usize, 2), registrations);
    try t.expectEqualStrings(key, g_account_keys_cache.published_key.?);
    try pull(301001, key);
    try t.expectEqual(@as(usize, 2), registrations);
    try acceptedSession(.{ .kind = .pull }, .{ .status = 200, .bytes = "" }, &reply);
    try t.expectEqual(@as(usize, 1), frees);
    try t.expectEqualStrings(key, g_account_keys_cache.published_key.?);
    try acceptedSession(.{ .kind = .login }, .{ .status = 200, .bytes = "" }, &reply);
    try t.expectEqual(@as(usize, 2), frees);
    try acceptedSession(.{ .kind = .login }, .{ .status = 200, .bytes = "" }, &reply);
    try t.expectEqual(@as(usize, 2), frees);
    try pull(301002, null);
    try t.expect(g_account_keys_cache.published_key == null);
    try pull(301003, key);
    try t.expectEqual(@as(usize, 3), registrations);
    try t.expectEqualStrings(key, g_account_keys_cache.published_key.?);
}`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'account-session-keys-'));
  try {
    require('./zig-copy').copyZig(['account_keys.zig'], dir);
    const file = path.join(dir, 'test.zig');
    const run = source => {
      fs.writeFileSync(file, source);
      return spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'IGSH-1635'], { encoding: 'utf8', timeout: 120000 });
    };
    const result = run(fixture);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 1 tests passed/);
    const negative = run(fixture.replace(reset, '    _ = job;\n'));
    assert.notEqual(negative.status, 0);
    assert.match(negative.stderr, /IGSH-1635 session reset and registration[^]*FAIL/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
