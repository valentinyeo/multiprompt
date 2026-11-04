const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || process.cwd();
const palette = fs.readFileSync(path.join(root, 'src/command_palette.zig'), 'utf8');

test('reader expands relative home under its own login', () => {
  const script = `import ast, os, re
source = open('src/chat_history_reader.py').read()
fragment = source[source.index('def host_folder(value):'):source.index('def host_cwd(provider, sid):')]
fn = ast.parse(fragment).body[0]
ns = {'os': os, 'HOST_FOLDER': re.compile(r'[A-Za-z0-9_./~\\-]+')}
exec(compile(ast.Module(body=[fn], type_ignores=[]), '<reader>', 'exec'), ns)
print(ns['host_folder']('~/projects/sample'))
print(ns['host_folder']('/home/owner/projects/sample'))`;
  const result = spawnSync('python3', ['-c', script], { cwd: root, env: { ...process.env, HOME: '/home/reader' }, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trim().split('\n'), ['/home/reader/projects/sample', '/home/owner/projects/sample']);
});

test('resolved cwd starts the agent as its owner', () => {
  const script = `import ast, os, re, json
from pathlib import Path
from types import SimpleNamespace
source = open('src/chat_history_reader.py').read()
def extract(start, end):
    return ast.parse(source[source.index(start):source.index(end)]).body[0]
owner = extract('def conversation_owner(cwd):', 'def conversation_path(')
start = extract('def host_agent_start(provider, sid):', 'def host_agent_recorded_pid(')
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
ns = dict(Path=Path, re=re, pwd=FakePwd(), HOME=Path('/home/reader'), subprocess=FakeSubprocess(),
          host_cwd=lambda *_: '/home/owner/projects/sample', host_config=lambda *_: {},
          host_binary_name=lambda *_: 'claude', HOST_PERMISSION_MODES=(), HOST_APPEND_PROMPT='',
          host_chat_name=lambda *_: 'live-test', READER_SOURCE='synthetic')
exec(compile(ast.Module(body=[owner, start], type_ignores=[]), '<reader>', 'exec'), ns)
print(json.dumps(ns['host_agent_start']('claude', 'test'))) `;
  const result = spawnSync('python3', ['-c', script], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const command = JSON.parse(result.stdout);
  assert.deepEqual(command.slice(0, 6), ['sudo', '-n', '-H', '-u', 'owner', '--']);
  assert.ok(command.includes('/home/owner/projects/sample'));
});

test('unknown home falls back and hosted chats are excluded', () => {
  const resolver = palette.slice(palette.indexOf('fn resolveWorkspaceLiveCwd('), palette.indexOf('test "workspace live cwd'));
  assert.match(resolver, /home orelse return cwd/);
  assert.match(resolver, /startsWith\(u8, shell\.tmux_session\[0\.\.shell\.tmux_session_len\], "live-"\)/);
});

test('live launch resolves before passing cwd to host', () => {
  const start = palette.slice(palette.indexOf('fn spawnWorkspaceSessionAt('), palette.indexOf('fn workspaceFolderForNewChat('));
  assert.match(start, /const cwd = if \(live_chat\) resolveWorkspaceLiveCwd\(/);
  assert.match(start, /workspaceLaunchCommand\(program, session, cwd, host_sid/);
});
