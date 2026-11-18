import json
from pathlib import Path
import platform
import sqlite3
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory(prefix='server-chat-locks-', dir=Path.home()) as folder:
    path = str(Path(folder) / 'probe.sqlite3')
    with sqlite3.connect(path) as db:
        db.execute('CREATE TABLE writes(value)')
        db.execute('INSERT INTO writes VALUES (1)')
        child = """
import sqlite3, sys
with sqlite3.connect(sys.argv[1], timeout=0) as db:
    try:
        db.execute('BEGIN IMMEDIATE')
    except sqlite3.OperationalError as error:
        if error.sqlite_errorcode != sqlite3.SQLITE_BUSY:
            raise
        print(error.sqlite_errorname)
    else:
        raise RuntimeError('The server filesystem allowed two concurrent SQLite writers')
"""
        blocked = subprocess.check_output([sys.executable, '-c', child, path], text=True).strip()
    subprocess.run([sys.executable, '-c', "import sqlite3,sys; db=sqlite3.connect(sys.argv[1]); db.execute('INSERT INTO writes VALUES (2)'); db.commit(); db.close()", path], check=True)
    with sqlite3.connect(path) as db:
        integrity = db.execute('PRAGMA integrity_check').fetchone()[0]
        writes = db.execute('SELECT COUNT(*) FROM writes').fetchone()[0]
        assert (blocked, integrity, writes) == ('SQLITE_BUSY', 'ok', 2)
    print(json.dumps(dict(kernel=platform.release(), blockedWriter=blocked, integrity=integrity, writes=writes)))
