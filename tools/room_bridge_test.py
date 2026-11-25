import importlib.util
import sys
import tempfile
import unittest
import uuid
from pathlib import Path
from unittest import mock


root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'src'))
spec = importlib.util.spec_from_file_location('room_bridge', root / 'src' / 'room_bridge.py')
bridge_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge_module)


def uid():
    return str(uuid.uuid4())


class BridgeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.bridge = bridge_module.RoomBridge(self.temp.name)
        self.host = self.bridge.execute({'op': 'capabilities'})['host_uuid']
        self.sid = uid()
        self.member = {'alias': 'alpha', 'display_name': 'Alpha', 'host_uuid': self.host, 'provider': 'claude', 'provider_sid': self.sid, 'session_identity': 'claude:' + self.sid}
        self.create = {'op': 'create', 'host_uuid': self.host, 'command_id': uid(), 'name': 'Room', 'members': [self.member]}

    def tearDown(self):
        self.bridge.close()
        self.temp.cleanup()

    def error(self, code, request):
        with self.assertRaises(bridge_module.RoomError) as caught:
            self.bridge.execute(request)
        self.assertEqual(code, caught.exception.code)

    @mock.patch.object(bridge_module, 'host_status')
    def test_create_retry_and_host_scope(self, status):
        status.return_value = {'enabled': True}
        receipt = self.bridge.execute(self.create)
        status.assert_called_once_with(self.sid)
        status.reset_mock()
        self.assertEqual(receipt, self.bridge.execute(self.create))
        status.assert_not_called()
        self.error('command_conflict', {**self.create, 'name': 'Changed'})
        self.error('different_host', {**self.create, 'host_uuid': uid(), 'command_id': uid()})
        listing = self.bridge.execute({'op': 'list', 'host_uuid': self.host, 'after': 0, 'through': None, 'limit': 10})
        self.assertEqual(receipt['event']['room_id'], listing['rooms'][0]['id'])

    @mock.patch.object(bridge_module.Path, 'home')
    def test_member_catalog_includes_unopened_claude_chats_with_shown_names(self, home):
        import hashlib
        import json
        home.return_value = Path(self.temp.name)
        root = home.return_value / '.local/state/multiprompt'
        hosts = root / 'agent-host'
        hosts.mkdir(parents=True)
        for provider, sid, slot in [('claude', self.sid, 1), ('codex', uid(), 1), ('claude', uid(), 2)]:
            key = hashlib.sha256((provider + ':' + sid).encode()).hexdigest()[:32]
            (hosts / (key + '.config.json')).write_text(json.dumps(dict(provider=provider, sid=sid, tmux='chat-' + sid, spawn_host=slot, enabled=True, spawn_display='Original')))
        (root / 'chat-names.json').write_text(json.dumps({'chat-' + self.sid: {'sid': self.sid, 'name': 'Research Notes'}}))
        with mock.patch.object(bridge_module, 'host_status', return_value=dict(enabled=True, alive=False, owner=None)):
            result = self.bridge.execute({'op': 'members', 'host_uuid': self.host, 'slot': 1})
        self.assertEqual([dict(provider='claude', sid=self.sid, tmux='chat-' + self.sid, display_name='Research Notes', enabled=True, alive=False, owner=None)], result['members'])

    @mock.patch.object(bridge_module, 'scoped_runtime', return_value=False)
    def test_old_runtime_explains_how_to_recover(self, runtime):
        result = self.bridge.execute({'op': 'capabilities', 'room_messages': 1})
        self.assertEqual('runtime_upgrade_required', result['reason'])
        self.assertIn('room_features', result)

    def test_real_runtime_install_with_reader_symlink_supports_live_rooms(self):
        import json
        import os
        import subprocess
        with tempfile.TemporaryDirectory() as home, mock.patch.dict(os.environ, {'HOME': home}):
            installed = subprocess.run([sys.executable, '-u', str(root / 'src/chat_history_reader.py'), '--serve'], input=json.dumps(dict(id=1, op='engine_info')) + '\n', text=True, capture_output=True, timeout=15, check=False)
            self.assertEqual(0, installed.returncode, installed.stderr)
            runtime = Path(home) / '.multiprompt-runtime'
            self.assertTrue((runtime / 'reader.py').is_symlink())
            active = json.loads((runtime / 'active.json').read_text())
            reader = bridge_module.selected_reader()
            self.assertEqual(active['sha256'] + '.py', reader.name)
            self.assertFalse(reader.is_symlink())
            result = self.bridge.execute({'op': 'capabilities', 'room_messages': 1})
            self.assertTrue(result['live_send'])
            self.assertEqual(1, result['room_reply_protocol'])

    def test_host_stderr_is_retained_for_the_room_error(self):
        reader = Path(self.temp.name) / 'reader.py'
        reader.write_text('import sys\nsys.stderr.write("host unreachable: connection refused")\nsys.exit(1)\n')
        with mock.patch.object(bridge_module, 'selected_reader', return_value=reader):
            with self.assertRaises(bridge_module.RoomError) as caught:
                bridge_module.host_status(self.sid)
        self.assertEqual('runtime_unavailable', caught.exception.code)
        self.assertEqual('host unreachable: connection refused', caught.exception.detail)

    @mock.patch.object(bridge_module, 'scoped_runtime', return_value=True)
    @mock.patch.object(bridge_module, 'host_status')
    def test_old_running_host_is_named_before_a_new_post_is_recorded(self, status, runtime):
        status.return_value = dict(enabled=True, alive=True, owner='host', room_message_protocol=1)
        room = self.bridge.execute(self.create)['event']['room_id']
        request = dict(op='post_human', host_uuid=self.host, command_id=uid(), room_id=room, expected_revision=1, text='hello', recipients=[], room_features=1)
        self.error('room_host_upgrade_required', request)
        self.assertEqual(1, self.bridge.store.room(room)['seq'])
        status.return_value['room_features'] = [1]
        with mock.patch.object(self.bridge, 'sweep_pending'):
            accepted = self.bridge.execute(request)
        self.assertEqual('human', accepted['event']['type'])
        self.assertEqual(2, self.bridge.store.room(room)['seq'])

    @mock.patch.object(bridge_module, 'scoped_runtime', return_value=True)
    @mock.patch.object(bridge_module, 'host_status', return_value=dict(enabled=True, alive=False))
    def test_lost_post_ack_can_be_recovered_when_runtime_is_unavailable(self, status, runtime):
        room = self.bridge.execute(self.create)['event']['room_id']
        request = dict(op='post_human', host_uuid=self.host, command_id=uid(), room_id=room, expected_revision=1, text='hello', recipients=[], room_features=1)
        with mock.patch.object(self.bridge, 'sweep_pending'):
            receipt = self.bridge.execute(request)
            runtime.return_value = False
            self.assertEqual(receipt, self.bridge.execute(request))
        self.assertEqual(2, self.bridge.store.room(room)['seq'])

    def test_legacy_reader_cannot_claim_capability_gated_work(self):
        import json
        import os
        import subprocess
        legacy = os.environ.get('LEGACY_ROOM_ROOT')
        if not legacy:
            self.skipTest('the hosted baseline checkout supplies the legacy helper')
        room = self.bridge.store.execute({key: value for key, value in self.create.items() if key != 'host_uuid'})['event']['room_id']
        sent = self.bridge.store.execute(dict(op='post_human', command_id=uid(), room_id=room, expected_revision=1, text='@Alpha enhanced question', recipients=['alpha'], room_features=1))
        program = '''import json,sys,uuid
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]) / 'src'))
import room_bridge
room_bridge.scoped_runtime = lambda: True
room_bridge.host_status = lambda sid: dict(enabled=True, tmux='fixture')
def unavailable(query):
    raise AssertionError('legacy collector claimed capability-gated work')
room_bridge.runtime_request = unavailable
bridge = room_bridge.RoomBridge(sys.argv[2])
try:
    page = bridge.execute(dict(op='events', host_uuid=sys.argv[3], room_id=sys.argv[4], after=0, limit=200))
    assert len(page['events']) == 2
    assert set(page['events'][1]) == {'id','room_id','seq','type','text','revision','recipients'}
    result = bridge.execute(dict(op='post_human', host_uuid=sys.argv[3], command_id=str(uuid.uuid4()), room_id=sys.argv[4], expected_revision=1, text='Legacy follow-up', recipients=[]))
    print(json.dumps(result))
finally:
    bridge.close()
'''
        done = subprocess.run([sys.executable, '-c', program, str(Path(legacy).resolve()), self.temp.name, self.host, room], text=True, capture_output=True, timeout=15, check=False)
        self.assertEqual(0, done.returncode, done.stderr)
        self.assertEqual('pending', json.loads(done.stdout)['deliveries'][0]['status'])
        work = self.bridge.store.execute(dict(op='delivery_work', room_id=room, delivery_id=sent['deliveries'][0]['id']))
        self.assertEqual('@Alpha enhanced question', work['text'])
        deliveries = self.bridge.store.execute(dict(op='deliveries', room_id=room, after=0, through=None, limit=200))['deliveries']
        self.assertEqual(['pending', 'pending'], [delivery['status'] for delivery in deliveries])

    @mock.patch.object(bridge_module, 'host_status')
    def test_disabled_and_unsupported_paths_fail_closed(self, status):
        status.return_value = {'enabled': False}
        self.error('host_disabled', self.create)
        self.error('unsupported_provider', {**self.create, 'members': [{**self.member, 'provider': 'codex'}]})
        self.error('unsupported_remote_capability', {'op': 'post_human'})
        self.assertFalse(self.bridge.execute({'op': 'capabilities'})['live_send'])
        status.return_value = {'enabled': True}
        self.error('invalid_session', {**self.create, 'members': [{**self.member, 'session_identity': 'other'}]})

    @mock.patch.object(bridge_module, 'host_status', return_value={'enabled': True})
    def test_room_create_publishes_the_shared_helper_without_a_connected_chat(self, status):
        import json
        import os
        with tempfile.TemporaryDirectory() as home:
            runtime = Path(home, '.multiprompt-runtime')
            with mock.patch.dict(os.environ, {'HOME': home}):
                bridge_module.RUNTIME_SOURCE = (root / 'src/chat_history_reader.py').read_bytes()
                bridge_module.STORE_DIRECTORY = self.temp.name
                try:
                    self.assertFalse(Path(runtime, 'active.json').exists())
                    with self.assertRaises(bridge_module.RoomError):
                        bridge_module.selected_reader()
                    published = bridge_module.publish_runtime()
                    receipt = self.bridge.execute(self.create)
                    active = json.loads(Path(runtime, 'active.json').read_text())
                    reader = bridge_module.selected_reader()
                    repeated = bridge_module.publish_runtime()
                finally:
                    bridge_module.RUNTIME_SOURCE = b''
                    bridge_module.STORE_DIRECTORY = None
            mode = Path(runtime, 'active.json').stat().st_mode & 0o777
            installed = Path(runtime, reader.name).is_file()
        self.assertTrue(published)
        self.assertFalse(repeated)
        self.assertEqual(0o600, mode)
        self.assertEqual(active['sha256'] + '.py', reader.name)
        self.assertTrue(installed)
        self.assertEqual('created', receipt['event']['type'])
        self.assertEqual('Room', receipt['event']['name'])

    def test_room_send_starts_from_the_published_helper_without_a_connected_chat(self):
        import os
        with tempfile.TemporaryDirectory() as home:
            runtime = Path(home, '.multiprompt-runtime')
            with mock.patch.dict(os.environ, {'HOME': home}):
                bridge_module.RUNTIME_SOURCE = (root / 'src/chat_history_reader.py').read_bytes()
                bridge_module.STORE_DIRECTORY = self.temp.name
                try:
                    before = self.bridge.execute({'op': 'capabilities', 'room_messages': 1})
                    bridge_module.publish_runtime()
                    live = self.bridge.execute({'op': 'capabilities', 'room_messages': 1})
                finally:
                    bridge_module.RUNTIME_SOURCE = b''
                    bridge_module.STORE_DIRECTORY = None
            published = Path(runtime, 'active.json').is_file()
        self.assertTrue(published)
        self.assertFalse(before['live_send'])
        self.assertTrue(live['live_send'])
        self.assertEqual(1, live['room_reply_protocol'])

    def test_host_refusal_reports_what_the_helper_printed(self):
        reader = Path(self.temp.name) / 'reader.py'
        reader.write_text('import sys\nsys.stdout.write("unsafe runtime permissions")\nsys.exit(1)\n')
        with mock.patch.object(bridge_module, 'selected_reader', return_value=reader):
            with self.assertRaises(bridge_module.RoomError) as caught:
                bridge_module.host_status(self.sid)
        self.assertEqual('runtime_unavailable', caught.exception.code)
        self.assertEqual('unsafe runtime permissions', caught.exception.detail)

    def test_a_second_room_request_reuses_the_published_helper(self):
        import io
        import os
        from contextlib import redirect_stderr, redirect_stdout
        from unittest import mock
        fingerprint = 'c' * 64
        store = Path(self.temp.name, 'serve')
        with tempfile.TemporaryDirectory() as home:
            with mock.patch.dict(os.environ, {'HOME': home}):
                bridge_module.RUNTIME_FINGERPRINT = fingerprint
                bridge_module.RUNTIME_SOURCE = (root / 'src/chat_history_reader.py').read_bytes()
                bridge_module.STORE_DIRECTORY = self.temp.name
                try:
                    self.assertTrue(bridge_module.publish_runtime(), 'the first request publishes the helper')
                    bridge_module.RUNTIME_SOURCE = b''
                    stdin = mock.MagicMock()
                    stdin.buffer.readline.side_effect = [b'{"op":"capabilities"}\n', b'']
                    errors = io.StringIO()
                    with mock.patch.object(sys, 'stdin', stdin), mock.patch.object(bridge_module.subprocess, 'run') as install, redirect_stdout(io.StringIO()), redirect_stderr(errors):
                        bridge_module.serve(str(store), b'', fingerprint)
                    install.assert_not_called()
                finally:
                    bridge_module.RUNTIME_SOURCE = b''
                    bridge_module.RUNTIME_FINGERPRINT = ''
                    bridge_module.STORE_DIRECTORY = None
        self.assertIn('[room_bridge] runtime already published', errors.getvalue())


if __name__ == '__main__':
    unittest.main()
