const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');

const program = String.raw`
import importlib.util, json, sys, tempfile, uuid
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
    calls = []
    def rpc(query):
        calls.append(query)
        if query['op'] == 'engine_info':
            return dict(id=1, room_message_protocols=[1])
        if query['op'] == 'events_subscribe':
            return dict(id=1, message_protocol=1, result=r['message_events_page']('claude', query['sid'], query['after']))
        return dict(id=1, message_protocol=1, result=r['message_store_request'](query))
    with patch.object(room_bridge, 'runtime_request', rpc), patch.object(room_bridge, 'host_status', return_value=dict(enabled=True, provider='claude', sid=sid, tmux=tmux)):
        bridge = room_bridge.RoomBridge(rooms)
        host = bridge.execute(dict(op='capabilities'))['host_uuid']
        assert bridge.execute(dict(op='capabilities', room_messages=1))['live_send']
        assert not bridge.execute(dict(op='capabilities'))['live_send']
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
        bridge.execute(dict(op='events', host_uuid=host, room_id=room, after=0, limit=200))
        for delivery, text in [(a['deliveries'][0], first['text']), (b['deliveries'][0], second['text'])]:
            status = r['message_store_request'](dict(message_protocol=1, op='message_status', provider='claude', sid=sid, tmux=tmux, message_id=delivery['id']))
            assert status['message']['text'] == text
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
        page = bridge.execute(events_request)
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
