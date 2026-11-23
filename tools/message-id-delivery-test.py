import importlib.util
import json
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
READER_SPEC = importlib.util.spec_from_file_location('message_id_reader', ROOT / 'src/chat_history_reader.py')
reader = importlib.util.module_from_spec(READER_SPEC)
READER_SPEC.loader.exec_module(reader)
CONNECTOR_SPEC = importlib.util.spec_from_file_location('message_id_claude', ROOT / 'src/chat_connectors/claude.py')
claude = importlib.util.module_from_spec(CONNECTOR_SPEC)
CONNECTOR_SPEC.loader.exec_module(claude)


class MessageIdDeliveryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(patch.stopall)
        self.home = Path(self.temp.name)
        patch.object(reader, 'HOME', self.home).start()
        patch.object(reader.time, 'sleep').start()
        self.path = self.home / 'sid.jsonl'
        self.path.write_text('')
        patch.object(reader, 'resolve_tmux_agent', return_value=('sid', self.path)).start()

    def request(self, op, **values):
        return reader.message_store_request(dict(message_protocol=1, provider='claude', sid='sid', tmux='fixture',
                                                 op='message_' + op, **values))

    def pane(self, box=''):
        state = dict(box=box, shown=box, buffer='')

        def run(command, **kwargs):
            stdout = ''
            if 'capture-pane' in command:
                state['shown'] = state['box']
                stdout = '\u276f ' + state['shown'] + '\n' + '\u2500' * 20 + '\n'
            elif 'load-buffer' in command:
                state['buffer'] = kwargs['input'].decode('utf-8')
            elif 'paste-buffer' in command:
                state['box'] += state['buffer']
            elif 'send-keys' in command and command[-1] in ('C-u', 'C-k', 'Enter'):
                state['box'] = ''
            return types.SimpleNamespace(returncode=0, stdout=stdout)

        return state, run

    def test_typed_text_keeps_the_message_id(self):
        token = 'aaaaaaaaaaaaaaaa'
        state, run = self.pane()
        with patch.object(reader.subprocess, 'run', side_effect=run):
            result = reader.send_response_preserve_draft(dict(tmux='fixture', sid='sid', text='please review the offer', token=token))
        self.assertEqual(result['status'], 'sent')
        self.assertIn('\n[mp:' + token + ']', state['buffer'])
        self.assertTrue(state['buffer'].startswith('please review the offer'))

    def test_rewritten_text_is_accepted_by_message_id(self):
        token = 'bbbbbbbbbbbbbbbb'
        text = 'Claude rewrote the request\n[mp:' + token + ']'
        event = dict(type='user', sessionId='sid', uuid='native-1', timestamp='2026-11-07T00:00:00.000Z',
                     message=dict(role='user', content=text))
        self.path.write_text(json.dumps(event) + '\n')
        shown = reader.conversation_event(event, 'claude')
        self.assertNotIn('[mp:', shown['text'])
        self.assertIn('Claude rewrote the request', shown['text'])
        info = self.path.stat()
        key = dict(provider='claude', sid='sid', id='message_fixture_0001', attempt='attemptfixture000001', epoch=0,
                   text_sha256='original')
        binding = dict(v=1, dev=info.st_dev, ino=info.st_ino, boundary=0, match=claude._match_digest('please review the offer'),
                       app_id=token, time=0)
        services = dict(resolve_tmux_agent=lambda *_args, **_kwargs: ('sid', self.path),
                        attempt_bindings=lambda: [dict(key=key, binding=binding, outcome='sent')],
                        load_line=reader.load_line, conversation_rows=reader.conversation_rows)
        result = claude.poll(dict(provider='claude', sid='sid', tmux='fixture', transcript_path=str(self.path)), {}, [], services)
        accepted = [fact['id'] for fact in result['facts'] if fact.get('kind') == 'accepted' and not fact.get('ambiguous')]
        self.assertEqual(accepted, ['message_fixture_0001'])

    def test_history_echoes_each_client_id_without_using_text(self):
        import uuid
        tokens = ['desktop-' + 'a' * 32, 'desktop-' + 'b' * 32]
        for token in tokens:
            self.request('submit', message_id=token, text='same prompt')
        events = [dict(type='user', uuid=str(uuid.uuid5(uuid.NAMESPACE_URL, 'multibot:' + token)),
                       timestamp='2026-11-07T00:00:00Z',
                       message=dict(role='user', content='rewritten prompt')) for token in reversed(tokens)]
        self.path.write_text(''.join(json.dumps(event) + '\n' for event in events))
        wire = reader.response(dict(id=1, sid='sid', tmux='fixture', source_offsets=True, offset=0, inode=0, cached_sid=''),
                               resolved=('claude', 'sid', self.path, None))
        rows = [json.loads(line) for line in wire.splitlines() if line.startswith('{')]
        self.assertEqual([row.get('client_id') for row in rows if row.get('role') == 'user'], list(reversed(tokens)))
        self.assertEqual([row['id'] for row in rows if row.get('role') == 'user'], [event['uuid'] for event in events])

    def test_terminal_marker_echoes_the_original_client_id(self):
        client = 'desktop-' + 'c' * 32
        message = self.request('submit', message_id=client, text='same prompt')['message']
        db = reader.message_store_db('fixture')
        with db:
            db.execute("UPDATE shared_messages SET state='sent' WHERE id=?", (client,))
        db.close()
        claim = reader.attempt_prepare('fixture', 'claude', 'sid',
                               dict(provider='claude', sid='sid', id=client, attempt=message['attempt'],
                                    epoch=message['epoch'], text_sha256=reader.hashlib.sha256(b'same prompt').hexdigest()),
                               dict(app_id='c' * 16))
        self.assertEqual(claim['status'], 'claimed')
        row = reader.conversation_event(dict(type='user', uuid='native', message=dict(
            role='user', content='rewritten prompt\n[mp:' + 'c' * 16 + ']')), 'claude')
        reader.history_client_ids([row], 'claude', 'sid')
        self.assertEqual(row['client_id'], client)
        self.assertEqual(row['text'], 'rewritten prompt')

    def test_native_alias_survives_live_event_retirement(self):
        client = 'desktop-' + 'd' * 32
        message = self.request('submit', message_id=client, text='same prompt')['message']
        db = reader.message_store_db('fixture')
        with db:
            db.execute("UPDATE shared_messages SET state='sent' WHERE id=?", (client,))
        db.close()
        claim = reader.attempt_prepare('fixture', 'claude', 'sid',
                               dict(provider='claude', sid='sid', id=client, attempt=message['attempt'],
                                    epoch=message['epoch'], text_sha256=reader.hashlib.sha256(b'same prompt').hexdigest()), dict(mode='host'))
        self.assertEqual(claim['status'], 'claimed')
        session = dict(sends=[dict(id=client, attempt=message['attempt'], uuid=None)])
        try:
            with patch.object(reader, 'host_turn_started'):
                reader.host_bind_uuid('claude', 'sid', 'fixture', session, dict(user_message_uuid='native-user'))
            with session['db'] as db:
                db.execute('DELETE FROM message_events')
            row = dict(role='user', id='native-user', text='rewritten prompt')
            reader.history_client_ids([row], 'claude', 'sid')
            self.assertEqual(row['client_id'], client)
            other = dict(role='user', id='native-user', text='same prompt')
            reader.history_client_ids([other], 'claude', 'other-session')
            self.assertNotIn('client_id', other)
        finally:
            session['db'].close()

    def test_queued_message_past_its_deadline_resolves(self):
        token = 'message_fixture_0001'
        self.request('submit', message_id=token, text='please review the offer')
        db = reader.message_store_db('fixture')
        with db:
            db.execute("UPDATE shared_messages SET deadline=? WHERE id=?", (reader.time.time() - 1, token))
        db.close()
        self.assertEqual(self.request('status', message_id=token)['message']['state'], 'failed')

    def test_reset_clears_the_server_queue_copy(self):
        legacy = reader.held_queue_db('fixture')
        with legacy:
            legacy.execute("INSERT INTO messages(key,sid,text,queued_at,state,origin,source_inode,receipt,created) VALUES (?,?,?,?,?,?,?,?,?)",
                           ('mirror-key', 'sid', 'stuck prompt', 1, 'submitted', 0, 1, '@mp-shared-v1:old:queued:1', 1))
        legacy.close()
        self.request('submit', message_id='message_fixture_0001', text='please review the offer')
        self.request('reset', reset_id='resetfixture00000001')
        legacy = reader.held_queue_db('fixture')
        state = legacy.execute("SELECT state FROM messages WHERE key='mirror-key'").fetchone()[0]
        legacy.close()
        self.assertEqual(state, 'cancelled')
        self.assertEqual(self.request('status', message_id='message_fixture_0001')['message']['state'], 'cancelled')


if __name__ == '__main__':
    unittest.main()
