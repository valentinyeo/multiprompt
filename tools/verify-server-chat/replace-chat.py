import base64
import json
from pathlib import Path
import runpy
import sys
import time

root = Path(sys.argv[1])
runtime = Path(json.loads((Path.home() / 'server-seed.json').read_text())['runtime'])
sources = {name: base64.b64encode((runtime / f'src/chat_connectors/{name}.py').read_bytes()).decode() for name in ('claude', 'codex')}
reader = runpy.run_path(str(runtime / 'src/chat_history_reader.py'), init_globals=dict(CONNECTOR_SOURCES=sources))
old = 'a1b2c3d4-2567-4000-8000-000000002567'
new = 'a1b2c3d4-2566-4000-8000-000000002566'
old_state = reader['host_session_state']('claude', old)
old_pid = old_state['pid']
result = reader['host_cli'](['disable', 'claude', old])
assert result['status'] == 'disabled', result
assert not Path(f'/proc/{old_pid}').exists(), 'Old host is still running'
result = reader['host_cli'](['enable', 'claude', new, '--tmux', 'live-ci', '--cwd', str(Path.home())])
assert result['status'] == 'enabled', result
paths = reader['host_paths']('claude', new)
config = reader['host_read'](paths['config'])
config['command'] = ['python3', '-u', str(root / 'tools/verify-server-chat/provider.py')]
reader['host_write'](paths['config'], config)
result = reader['host_cli'](['start', 'claude', new])
assert result['status'] in ('started', 'already'), result
result = reader['host_send']('claude', new, 'fresh replacement seed', 'live-ci')
assert result['status'] in ('sent', 'queued', 'ok', 'accepted'), result
for _ in range(300):
    receipts = [json.loads(line) for line in (Path.home() / 'provider-input.jsonl').read_text().splitlines()]
    if any(row['sid'] == new and row['text'] == 'fresh replacement seed' for row in receipts):
        break
    time.sleep(0.1)
else:
    raise RuntimeError('Replacement host did not deliver its seed')
print(json.dumps(dict(old=old, new=new, oldHostPid=old_pid, oldHostGone=not Path(f'/proc/{old_pid}').exists(), tmux='live-ci')))
