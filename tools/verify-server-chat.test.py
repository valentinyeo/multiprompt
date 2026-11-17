import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ProviderTest(unittest.TestCase):
    def test_round_trip_and_clear_reach_the_provider_once(self):
        with tempfile.TemporaryDirectory() as home:
            program = ROOT / 'tools/verify-server-chat/provider.py'
            script = 'import os,runpy,sys; sys.argv=sys.argv[1:]; home=sys.argv.pop(1); os.environ.update(HOME=home,USERPROFILE=home); runpy.run_path(sys.argv[0],run_name="__main__")'
            requests = [dict(type='user', uuid=f'user-{index}', message=dict(content=[dict(type='text', text=text)])) for index, text in enumerate(('windows send proof', '/clear', 'windows after clear'))]
            result = subprocess.run([sys.executable, '-c', script, str(program), home, '--session-id', 'a1b2c3d4-2567-4000-8000-000000002567'], input=''.join(json.dumps(row) + '\n' for row in requests), text=True, capture_output=True, check=True, cwd=home)
            events = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertEqual(events[0]['subtype'], 'init')
            self.assertEqual([row['message']['content'][0]['text'] for row in events if row['type'] == 'assistant'], ['Server received: ' + request['message']['content'][0]['text'] for request in requests])
            receipts = [json.loads(line) for line in (Path(home) / 'provider-input.jsonl').read_text().splitlines()]
            self.assertEqual([row['text'] for row in receipts], ['windows send proof', '/clear', 'windows after clear'])
            self.assertEqual(len(list((Path(home) / '.claude/projects').glob('*/*.jsonl'))), 1)


if __name__ == '__main__':
    unittest.main()
