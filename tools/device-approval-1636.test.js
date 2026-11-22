const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const desktop = read('src/account_desktop.zig');
const fixture = 'tools/fixtures/IGSH-1636/';

function section(source, name) {
  const start = source.indexOf('fn ' + name + '(');
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\nfn ', start + 3);
  const publicEnd = source.indexOf('\npub fn ', start + 3);
  return source.slice(start, Math.min(...[end, publicEnd, source.length].filter(n => n >= 0)));
}

test('IGSH-1636 production rollout, decisions and retry boundaries', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'device-approval-'));
  try {
    require('./zig-copy').copyZig(['account_keys.zig', 'account_hosts.zig'], dir);
    fs.writeFileSync(path.join(dir, 'console.zig'), 'pub fn appendSshExe(buf: []u8, len: *usize) bool { const s = "ssh "; @memcpy(buf[0..s.len], s); len.* = s.len; return true; }\n');
    const request = section(desktop, 'accountRequest');
    const begin = request.indexOf('    if (job.kind == .device_keys or job.kind == .decide_keys) {');
    const end = request.indexOf('\n    var remote =', begin);
    assert.ok(begin >= 0 && end > begin);
    const boundary = 'fn requestDeviceKeys(job: AccountJob, reply: *LayoutReply) void {\n    const access: []const u8 = "";\n' + request.slice(begin, end) + '\n}\n';
    const source = read(fixture + 'fixture.zig') + '\n' + section(desktop, 'accountDeviceKeyError') + '\n' + section(desktop, 'accountSyncDeviceKeys') + '\n' + boundary + '\n' + section(desktop, 'accountRunKeyCommand');
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, source);
    const current = spawnSync(process.env.ZIG || 'zig', ['test', file, '--test-filter', 'IGSH-1636'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(current.status, 0, current.stdout + current.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('IGSH-1636 native notice is explicit and guarded', () => {
  const reply = section(desktop, 'handleLayoutReply');
  const start = reply.indexOf('    if (reply.job.kind == .decide_keys) {');
  const end = reply.indexOf('    if (reply.job.kind == .device_keys) return;', start);
  assert.ok(start >= 0 && end > start);
  const dispatch = reply.slice(start, end);
  assert.match(dispatch, /if \(reply\.key_error == null and !reply\.cancelled and !reply\.unauthorized\)/);
  assert.match(dispatch, /if \(reply\.bytes\) \|notice\|/);
  assert.match(dispatch, /showSyncMessage\(notice, false\)/);
  assert.match(dispatch, /return;/);
  assert.equal((reply.match(/showSyncMessage\(notice, false\)/g) || []).length, 1);
  assert.ok(reply.indexOf('if (reply.cancelled) {') < start);
  assert.ok(reply.indexOf('if (reply.unauthorized) {') < start);
});
