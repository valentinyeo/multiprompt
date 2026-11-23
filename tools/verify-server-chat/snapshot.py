import json
from pathlib import Path
import sqlite3

home = Path.home()
with sqlite3.connect(f'file:{home}/.local/state/multiprompt/shared-messages/store.sqlite3?mode=ro', uri=True) as db:
    db.row_factory = sqlite3.Row
    tables = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)] for name in ('message_chats', 'message_resets', 'shared_messages')}
inputs = home / 'provider-input.jsonl'
host = None
for state in sorted((home / '.local/state/multiprompt/agent-host').glob('*.state.json')):
    try:
        saved = json.loads(state.read_text())
    except (OSError, ValueError):
        continue
    if isinstance(saved, dict) and saved.get('provider') == 'claude':
        host = saved
        break
print(json.dumps(dict(tables=tables, inputs=[json.loads(line) for line in inputs.read_text().splitlines()], host=host)))
