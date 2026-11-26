import importlib.util
import io
import sys
import tempfile
import unittest
import uuid
from contextlib import redirect_stderr
from pathlib import Path
from unittest import mock


root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'src'))
spec = importlib.util.spec_from_file_location('room_bridge', root / 'src' / 'room_bridge.py')
bridge_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge_module)


def uid():
    return str(uuid.uuid4())


class FakeRuntime:
    def __init__(self):
        self.submits = []
        self.stored = {}
        self.events = {}
        self.fail_once = set()
        self.answer = True
        self.reject = False

    def request(self, query):
        op = query['op']
        if op == 'engine_info':
            return {'id': 1, 'room_message_protocols': [1]}
        if op == 'message_status':
            return {'id': 1, 'result': {'seq': len(self.events.get(query['sid'], []))}}
        if op == 'message_submit':
            key = query['message_id']
            if key in self.fail_once:
                self.fail_once.discard(key)
                bridge_module.fail('runtime_unavailable')
            if key in self.stored:
                if self.stored[key] != query['text']:
                    bridge_module.fail('runtime_unavailable')
            else:
                self.stored[key] = query['text']
                self.submits.append((query['sid'], key, query['text']))
                if self.answer and not self.reject:
                    self.reply(query['sid'], key, query['room_scope'], 'reply to ' + query['text'])
            return {'id': 1, 'result': {'message': {'id': key, 'state': 'failed' if self.reject else 'accepted'}}}
        if op == 'events_subscribe':
            rows = self.events.get(query['sid'], [])
            page = [row for row in rows if row['seq'] > query['after']]
            return {'id': 1, 'result': {'events': page, 'next_after': rows[-1]['seq'] if rows else query['after']}}
        raise AssertionError(op)

    def reply(self, sid, message_id, scope, text, text_row=True, turn=None):
        rows = self.events.setdefault(sid, [])
        turn = turn or 'turn-' + message_id
        steps = [('turn.started', {'message_id': message_id})]
        if text_row:
            steps.append(('text.done', {'text': text}))
        steps.append(('turn.ended', {'status': 'completed'}))
        for kind, payload in steps:
            rows.append({'seq': len(rows) + 1, 'event': {'sid': sid, 'room_scope': scope, 'message_id': message_id, 'kind': kind, 'turn': turn, 'item': 'item-' + message_id, 'payload': payload}})


class RoutingTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.runtime = FakeRuntime()
        self.enabled = {}
        self.patches = [mock.patch.object(bridge_module, 'runtime_request', self.runtime.request), mock.patch.object(bridge_module, 'host_status', self.status)]
        for patch in self.patches:
            patch.start()
        self.open()
        self.host = self.bridge.execute({'op': 'capabilities'})['host_uuid']
        self.room_features = self.bridge.execute({'op': 'capabilities', 'room_messages': 1}).get('room_features') == [1]
        self.sids = {'alpha': uid(), 'beta': uid()}
        for sid in self.sids.values():
            self.enabled[sid] = True
        members = [{'alias': alias, 'display_name': alias.title(), 'host_uuid': self.host, 'provider': 'claude', 'provider_sid': sid, 'session_identity': 'claude:' + sid} for alias, sid in self.sids.items()]
        self.room = self.bridge.execute({'op': 'create', 'host_uuid': self.host, 'command_id': uid(), 'name': 'Room', 'members': members})['event']['room_id']
        self.revision = 1

    def tearDown(self):
        self.bridge.close()
        for patch in self.patches:
            patch.stop()
        self.temp.cleanup()

    def open(self):
        self.bridge = bridge_module.RoomBridge(self.temp.name)

    def status(self, sid):
        return {'status': 'ok', 'provider': 'claude', 'sid': sid, 'enabled': self.enabled.get(sid, True), 'tmux': 'tmux-' + sid[:8]}

    def post(self, text, recipients=(), features=False):
        request = {'op': 'post_human', 'host_uuid': self.host, 'command_id': uid(), 'room_id': self.room, 'expected_revision': self.revision, 'text': text, 'recipients': list(recipients)}
        if features and self.room_features:
            request['room_features'] = 1
        return self.bridge.execute(request)

    def sweep(self):
        return self.bridge.execute({'op': 'events', 'host_uuid': self.host, 'room_id': self.room, 'after': 0, 'limit': 200})

    def sent_to(self, alias):
        return [text for sid, _, text in self.runtime.submits if sid == self.sids[alias]]

    def test_plain_message_reaches_every_agent_once(self):
        self.post('hello all')
        self.sweep()
        self.sweep()
        self.assertEqual(['hello all'], self.sent_to('alpha'))
        self.assertEqual(['hello all'], self.sent_to('beta'))
        replies = [e for e in self.sweep()['events'] if e['type'] == 'agent_reply']
        self.assertEqual(2, len(replies))

    def test_mention_reaches_only_that_agent(self):
        self.post('@beta hello', ['beta'])
        self.sweep()
        self.assertEqual([], self.sent_to('alpha'))
        self.assertEqual(['@beta hello'], self.sent_to('beta'))

    def test_each_agent_receives_messages_in_post_order_after_a_runtime_failure(self):
        self.enabled[self.sids['beta']] = False
        first = self.post('one')
        self.runtime.fail_once.add(first['deliveries'][1]['id'])
        self.enabled[self.sids['beta']] = True
        self.post('two')
        self.sweep()
        self.sweep()
        self.sweep()
        self.assertEqual(['one', 'two'], [text.rsplit('New message from the user:\n\n', 1)[-1] for text in self.sent_to('alpha')])
        self.assertEqual(['one', 'two'], [text.rsplit('New message from the user:\n\n', 1)[-1] for text in self.sent_to('beta')])

    def test_offline_agent_receives_message_when_it_returns(self):
        self.enabled[self.sids['beta']] = False
        self.post('hello')
        self.sweep()
        self.assertEqual(['hello'], self.sent_to('alpha'))
        self.assertEqual([], self.sent_to('beta'))
        self.enabled[self.sids['beta']] = True
        self.sweep()
        self.assertEqual(['hello'], self.sent_to('beta'))

    def test_agent_coming_back_mid_sweep_still_gets_messages_in_order(self):
        self.enabled[self.sids['beta']] = False
        self.post('one')
        self.post('two')
        self.enabled[self.sids['beta']] = True
        beta = self.sids['beta']
        answers = iter([False, True, True, True, True, True])
        original = self.status

        def flipping(sid):
            status = original(sid)
            if sid == beta:
                status['enabled'] = next(answers, True)
            return status

        with mock.patch.object(bridge_module, 'host_status', flipping):
            self.sweep()
            self.sweep()
        self.assertEqual(['one', 'two'], [text.rsplit('New message from the user:\n\n', 1)[-1] for text in self.sent_to('beta')])

    def test_longest_message_still_reaches_the_agent_with_context(self):
        self.post('first question')
        self.sweep()
        long_text = 'x' * 65000
        self.post(long_text)
        self.sweep()
        self.assertEqual(long_text, self.sent_to('beta')[1])
        self.assertTrue(all(len(text.encode('utf-8')) <= 66000 for text in self.sent_to('alpha') + self.sent_to('beta')))

    def test_restart_neither_loses_nor_repeats(self):
        self.post('hello')
        self.sweep()
        before = list(self.runtime.submits)
        self.bridge.close()
        self.open()
        page = self.sweep()
        self.assertEqual(before, self.runtime.submits)
        self.assertEqual(2, len([e for e in page['events'] if e['type'] == 'agent_reply']))

    def test_displayed_name_selects_stable_member_and_alias_still_works(self):
        sent = self.post('@bEtA hello', ['beta'], features=True)
        member = next(m for m in self.bridge.store.members(self.room) if m['alias'] == 'beta')
        self.assertEqual([member['id']], sent['event']['recipients'])
        self.sweep()
        self.assertEqual([], self.sent_to('alpha'))
        self.assertEqual(['@bEtA hello'], self.sent_to('beta'))
        self.post('@beta again', ['beta'], features=True)
        self.sweep()
        self.assertEqual(2, len(self.sent_to('beta')))

    def test_post_admits_without_a_history_reader(self):
        self.post('no reader')
        self.assertEqual(['no reader'], self.sent_to('alpha'))
        self.assertEqual(['no reader'], self.sent_to('beta'))

    def test_request_to_another_room_sweeps_offline_work_once_after_restart(self):
        self.enabled[self.sids['beta']] = False
        self.post('offline')
        self.bridge.close()
        self.open()
        self.enabled[self.sids['beta']] = True
        for _ in range(2):
            self.bridge.execute({'op': 'capabilities', 'room_messages': 1})
        self.assertEqual(['offline'], self.sent_to('beta'))
        replies = [e for e in self.bridge.store.execute({'op': 'events', 'room_id': self.room, 'after': 0, 'limit': 200})['events'] if e['type'] == 'agent_reply']
        self.assertEqual(2, len(replies))

    def test_empty_and_failed_turns_publish_no_answer_once_and_allow_resend(self):
        self.runtime.answer = False
        sent = self.post('question')
        self.sweep()
        for delivery in sent['deliveries']:
            member = next(m for m in self.bridge.store.members(self.room) if m['id'] == delivery['member_id'])
            scope = dict(host_uuid=self.host, room_id=self.room, parent_event_id=sent['event']['id'], member_id=member['id'])
            self.runtime.reply(member['provider_sid'], delivery['id'], scope, '')
            if member['alias'] == 'beta':
                self.runtime.events[member['provider_sid']][-1]['event']['payload']['status'] = 'failed'
        page = self.sweep()
        self.sweep()
        replies = [e for e in page['events'] if e['type'] == 'agent_reply']
        self.assertEqual(2, len(replies))
        self.assertTrue(all('No answer' in e['text'] and 'again' in e['text'] for e in replies))
        names = {m['id']: m['display_name'] for m in self.bridge.store.members(self.room)}
        for reply in replies:
            self.assertIn(names[reply['member_id']], reply['text'])
            self.assertIn('Type @ in the room and choose that chat from the mention picker', reply['text'])
            self.assertNotIn(names[[i for i in names if i != reply['member_id']][0]], reply['text'])
        self.runtime.answer = True
        self.post('question')
        self.sweep()
        self.assertEqual(2, len(self.sent_to('alpha')))
        self.assertEqual(2, len(self.sent_to('beta')))

    def test_ended_turn_preserves_text_and_identity_once_across_collection_and_restart(self):
        self.runtime.answer = False
        for status in ('completed', 'interrupted', 'cancelled', 'failed', 'error'):
            for text in ('Bravo says BROADCAST534', '', ' \t\n'):
                with self.subTest(status=status, text=text):
                    sent = self.post('@beta question', ['beta'])
                    self.sweep()
                    delivery = sent['deliveries'][0]
                    member = next(m for m in self.bridge.store.members(self.room) if m['id'] == delivery['member_id'])
                    work = self.bridge.store.execute(dict(op='delivery_work', room_id=self.room, delivery_id=delivery['id']))
                    scope = dict(host_uuid=self.host, room_id=self.room, parent_event_id=sent['event']['id'], member_id=member['id'])
                    self.runtime.reply(member['provider_sid'], delivery['id'], scope, text)
                    self.runtime.events[member['provider_sid']][-1]['event']['payload']['status'] = status
                    progress = self.bridge.store.db.execute('SELECT * FROM reply_progress WHERE delivery_id=?', (delivery['id'],)).fetchone()
                    page = self.runtime.request(dict(op='events_subscribe', sid=member['provider_sid'], after=progress['after_seq']))['result']
                    errors = io.StringIO()
                    with redirect_stderr(errors):
                        self.bridge.collect_reply(work, scope, progress, page)
                        self.bridge.collect_reply(work, scope, progress, page)
                    self.assertIn('status=' + status + ' answered=' + str(int(bool(text.strip()))), errors.getvalue())
                    self.assertEqual(status, self.runtime.events[member['provider_sid']][-1]['event']['payload']['status'])
                    before = list(self.runtime.submits)
                    self.bridge.close()
                    self.open()
                    self.sweep()
                    self.bridge.collect_reply(work, scope, progress, page)
                    replies = [e for e in self.sweep()['events'] if e['type'] == 'agent_reply' and e['parent_event_id'] == sent['event']['id']]
                    self.assertEqual(1, len(replies))
                    reply = replies[0]
                    self.assertEqual(self.room, reply['room_id'])
                    self.assertEqual(member['id'], reply['member_id'])
                    self.assertEqual(str(uuid.uuid5(uuid.NAMESPACE_URL, 'multibot-room-reply:' + delivery['id'])), reply['response_id'])
                    if text.strip():
                        self.assertEqual(text, reply['text'])
                    else:
                        self.assertTrue(reply['text'].startswith('No answer. Beta '))
                        self.assertIn('mention picker', reply['text'])
                    self.assertEqual(before, self.runtime.submits)

    def test_retry_guidance_uses_the_real_picker_for_all_display_names(self):
        member = next(m for m in self.bridge.store.members(self.room) if m['alias'] == 'beta')
        for name in ('Alpha Bot', 'Research / QA!', 'Zoë 東京', 'Alpha', '@nested name', 'a' * 128):
            with self.subTest(name=name):
                self.bridge.store.db.execute('UPDATE members SET display_name=? WHERE id=?', (name, member['id']))
                guidance = self.bridge.retry_sentence(member['id'], 'did not complete a reply')
                self.assertTrue(guidance.startswith('No answer. ' + name + ' '))
                self.assertIn('Type @ in the room and choose that chat from the mention picker', guidance)
                self.assertNotIn('as @' + name, guidance)

    def test_no_answer_decision_records_the_turn_rows_it_read(self):
        self.runtime.answer = False
        sent = self.post('question')
        self.sweep()
        for delivery in sent['deliveries']:
            member = next(m for m in self.bridge.store.members(self.room) if m['id'] == delivery['member_id'])
            scope = dict(host_uuid=self.host, room_id=self.room, parent_event_id=sent['event']['id'], member_id=member['id'])
            self.runtime.reply(member['provider_sid'], delivery['id'], scope, '', text_row=False)
        errors = io.StringIO()
        with redirect_stderr(errors):
            page = self.sweep()
        lines = [line for line in errors.getvalue().splitlines() if ' answered=0' in line]
        self.assertEqual(2, len(lines))
        for delivery in sent['deliveries']:
            line = next((item for item in lines if 'delivery=' + delivery['id'] in item), None)
            self.assertIsNotNone(line)
            self.assertIn('turn=turn-' + delivery['id'], line)
            self.assertIn('parts=0', line)
            self.assertIn('status=completed', line)
            rows = [item for item in errors.getvalue().splitlines() if 'delivery=' + delivery['id'] + ' row ' in item]
            self.assertEqual(2, len(rows))
            self.assertIn('kind=turn.started', rows[0])
            self.assertIn('kind=turn.ended', rows[1])
            self.assertIn('own=1', rows[1])
            self.assertIn('turn=turn-' + delivery['id'], rows[0])
            self.assertIn('turn=turn-' + delivery['id'], rows[1])
        replies = [e for e in page['events'] if e['type'] == 'agent_reply']
        self.assertEqual(2, len(replies))
        self.assertTrue(all('No answer' in e['text'] for e in replies))

    def test_a_no_answer_decision_bounds_a_long_turn_identifier(self):
        self.runtime.answer = False
        long_turn = 'turn-' + 'a' * 200
        sent = self.post('question')
        self.sweep()
        for delivery in sent['deliveries']:
            member = next(m for m in self.bridge.store.members(self.room) if m['id'] == delivery['member_id'])
            scope = dict(host_uuid=self.host, room_id=self.room, parent_event_id=sent['event']['id'], member_id=member['id'])
            self.runtime.reply(member['provider_sid'], delivery['id'], scope, '', text_row=False, turn=long_turn)
        errors = io.StringIO()
        with redirect_stderr(errors):
            page = self.sweep()
        bounded = long_turn[:bridge_module.REPLY_DIAGNOSTIC_ID]
        self.assertGreater(bridge_module.REPLY_DIAGNOSTIC_ID, 36)
        lines = [line for line in errors.getvalue().splitlines() if ' answered=0' in line]
        self.assertEqual(2, len(lines))
        for line in lines:
            self.assertIn('turn=' + bounded, line)
            self.assertNotIn(long_turn, line)
        rows = [item for item in errors.getvalue().splitlines() if ' row ' in item]
        self.assertEqual(4, len(rows))
        for item in rows:
            self.assertIn('turn=' + bounded, item)
            self.assertNotIn(long_turn, item)
        replies = [e for e in page['events'] if e['type'] == 'agent_reply']
        self.assertEqual(2, len(replies))
        self.assertTrue(all('No answer' in e['text'] for e in replies))

    def test_failed_admission_publishes_no_answer_and_resend_uses_a_new_identity(self):
        self.runtime.reject = True
        first = self.post('try this')
        self.sweep()
        replies = [e for e in self.sweep()['events'] if e['type'] == 'agent_reply']
        self.assertEqual(2, len(replies))
        self.assertTrue(all('No answer' in e['text'] for e in replies))
        self.runtime.reject = False
        second = self.post('try this')
        self.sweep()
        self.assertTrue({d['id'] for d in first['deliveries']}.isdisjoint({d['id'] for d in second['deliveries']}))
        self.assertEqual(2, len(self.sent_to('alpha')))
        self.assertEqual(2, len(self.sent_to('beta')))

    def test_host_schedule_completes_offline_work_once_without_room_requests(self):
        import ast
        import base64
        import re
        import sqlite3
        import time
        import types
        outer = ast.parse((root / 'src/chat_history_reader.py').read_text())
        source = ast.literal_eval(next(node.value for node in outer.body if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == 'READER_SOURCE' for target in node.targets)))
        functions = [node for node in ast.parse(source).body if isinstance(node, ast.FunctionDef) and node.name in ('host_room_sources', 'host_room_sweep', 'host_room_tick')]
        self.assertEqual(3, len(functions))
        fixture = types.ModuleType('mubo_room_runtime')
        fixture.runtime_request = self.runtime.request
        fixture.host_status = self.status
        bridge_source = (root / 'src/room_bridge.py').read_text() + '\nfrom mubo_room_runtime import runtime_request, host_status\n'
        with tempfile.TemporaryDirectory() as home, mock.patch.dict(sys.modules, {'mubo_room_runtime': fixture}):
            directory = Path(home) / '.local/state/multiprompt' / ('rooms-account-' + 'a' * 64)
            directory.mkdir(mode=0o700, parents=True)
            bridge = bridge_module.RoomBridge(directory)
            try:
                host = bridge.store.host_uuid
                sid = self.sids['beta']
                member = dict(alias='beta', display_name='Beta', host_uuid=host, provider='claude', provider_sid=sid, session_identity='claude:' + sid)
                room = bridge.store.execute(dict(op='create', command_id=uid(), name='Offline', members=[member]))['event']['room_id']
                bridge.store.execute(dict(op='post_human', command_id=uid(), room_id=room, expected_revision=1, text='return without a reader', recipients=[]))
                namespace = dict(HOME=Path(home), sys=sys, re=re, sqlite3=sqlite3, time=time, HOST_ROOM_SOURCES=dict(checked=0.0, service='', bridge=''), ROOM_SERVICE_SOURCE=base64.b64encode((root / 'src/room_service.py').read_bytes()).decode(), ROOM_BRIDGE_SOURCE=base64.b64encode(bridge_source.encode()).decode())
                exec(compile(ast.Module(body=functions, type_ignores=[]), '<room-host-schedule>', 'exec'), namespace)
                self.enabled[sid] = False
                namespace['host_room_sweep'](sid)
                self.assertEqual([], self.sent_to('beta'))
                self.enabled[sid] = True
                for _ in range(2):
                    session = {}
                    namespace['host_room_tick']('claude', sid, session)
                    session['room_worker'].join(timeout=10)
                    self.assertFalse(session['room_worker'].is_alive())
                self.assertEqual(['return without a reader'], self.sent_to('beta'))
                rows = bridge.store.db.execute("SELECT body FROM events WHERE room_id=? AND json_extract(body,'$.type')='agent_reply'", (room,)).fetchall()
                self.assertEqual(1, len(rows))
            finally:
                bridge.close()

    def test_agents_see_the_same_ordered_conversation(self):
        self.post('first question', features=True)
        self.sweep()
        self.post('@alpha private question', ['alpha'], features=True)
        self.sweep()
        self.post('third question', features=True)
        self.sweep()
        alpha, beta = self.sent_to('alpha'), self.sent_to('beta')
        self.assertEqual(3, len(alpha))
        self.assertEqual(2, len(beta))
        self.assertEqual('first question', alpha[0])
        self.assertEqual('first question', beta[0])
        self.assertIn('beta: reply to first question', alpha[1])
        self.assertNotIn('alpha: reply to first question', alpha[1])
        self.assertTrue(alpha[1].endswith('@alpha private question'))
        self.assertIn('alpha: reply to first question', beta[1])
        self.assertIn('User: @alpha private question', beta[1])
        self.assertIn('alpha: reply to', beta[1])
        self.assertTrue(beta[1].endswith('third question'))
        self.bridge.close()
        self.open()
        self.sweep()
        self.assertEqual(alpha, self.sent_to('alpha'))
        self.assertEqual(beta, self.sent_to('beta'))


if __name__ == '__main__':
    unittest.main()
