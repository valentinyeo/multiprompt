import ast
import base64
import json
import os
from pathlib import Path
import re
import runpy
import sqlite3
import sys
import types
import uuid


ROOT = Path(os.environ['MP_VERIFY_STATE'])
if os.environ.get('GITHUB_ACTIONS') != 'true' or os.name != 'nt':
    raise RuntimeError('Hosted Windows fixture only')


def room_request():
    source = base64.b64decode(sys.stdin.buffer.readline()).decode('utf-8')
    bridge_source = base64.b64decode(sys.stdin.buffer.readline()).decode('utf-8')
    digest = sys.stdin.buffer.readline().decode('ascii').strip()
    if re.fullmatch('[0-9a-f]{64}', digest) is None:
        raise RuntimeError('Invalid account scope')
    request = json.loads(sys.stdin.buffer.readline())
    service = types.ModuleType('room_service')
    sys.modules['room_service'] = service
    exec(compile(source, 'room_service.py', 'exec'), service.__dict__)
    bridge_module = types.ModuleType('room_bridge')
    exec(compile(bridge_source, 'room_bridge.py', 'exec'), bridge_module.__dict__)
    constructor = next(node for node in ast.walk(ast.parse(source))
                       if isinstance(node, ast.FunctionDef) and node.name == '__init__'
                       and any(isinstance(child, ast.Attribute) and child.attr == 'executescript' for child in ast.walk(node)))
    schemas = [ast.literal_eval(node.args[0]) for node in ast.walk(constructor)
               if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == 'executescript']
    if len(schemas) != 1:
        raise RuntimeError('Room schema fixture is ambiguous')
    directory = ROOT / ('account-' + digest)
    directory.mkdir(exist_ok=True)
    store = service.RoomStore.__new__(service.RoomStore)
    store.db = sqlite3.connect(directory / 'rooms.sqlite3', timeout=30, isolation_level=None)
    store.db.row_factory = sqlite3.Row
    store.db.execute('PRAGMA foreign_keys=ON')
    store.db.executescript(schemas[0])
    store.db.execute('INSERT OR IGNORE INTO meta VALUES (?,?)', ('host_uuid', str(uuid.uuid4())))
    store.host_uuid = store.db.execute("SELECT value FROM meta WHERE key='host_uuid'").fetchone()[0]
    bridge = bridge_module.RoomBridge.__new__(bridge_module.RoomBridge)
    bridge.store = store
    bridge_module.host_status = lambda sid: dict(status='ok', provider='claude', sid=sid, enabled=True, owner='host', alive=True)
    if hasattr(bridge_module, 'scoped_runtime'):
        bridge_module.scoped_runtime = lambda: False
    try:
        try:
            response = dict(ok=True, result=bridge.execute(request))
        except service.RoomError as error:
            response = dict(ok=False, error=error.code)
        if request.get('op') == 'status' and response.get('ok') and re.fullmatch('[A-Za-z0-9_-]{1,80}', request.get('sid', '')):
            (ROOT / ('status-' + request['sid'] + '.json')).write_text('{}', encoding='utf-8')
        rows = []
        for row in store.db.execute('SELECT id,name,revision FROM rooms ORDER BY creation_seq'):
            rows.append(dict(row, members=store.members(row['id']), events=[json.loads(event[0]) for event in
                store.db.execute('SELECT body FROM events WHERE room_id=? ORDER BY seq', (row['id'],))]))
        witness = dict(rooms=rows, boundaries=['SSH and provider availability stand in', 'POSIX ownership is not verified on Windows'])
        temporary = ROOT / ('witness-' + uuid.uuid4().hex + '.json')
        temporary.write_text(json.dumps(witness), encoding='utf-8')
        os.replace(temporary, ROOT / 'witness.json')
        print(service.encoded(response), flush=True)
    finally:
        store.close()
    return 0


if sys.argv[1] == 'ssh' and 'room_service' in ' '.join(sys.argv[2:]):
    sys.exit(room_request())
runpy.run_path(str(Path(__file__).resolve().parents[1] / 'verify-chat-delivery' / 'boundary.py'), run_name='__main__')
