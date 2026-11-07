const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

const script = String.raw`
import ast, base64, json, pathlib, queue, signal, subprocess, sys, tempfile, threading, types
root = pathlib.Path(sys.argv[1])
source = (root / 'tools/verify-chat-delivery/boundary.py').read_text(encoding='utf-8')
adapter = next(node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == 'transport_reader')
ssh = next(node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name == 'ssh')
broker = (root / 'src/chat_transport.py').read_text(encoding='utf-8')
main = next(node for node in ast.parse(broker).body if isinstance(node, ast.If) and isinstance(node.test, ast.Compare))
registered = []
minimal_signal = types.SimpleNamespace(SIGTERM=15, signal=lambda event, handler: registered.append(event))
exec(compile(ast.Module(body=[main.body[0]], type_ignores=[]), '<signal-registration>', 'exec'), dict(signal=minimal_signal, sys=sys))
assert registered == [15], registered
prefix = '''import base64,importlib.util,json,os as real_os,re,shlex,subprocess,sys,time,types
from pathlib import Path
os = types.SimpleNamespace(name='nt',environ=real_os.environ,getpid=real_os.getpid,pathsep=real_os.pathsep)
if not hasattr(subprocess,'CREATE_NO_WINDOW'): subprocess.CREATE_NO_WINDOW=0
ROOT = Path(__file__).parent
MODE = sys.argv[1]
ARGS = ['python3','-u','-c',"'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))'"]
def state(): return {}
def declined_remote(args): return None
def record(*args, **kwargs): pass
def serve_reader():
    assert base64.b64decode(sys.stdin.buffer.readline()) == b'fixture-reader'
    for line in sys.stdin.buffer:
        value=json.loads(line)
        if value.get('exit'): return
        if value.get('hold'):
            while not Path(__file__).with_suffix('.release').exists(): time.sleep(0.01)
        print(json.dumps(dict(id=value['id'],value=value.get('value'),watch='--watch' in sys.argv)),flush=True)
def watch_reader(): serve_reader()
'''
with tempfile.TemporaryDirectory() as folder:
    fixture = pathlib.Path(folder) / 'fixture_boundary.py'
    fixture.write_text(prefix + '\n' + ast.unparse(adapter) + '\n' + ast.unparse(ssh) + "\nif __name__ == '__main__': sys.exit(ssh())\n")
    child = subprocess.Popen([sys.executable, '-u', str(fixture), 'ssh'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    replies = queue.Queue()
    def receive():
        for line in child.stdout: replies.put(json.loads(line))
        replies.put(None)
    threading.Thread(target=receive, daemon=True).start()
    def next_reply():
        value = replies.get(timeout=15)
        assert value is not None, child.stderr.read().decode() + ''.join(file.read_text(encoding='utf-8') for file in pathlib.Path(folder).glob('reader-*.stderr.log'))
        return value
    def send(channel, value, watch=False):
        child.stdin.write((json.dumps(dict(channel=channel, data=json.dumps(value), watch=watch)) + '\n').encode())
        child.stdin.flush()
    def page(channel):
        value = next_reply()
        assert value['channel'] == channel, value
        return json.loads(value['data'])
    try:
        child.stdin.write(base64.b64encode(broker.encode()) + b'\n' + base64.b64encode(b'fixture-reader') + b'\n')
        child.stdin.flush()
        assert next_reply() == dict(ready=True)
        send(1, dict(id=7, value='history', hold=True), watch=True)
        send(2, dict(id=7, value='message'))
        assert page(2) == dict(id=7, value='message', watch=False)
        fixture.with_suffix('.release').touch()
        assert page(1) == dict(id=7, value='history', watch=True)
        child.stdin.write(b'{"channel":1,"close":true}\n')
        child.stdin.flush()
        text = '\u96ea' * 100000
        send(2, dict(id=8, value=text))
        assert page(2) == dict(id=8, value=text, watch=False)
        send(3, dict(id=9, exit=True))
        assert next_reply() == dict(channel=3, closed=True)
        send(2, dict(id=10, value='survived'))
        assert page(2)['value'] == 'survived'
        child.stdin.close()
        assert child.wait(timeout=15) == 0, child.stderr.read().decode()
        assert not child.stderr.read(), 'adapter wrote errors'
    finally:
        if child.poll() is None:
            child.kill()
            child.wait()
print('TRANSPORT_BOUNDARY_PASS')
`;

test('Windows-safe fake host preserves real logical channel routing and reader bootstraps', () => {
  const source = fs.readFileSync(path.join(root, 'tools/verify-chat-delivery/boundary.py'), 'utf8');
  assert.match(source, /def transport_reader\(/);
  assert.match(source, /entry = "transport_reader"/);
  assert.match(source, /entry = "watch_reader" if value\.get\("watch"\) else "serve_reader"/);
  const result = execFileSync('python3', ['-I', '-c', script, root], { encoding: 'utf8', timeout: 45000 });
  assert.match(result, /TRANSPORT_BOUNDARY_PASS/);
});
