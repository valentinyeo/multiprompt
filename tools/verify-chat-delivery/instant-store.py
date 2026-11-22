import json
from pathlib import Path
import sqlite3
import sys

path = Path(sys.argv[1])
rows = []
if path.exists():
    with sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True, timeout=2) as db:
        db.row_factory = sqlite3.Row
        rows = [dict(row) for row in db.execute('SELECT id,text,position,state FROM shared_messages ORDER BY position')]
print(json.dumps(rows))
