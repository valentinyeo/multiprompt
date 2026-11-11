const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');

const program = String.raw`
import importlib.util, json, sys, tempfile, time, uuid
from pathlib import Path
from unittest.mock import patch
root = Path.cwd()
sys.path.insert(0, str(root / 'src'))
import room_bridge
outer = {}
exec(compile((root / 'src/chat_history_reader.py').read_text(), 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
assert r.get('ROOM_MESSAGE_PROTOCOL') == 1, 'canonical runtime must explicitly support scoped room messages'
uid = lambda: str(uuid.uuid4())
with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as rooms:
    r['HOME'] = Path(home)
    sid, tmux = uid(), 'room-agent'
    r['host_write'](r['host_paths']('claude', sid)['config'], dict(enabled=True, tmux=tmux))
    r['resolve_tmux_agent'] = lambda *a, **k: None
    with patch.object(room_bridge, 'runtime_request', return_value=dict(id=1, message_protocols=[1])):
        legacy = room_bridge.RoomBridge(rooms)
        assert not legacy.execute(dict(op='capabilities', room_messages=1))['live_send']
        try:
            legacy.execute(dict(op='post_human'))
            raise AssertionError('old runtime allowed room sending')
        except room_bridge.RoomError as error:
            assert error.code == 'unsupported_remote_capability'
        legacy.close()
    sent_to_host = []
    def old_host(provider, session, request):
        sent_to_host.append(request['op'])
        return dict(status='ok', sid=session)
    with patch.dict(r, host_owned=lambda *a: True, host_request=old_host, host_start=lambda *a: dict(status='already')):
        scope = {key: uid() for key in ('host_uuid', 'room_id', 'parent_event_id', 'member_id')}
        refused = r['host_deliver']('claude', sid, uid(), 'attempt', 0, 'Room request', room_scope=scope)
        assert refused['status'] == 'busy' and sent_to_host == ['ping', 'ping'], 'older host received a scoped delivery'
    calls = []
    def rpc(query):
        calls.append(query)
        if query['op'] == 'engine_info':
            return dict(id=1, room_message_protocols=[1])
        if query['op'] == 'events_subscribe':
            return dict(id=1, message_protocol=1, result=r['message_events_page']('claude', query['sid'], query['after']))
        return dict(id=1, message_protocol=1, result=r['message_store_request'](query))
    with patch.object(room_bridge, 'runtime_request', rpc), patch.object(room_bridge, 'host_status', return_value=dict(enabled=True, provider='claude', sid=sid, tmux=tmux)) as status:
        bridge = room_bridge.RoomBridge(rooms)
        host = bridge.execute(dict(op='capabilities'))['host_uuid']
        assert bridge.execute(dict(op='capabilities', room_messages=1))['live_send']
        legacy_capabilities = bridge.execute(dict(op='capabilities'))
        assert legacy_capabilities == dict(room_protocol=1, host_uuid=host, store_only=True, live_send=False, reason='unsupported_remote_capability')
        member = dict(alias='alpha', display_name='Alpha', host_uuid=host, provider='claude', provider_sid=sid, session_identity='claude:' + sid)
        def create():
            return bridge.execute(dict(op='create', host_uuid=host, command_id=uid(), name='Room', members=[member]))['event']['room_id']
        room, other_room = create(), create()
        member_id = bridge.store.members(room)[0]['id']
        def post(text):
            return dict(op='post_human', host_uuid=host, command_id=uid(), room_id=room, expected_revision=1, text=text, recipients=[])
        first, second = post('First room question'), post('Second room question')
        a, b = bridge.execute(first), bridge.execute(second)
        assert bridge.execute(first) == a
        deadline = time.monotonic() + 20
        for delivery, text in [(a['deliveries'][0], first['text']), (b['deliveries'][0], second['text'])]:
            while True:
                bridge.execute(dict(op='events', host_uuid=host, room_id=room, after=0, limit=200))
                saved = r['message_store_request'](dict(message_protocol=1, op='message_status', provider='claude', sid=sid, tmux=tmux, message_id=delivery['id']))
                if saved['message'] is not None:
                    break
                assert time.monotonic() < deadline, 'stored room message timeout: ' + delivery['id']
                time.sleep(0.05)
            assert saved['message']['text'] == text
        logs = []
        state = {}
        session = dict(state=state)
        r['host_session_reset'](session)
        r['host_attempt'] = lambda *a, **k: dict(status='claimed')
        r['host_state_write'] = lambda *a, **k: None
        r['host_log'] = lambda *a, **k: None
        r['host_control_send'] = lambda session, message: logs.append(message) or True
        def deliver(delivery):
            scope = dict(host_uuid=host, room_id=room, parent_event_id=delivery['event_id'], member_id=member_id)
            request = dict(op='deliver', id=delivery['id'], attempt='attempt', epoch=0, text='Room request', room_scope=scope)
            assert r['host_handle_request']('claude', sid, tmux, session, request)['status'] == 'sent'
            return request
        req = deliver(a['deliveries'][0])
        private = dict(op='deliver', id='private-' + uuid.uuid4().hex, attempt='attempt', epoch=0, text='PRIVATE SENTINEL')
        assert r['host_handle_request']('claude', sid, tmux, session, private)['status'] == 'busy'
        def reply(text):
            r['host_agent_event']('claude', sid, tmux, session, json.dumps(dict(type='assistant', message=dict(id=uid(), content=[dict(type='text', text=text)]))))
            r['host_agent_event']('claude', sid, tmux, session, json.dumps(dict(type='result', subtype='success')))
        reply('Answer one')
        assert r['host_handle_request']('claude', sid, tmux, session, private)['status'] == 'sent'
        blocked = dict(req, id=b['deliveries'][0]['id'])
        assert r['host_handle_request']('claude', sid, tmux, session, blocked)['status'] == 'busy'
        reply('PRIVATE SENTINEL')
        deliver(b['deliveries'][0])
        reply('Answer two')
        events_request = dict(op='events', host_uuid=host, room_id=room, after=0, limit=200)
        status.return_value['enabled'] = False
        submitted_before = sum(q.get('op') == 'message_submit' for q in calls)
        page = bridge.execute(events_request)
        assert sum(q.get('op') == 'message_submit' for q in calls) == submitted_before, 'disabled host received a new submission'
        replies = [e for e in page['events'] if e['type'] == 'agent_reply']
        assert [(e['parent_event_id'], e['text']) for e in replies] == [(a['event']['id'], 'Answer one'), (b['event']['id'], 'Answer two')], replies
        assert all(e['member_id'] == member_id for e in replies)
        assert 'PRIVATE SENTINEL' not in json.dumps(page)
        assert not [e for e in bridge.execute(dict(events_request, room_id=other_room))['events'] if e['type'] == 'agent_reply']
        bridge.close()
        bridge = room_bridge.RoomBridge(rooms)
        assert bridge.execute(events_request) == page
        assert bridge.execute(first) == a
        assert len([q for q in calls if q.get('op') == 'message_submit']) >= 2
        for mutation in [dict(room_id=other_room), dict(member_id=uid()), dict(parent_event_id=uid())]:
            changed = dict(req['room_scope'], **mutation)
            try:
                r['message_store_request'](dict(message_protocol=1, op='message_submit', provider='claude', sid=sid, tmux=tmux, message_id=req['id'], text=first['text'], room_scope=changed))
                raise AssertionError('scope changed on retry')
            except ValueError:
                pass
        try:
            bridge.execute(dict(op='agent_reply', host_uuid=host))
            raise AssertionError('unproven reply accepted')
        except room_bridge.RoomError:
            pass
        status.return_value['enabled'] = True
        third = bridge.execute(post('Removed recipient must not receive this'))
        third_id = third['deliveries'][0]['id']
        def removing_rpc(query):
            if query.get('op') == 'message_status' and query.get('message_id') == third_id:
                bridge.store.execute(dict(op='edit_members', command_id=uid(), room_id=room, expected_revision=1, members=[]))
            return rpc(query)
        with patch.object(room_bridge, 'runtime_request', removing_rpc):
            bridge.execute(events_request)
        assert not any(q.get('op') == 'message_submit' and q.get('message_id') == third_id for q in calls), 'membership removal raced canonical admission'
        bridge.close()
print('ROOM_SCOPED_REPLIES_PASS')
`;

test('existing room store and bridge contracts remain compatible', { skip: process.platform === 'win32' }, () => {
  const result = spawnSync('python3', ['-m', 'unittest', 'discover', '-s', 'tools', '-p', 'room_*test.py'], { cwd: root, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('room replies retain their exact parent and session without publishing private turns', { skip: process.platform === 'win32' }, () => {
  const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
  assert.ok(source.includes('ROOM_MESSAGE_PROTOCOL = 1'), 'scoped canonical room protocol is available');
  const result = spawnSync('python3', ['-'], { cwd: root, input: program, encoding: 'utf8', timeout: 60000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /ROOM_SCOPED_REPLIES_PASS/);
});

const processProgram = String.raw`
import hashlib, json, os, signal, sys, tempfile, time, uuid
from pathlib import Path
sys.path.insert(0, str(Path.cwd() / 'src'))
import room_bridge
outer = {}
exec(compile(Path('src/chat_history_reader.py').read_text(), 'reader', 'exec'), outer)
assert 'ROOM_MESSAGE_PROTOCOL = 1' in outer['READER_SOURCE'], 'scoped runtime required'
source = outer['READER_SOURCE'].encode()
nonce = uuid.uuid4().hex
os.environ['MULTIPROMPT_ROOM_PROOF'] = nonce
agent_source = '''import json, sys
args = sys.argv[1:]
sid = args[args.index('--resume') + 1] if '--resume' in args else args[args.index('--session-id') + 1]
print(json.dumps(dict(type='system', subtype='init', session_id=sid)), flush=True)
for line in sys.stdin:
    message = json.loads(line)
    if message.get('type') != 'user':
        continue
    content = message['message']['content']
    text = content if isinstance(content, str) else ''.join(part.get('text', '') for part in content)
    reply = dict(type='assistant', message=dict(id='fixture-' + sid, content=[dict(type='text', text='reply:' + sid + ':' + text + ':' + str(index)) for index in range(300)]))
    print(json.dumps(reply), flush=True)
    print(json.dumps(dict(type='result', subtype='success')), flush=True)
'''
def owned():
    found = []
    marker = ('MULTIPROMPT_ROOM_PROOF=' + nonce).encode()
    for process in Path('/proc').glob('[0-9]*'):
        try:
            if int(process.name) != os.getpid() and marker in (process / 'environ').read_bytes().split(b'\0'):
                found.append(int(process.name))
        except (OSError, ValueError):
            pass
    return found
with tempfile.TemporaryDirectory() as home:
    os.environ['HOME'] = home
    runtime = Path(home) / '.multiprompt-runtime'
    runtime.mkdir(mode=0o700)
    digest = hashlib.sha256(source).hexdigest()
    for name, data in [('reader.py', source), (digest + '.py', source), ('active.json', json.dumps(dict(protocol=1, generation=outer['RUNTIME_GENERATION'], sha256=digest)).encode())]:
        file = runtime / name
        file.write_bytes(data)
        file.chmod(0o600)
    script = Path(home) / 'fixture_agent.py'
    script.write_text(agent_source)
    r = {}
    exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
    bridge = room_bridge.RoomBridge(Path(home) / 'rooms')
    try:
        capabilities = bridge.execute(dict(op='capabilities', room_messages=1))
        assert capabilities['live_send'], capabilities
        host = capabilities['host_uuid']
        members = []
        for alias in ['alpha', 'beta']:
            sid = str(uuid.uuid4())
            r['host_write'](r['host_paths']('claude', sid)['config'], dict(enabled=True, tmux='proof-' + alias, command=[sys.executable, str(script)]))
            members.append(dict(alias=alias, display_name=alias.title(), host_uuid=host, provider='claude', provider_sid=sid, session_identity='claude:' + sid))
        room = bridge.execute(dict(op='create', command_id=str(uuid.uuid4()), host_uuid=host, name='Proof', members=members))['event']['room_id']
        receipts = []
        for member in members:
            request = dict(op='post_human', command_id=str(uuid.uuid4()), host_uuid=host, room_id=room, expected_revision=1, text='Question @' + member['alias'], recipients=[member['alias']])
            receipts.append((request, bridge.execute(request)))
        query = dict(op='events', host_uuid=host, room_id=room, after=0, limit=200)
        deadline = time.monotonic() + 40
        while True:
            page = bridge.execute(query)
            replies = [event for event in page['events'] if event['type'] == 'agent_reply']
            if len(replies) == 2:
                break
            assert time.monotonic() < deadline, 'real host reply timeout'
            time.sleep(0.1)
        by_parent = {event['parent_event_id']: event for event in replies}
        bindings = {member['alias']: member['id'] for member in bridge.store.members(room)}
        for member, (request, receipt) in zip(members, receipts):
            reply = by_parent[receipt['event']['id']]
            expected = '\n\n'.join('reply:' + member['provider_sid'] + ':' + request['text'] + ':' + str(index) for index in range(300))
            assert reply['text'] == expected, 'reply parts changed order across canonical pages'
            assert reply['member_id'] == bindings[member['alias']]
            assert bridge.execute(request) == receipt
        bridge.close()
        bridge = room_bridge.RoomBridge(Path(home) / 'rooms')
        assert bridge.execute(query) == page
        print('ROOM_REAL_HOST_PROCESS_PASS')
    finally:
        bridge.close()
        for pid in owned():
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 3
        while owned() and time.monotonic() < deadline:
            time.sleep(0.05)
        for pid in owned():
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        assert not owned(), 'owned fixture processes remain'
`;

test('real selected runtime and host processes produce scoped room replies', { skip: process.platform !== 'linux' }, () => {
  const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');
  assert.ok(source.includes('ROOM_MESSAGE_PROTOCOL = 1'), 'scoped canonical room protocol is available');
  const result = spawnSync('python3', ['-'], { cwd: root, input: processProgram, encoding: 'utf8', timeout: 90000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /ROOM_REAL_HOST_PROCESS_PASS/);
});
