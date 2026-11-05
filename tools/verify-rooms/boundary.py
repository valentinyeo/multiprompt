import ast
import base64
import json
import os
from pathlib import Path
import re
import runpy
import sqlite3
import sys
import time
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
            if not finished and not (ROOT / 'agents-offline').is_file():
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
                    answer = 'Second ready.' if query['text'].startswith('Second room question:') else 'Ready.'
                    text = 'Synthetic ' + member['display_name'].title() + ' reply: ' + answer
                    runtime['host_agent_event'](query['provider'], query['sid'], query['tmux'], session, json.dumps(dict(type='assistant', message=dict(id='synthetic-' + query['message_id'], content=[dict(type='text', text=text)]))))
                    runtime['host_agent_event'](query['provider'], query['sid'], query['tmux'], session, json.dumps(dict(type='result', subtype='success')))
                    sent.clear()
                    if (ROOT / 'private-replies').is_file():
                        private_id = 'synthetic-private-' + query['sid']
                        previous = runtime['message_events_page'](query['provider'], query['sid'], 0)
                        private_finished = any(row['event'].get('kind') == 'turn.ended' and row['event'].get('message_id') == private_id for row in previous['events'])
                        if not private_finished:
                            private = runtime['message_store_transaction'](dict(op='message_submit', provider=query['provider'], sid=query['sid'], tmux=query['tmux'], message_id=private_id, text='Synthetic private question.'))
                            admitted = runtime['host_handle_request'](query['provider'], query['sid'], query['tmux'], session, dict(op='deliver', id=private_id, attempt=private['message']['attempt'], epoch=private['epoch'], text='Synthetic private question.'))
                            if admitted.get('status') != 'sent' or len(sent) != 1:
                                raise RuntimeError('Synthetic private provider admission failed')
                            runtime['host_agent_event'](query['provider'], query['sid'], query['tmux'], session, json.dumps(dict(type='assistant', message=dict(id=private_id, content=[dict(type='text', text='Synthetic private answer: keep outside rooms.')]))))
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
    bridge_module.host_status = lambda sid: dict(status='ok', provider='claude', sid=sid, tmux='proof-' + sid, enabled=True, owner='host', alive=not (ROOT / 'agents-offline').is_file())
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
        messages = []
        if live:
            for member in store.db.execute('SELECT DISTINCT provider_sid FROM members'):
                page = bridge_module.runtime_request(dict(op='events_subscribe', provider='claude', sid=member['provider_sid'], after=0))['result']
                canonical.extend(page['events'])
            for delivery in store.db.execute('SELECT d.id,d.room_id,d.event_id,d.member_id,m.provider_sid FROM deliveries d JOIN members m ON m.id=d.member_id ORDER BY d.delivery_seq'):
                saved = bridge_module.runtime_request(dict(op='message_status', provider='claude', sid=delivery['provider_sid'], tmux='proof-' + delivery['provider_sid'], message_id=delivery['id']))['result'].get('message')
                if saved is not None:
                    messages.append(dict(id=delivery['id'], room_id=delivery['room_id'], parent_event_id=delivery['event_id'], member_id=delivery['member_id'], state=saved['state']))
        witness = dict(rooms=rows, canonical_events=canonical, room_messages=messages, live=live, boundaries=['Isolated actual account Worker', 'SSH, host ownership and provider stdin/output are synthetic', 'Production canonical transaction and host event reducers run in-process', 'POSIX ownership and dispatch locks are not verified on Windows'])
        if request.get('op') == 'list' and response.get('ok'):
            (ROOT / 'catalog-observed.json').write_text(json.dumps(dict(room_ids=[room['id'] for room in response['result']['rooms']])), encoding='utf-8')
        if live and request.get('op') == 'snapshot' and response.get('ok'):
            (ROOT / 'snapshot-live.json').write_text(json.dumps(dict(room_id=request['room_id'])), encoding='utf-8')
        temporary = ROOT / ('witness-' + uuid.uuid4().hex + '.json')
        temporary.write_text(json.dumps(witness), encoding='utf-8')
        os.replace(temporary, ROOT / 'witness.json')
        background = request.get('op') == 'list' or (request.get('op') == 'snapshot' and request.get('metadata') is True)
        first_complete = len(rows) == 1 and sum(event['type'] == 'human' for event in rows[0]['events']) == 1 and sum(event['type'] == 'agent_reply' for event in rows[0]['events']) == 2
        if live and background and first_complete and (ROOT / 'hold-next-background-read').is_file() and not (ROOT / 'background-read-held.json').exists():
            (ROOT / 'background-read-held.json').write_text(json.dumps(dict(kind='catalog' if request['op'] == 'list' else 'catalog_metadata')), encoding='utf-8')
            deadline = time.monotonic() + 12
            while not (ROOT / 'release-background-read').is_file():
                if time.monotonic() >= deadline:
                    (ROOT / 'background-read-timeout').write_text('expired', encoding='ascii')
                    raise RuntimeError('Synthetic background-read hold expired')
                time.sleep(0.025)
        print(service.encoded(response), flush=True)
    finally:
        store.close()
    return 0


if sys.argv[1] == 'ssh' and 'room_service' in ' '.join(sys.argv[2:]):
    sys.exit(room_request())
runpy.run_path(str(Path(__file__).resolve().parents[1] / 'verify-chat-delivery' / 'boundary.py'), run_name='__main__')
