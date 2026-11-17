import base64
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
import uuid

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parents[2] / 'src'


class RoomsFixtureTest(unittest.TestCase):
    def test_seed_and_real_bridge_create_send_and_reply_without_duplicates(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'fixture'
            env = dict(os.environ, MP_ROOMS_FIXTURE=str(root))
            seeded = subprocess.run([sys.executable, str(HERE / 'rooms-fixture.py'), 'seed'], env=env, capture_output=True, text=True, check=True)
            manifest = json.loads(seeded.stdout)
            self.assertEqual(manifest['candidateCount'], 32)
            self.assertEqual(manifest['largestRoomEvents'], 1201)
            self.assertEqual(manifest['events'], 1476)
            self.assertEqual(len(manifest['rooms']), 12)
            cached = json.loads((root / 'session.json').read_text())
            self.assertEqual(cached['tabs'][0]['csid'], 'rooms-agent-00')
            db = sqlite3.connect(root / 'rooms.sqlite3')
            host = db.execute("SELECT value FROM meta WHERE key='host_uuid'").fetchone()[0]
            members = [dict(zip(('alias','display_name','host_uuid','provider','provider_sid','session_identity'), row)) for row in db.execute('SELECT alias,display_name,host_uuid,provider,provider_sid,session_identity FROM members LIMIT 2')]
            db.close()
            process = subprocess.Popen([sys.executable, str(HERE / 'rooms-fixture.py'), 'ssh', 'room_service'], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                for module in ('room_service', 'room_bridge'):
                    process.stdin.write(base64.b64encode((SOURCE / (module + '.py')).read_bytes()).decode() + '\n')
                process.stdin.write('a' * 64 + '\n')

                def call(request):
                    process.stdin.write(json.dumps(request) + '\n')
                    process.stdin.flush()
                    line = process.stdout.readline()
                    self.assertTrue(line, 'Room bridge closed unexpectedly')
                    reply = json.loads(line)
                    self.assertTrue(reply['ok'], reply)
                    return reply['result']

                self.assertTrue(call(dict(op='capabilities', room_messages=1))['live_send'])
                created = call(dict(op='create', host_uuid=host, command_id=str(uuid.uuid4()), name='Created through bridge', members=members))
                room = created['event']['room_id']
                post = dict(op='post_human', host_uuid=host, command_id=str(uuid.uuid4()), room_id=room, expected_revision=1, text='New user message', recipients=[])
                self.assertEqual(call(post), call(post))
                request = dict(op='events', host_uuid=host, room_id=room, after=0, limit=200)
                events = call(request)['events']
                self.assertEqual([event['type'] for event in events], ['created', 'human', 'agent_reply', 'agent_reply'])
                self.assertEqual([event['seq'] for event in events], [1, 2, 3, 4])
                self.assertEqual(events, call(request)['events'])
            finally:
                process.stdin.close()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                error = process.stderr.read()
                process.stdout.close()
                process.stderr.close()
            self.assertEqual(process.returncode, 0, error)


if __name__ == '__main__':
    unittest.main()
