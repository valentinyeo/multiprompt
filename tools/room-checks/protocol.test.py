import json
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path


SERVICE = Path(__file__).resolve().parents[2] / 'src' / 'room_service.py'


def uid():
    return str(uuid.uuid4())


class ProtocolTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        host = self.call({'op': 'capabilities'})['host_uuid']
        self.members = [dict(alias=name, display_name=name.title(), host_uuid=host, provider='claude', provider_sid='provider-' + name, session_identity='session-' + name) for name in ('alice', 'bob')]
        created = self.call({'op': 'create', 'command_id': uid(), 'name': 'Room', 'members': self.members})
        self.room = created['event']['room_id']

    def exchange(self, requests):
        data = ''.join(json.dumps(request) + '\n' for request in requests)
        result = subprocess.run([sys.executable, str(SERVICE), '--serve', '--state-dir', self.temp.name], input=data, text=True, capture_output=True, timeout=20, check=True)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(len(requests), len(responses))
        return responses

    def call(self, request):
        response = self.exchange([request])[0]
        self.assertTrue(response['ok'], response)
        return response['result']

    def post(self, text, recipients):
        return {'op': 'post_human', 'command_id': uid(), 'room_id': self.room, 'expected_revision': 1, 'text': text, 'recipients': recipients}

    def snapshot(self):
        return self.call({'op': 'snapshot', 'room_id': self.room})

    def deliveries(self):
        return self.call({'op': 'deliveries', 'room_id': self.room, 'after': 0, 'through': None, 'limit': 200})['deliveries']

    def events(self, limit=200):
        after = 0
        events = []
        sizes = []
        for _ in range(100):
            response = self.exchange([{'op': 'events', 'room_id': self.room, 'after': after, 'limit': limit}])[0]
            self.assertTrue(response['ok'], response)
            sizes.append(len(json.dumps(response, ensure_ascii=True, sort_keys=True, separators=(',', ':')).encode('utf-8')))
            page = response['result']
            self.assertLessEqual(len(page['events']), limit)
            if not page['events']:
                self.assertEqual(after, page['next_after'])
                return events, sizes
            self.assertGreater(page['next_after'], after)
            events.extend(page['events'])
            after = page['next_after']
        self.fail('Events did not reach an empty page within 100 requests')

    def test_retry_and_restart_do_not_duplicate(self):
        request = self.post('Hello', [])
        first, repeat = self.exchange([request, request])
        self.assertTrue(first['ok'], first)
        self.assertEqual(first, repeat)
        self.assertEqual(first['result'], self.call(request))
        self.assertEqual(first['result']['deliveries'], self.deliveries())
        self.assertEqual([1, 2], [event['seq'] for event in self.events()[0]])

    def test_mentions_reject_mismatches_without_side_effects(self):
        ids = {member['alias']: member['id'] for member in self.snapshot()['members']}
        sent = self.call(self.post('Hello @alice', ['alice']))
        self.assertEqual([ids['alice']], sent['event']['recipients'])
        self.assertEqual([ids['alice']], [delivery['member_id'] for delivery in sent['deliveries']])
        before = (self.snapshot(), self.events()[0], self.deliveries())
        for recipients in ([], ['bob'], ['alice', 'bob']):
            self.assertEqual({'ok': False, 'error': 'invalid_mentions'}, self.exchange([self.post('Hello @alice', recipients)])[0])
        self.assertEqual(before, (self.snapshot(), self.events()[0], self.deliveries()))

    def test_edit_history_and_identities_survive_restart(self):
        original = self.snapshot()
        self.call(self.post('Before edit', []))
        edited = [dict(self.members[0], display_name='Alice renamed'), self.members[1]]
        self.call({'op': 'edit', 'command_id': uid(), 'room_id': self.room, 'expected_revision': 1, 'name': 'Renamed', 'members': edited})
        snapshot = self.snapshot()
        history = self.events()[0]
        self.assertEqual([member['id'] for member in original['members']], [member['id'] for member in snapshot['members']])
        self.assertEqual('Alice renamed', snapshot['members'][0]['display_name'])
        self.assertEqual(snapshot, self.snapshot())
        self.assertEqual(history, self.events()[0])

    def test_large_event_pages_have_no_gaps(self):
        expected = self.events()[0]
        for index in range(12):
            text = str(index).zfill(2) + ('\x01' * 10000) + ('x' * 50000)
            expected.append(self.call(self.post(text, []))['event'])
        events, sizes = self.events()
        self.assertGreater(len(sizes), 2)
        self.assertTrue(all(size <= 262144 for size in sizes))
        self.assertEqual(expected, events)
        self.assertEqual(list(range(1, len(expected) + 1)), [event['seq'] for event in events])
        self.assertEqual(len(events), len({event['id'] for event in events}))
        self.assertEqual(expected, self.events(limit=2)[0])


if __name__ == '__main__':
    unittest.main()
