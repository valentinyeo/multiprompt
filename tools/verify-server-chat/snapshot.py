import json
from pathlib import Path
import sqlite3

home = Path.home()
with sqlite3.connect(f'file:{home}/.local/state/multiprompt/shared-messages/store.sqlite3?mode=ro', uri=True) as db:
    db.row_factory = sqlite3.Row
    tables = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)] for name in ('message_chats', 'message_resets', 'shared_messages')}
inputs = home / 'provider-input.jsonl'
hosts = home / '.local/state/multiprompt/agent-host'
configs = list(hosts.glob('*.config.json'))
state = {}
config = {}
if configs:
    config = json.loads(configs[0].read_text())
    state_path = configs[0].with_name(configs[0].name.replace('.config.json', '.state.json'))
    if state_path.is_file():
        state = json.loads(state_path.read_text())
state = {'context_session': None, 'native_session': None, **state}
print(json.dumps(dict(tables=tables, host=dict(config=config, state=state), inputs=[json.loads(line) for line in inputs.read_text().splitlines()])))
