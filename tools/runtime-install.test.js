const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');

const harness = String.raw`
import ast, base64, contextlib, hashlib, importlib.machinery, io, json, multiprocessing, os, pathlib, stat, subprocess, tempfile
from unittest.mock import patch
root = pathlib.Path.cwd()
source = (root / 'src/chat_history_reader.py').read_text()
tree = ast.parse(source)
loader = next(n for n in tree.body if isinstance(n, ast.If) and any(isinstance(x, ast.FunctionDef) and x.name == '_select_runtime' for x in n.body))
loader = compile(ast.Module(body=loader.body[:next(i for i, n in enumerate(loader.body) if isinstance(n, ast.Try))], type_ignores=[]), '<installer>', 'exec')
home = tempfile.TemporaryDirectory()
os.environ['HOME'] = home.name
runtime = pathlib.Path(home.name) / '.multiprompt-runtime'

def bundle(label, version='1.0.0', real=False):
    ns = dict(__name__='runtime_install_test', MULTIBOT_APP_VERSION=version)
    for key, file in [('MP_SEND_SOURCE', 'mp_send.py'), ('MP_SESSIONS_SOURCE', 'mp_sessions.py')]:
        body = (root / 'src' / file).read_bytes() if real else b'#!/usr/bin/env python3\n'
        ns[key] = base64.b64encode(body + ('\nBUILD = ' + repr(label) + '\n').encode()).decode()
    if real:
        for key, file in [('MP_FRESH_SOURCE', 'mp_fresh.py'), ('MP_LAYOUT_SOURCE', 'mp_layout.mjs')]:
            ns[key] = base64.b64encode((root / 'src' / file).read_bytes()).decode()
    exec(compile(source, '<bundle>', 'exec'), ns)
    exec(loader, ns)
    return ns

def install(ns):
    return ns['_select_runtime'](ns['READER_SOURCE'].encode())

def selected():
    return (runtime / 'current').resolve(strict=True)

def pair(folder=None):
    folder = folder or selected()
    return tuple((folder / name).read_bytes().split(b'BUILD = ')[-1].strip() for name in ('mp-send', 'mp-sessions'))

old = bundle('old', '1.0.9')
new = bundle('new', '1.0.10')
`;

function run(code) {
  const result = spawnSync('python3', ['-c', harness + '\n' + code], {
    encoding: 'utf8', timeout: 60000, maxBuffer: 1024 * 1024,
    env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' },
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr + result.stdout);
}

test('partial writes and failed installs leave the complete old tool set visible', () => run(String.raw`
install(old)
before = selected()
fdopen = os.fdopen
class PartialWriter:
    def __init__(self, stream): self.stream = stream
    def __enter__(self): self.stream.__enter__(); return self
    def __exit__(self, *args): return self.stream.__exit__(*args)
    def fileno(self): return self.stream.fileno()
    def flush(self): return self.stream.flush()
    def write(self, data):
        if stat.S_IMODE(os.fstat(self.fileno()).st_mode) != 0o700 or b"BUILD =" not in data:
            return self.stream.write(data)
        self.stream.write(data[:len(data)//2])
        self.stream.flush()
        assert pair() == (b"'old'", b"'old'")
        assert selected() == before
        raise OSError('interrupted write')
def partial(fd, mode, **kwargs):
    stream = fdopen(fd, mode, **kwargs)
    return PartialWriter(stream) if mode == 'wb' else stream
with patch.object(os, 'fdopen', side_effect=partial):
    try: install(new)
    except OSError: pass
    else: raise AssertionError('write should fail')
assert pair() == (b"'old'", b"'old'")
install(new)
assert pair() == (b"'new'", b"'new'")
`));

test('every published tool has mode 0700 and durable complete bytes before any link is exposed', () => run(String.raw`
install(old)
replace, fsync = os.replace, os.fsync
synced = set()
seen = []
def sync(fd):
    st = os.fstat(fd)
    if stat.S_ISREG(st.st_mode): synced.add((st.st_dev, st.st_ino))
    return fsync(fd)
def replace_checked(src, dst, **kwargs):
    src, dst = pathlib.Path(src), pathlib.Path(dst)
    if src.is_symlink():
        target = (dst.parent / os.readlink(src)).resolve(strict=True)
        if target.is_file() and dst.name in ('mp-send', 'mp-sessions'):
            assert stat.S_IMODE(target.stat().st_mode) == 0o700
            assert target.read_bytes().endswith(b"BUILD = 'new'\n")
    elif '-mp-' in dst.name:
        st = src.stat()
        assert stat.S_IMODE(st.st_mode) == 0o700
        assert (st.st_dev, st.st_ino) in synced
        assert hashlib.sha256(src.read_bytes()).hexdigest() == dst.name[:64]
        seen.append(dst.name)
    return replace(src, dst, **kwargs)
with patch.object(os, 'fsync', side_effect=sync), patch.object(os, 'replace', side_effect=replace_checked):
    install(new)
assert len(seen) == 2
assert pair() == (b"'new'", b"'new'")
`));

test('omitted tools never expose an executable entry from another set', () => run(String.raw`
install(old)
assert not (runtime / 'multibot-feedback').exists()
assert not (runtime / 'mp-fresh').exists()
empty = dict(__name__='runtime_install_test', MULTIBOT_APP_VERSION='1.0.11')
exec(compile(source, '<empty-bundle>', 'exec'), empty)
exec(loader, empty)
install(empty)
assert not (runtime / 'mp-send').exists()
assert not (runtime / 'mp-sessions').exists()
install(bundle('restored', '1.0.12'))
assert (runtime / 'mp-send').is_file()
assert pair() == (b"'restored'", b"'restored'")
`));

test('an older or unstamped client keeps the newer set and logs the refused downgrade', () => run(String.raw`
expected = install(new)
before = selected()
mtime = (runtime / 'active.json').stat().st_mtime_ns
for ns in (old, bundle('unstamped', '0.0.0')):
    log = io.StringIO()
    with contextlib.redirect_stderr(log): result = install(ns)
    assert result == expected
    assert 'refusing older build' in log.getvalue()
    assert selected() == before
    assert (runtime / 'active.json').stat().st_mtime_ns == mtime
    assert pair() == (b"'new'", b"'new'")
`));

test('one pointer commits tools and manifests together without a missing-link window', () => run(String.raw`
install(old)
replace = os.replace
commits = []
def observe(src, dst, **kwargs):
    before = pair()
    result = replace(src, dst, **kwargs)
    after = pair()
    if pathlib.Path(dst) == runtime / 'current':
        commits.append((before, after))
        active = json.loads((runtime / 'active.json').read_text())
        assert (runtime / 'reader.py').read_bytes() == (runtime / (active['sha256'] + '.py')).read_bytes()
        assert json.loads((selected() / 'build.json').read_text())['version'] == [1, 0, 10]
    else: assert before == after
    for name in ('mp-send', 'mp-sessions', 'reader.py', 'active.json'):
        assert (runtime / name).is_file()
    return result
with patch.object(os, 'replace', side_effect=observe): install(new)
assert commits == [((b"'old'", b"'old'"), (b"'new'", b"'new'"))]
`));

test('a failure immediately before cutover leaves the old set and retry succeeds', () => run(String.raw`
install(old)
replace = os.replace
def fail(src, dst, **kwargs):
    if pathlib.Path(dst) == runtime / 'current': raise OSError('cutover interrupted')
    return replace(src, dst, **kwargs)
with patch.object(os, 'replace', side_effect=fail):
    try: install(new)
    except OSError: pass
    else: raise AssertionError('cutover should fail')
assert pair() == (b"'old'", b"'old'")
install(new)
assert pair() == (b"'new'", b"'new'")
`));

test('running sessions and sender keep their original sibling tools and reader across an upgrade', () => run(String.raw`
old = bundle('old', '1.0.9', real=True)
new = bundle('new', '1.0.10', real=True)
body = base64.b64decode(old['MP_SESSIONS_SOURCE']).decode()
hook = '''if __name__ == "__main__":
    print('ready', flush=True)
    sys.stdin.readline()
    send = load_send()
    print(send.BUILD, flush=True)
    print(send.reader_path().name, flush=True)
    sys.exit(0)
'''
assert 'if __name__ == "__main__":' in body
old['MP_SESSIONS_SOURCE'] = base64.b64encode(body.replace('if __name__ == "__main__":', hook, 1).encode()).decode()
exec(compile(source, '<bundle>', 'exec'), old)
_, info = install(old)
fresh = importlib.machinery.SourceFileLoader('pinned_fresh', str((selected() / 'mp-fresh').resolve())).load_module()
process = subprocess.Popen([str(runtime / 'mp-sessions')], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    assert process.stdout.readline().strip() == 'ready'
    install(new)
    output, error = process.communicate('\n', timeout=10)
    assert process.returncode == 0, error
    assert output.splitlines() == ['old', info['sha256'] + '.py']
    assert fresh.reader_path().name == info['sha256'] + '.py'
finally:
    if process.poll() is None:
        process.kill()
        process.communicate()
`));

test('concurrent desktops converge on the newest complete tool set', () => run(String.raw`
install(old)
def worker(ns):
    for _ in range(4): install(ns)
processes = [multiprocessing.Process(target=worker, args=(ns,)) for ns in (new, old, new, old)]
for process in processes: process.start()
while any(p.is_alive() for p in processes):
    assert pair() in ((b"'old'", b"'old'"), (b"'new'", b"'new'"))
for process in processes:
    process.join(10)
    assert process.exitcode == 0
assert pair() == (b"'new'", b"'new'")
`));

test('legacy migration never exposes a mixture of old and new tools', () => run(String.raw`
runtime.mkdir(mode=0o700)
data = old['READER_SOURCE'].encode()
digest = hashlib.sha256(data).hexdigest()
(runtime / (digest + '.py')).write_bytes(data)
(runtime / (digest + '.py')).chmod(0o600)
active = runtime / 'active.json'
active.write_text(json.dumps(dict(protocol=1, generation=old['RUNTIME_GENERATION'], sha256=digest)))
active.chmod(0o600)
for name, key in [('mp-send', 'MP_SEND_SOURCE'), ('mp-sessions', 'MP_SESSIONS_SOURCE')]:
    payload = base64.b64decode(old[key])
    target = runtime / (hashlib.sha256(payload).hexdigest() + '-' + name)
    target.write_bytes(payload)
    target.chmod(0o700)
    (runtime / name).symlink_to(target.name)
replace = os.replace
def observe(src, dst, **kwargs):
    result = replace(src, dst, **kwargs)
    paths = [runtime / name for name in ('mp-send', 'mp-sessions')]
    paths = [selected() / path.name if path.resolve().name.endswith('-entry.py') else path for path in paths]
    values = tuple(path.read_bytes().split(b'BUILD = ')[-1].strip() for path in paths)
    assert values in ((b"'old'", b"'old'"), (b"'new'", b"'new'"))
    return result
with patch.object(os, 'replace', side_effect=observe): install(new)
assert pair() == (b"'new'", b"'new'")
assert os.readlink(runtime / 'active.json') == 'current/active.json'
`));

test('an interrupted first migration can resume and still publish every bundled tool', () => run(String.raw`
new = bundle('new', '0.0.0')
replace = os.replace
failed = False
def fail(src, dst, **kwargs):
    global failed
    if pathlib.Path(dst) == runtime / 'active.json' and not failed:
        failed = True
        raise OSError('migration interrupted')
    return replace(src, dst, **kwargs)
with patch.object(os, 'replace', side_effect=fail):
    try: install(new)
    except OSError: pass
    else: raise AssertionError('migration should fail')
install(new)
assert pair() == (b"'new'", b"'new'")
assert not json.loads((selected() / 'build.json').read_text())['migrating']
`));
