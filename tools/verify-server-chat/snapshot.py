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


print(json.dumps(dict(tables=tables, inputs=rows('provider-input.jsonl'), controls=rows('provider-control.jsonl'),
                      queued=rows('provider-queued.jsonl'),
                      provider=json.loads((home / 'provider-state.json').read_text()) if (home / 'provider-state.json').exists() else None,
                      seed=json.loads((home / 'server-seed.json').read_text()))))
