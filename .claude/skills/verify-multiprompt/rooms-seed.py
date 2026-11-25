import base64
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import time

root = Path(sys.argv[1])
sources = {name: base64.b64encode((root / f'src/chat_connectors/{name}.py').read_bytes()).decode() for name in ('claude', 'codex')}
reader = runpy.run_path(str(root / 'src/chat_history_reader.py'), init_globals=dict(CONNECTOR_SOURCES=sources))
for name, sid in [('Alpha', 'a1b2c3d4-0534-4000-8000-000000000001'), ('Bravo', 'a1b2c3d4-0534-4000-8000-000000000002')]:
    for marker in ('AWAY534', 'RESTART534'):
        os.mkfifo(Path.home() / (sid + '-' + marker + '.fifo'), 0o600)
    session = 'rooms-' + name.lower()
    subprocess.run(['tmux', 'new-session', '-d', '-s', session, '-c', str(Path.home())], check=True)
    result = reader['host_cli'](['enable', 'claude', sid, '--tmux', session, '--cwd', str(Path.home())])
    assert result['status'] == 'enabled', result
    paths = reader['host_paths']('claude', sid)
    config = reader['host_read'](paths['config'])
    config['command'] = ['python3', '-u', str(root / '.claude/skills/verify-multiprompt/rooms-provider.py')]
    reader['host_write'](paths['config'], config)
    result = reader['host_start']('claude', sid)
    assert result['status'] in ('started', 'already'), result
    for _ in range(200):
        events = reader['message_events_page']('claude', sid, 0)['events']
        if any(entry['event'].get('kind') == 'host.status' and entry['event'].get('payload', {}).get('state') == 'ready' for entry in events):
            break
        time.sleep(0.1)
    else:
        raise RuntimeError(name + ' provider did not become ready')
    result = reader['host_send']('claude', sid, 'READY534', session)
    assert result['status'] in ('sent', 'queued', 'ok', 'accepted'), result
    print(json.dumps(dict(name=name, sid=sid, tmux=session, ready=result)))
