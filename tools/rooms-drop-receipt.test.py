import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHIM = ROOT / '.claude/skills/verify-multiprompt/rooms-drop-receipt.py'
CONFIG = Path('/tmp/mp-room-drop-receipt.json')
STATE = Path('/tmp/mp-room-drop-receipt-state.json')
LOG = Path('/tmp/mp-room-drop-receipt-log.jsonl')
BOOTSTRAP = "import room_service, room_bridge, re; re.fullmatch('x','x')"
COMMAND = '20000000-0000-4000-8000-000000000002'
ROOM = '30000000-0000-4000-8000-000000000003'
EVENT = '40000000-0000-4000-8000-000000000004'


def request(text='LOSTACK534', command=COMMAND):
    return dict(op='post_human', room_features=1, host_uuid='50000000-0000-4000-8000-000000000005', command_id=command, room_id=ROOM, expected_revision=3, text=text, recipients=['alpha'], bodies=[])


def payload(body, op='post_human'):
    line = json.dumps(dict(body, op=op), separators=(',', ':')).encode()
    return b'c291cmNl\nc291cmNl\n' + b'0' * 64 + b'\n' + b'cGF5bG9hZA==\n' + b'1' * 64 + b'\n' + line + b'\n'


class BoundaryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.server = Path(self.tmp.name) / 'server-python3'
        self.server.write_text(
            '#!/usr/bin/env python3\n'
            'import json, sys\n'
            'lines = [line for line in sys.stdin.buffer.read().split(b"\\n") if line.strip()]\n'
            'request = json.loads(lines[-1]) if lines else {}\n'
            f'print(json.dumps({{"ok": True, "result": {{"event": {{"id": "{EVENT}", "room_id": request.get("room_id"), "text": request.get("text")}}}}}}), flush=True)\n'
        )
        self.server.chmod(0o755)
        for path in (CONFIG, STATE, LOG):
            path.unlink(missing_ok=True)
        CONFIG.write_text(json.dumps(dict(text='LOSTACK534')))
        self.env = dict(os.environ, MP_DROP_RECEIPT_PYTHON=str(self.server))

    def tearDown(self):
        for path in (CONFIG, STATE, LOG):
            path.unlink(missing_ok=True)

    def run_shim(self, body):
        return subprocess.run([sys.executable, str(SHIM), '-u', '-c', BOOTSTRAP], input=body, capture_output=True, env=self.env)

    def entries(self):
        return [json.loads(line) for line in LOG.read_text().splitlines() if line.strip()]

    def test_a_committed_command_loses_one_receipt_and_the_retry_replays_the_same_command(self):
        first = self.run_shim(payload(request()))
        self.assertEqual(0, first.returncode)
        self.assertEqual(b'', first.stdout)
        self.assertIn(b'mp-room-drop-receipt: withheld the first receipt', first.stderr)
        state = json.loads(STATE.read_text())
        self.assertTrue(state['withheld'])
        receipt = json.loads(state['reply'])
        self.assertTrue(receipt['ok'])
        self.assertEqual(ROOM, receipt['result']['event']['room_id'])
        self.assertEqual('LOSTACK534', receipt['result']['event']['text'])
        second = self.run_shim(payload(request()))
        self.assertEqual(0, second.returncode)
        self.assertEqual(receipt, json.loads(second.stdout))
        entries = self.entries()
        self.assertEqual(2, len(entries))
        self.assertTrue(entries[0]['withheld'])
        self.assertFalse(entries[1]['withheld'])
        for entry in entries:
            self.assertEqual(COMMAND, entry['command_id'])
            self.assertEqual(ROOM, entry['room_id'])
            self.assertEqual('LOSTACK534', entry['text'])

    def test_another_body_and_another_operation_keep_their_receipt(self):
        other = self.run_shim(payload(request(text='OTHER534', command='60000000-0000-4000-8000-000000000006')))
        self.assertEqual(0, other.returncode)
        self.assertTrue(json.loads(other.stdout)['ok'])
        read = self.run_shim(payload(dict(room_id=ROOM, command_id=COMMAND), op='snapshot'))
        self.assertEqual(0, read.returncode)
        self.assertTrue(json.loads(read.stdout)['ok'])
        self.assertFalse(LOG.exists() and self.entries())

    def test_without_an_armed_boundary_the_command_keeps_its_receipt(self):
        CONFIG.unlink()
        plain = self.run_shim(payload(request()))
        self.assertEqual(0, plain.returncode)
        self.assertTrue(json.loads(plain.stdout)['ok'])


if __name__ == '__main__':
    unittest.main()
