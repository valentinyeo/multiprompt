import json
from pathlib import Path
import sqlite3

home = Path.home()
with sqlite3.connect(f'file:{home}/.local/state/multiprompt/shared-messages/store.sqlite3?mode=ro', uri=True) as db:
    db.row_factory = sqlite3.Row
    tables = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)] for name in ('message_chats', 'message_resets', 'shared_messages')}
inputs = home / 'provider-input.jsonl'
fixture = json.loads((home / 'server-chat-fixture.json').read_text())
with (home / fixture['path']).open(encoding='utf-8') as source:
    fixture['transcriptMessages'] = sum(1 for line in source if line.strip())
print(json.dumps(dict(tables=tables, inputs=[json.loads(line) for line in inputs.read_text().splitlines()], fixture=fixture)))
