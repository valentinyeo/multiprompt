const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

function section(source, name) {
  const start = source.indexOf('fn ' + name + '(');
  if (start < 0) return '';
  const end = source.indexOf('\nfn ', start + 3);
  return source.slice(start, end < 0 ? source.length : end);
}

function prepare(source) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'account-hosts-'));
  require('./zig-copy').copyZig(['account_hosts.zig', 'session_layout.zig', 'account_layout.zig'], dir);
  const request = section(source, 'accountRequest');
  const tail = request.slice(request.indexOf('    var remote = try account_client.request("GET", "/v1/layout"'));
  let production = section(source, 'accountSyncHosts') + '\n' + section(source, 'accountApplyHostAddresses') + '\n' +
    'fn accountRequest(job: AccountJob, reply: *LayoutReply) !void {\n    const a = std.heap.page_allocator;\n    const access = "fixture";\n' + tail;
  production = production.replaceAll('app_state.', '')
    .replaceAll('@import("console.zig").appendSshExe', 'appendSshExe')
    .replaceAll('@import("file_io.zig").win32WidePath', 'win32WidePath')
    .replaceAll('@import("win32.zig").GetSystemTimeAsFileTime', 'GetSystemTimeAsFileTime')
    .replace(/const kernel = struct \{\s*extern "kernel32" fn CopyFileW\([^;]+;\s*\};/, 'const kernel = FakeKernel;');
  const file = path.join(dir, 'test.zig');
  fs.writeFileSync(file, fs.readFileSync(path.join(__dirname, 'account-hosts-fixture.zig'), 'utf8') + '\n' + production);
  return { dir, file, cleanup: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

function build(source) {
  const fixture = prepare(source);
  const exe = path.join(fixture.dir, process.platform === 'win32' ? 'client.exe' : 'client');
  const result = spawnSync(process.env.ZIG || 'zig', ['build-exe', fixture.file, '-OReleaseSafe', '-femit-bin=' + exe], { encoding: 'utf8', timeout: 120000 });
  if (result.status !== 0) {
    fixture.cleanup();
    throw new Error(result.stdout + result.stderr);
  }
  return { ...fixture, run(input) {
    const result = spawnSync(exe, [JSON.stringify(input)], { encoding: 'utf8', timeout: 10000 });
    if (result.status !== 0) throw new Error(result.stdout + result.stderr);
    return JSON.parse(result.stdout);
  } };
}

module.exports = { prepare, build };
