import json
from pathlib import Path
import sqlite3

home = Path.home()
with sqlite3.connect(f'file:{home}/.local/state/multiprompt/shared-messages/store.sqlite3?mode=ro', uri=True) as db:
    db.row_factory = sqlite3.Row
    tables = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)] for name in ('message_chats', 'message_resets', 'shared_messages', 'message_events')}


def rows(name):
    path = home / name
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


hosts = []
for path in (home / '.local/state/multiprompt/agent-host').glob('*.state.json'):
    state = json.loads(path.read_text())
    host = {key: state.get(key) for key in ('provider', 'sid', 'native_session', 'context_session', 'tmux', 'pid')}
    host['alive'] = isinstance(host['pid'], int) and Path(f'/proc/{host["pid"]}').exists()
    host['freshPhase'] = (state.get('fresh_start') or {}).get('phase')
    hosts.append(host)

print(json.dumps(dict(hosts=hosts, tables=tables, inputs=rows('provider-input.jsonl'), controls=rows('provider-control.jsonl'),
                      received=rows('provider-received.jsonl'), queued=rows('provider-queued.jsonl'), discarded=rows('provider-discarded.jsonl'),
                      provider=json.loads((home / 'provider-state.json').read_text()) if (home / 'provider-state.json').exists() else None,
                      seed=json.loads((home / 'server-seed.json').read_text()))))
