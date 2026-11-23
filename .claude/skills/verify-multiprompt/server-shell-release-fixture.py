import base64
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time

root = Path(sys.argv[1])
folder = Path.home() / 'shell-proof-folder'
folder.mkdir(exist_ok=True)
subprocess.run(['tmux', 'new-session', '-d', '-s', 'proof-shell', '-c', str(folder)], check=True)
subprocess.run(['tmux', 'set-option', '-g', 'status', 'off'], check=True)
subprocess.run(['tmux', 'set-option', '-g', 'mouse', 'off'], check=True)
source = '''import json, os, time
from pathlib import Path
root = Path.home()
print('\\x1b[2J\\x1b[HSOFT3001-COPY-EXACT', flush=True)
try:
    while True:
        (root / 'shell-heartbeat.tmp').write_text(json.dumps(dict(pid=os.getpid(), tick=time.monotonic_ns(), columns=os.get_terminal_size().columns)))
        (root / 'shell-heartbeat.tmp').replace(root / 'shell-heartbeat.json')
        time.sleep(0.1)
except KeyboardInterrupt:
    (root / 'shell-interrupt.json').write_text(json.dumps(dict(pid=os.getpid(), interrupted=True)))
    print('SOFT3001 INTERRUPTED', flush=True)
'''
(Path.home() / 'shell-proof.py').write_text(source)
sid = 'a1b2c3d4-2567-4000-8000-000000002567'
sources = {name: base64.b64encode((root / f'src/chat_connectors/{name}.py').read_bytes()).decode() for name in ('claude', 'codex')}
reader = runpy.run_path(str(root / 'src/chat_history_reader.py'), init_globals=dict(CONNECTOR_SOURCES=sources))
reader['host_stop']('claude', sid)
reader['host_cli'](['enable', 'claude', sid, '--tmux', 'live-ci', '--cwd', str(folder)])
started = reader['host_start']('claude', sid)
assert started['status'] in ('started', 'already'), started
sent = reader['host_send']('claude', sid, 'shell folder proof', 'live-ci')
assert sent['status'] in ('sent', 'queued', 'ok', 'accepted'), sent
for _ in range(200):
    if any('Server received: shell folder proof' in file.read_text() for file in (Path.home() / '.claude/projects').glob('*/*.jsonl')):
        break
    time.sleep(0.1)
else:
    raise RuntimeError('Server chat in the proof folder did not become ready')
print(json.dumps(dict(folder=str(folder), sid=sid, shell='proof-shell')))
