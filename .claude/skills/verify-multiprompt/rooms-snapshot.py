import json
from pathlib import Path
import sqlite3

home = Path.home()
rooms = []
for path in sorted((home / '.local/state/multiprompt/rooms-accounts').glob('*/rooms.sqlite3')):
    with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        rooms.append(dict(account_digest=path.parent.name, tables={name: [dict(row) for row in db.execute('SELECT * FROM ' + name + (' ORDER BY seq' if name == 'events' else ''))] for name in ('rooms', 'members', 'events', 'deliveries')}))
input_path = home / 'provider-input.jsonl'
inputs = [json.loads(line) for line in input_path.read_text().splitlines()] if input_path.exists() else []
for entry in inputs:
    entry.setdefault('marker', None)
transcripts = {str(path.relative_to(home)): [json.loads(line) for line in path.read_text().splitlines()] for path in (home / '.claude/projects').glob('*/*.jsonl')}
hosts = []
for path in sorted((home / '.local/state/multiprompt/agent-host').glob('*.state.json')):
    state = json.loads(path.read_text())
    hosts.append(dict(file=path.name, inflight=bool(state.get('inflight')), queued=len(state.get('sends', [])), state=state))
print(json.dumps(dict(rooms=rooms, hosts=hosts, inputs=inputs, transcripts=transcripts)))
