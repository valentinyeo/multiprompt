const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || process.cwd();
const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');

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
          host_cwd=lambda *_: '/home/owner/projects/sample', host_config=lambda *_: {},
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
  assert.match(resolver, /if \(ambiguous\) return null/);
});

test('live launch resolves before passing cwd to host', () => {
  const start = palette.slice(palette.indexOf('fn spawnWorkspaceSessionAt('), palette.indexOf('fn workspaceFolderForNewChat('));
  assert.match(start, /const cwd = if \(live_chat\) resolveWorkspaceLiveCwd\(/);
  assert.match(start, /workspaceLaunchCommand\(program, session, cwd, host_sid/);
});
