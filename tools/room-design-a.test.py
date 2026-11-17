import importlib.util
import json
import sys
from pathlib import Path
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('room_service', ROOT / 'src/room_service.py')
service = importlib.util.module_from_spec(spec)
spec.loader.exec_module(service)


def uid():
    return str(uuid.uuid4())


class RoomsDesignA(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = service.RoomStore(self.temp.name)
        self.members = [dict(alias=name, display_name=name.title(), host_uuid=self.store.host_uuid,
                             provider='claude', provider_sid=name, session_identity='claude:' + name)
                        for name in ('alpha', 'beta')]
        self.room = self.store.execute(dict(op='create', command_id=uid(), name='Crew', members=self.members))['event']['room_id']

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def execute(self, request):
        try:
            return self.store.execute(request)
        except service.RoomError as error:
            return dict(error=error.code)

    def post(self, recipients, text='Plain message'):
        return dict(op='post_human', command_id=uid(), room_id=self.room, expected_revision=1,
                    text=text, recipients=recipients, target_mode='explicit')

    def snapshot(self):
        return self.store.execute(dict(op='snapshot', room_id=self.room))

    def test_to_one_session_does_not_require_inserting_a_mention(self):
        request = self.post(['alpha'])
        sent = self.execute(request)
        self.assertNotIn('error', sent, 'To one session must accept ordinary message text')
        members = {member['alias']: member['id'] for member in self.snapshot()['members']}
        self.assertEqual([members['alpha']], sent['event']['recipients'])
        self.assertEqual('Plain message', sent['event']['text'])
        self.assertEqual(sent, self.execute(request))
        self.assertEqual(1, self.store.db.execute('SELECT COUNT(*) FROM deliveries').fetchone()[0])

    def test_to_everyone_is_explicit_even_when_message_contains_an_at_sign(self):
        sent = self.execute(self.post([], 'Discuss @alpha with everyone'))
        self.assertNotIn('error', sent, 'The To chip, not message punctuation, chooses recipients')
        self.assertEqual(2, len(sent['deliveries']))
        self.assertEqual('Discuss @alpha with everyone', sent['event']['text'])
        rejected = self.execute(self.post(['missing']))
        self.assertEqual(dict(error='invalid_recipients'), rejected)

    def test_delete_removes_only_the_confirmed_room_and_is_retry_safe(self):
        other = self.store.execute(dict(op='create', command_id=uid(), name='Keep', members=self.members))['event']['room_id']
        sent = self.store.execute(dict(op='post_human', command_id=uid(), room_id=self.room,
                                       expected_revision=1, text='Keep sessions running', recipients=[]))
        original = json.loads(self.store.db.execute("SELECT body FROM commands WHERE json_extract(receipt, '$.event.room_id')=? AND json_extract(body, '$.op')='create'", (self.room,)).fetchone()[0])
        request = dict(op='delete_room', command_id=uid(), room_id=self.room, expected_revision=1)
        self.assertEqual(dict(deleted=self.room), self.execute(request))
        self.assertEqual(dict(deleted=self.room), self.execute(request))
        self.assertEqual('Keep', self.store.room(other)['name'])
        self.assertEqual(dict(error='room_not_found'), self.execute(dict(op='snapshot', room_id=self.room)))
        self.assertEqual(0, self.store.db.execute('SELECT COUNT(*) FROM events WHERE room_id=?', (self.room,)).fetchone()[0])
        self.assertEqual(0, self.store.db.execute('SELECT COUNT(*) FROM deliveries WHERE room_id=?', (self.room,)).fetchone()[0])
        self.assertEqual(2, len(self.store.members(other)))
        self.assertEqual(2, len(sent['deliveries']))
        self.assertEqual(dict(error='room_not_found'), self.execute(original))
        saved_commands = '\n'.join(row[0] + row[1] for row in self.store.db.execute('SELECT body, receipt FROM commands'))
        self.assertNotIn('Keep sessions running', saved_commands)

    def test_member_status_comes_from_delivery_and_reply_evidence(self):
        self.assertEqual({'alpha': 'not_asked', 'beta': 'not_asked'}, self.snapshot().get('member_states'))
        sent = self.execute(self.post(['alpha']))
        self.assertNotIn('error', sent)
        self.assertEqual({'alpha': 'queued', 'beta': 'not_asked'}, self.snapshot()['member_states'])
        delivery = sent['deliveries'][0]
        self.store.db.execute('INSERT INTO reply_progress VALUES (?, 1, ?, ?, 0, 0)', (delivery['id'], 'turn', '[]'))
        self.assertEqual('working', self.snapshot()['member_states']['alpha'])
        self.assertEqual(sent['event']['id'], self.snapshot().get('working_events', {}).get('alpha'))
        self.store.execute(dict(op='agent_reply', command_id=uid(), room_id=self.room,
                                parent_event_id=sent['event']['id'], member_id=delivery['member_id'],
                                response_id=uid(), text='Actual answer'))
        self.assertEqual({'alpha': 'replied', 'beta': 'not_asked'}, self.snapshot()['member_states'])
        stale = dict(op='delete_room', command_id=uid(), room_id=self.room, expected_revision=2)
        self.assertEqual(dict(error='revision_conflict'), self.execute(stale))
        self.assertEqual('Crew', self.snapshot()['name'])


class DeliveryWithoutAnOpenRoom(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(ROOT / 'src'))
        spec = importlib.util.spec_from_file_location('room_routing_fixture', ROOT / 'tools/room-routing.test.py')
        self.routing = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.routing)
        self.fixture = self.routing.RoutingTest(methodName='test_plain_message_reaches_every_agent_once')
        self.fixture.setUp()

    def tearDown(self):
        self.fixture.tearDown()

    def test_accepted_send_dispatches_without_opening_or_polling_the_conversation(self):
        fixture = self.fixture
        fixture.runtime.answer = False
        posted = fixture.post('Continue while the Room is not visible')
        self.assertEqual(['Continue while the Room is not visible'], fixture.sent_to('alpha'))
        self.assertEqual(['Continue while the Room is not visible'], fixture.sent_to('beta'))
        members = {member['id']: member for member in fixture.bridge.store.members(fixture.room)}
        for delivery in posted['deliveries']:
            scope = dict(host_uuid=fixture.host, room_id=fixture.room,
                         parent_event_id=posted['event']['id'], member_id=delivery['member_id'])
            fixture.runtime.reply(members[delivery['member_id']]['provider_sid'], delivery['id'], scope, 'Background answer')
        snapshot = fixture.bridge.execute(dict(op='snapshot', host_uuid=fixture.host, room_id=fixture.room, metadata=True))
        self.assertEqual({'alpha': 'replied', 'beta': 'replied'}, snapshot['member_states'])
        self.assertEqual('Background answer', snapshot['preview']['text'])
        self.assertEqual(2, len(fixture.runtime.submits))


if __name__ == '__main__':
    unittest.main()
