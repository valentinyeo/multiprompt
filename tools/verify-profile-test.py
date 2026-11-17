import base64
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
READER_SPEC = importlib.util.spec_from_file_location('fixture_reader', ROOT / 'src/chat_history_reader.py')
reader = importlib.util.module_from_spec(READER_SPEC)
READER_SPEC.loader.exec_module(reader)


class ProfileFixtureTest(unittest.TestCase):
    def setUp(self):
        generator = ROOT / '.claude/skills/verify-multiprompt/seed-profile.py'
        self.assertTrue(generator.is_file(), 'Desktop journeys need the shared real-size fixture generator')
        spec = importlib.util.spec_from_file_location('seed_profile', generator)
        self.fixture = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.fixture)

    def test_real_size_profile_is_deterministic_and_preserves_journey_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / 'home'
            settings = root / 'roaming/ZigShell'
            self.fixture.write_json(settings / 'session.json', dict(active_tab=1, tabs=[dict(name='Keep this journey')]))
            self.fixture.write_json(settings / 'windows.json', dict(windows=[dict(id='journey', name='Keep this workspace', restore=True)]))
            before = (settings / 'session.json').read_bytes()
            metadata = home / '.claude/sessions/4300.json'
            self.fixture.write_json(metadata, dict(sessionId='keep-the-existing-agent', pid=4300))
            before_metadata = metadata.read_bytes()
            first = self.fixture.seed(root, home)
            second = self.fixture.seed(root, home)
            self.assertEqual(first, second)
            self.assertEqual((settings / 'session.json').read_bytes(), before)
            self.assertEqual(metadata.read_bytes(), before_metadata)
            self.assertEqual(first['sessions'], 64)
            self.assertEqual(first['messages'], 19872)
            self.assertEqual(first['messagesPerLongChat'], 2400)
            self.assertEqual(len(json.loads((settings / 'windows.json').read_text())['windows']), 9)
            saved = [json.loads(file.read_text()) for file in sorted(settings.glob('session-fixture-v1-*.json'))]
            self.assertEqual(sum(len(document['tabs']) for document in saved), 64)
            self.assertEqual({tab['kind'] for document in saved for tab in document['tabs']}, {'cmd', 'tmux'})
            identities = [tab['csid'] for document in saved for tab in document['tabs']]
            self.assertEqual(len(set(identities)), 64)
            self.assertTrue(all(tab['tmux_session'].startswith('fixture-agent-') for document in saved for tab in document['tabs']))
            source = home / first['files'][0]['path']
            rows = [json.loads(line) for line in source.read_text().splitlines()]
            self.assertEqual(len(rows), 2400)
            self.assertEqual(len({row['uuid'] for row in rows}), 2400)
            self.assertIn('| Check |', rows[1]['message']['content'][0]['text'])
            self.assertIn('```python', rows[1]['message']['content'][0]['text'])
            image = rows[0]['message']['content'][1]['source']
            self.assertEqual(base64.b64decode(image['data']), (home / 'fixture-assets/sample.png').read_bytes())
            self.assertTrue(base64.b64decode(image['data']).startswith(b'\x89PNG\r\n\x1a\n'))
            sid = saved[0]['tabs'][0]['csid']
            with patch.object(reader, 'HOME', home):
                wire = reader.response(dict(id=7, codex=False, sid=sid, tmux='', cwd='', cached_sid='', inode=0, offset=0))
            self.assertIn('Synthetic chat 00 answer 1199', wire)
            self.assertIn('\thistory\tok\t', wire)

    def test_activate_has_busy_server_chats_and_refuses_existing_session(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture.seed(root, root / 'home', activate=True)
            saved = json.loads((root / 'roaming/ZigShell/session.json').read_text())
            state = json.loads((root / 'state/state.json').read_text())
            self.assertEqual(len(saved['tabs']), 8)
            self.assertTrue(all(tab['kind'] == 'tmux' and tab['cv'] for tab in saved['tabs']))
            self.assertEqual(state['mode'], 'busy')
            self.assertEqual(len(state['sids']), 8)
            with self.assertRaisesRegex(ValueError, 'without session.json'):
                self.fixture.seed(root, root / 'home', activate=True)


if __name__ == '__main__':
    unittest.main()
