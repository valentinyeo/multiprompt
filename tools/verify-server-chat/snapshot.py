import json
from pathlib import Path
import re
import sqlite3

home = Path.home()
with sqlite3.connect(f'file:{home}/.local/state/multiprompt/shared-messages/store.sqlite3?mode=ro', uri=True) as db:
    db.row_factory = sqlite3.Row
    tables = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)] for name in ('message_chats', 'message_resets', 'shared_messages')}
inputs = home / 'provider-input.jsonl'
transcript_rows = []
for path in (home / '.claude/projects').glob('*/*.jsonl'):
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get('type') != 'user':
            continue
        content = row.get('message', {}).get('content')
        if isinstance(content, str) and '<command-name>' in content:
            transcript_rows.append(dict(uuid=row.get('uuid'), content=content))
print(json.dumps(dict(tables=tables, inputs=[json.loads(line) for line in inputs.read_text().splitlines()], commands=transcript_rows)))