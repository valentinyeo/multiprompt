const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || process.cwd();
const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');
const vps = fs.readFileSync(path.join(root, 'src/vps.zig'), 'utf8');

test('reader expands relative home under its own login', () => {
  const script = `from unittest.mock import patch
source = open('src/chat_history_reader.py').read()
outer = {'__name__': 'fixture'}
exec(compile(source, '<reader>', 'exec'), outer)
ns = {'__name__': 'fixture'}
exec(compile(outer['READER_SOURCE'], '<runtime>', 'exec'), ns)
with patch('os.path.isdir', return_value=False), patch('os.listdir', return_value=[]):
    print(ns['host_folder']('~/projects/sample'))
    print(ns['host_folder']('/home/owner/projects/sample'))`;
  const result = spawnSync('python3', ['-c', script], { cwd: root, env: { ...process.env, HOME: '/home/reader' }, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trim().split('\n'), ['/home/reader/projects/sample', '/home/owner/projects/sample']);
});

test('host agent environment carries app version and provider', () => {
  const script = `import json
source = open('src/chat_history_reader.py').read()
outer = {}
exec(compile(source, '<reader>', 'exec'), outer)
ns = {}
exec(compile("MULTIBOT_APP_VERSION = '1.2.3'\\n" + outer['READER_SOURCE'], '<runtime>', 'exec'), ns)
ns.update(host_config=lambda *_: {}, host_chat_name=lambda *_: '')
env = ns['host_agent_env']('codex', 'test')
print(json.dumps({key: env.get(key) for key in ('MULTIBOT_APP_VERSION', 'MULTIBOT_PROVIDER')}))`;
  const result = spawnSync('python3', ['-c', script], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), { MULTIBOT_APP_VERSION: '1.2.3', MULTIBOT_PROVIDER: 'codex' });
});

test('resolved cwd starts the agent as its owner', () => {
  const script = `import json
from pathlib import Path
from types import SimpleNamespace
source = open('src/chat_history_reader.py').read()
outer = {}
exec(compile(source, '<reader>', 'exec'), outer)
ns = {}
exec(compile(outer['READER_SOURCE'], '<runtime>', 'exec'), ns)
class FakePwd:
    def getpwnam(self, name):
        return SimpleNamespace(pw_name=name, pw_dir='/home/' + name, pw_uid=1001)
class FakeSubprocess:
    DEVNULL = PIPE = None
    SubprocessError = RuntimeError
    def run(self, command, **kwargs):
        return SimpleNamespace(returncode=0)
    def Popen(self, command, **kwargs):
        return command
ns.update(pwd=FakePwd(), HOME=Path('/home/reader'), subprocess=FakeSubprocess(),
          host_cwd=lambda *_: '/home/owner/projects/sample', host_config=lambda *_: {}, host_session_state=lambda *_: {},
          host_binary_name=lambda *_: 'claude', host_chat_name=lambda *_: 'live-test',
          READER_SOURCE=outer['READER_SOURCE'])
print(json.dumps(ns['host_agent_start']('claude', 'test'))) `;
  const result = spawnSync('python3', ['-c', script], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const command = JSON.parse(result.stdout);
  assert.deepEqual(command.slice(0, 6), ['sudo', '-n', '-H', '-u', 'owner', '--']);
  assert.ok(command.includes('/home/owner/projects/sample'));
});

test('reported project cwd takes priority over the terminal carrier', () => {
  const resolver = palette.slice(palette.indexOf('fn resolveWorkspaceLiveCwd('), palette.indexOf('test "workspace live cwd'));
  assert.match(resolver, /home orelse return cwd/);
  assert.match(resolver, /shell\.workspace != workspace\) continue[\s\S]*remoteHostForShell\(shell\) orelse continue\) != host\) continue/);
  assert.match(resolver, /const reported = if \(shell\.claude_cwd_len > 0\) workspaceHomeCandidate\(cwd, shell\.claude_cwd\[0\.\.shell\.claude_cwd_len\]\) else null;/);
  assert.match(resolver, /const candidate = reported orelse if \(live\) continue else blk: \{[\s\S]*shellKnownRemotePath\(shell, host\) orelse continue;[\s\S]*workspaceHomeCandidate\(cwd, known\) orelse continue;/);
  assert.match(resolver, /if \(i == app_state\.active_shell\) return/);
  assert.match(resolver, /if \(ambiguous\) return cwd/);
});

test('live launch resolves before passing cwd to host', () => {
  const start = palette.slice(palette.indexOf('fn spawnWorkspaceSessionAt('), palette.indexOf('fn workspaceFolderForNewChat('));
  assert.match(start, /const cwd = if \(live_chat\) resolveWorkspaceLiveCwd\(/);
  assert.match(start, /workspaceLaunchCommand\(program, session, cwd, host_sid/);
});

test('surviving shells cannot migrate roots to a new endpoint', t => {
  assert.ok(vps.includes('fn repoConfigureCache('), 'cache reconfiguration must be testable');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'repo-identity-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const row = vps.slice(vps.indexOf('pub const RepoRow = struct'), vps.indexOf('const MAX_REPO_ROWS'));
  const cache = vps.slice(vps.indexOf('const RepoStatus = enum'), vps.indexOf('var g_repo_caches:'));
  const listing = vps.slice(vps.indexOf('fn repoPathSafe('), vps.indexOf('pub fn repoRowAvailable('));
  assert.match(cache, /rows: \[REPO_CACHE_ROWS\]RepoRow = undefined,/);
  const configure = vps.slice(vps.indexOf('fn repoConfigureCache('), vps.indexOf('pub fn requestRepoRefresh('));
  const publish = vps.slice(vps.indexOf('fn repoPublish('), vps.indexOf('fn repoFetchThread('));
  const file = path.join(root, 'identity.zig');
  fs.writeFileSync(file, `const std = @import("std");
const MAX_REPO_ROWS = 8;
const REPO_CACHE_ROWS = 8;
${row}
${cache}
var g_repo_caches: [3]RepoCache = @splat(.{});
const SpinMutex = struct {
    state: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),
    fn tryLock(self: *SpinMutex) bool { return self.state.cmpxchgStrong(0, 1, .acquire, .monotonic) == null; }
    fn unlock(self: *SpinMutex) void { self.state.store(0, .release); }
};
var g_repo_mutex: SpinMutex = .{};
fn Sleep(_: u32) void {}
const app_state = struct {
    const Shell = struct { tmux_session_len: usize = 1 };
    var shells = [_]Shell{.{}};
    const shell_count = 1;
};
fn tmuxHostForShell(_: *const app_state.Shell) ?u8 { return 0; }
fn shellKnownRemotePath(_: *const app_state.Shell, _: u8) ?[]const u8 { return "/old/project"; }
fn remoteRepoRoot(path: []const u8) []const u8 { return path; }
${listing}
${configure}
${publish}
test "endpoint replacement excludes old shell but permits discovery" {
    const cache = &g_repo_caches[0];
    var rows: [8]RepoRow = @splat(.{});
    repoConfigureCache(cache, true, "old", "Old");
    try std.testing.expectEqual(@as(u32, 1), repoRowsForHost(0, &rows));
    repoConfigureCache(cache, true, "old", "Renamed");
    try std.testing.expectEqual(@as(u32, 1), repoRowsForHost(0, &rows));
    const old_generation = cache.generation;
    repoConfigureCache(cache, true, "new", "New");
    try std.testing.expect(cache.generation != old_generation);
    try std.testing.expectEqual(@as(u32, 0), repoRowsForHost(0, &rows));
    var found: [8]RepoRow = @splat(.{});
    const n = parseRepoListing(0, "/new/project", &found);
    repoPublish(cache, cache.generation, true, found[0..n]);
    try std.testing.expectEqual(@as(u32, 1), repoRowsForHost(0, &rows));
    try std.testing.expectEqualStrings("/new/project", rows[0].path[0..rows[0].path_len]);
    repoConfigureCache(cache, false, "new", "New");
    repoConfigureCache(cache, true, "new", "New");
    try std.testing.expectEqual(@as(u32, 0), repoRowsForHost(0, &rows));
}
`);
  const result = spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
