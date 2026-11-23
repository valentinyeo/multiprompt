const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('host folders that appear after the existence check are reused', () => {
  const program = String.raw`
import os, pathlib, sys, tempfile
from pathlib import Path

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)

scratch = tempfile.mkdtemp(prefix='mp-host-race-')
os.environ['TMPDIR'] = scratch
tempfile.tempdir = None
socket = r['host_socket_root']()
assert socket.is_dir() and oct(socket.stat().st_mode & 0o777) == '0o700', socket

r['HOME'] = Path(tempfile.mkdtemp(prefix='home-'))
folder = r['HOME'] / '.local/state/multiprompt/agent-host'
folder.mkdir(mode=0o700, parents=True)

gone = {str(socket), str(folder)}
real_is_dir = pathlib.Path.is_dir

def raced(self):
    if str(self) in gone and sys._getframe(1).f_code.co_name in ('host_socket_root', 'host_paths'):
        return False
    return real_is_dir(self)

pathlib.Path.is_dir = raced
try:
    assert r['host_socket_root']() == socket
    paths = r['host_paths']('claude', 'synthetic-race')
finally:
    pathlib.Path.is_dir = real_is_dir

assert paths['root'] == folder and paths['socket'].parent == socket
assert folder.is_dir() and oct(folder.stat().st_mode & 0o777) == '0o700'
print('host folders reused after they appear')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /host folders reused after they appear/);
});
