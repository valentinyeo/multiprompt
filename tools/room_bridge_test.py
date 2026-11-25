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
        self.assertEqual([dict(provider='claude', sid=self.sid, display_name='Research Notes', enabled=True, alive=False, owner=None)], result['members'])

    @mock.patch.object(bridge_module, 'scoped_runtime', return_value=False)
    def test_old_runtime_explains_how_to_recover(self, runtime):
        result = self.bridge.execute({'op': 'capabilities', 'room_messages': 1})
        self.assertEqual('runtime_upgrade_required', result['reason'])
        self.assertIn('room_features', result)

    @mock.patch.object(bridge_module, 'host_status')
    def test_disabled_and_unsupported_paths_fail_closed(self, status):
        status.return_value = {'enabled': False}
        self.error('host_disabled', self.create)
        self.error('unsupported_provider', {**self.create, 'members': [{**self.member, 'provider': 'codex'}]})
        self.error('unsupported_remote_capability', {'op': 'post_human'})
        self.assertFalse(self.bridge.execute({'op': 'capabilities'})['live_send'])
        status.return_value = {'enabled': True}
        self.error('invalid_session', {**self.create, 'members': [{**self.member, 'session_identity': 'other'}]})


if __name__ == '__main__':
    unittest.main()
