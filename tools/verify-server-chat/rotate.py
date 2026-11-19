import base64
import json
from pathlib import Path
import runpy
import sys
import time

root = Path(sys.argv[1])
sid = 'a1b2c3d4-2567-4000-8000-000000002567'
sources = {name: base64.b64encode((root / f'src/chat_connectors/{name}.py').read_bytes()).decode() for name in ('claude', 'codex')}
reader = runpy.run_path(str(root / 'src/chat_history_reader.py'), init_globals=dict(CONNECTOR_SOURCES=sources))
before = reader['host_session_state']('claude', sid)
runtime = reader['host_published_runtime']()
if runtime is None:
    raise RuntimeError('App did not publish the host rotation runtime')
paths = reader['host_paths']('claude', sid)
log_start = paths['log'].stat().st_size if paths['log'].exists() else 0
result = reader['host_restart']('claude', sid)
deadline = time.monotonic() + 20
while True:
    after = reader['host_session_state']('claude', sid)
    stderr = paths['errors'].read_text() if paths['errors'].exists() else ''
    restarted = before.get('started') != after.get('started') and reader['host_owned']('claude', sid)
    if restarted or 'NameError' in stderr or result.get('status') not in ('restarted', 'restarting') or time.monotonic() >= deadline:
        break
    time.sleep(0.1)
with paths['log'].open('rb') as stream:
    stream.seek(log_start)
    events = [json.loads(line) for line in stream if line.strip()]
rotations = [event for event in events if event.get('event') == 'rotate']
print(json.dumps(dict(result=result, runtime=runtime, before=before, after=after,
                     rotations=rotations, stderr=stderr,
                     passed=restarted
                     and len(rotations) == 1 and rotations[0]['detail']['generation'] == reader['RUNTIME_GENERATION']
                     and 'NameError' not in stderr)))
