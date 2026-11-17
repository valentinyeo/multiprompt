import base64
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import sys
import time

root = Path(sys.argv[1])
runtime = Path(sys.argv[2])
sid = 'a1b2c3d4-2567-4000-8000-000000002567'
sources = {name: base64.b64encode((runtime / f'src/chat_connectors/{name}.py').read_bytes()).decode() for name in ('claude', 'codex')}
reader = runpy.run_path(str(runtime / 'src/chat_history_reader.py'), init_globals=dict(CONNECTOR_SOURCES=sources))
seed = runpy.run_path(str(root / '.claude/skills/verify-multiprompt/seed-profile.py'))
folder = Path.home() / '.claude/projects' / str(Path.home()).replace('/', '-')
folder.mkdir(parents=True, exist_ok=True)
rows = list(seed['source_rows'](0, sid))
(folder / (sid + '.jsonl')).write_text(''.join(json.dumps(row) + '\n' for row in rows))
(Path.home() / 'server-seed.json').write_text(json.dumps(dict(messages=len(rows), runtime=str(runtime), reader_sha256=hashlib.sha256((runtime / 'src/chat_history_reader.py').read_bytes()).hexdigest())))
subprocess.run(['tmux', 'new-session', '-d', '-s', 'live-ci', '-c', str(Path.home())], check=True)
result = reader['host_cli'](['enable', 'claude', sid, '--tmux', 'live-ci', '--cwd', str(Path.home())])
assert result['status'] == 'enabled', result
paths = reader['host_paths']('claude', sid)
config = reader['host_read'](paths['config'])
config['command'] = ['python3', '-u', str(root / 'tools/verify-server-chat/provider.py')]
reader['host_write'](paths['config'], config)
result = reader['host_start']('claude', sid)
assert result['status'] in ('started', 'already'), result
result = reader['host_send']('claude', sid, 'server seed', 'live-ci')
assert result['status'] in ('sent', 'queued', 'ok', 'accepted'), result
for _ in range(200):
    if any('Server received: server seed' in file.read_text() for file in (Path.home() / '.claude/projects').glob('*/*.jsonl')):
        break
    time.sleep(0.1)
else:
    raise RuntimeError('Real host did not persist the seeded reply')
print(json.dumps(dict(sid=sid, tmux='live-ci', home=str(Path.home()), seed=result)))
