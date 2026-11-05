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
if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') not in ('Windows', 'Linux'):
    raise RuntimeError('GitHub-hosted fixture only')


def synthetic_runtime(store, directory):
    outer = {}
    reader_path = Path(__file__).resolve().parents[2] / 'src/chat_history_reader.py'
    exec(compile(reader_path.read_text(encoding='utf-8'), str(reader_path), 'exec'), outer)
    runtime = {}
    exec(compile(outer['READER_SOURCE'], 'room-preview-runtime', 'exec'), runtime)
    runtime['HOME'] = directory / 'canonical'
    runtime['resolve_tmux_agent'] = lambda *args, **kwargs: None
    runtime['host_dispatch_switch'] = lambda *args: False
    runtime['host_state_write'] = lambda *args: None
    runtime['host_log'] = lambda *args: None
    runtime['host_attempt'] = lambda *args: dict(status='claimed')
    sent = []
    runtime['host_control_send'] = lambda session, message: sent.append(message) or True

    def request(query):
        operation = query.get('op')
        if operation == 'engine_info':
            return dict(id=1, room_message_protocols=[runtime['ROOM_MESSAGE_PROTOCOL']])
        if operation == 'events_subscribe':
            return dict(id=1, result=runtime['message_events_page'](query['provider'], query['sid'], query['after']))
        if operation not in ('message_status', 'message_submit'):
            raise RuntimeError('Unexpected preview runtime operation')
        result = runtime['message_store_transaction'](query)
        if operation == 'message_submit':
            previous = runtime['message_events_page'](query['provider'], query['sid'], 0)
            finished = any(row['event'].get('kind') == 'turn.ended' and row['event'].get('message_id') == query['message_id'] for row in previous['events'])
            if not finished:
                member = store.db.execute('SELECT display_name FROM members WHERE id=? AND provider_sid=?', (query['room_scope']['member_id'], query['sid'])).fetchone()
                if member is None:
                    raise RuntimeError('Synthetic provider identity mismatch')
                session = dict(state={})
                runtime['host_session_reset'](session)
                try:
                    delivery = dict(op='deliver', id=query['message_id'], attempt=result['message']['attempt'], epoch=result['epoch'], text=query['text'], room_scope=query['room_scope'])
                    delivered = runtime['host_handle_request'](query['provider'], query['sid'], query['tmux'], session, delivery)
                    if delivered.get('status') != 'sent' or len(sent) != 1:
                        raise RuntimeError('Synthetic provider admission failed')
                    text = 'Synthetic ' + member['display_name'].title() + ' reply: Ready.'
                    runtime['host_agent_event'](query['provider'], query['sid'], query['tmux'], session, json.dumps(dict(type='assistant', message=dict(id='synthetic-' + query['message_id'], content=[dict(type='text', text=text)]))))
                    runtime['host_agent_event'](query['provider'], query['sid'], query['tmux'], session, json.dumps(dict(type='result', subtype='success')))
                    sent.clear()
                finally:
                    if session.get('db') is not None:
                        session['db'].close()
        return dict(id=1, result=result)

    return request


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
    bridge_module.host_status = lambda sid: dict(status='ok', provider='claude', sid=sid, tmux='proof-' + sid, enabled=True, owner='host', alive=True)
    live = (ROOT / 'live-replies').is_file()
    bridge_module.scoped_runtime = lambda: live
    if live:
        bridge_module.runtime_request = synthetic_runtime(store, directory)
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
        canonical = []
        if live:
            for member in store.db.execute('SELECT DISTINCT provider_sid FROM members'):
                page = bridge_module.runtime_request(dict(op='events_subscribe', provider='claude', sid=member['provider_sid'], after=0))['result']
                canonical.extend(page['events'])
        witness = dict(rooms=rows, canonical_events=canonical, live=live, boundaries=['Isolated actual account Worker', 'SSH, host ownership and provider stdin/output are synthetic', 'Production canonical transaction and host event reducers run in-process', 'POSIX ownership and dispatch locks are not verified on Windows'])
        if live and request.get('op') == 'snapshot' and response.get('ok'):
            (ROOT / 'snapshot-live.json').write_text(json.dumps(dict(room_id=request['room_id'])), encoding='utf-8')
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
