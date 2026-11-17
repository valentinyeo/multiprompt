import ast
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys
import time
import uuid

ROOT = Path(os.environ['MP_ROOMS_FIXTURE'])
SOURCE = Path(__file__).resolve().parents[3] / 'src'


def load(name, source=None):
    import types
    module = types.ModuleType(name)
    module.__file__ = str(SOURCE / (name + '.py'))
    sys.modules[name] = module
    exec(compile(source or (SOURCE / (name + '.py')).read_bytes(), module.__file__, 'exec'), module.__dict__)
    return module


def open_store(service):
    store = object.__new__(service.RoomStore)
    store.db = sqlite3.connect(str(ROOT / 'rooms.sqlite3'), timeout=30, isolation_level=None)
    store.db.row_factory = sqlite3.Row
    store.db.execute('PRAGMA foreign_keys=ON')
    store.host_uuid = store.db.execute("SELECT value FROM meta WHERE key='host_uuid'").fetchone()[0]
    return store


def seed():
    ROOT.mkdir(parents=True, exist_ok=False)
    service = load('room_service')
    tree = ast.parse((SOURCE / 'room_service.py').read_text())
    store_class = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == 'RoomStore')
    initializer = next(node for node in store_class.body if isinstance(node, ast.FunctionDef) and node.name == '__init__')
    schema = next(node.args[0].value for node in ast.walk(initializer) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == 'executescript')
    db = sqlite3.connect(str(ROOT / 'rooms.sqlite3'))
    db.executescript(schema)
    host = str(uuid.uuid4())
    db.execute('INSERT INTO meta VALUES (?,?)', ('host_uuid', host))
    db.commit()
    db.close()
    store = open_store(service)
    members = [dict(alias='agent_' + hashlib.sha256(f'rooms-agent-{i:02d}'.encode()).hexdigest()[:24], display_name=f'Rooms agent {i:02d}', host_uuid=host, provider='claude', provider_sid=f'rooms-agent-{i:02d}', session_identity=f'claude:rooms-agent-{i:02d}') for i in range(32)]
    rooms = []
    for index in range(12):
        created = store.execute(dict(op='create', command_id=str(uuid.uuid4()), name=f'Rooms history {index:02d}', members=members[:2]))
        room = created['event']['room_id']
        rooms.append(dict(id=room, name=f'Rooms history {index:02d}', events=1201 if index == 0 else 25))
        active = store.members(room)
        for turn in range(400 if index == 0 else 8):
            body = f'Synthetic room {index:02d} turn {turn:04d}. ' + ('Generated planning detail. ' * (80 if turn % 7 == 0 else 8))
            if turn % 11 == 0:
                body += '\n```python\nprint("generated fixture")\n```\n| Item | Count |\n| --- | --- |\n| Synthetic | 42 |'
            posted = store.execute(dict(op='post_human', command_id=str(uuid.uuid4()), room_id=room, expected_revision=1, text=body, recipients=[]))
            for member in reversed(active):
                store.execute(dict(op='agent_reply', command_id=str(uuid.uuid4()), room_id=room, parent_event_id=posted['event']['id'], member_id=member['id'], response_id=str(uuid.uuid4()), text=f'{member["display_name"]} reply to {turn:04d}. ' + body))
    store.db.execute("INSERT INTO reply_progress SELECT id,3,id,'[]',1,0 FROM deliveries")
    manifest = dict(rooms=rooms, candidateCount=32, events=store.db.execute('SELECT COUNT(*) FROM events').fetchone()[0], largestRoomEvents=1201, synthetic=True, boundary='Production RoomStore and RoomBridge methods; Windows SQLite opener replaces POSIX ownership checks. Synthetic account and SSH/AI runtime. Not real SSH, authentication, paid agents, or POSIX storage-security proof.')
    (ROOT / 'manifest.json').write_text(json.dumps(manifest))
    tabs = [dict(kind='tmux', name=m['display_name'], tmux_session=m['provider_sid'], tmux_host=0, workspace='Work') for m in members]
    layout = dict(schema=1, revision=1, workspaces=[dict(name='Work'), dict(name='Notes')], tabs=tabs, hosts=[dict(slot=0, name='Rooms fixture', hostname='127.0.0.1', port=22, user='fixture')])
    (ROOT / 'layout.json').write_text(json.dumps(layout))
    cached = [dict(t, workspace=0, ai_agent=1, csid=m['provider_sid'], sync_owned=True) for t, m in zip(tabs, members)]
    (ROOT / 'session.json').write_text(json.dumps(dict(active_tab=0, single_window=True, tabs=cached, workspaces=[dict(name='Work'), dict(name='Notes')])))
    store.close()
    print(json.dumps(manifest))


def inspect():
    store = open_store(load('room_service'))
    result = []
    for row in store.db.execute('SELECT * FROM rooms ORDER BY creation_seq'):
        room = dict(row)
        room['members'] = store.members(room['id'])
        room['events'] = [json.loads(event[0]) for event in store.db.execute('SELECT body FROM events WHERE room_id=? ORDER BY seq', (room['id'],))]
        result.append(room)
    print(json.dumps(result))
    store.close()


def ssh():
    args = ' '.join(sys.argv[2:])
    if 'room_service' not in args:
        if '-G' in sys.argv[2:]:
            print('hostname 127.0.0.1\nuser fixture\nport 22')
        elif 'list-sessions' in args or '@@LS_OK@@' in args:
            for i in range(32):
                print(f'@@S rooms-agent-{i:02d}\n@@I rooms-agent-{i:02d}|1700000000:4242:${i}')
            print('@@LS_OK@@\n@@MP_LIVE@@')
        elif '-tt' in sys.argv[2:] or 'attach' in args or 'host connect' in args:
            print('Rooms synthetic agent transport', flush=True)
            sys.stdin.buffer.read()
        return
    import base64
    service = load('room_service', base64.b64decode(sys.stdin.buffer.readline()))
    bridge = load('room_bridge', base64.b64decode(sys.stdin.buffer.readline()))
    digest = sys.stdin.buffer.readline().decode().strip()
    if len(digest) != 64:
        raise ValueError('Missing account scope')
    bridge.RoomStore = lambda directory: open_store(service)
    bridge.host_status = lambda sid: dict(status='ok', provider='claude', sid=sid, enabled=True, owner='host', alive=True, tmux=sid)
    submitted = {}

    def runtime(query):
        op = query['op']
        if op == 'engine_info':
            return dict(room_message_protocols=[1])
        if op == 'message_status':
            return dict(result=dict(seq=0))
        if op == 'message_submit':
            submitted[query['sid']] = query
            return dict(result=dict(message=dict(id=query['message_id'])))
        if op == 'events_subscribe':
            message = submitted.get(query['sid'])
            if message is None:
                return dict(result=dict(events=[], next_after=query['after']))
            common = dict(sid=query['sid'], room_scope=message['room_scope'], message_id=message['message_id'], turn=message['message_id'])
            events = [dict(seq=1, event=dict(common, kind='turn.started', payload=dict(message_id=message['message_id']))), dict(seq=2, event=dict(common, kind='text.done', item='reply', payload=dict(text=f'Synthetic reply from {query["sid"]}: {message["text"][:160]}'))), dict(seq=3, event=dict(common, kind='turn.ended', payload=dict(status='completed')))]
            if message['text'].endswith('ROOMS CONTINUE WHILE AWAY'):
                clock = ROOT / (message['message_id'] + '.started')
                if not clock.exists():
                    clock.write_text(str(time.time()))
                if time.time() - float(clock.read_text()) < 5:
                    return dict(result=dict(events=[row for row in events[:1] if row['seq'] > query['after']], next_after=max(1, query['after'])))
            return dict(result=dict(events=[row for row in events if row['seq'] > query['after']], next_after=3))
        raise ValueError('Unexpected runtime operation ' + op)

    bridge.runtime_request = runtime
    execute = bridge.RoomBridge.execute

    def observed_execute(self, request):
        result = execute(self, request)
        if request.get('op') == 'post_human' and request.get('text') == 'ROOMS CONTINUE WHILE AWAY':
            time.sleep(2)
        if request.get('op') == 'snapshot' and request.get('metadata'):
            target = ROOT / (request['room_id'] + '.metadata.json')
            temporary = target.with_suffix('.' + uuid.uuid4().hex + '.tmp')
            temporary.write_text(json.dumps(dict(memberCount=len(result['members']))))
            temporary.replace(target)
        if request.get('op') == 'events':
            target = ROOT / (request['room_id'] + '.observed.json')
            temporary = target.with_suffix('.' + uuid.uuid4().hex + '.tmp')
            temporary.write_text(json.dumps(dict(next_after=result['next_after'])))
            temporary.replace(target)
        return result

    bridge.RoomBridge.execute = observed_execute
    bridge.serve(str(ROOT))


if __name__ == '__main__':
    {'seed': seed, 'inspect': inspect, 'ssh': ssh}[sys.argv[1]]()
