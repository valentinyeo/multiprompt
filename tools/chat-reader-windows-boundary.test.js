const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');

const python = String.raw`
import ast
import base64
import io
import os
from pathlib import Path
import sys
import types

path = Path('tools/verify-chat-delivery/boundary.py')
tree = ast.parse(path.read_text(encoding='utf-8'))
function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'reader_namespace')
module = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))

scenario = sys.argv[1]
slash = sys.argv[2] == 'slash'
source = '''
def start_message_worker(*args, **kwargs):
    return "worker ran"
def events_wake():
    return "original wake"
def serve_request(*args):
    return "original request"
'''
input_sys = types.SimpleNamespace(stdin=types.SimpleNamespace(buffer=io.BytesIO(base64.b64encode(source.encode()) + b'\n')), modules=sys.modules)
locks = []
seeks = []
msvcrt = types.ModuleType('msvcrt')
msvcrt.LK_UNLCK, msvcrt.LK_NBLCK, msvcrt.LK_LOCK = 0, 1, 2
msvcrt.locking = lambda fd, mode, length: locks.append((fd, mode, length))
sys.modules['msvcrt'] = msvcrt
fake_os = types.SimpleNamespace(**{**vars(os), 'name': 'nt', 'lseek': lambda *args: seeks.append(args)})
records = []
installed = []
class Loader:
    def exec_module(self, module):
        module.install = lambda namespace, *args: installed.append(module.name)
class Util:
    def spec_from_file_location(self, name, path):
        return types.SimpleNamespace(name=name, loader=Loader())
    def module_from_spec(self, spec):
        return types.SimpleNamespace(name=spec.name)
context = {'sys': input_sys, 'os': fake_os, 'importlib': types.SimpleNamespace(util=Util()), 'Path': Path, '__file__': str(path), 'ROOT': Path('.'), 'state': lambda: {'name': scenario, 'slashProof': slash}, 'record': lambda *args, **kwargs: records.append((args, kwargs))}
exec(compile(module, str(path), 'exec'), context)
namespace = context['reader_namespace']()
assert 'fcntl' in sys.modules and hasattr(sys.modules['fcntl'], 'flock'), 'Windows locking adapter missing'
fcntl = sys.modules['fcntl']
fcntl.flock(7, fcntl.LOCK_EX)
fcntl.flock(7, fcntl.LOCK_EX | fcntl.LOCK_NB)
fcntl.flock(7, fcntl.LOCK_UN)
assert locks == [(7, 2, 1), (7, 1, 1), (7, 0, 1)], locks
assert seeks == [(7, 0, os.SEEK_SET)] * 3, seeks
assert namespace['events_wake']() is None, 'poll fallback missing'
expected = None if scenario in ('instant-chat', 'startup-failure') else 'worker ran'
assert namespace['start_message_worker']() == expected, 'incorrect worker suppression'
assert ('slash_host' in installed) == slash, installed
assert any(row[1].get('notification') == 'poll fallback' for row in records), records
`;

for (const [scenario, slash] of [
  ['full-history', false],
  ['instant-chat', false],
  ['startup-failure', false],
  ['full-history', true],
  ['instant-chat', true],
]) {
  test(`Windows ${scenario}${slash ? ' with slash adapter' : ''}`, () => {
    const result = spawnSync('python3', ['-c', python, scenario, slash ? 'slash' : 'none'], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr || result.error?.message);
  });
}
