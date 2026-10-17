import argparse
import base64
import hashlib
import json
import math
from pathlib import Path
import selectors
import shlex
import statistics
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--host', default='remote-1')
parser.add_argument('--samples', type=int, default=10)
parser.add_argument('--out', required=True)
args = parser.parse_args()
if args.samples < 10:
    parser.error('at least ten requests per mode are required')
reader = (Path(__file__).resolve().parents[1] / 'src/chat_history_reader.py').read_bytes()
ssh = ['ssh', '-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', args.host]
setup = '''import json,tempfile
from pathlib import Path
home = Path(tempfile.mkdtemp(prefix="mp-history-latency-"))
path = home / ".claude/projects/-work-demo/latency.jsonl"
path.parent.mkdir(parents=True)
with path.open("w") as output:
    for i in range(500):
        output.write(json.dumps(dict(type="assistant", message=dict(role="assistant", content="uncached request " + str(i) + " x" * 2000))) + "\\n")
print(home)
'''
result = subprocess.run(ssh + ['python3 -c ' + shlex.quote(setup)], capture_output=True, text=True, timeout=20, check=True)
home = result.stdout.strip()
if not home.startswith('/tmp/mp-history-latency-') or not home.replace('-', '').replace('/', '').isalnum():
    raise ValueError('unexpected fixture directory')
query = dict(id=1, codex=False, sid='latency', tmux='', cwd='/work/demo', cached_sid='', inode=0, offset=0)
server = None
samples = dict(one_shot_ms=[], persistent_ms=[])

def verify(wire, rid):
    lines = wire.splitlines()
    fields = lines[0].split('\t')
    assert fields[:4] == ['@mp', str(rid), 'history', 'ok'], fields
    assert fields[13] == 'tail', fields
    assert lines[-1] == '@@MP_END@@'
    assert json.loads(lines[-2])['text'].startswith('uncached request 499 ')

try:
    for rid in range(1, args.samples + 1):
        query['id'] = rid
        encoded = base64.b64encode(json.dumps(query).encode()).decode()
        start = time.perf_counter()
        reply = subprocess.run(ssh + [f'HOME={shlex.quote(home)} python3 - {encoded}'],
                               input=reader, capture_output=True, timeout=65, check=True)
        elapsed = (time.perf_counter() - start) * 1000
        verify(reply.stdout.decode(), rid)
        samples['one_shot_ms'].append(elapsed)
    start = time.perf_counter()
    bootstrap = "import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))"
    server = subprocess.Popen(ssh + [f'HOME={shlex.quote(home)} python3 -u -c {shlex.quote(bootstrap)} --serve'],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    server.stdin.write(base64.b64encode(reader) + b'\n')
    server.stdin.flush()
    for rid in range(1, args.samples + 1):
        if rid > 1:
            start = time.perf_counter()
        query['id'] = rid
        server.stdin.write(json.dumps(query).encode() + b'\n')
        server.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(server.stdout, selectors.EVENT_READ)
            if not selector.select(timeout=65):
                raise TimeoutError('persistent reader timed out')
        reply = json.loads(server.stdout.readline())
        elapsed = (time.perf_counter() - start) * 1000
        assert reply['id'] == rid
        verify(reply['wire'], rid)
        samples['persistent_ms'].append(elapsed)
    report = dict(host=args.host, samples=args.samples, uncached=True, first_persistent_includes_startup=True,
                  reader_sha256=hashlib.sha256(reader).hexdigest(), raw=samples)
    for mode, values in samples.items():
        report[mode] = dict(median=round(statistics.median(values), 2),
                            p95=round(sorted(values)[math.ceil(len(values) * .95) - 1], 2))
    Path(args.out).write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
finally:
    if server is not None:
        server.stdin.close()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=5)
        server.stdout.close()
        server.stderr.close()
    subprocess.run(ssh + ['rm -rf -- ' + shlex.quote(home)], check=True, timeout=15)
