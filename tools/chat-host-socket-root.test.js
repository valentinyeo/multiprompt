const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { chatHostIsolatedEnv } = require('./chat-host-test-env');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('concurrent host folder creation never raises file exists', () => {
  const program = String.raw`
import os, shutil, tempfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
SOURCE = outer['READER_SOURCE']

def socket_worker(_):
    runtime = {}
    exec(compile(SOURCE, 'runtime', 'exec'), runtime)
    return str(runtime['host_socket_root']())

def paths_worker(index):
    runtime = {}
    exec(compile(SOURCE, 'runtime', 'exec'), runtime)
    runtime['HOME'] = Path(tempfile.mkdtemp(prefix='home-'))
    provider, sid = 'claude', f'synthetic-{index}'
    runtime['host_paths'](provider, sid)
    return str(runtime['HOME'] / '.local/state/multiprompt/agent-host')

tmpdir = tempfile.mkdtemp(prefix='mp-host-race-')
os.environ['TMPDIR'] = tmpdir
os.environ['TMP'] = tmpdir
os.environ['TEMP'] = tmpdir
socket = Path(tempfile.gettempdir()) / ('mp-agent-host-' + str(os.getuid()))
if socket.exists():
    shutil.rmtree(socket)
with ProcessPoolExecutor(max_workers=12) as pool:
  roots = list(pool.map(socket_worker, range(24)))
assert len(set(roots)) == 1, roots
assert socket.is_dir() and oct(socket.stat().st_mode & 0o777) == '0o700'
with ProcessPoolExecutor(max_workers=12) as pool:
  pool.map(paths_worker, range(24))
print('host folders survived concurrent creation')
`;
  const { env } = chatHostIsolatedEnv();
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 120000, env });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /host folders survived concurrent creation/);
});