import concurrent.futures
import importlib.util
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path


spec = importlib.util.spec_from_file_location('room_service', Path(__file__).resolve().parents[1] / 'src' / 'room_service.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def uid():
    return str(uuid.uuid4())


class RoomServiceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = self.temp.name
        self.store = module.RoomStore(self.path)
        self.host = self.store.execute({'op': 'capabilities'})['host_uuid']
        self.alice = self.member('alice')
        self.bob = self.member('bob')
        self.create = {'op': 'create', 'command_id': uid(), 'name': 'Room', 'members': [self.alice, self.bob]}
        self.created = self.store.execute(self.create)
        self.room = self.created['event']['room_id']

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def member(self, alias):
        return {'alias': alias, 'display_name': alias.title(), 'host_uuid': self.host, 'provider': 'claude', 'provider_sid': 'provider-' + alias, 'session_identity': 'session-incarnation-' + alias}

    def post(self, message, recipients, revision=1):
        return {'op': 'post_human', 'command_id': uid(), 'room_id': self.room, 'expected_revision': revision, 'text': message, 'recipients': recipients}

    def edit(self, members, revision=1):
        return {'op': 'edit_members', 'command_id': uid(), 'room_id': self.room, 'expected_revision': revision, 'members': members}

    def error(self, code, request):
        with self.assertRaises(module.RoomError) as caught:
            self.store.execute(request)
        self.assertEqual(caught.exception.code, code)

    def snapshot(self):
        return self.store.execute({'op': 'snapshot', 'room_id': self.room})

    def deliveries(self):
        return self.store.execute({'op': 'deliveries', 'room_id': self.room, 'after': 0, 'through': None, 'limit': 200})['deliveries']

    def test_persistence_idempotency_and_conflict(self):
        request = self.post('Hello', [])
        first = self.store.execute(request)
        self.assertEqual(first, self.store.execute(request))
        self.error('command_conflict', {**request, 'text': 'Changed'})
        self.store.close()
        self.store = module.RoomStore(self.path)
        self.assertEqual(self.host, self.store.execute({'op': 'capabilities'})['host_uuid'])
        self.assertEqual(first, self.store.execute(request))
        self.assertEqual(2, len(self.deliveries()))
        self.assertEqual(0, os.stat(Path(self.path) / 'rooms.sqlite3').st_mode & 0o077)

    def test_targeting_and_unknown_mentions(self):
        sent = self.store.execute(self.post('Hi @alice', ['alice']))
        members = {m['alias']: m['id'] for m in self.snapshot()['members']}
        self.assertEqual([members['alice']], sent['event']['recipients'])
        self.error('invalid_text', self.post('   ', []))
        self.error('invalid_mentions', self.post('Hi @missing', []))
        self.error('invalid_mentions', self.post('Hi @alice', ['bob']))
        self.assertEqual(2, len(self.store.execute(self.post(r'Email a@example.org and \@alice', []))['deliveries']))
        self.assertEqual(2, len(self.store.execute(self.post('@alice and @bob', ['alice', 'bob']))['deliveries']))

    def test_membership_cancellation_and_scoped_reply(self):
        sent = self.store.execute(self.post('Hello', []))
        members = {m['alias']: m['id'] for m in self.snapshot()['members']}
        reply = {'op': 'agent_reply', 'command_id': uid(), 'room_id': self.room, 'parent_event_id': sent['event']['id'], 'member_id': members['alice'], 'response_id': uid(), 'text': 'Answer'}
        result = self.store.execute(reply)
        self.assertEqual([], result['deliveries'])
        self.assertEqual(result, self.store.execute({**reply, 'command_id': uid()}))
        self.error('response_conflict', {**reply, 'command_id': uid(), 'text': 'Different'})
        self.error('invalid_scope', {**reply, 'command_id': uid(), 'response_id': uid(), 'parent_event_id': result['event']['id']})
        self.store.execute(self.edit([self.bob, self.member('carol')]))
        deliveries = self.deliveries()
        self.assertEqual('cancelled', next(d['status'] for d in deliveries if d['member_id'] == members['alice']))
        self.assertEqual(2, len(deliveries))
        self.error('invalid_scope', {**reply, 'command_id': uid(), 'response_id': uid()})
        self.error('revision_conflict', self.post('stale', []))
        self.assertEqual(2, len(self.store.execute(self.post('new', [], 2))['deliveries']))

    def test_delivery_work_is_stable_and_scoped(self):
        request = self.post('Hello @alice', ['alice'])
        receipt = self.store.execute(request)
        delivery = receipt['deliveries'][0]
        work_request = {'op': 'delivery_work', 'room_id': self.room, 'delivery_id': delivery['id']}
        work = self.store.execute(work_request)
        self.assertEqual(delivery['id'], work['message_id'])
        self.assertEqual(receipt['event']['id'], work['parent_event_id'])
        self.assertEqual(self.host, work['host_uuid'])
        self.assertEqual(self.alice['session_identity'], work['session_identity'])
        self.assertEqual(request['text'], work['text'])
        self.assertEqual(work, self.store.execute(work_request))
        self.store.close()
        self.store = module.RoomStore(self.path)
        self.assertEqual(work, self.store.execute(work_request))
        self.store.execute(self.edit([self.bob]))
        self.error('invalid_scope', work_request)
        self.error('invalid_scope', {**work_request, 'delivery_id': uid()})

    def test_rollback_and_pagination(self):
        before = self.snapshot()
        self.error('duplicate_member', self.edit([self.alice, self.alice]))
        self.assertEqual(before, self.snapshot())
        self.store.db.execute("CREATE TRIGGER reject_delivery BEFORE INSERT ON deliveries BEGIN SELECT RAISE(ABORT, 'forced'); END")
        request = self.post('rollback', [])
        with self.assertRaises(sqlite3.IntegrityError):
            self.store.execute(request)
        self.assertEqual(before, self.snapshot())
        self.store.db.execute('DROP TRIGGER reject_delivery')
        self.store.execute(request)
        self.store.execute(self.post('next', []))
        first = self.store.execute({'op': 'events', 'room_id': self.room, 'after': 0, 'limit': 2})
        second = self.store.execute({'op': 'events', 'room_id': self.room, 'after': first['next_after'], 'limit': 2})
        self.assertEqual([1, 2, 3], [e['seq'] for e in first['events'] + second['events']])

    def test_event_pages_obey_byte_limit_without_skips(self):
        for i in range(7):
            self.store.execute(self.post(str(i) + ('\x01' * 19000 if i % 2 else 'x' * 60000), []))
        after = 0
        seen = []
        pages = 0
        while True:
            page = self.store.execute({'op': 'events', 'room_id': self.room, 'after': after, 'limit': 200})
            self.assertLessEqual(len(module.encoded({'ok': True, 'result': page}).encode('utf-8')), 262144)
            if not page['events']:
                break
            pages += 1
            seen.extend(event['seq'] for event in page['events'])
            after = page['next_after']
        self.assertGreater(pages, 1)
        self.assertEqual(list(range(1, 9)), seen)

    def test_concurrent_commands(self):
        requests = [self.post('message ' + str(i), []) for i in range(12)]
        def submit(request):
            store = module.RoomStore(self.path)
            try:
                return store.execute(request)
            finally:
                store.close()
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(submit, requests + [requests[0]]))
        self.assertEqual(results[0], results[-1])
        self.assertEqual(list(range(2, 14)), sorted(r['event']['seq'] for r in results[:-1]))
        self.assertEqual(24, len(self.deliveries()))

    def test_capabilities_and_validation(self):
        self.assertEqual(1, self.store.execute({'op': 'capabilities'})['room_protocol'])
        self.assertEqual(self.room, self.store.execute({'op': 'list', 'after': 0, 'through': None, 'limit': 10})['rooms'][0]['id'])
        self.error('invalid_fields', {'op': 'capabilities', 'extra': True})
        self.error('invalid_number', self.post('text', [], True))
        self.error('invalid_id', {**self.create, 'command_id': '0'})
        changed = dict(self.alice, provider_sid='another')
        self.error('binding_immutable', self.edit([changed, self.bob]))

    def test_provider_identity(self):
        other = dict(self.alice, alias='other', provider='codex')
        result = self.store.execute(self.edit([self.alice, self.bob, other]))
        members = {m['alias']: m for m in result['event']['members']}
        self.assertEqual('claude', members['alice']['provider'])
        self.assertEqual('codex', members['other']['provider'])
        self.assertEqual(members, {m['alias']: m for m in self.snapshot()['members']})
        duplicate = dict(other, alias='duplicate')
        self.error('duplicate_member', self.edit([self.alice, self.bob, other, duplicate], 2))
        different_incarnation = dict(self.alice, alias='duplicate', session_identity='different-incarnation')
        self.error('duplicate_member', self.edit([self.alice, self.bob, other, different_incarnation], 2))
        changed = dict(self.alice, provider='codex')
        self.error('binding_immutable', self.edit([changed, self.bob], 2))
        self.error('invalid_provider', self.edit([dict(self.alice, provider='unknown')], 2))
        self.error('different_host', self.edit([dict(self.alice, host_uuid=uid())], 2))
        self.error('binding_immutable', self.edit([dict(self.alice, session_identity='new-incarnation'), self.bob], 2))
        legacy = dict(self.alice)
        legacy['tmux_identity'] = legacy.pop('session_identity')
        self.error('invalid_fields', self.edit([legacy, self.bob], 2))
        old_id = members['alice']['id']
        self.store.execute(self.edit([self.bob, other], 2))
        readded = self.store.execute(self.edit([dict(self.alice, session_identity='new-incarnation'), self.bob, other], 3))
        replacement = next(m for m in readded['event']['members'] if m['alias'] == 'alice')
        self.assertNotEqual(old_id, replacement['id'])
        self.assertEqual('new-incarnation', replacement['session_identity'])

    def test_catalog_and_delivery_watermarks_survive_reopen(self):
        self.store.execute({**self.create, 'command_id': uid(), 'name': 'Second'})
        self.store.execute({**self.create, 'command_id': uid(), 'name': 'Third'})
        catalog = self.store.execute({'op': 'list', 'after': 0, 'through': None, 'limit': 1})
        self.store.execute(self.post('first', []))
        self.store.execute(self.post('second', []))
        snapshot = self.snapshot()
        request = {'op': 'deliveries', 'room_id': self.room, 'after': 0, 'through': snapshot['seq'], 'limit': 1}
        first = self.store.execute(request)
        self.assertEqual('pending', first['deliveries'][0]['status'])
        self.store.execute(self.edit([self.alice]))
        self.store.execute(self.post('later', [], 2))
        self.store.execute({**self.create, 'command_id': uid(), 'name': 'Fourth'})
        self.store.close()
        self.store = module.RoomStore(self.path)
        rooms = catalog['rooms'][:]
        after = catalog['next_after']
        while True:
            page = self.store.execute({'op': 'list', 'after': after, 'through': catalog['through'], 'limit': 1})
            if not page['rooms']:
                break
            rooms.extend(page['rooms'])
            after = page['next_after']
        self.assertEqual(['Room', 'Second', 'Third'], [room['name'] for room in rooms])
        self.assertEqual(sorted(room['creation_seq'] for room in rooms), [room['creation_seq'] for room in rooms])
        deliveries = first['deliveries'][:]
        after = first['next_after']
        while True:
            page = self.store.execute({**request, 'after': after})
            if not page['deliveries']:
                break
            deliveries.extend(page['deliveries'])
            after = page['next_after']
        self.assertEqual(4, len(deliveries))
        self.assertEqual(['pending', 'cancelled', 'pending', 'cancelled'], [d['status'] for d in deliveries])
        self.assertEqual(4, len({d['id'] for d in deliveries}))
        self.assertTrue(all(d['event_seq'] <= snapshot['seq'] for d in deliveries))
        self.assertEqual(5, len(self.deliveries()))
        self.error('invalid_cursor', {'op': 'list', 'after': 1, 'through': None, 'limit': 1})
        self.error('invalid_cursor', {**request, 'through': snapshot['seq'] + 100})

    def test_invalid_unicode_embedding(self):
        self.error('invalid_json', self.post('\ud800', []))
        self.error('invalid_json', {**self.create, 'name': '\udfff'})

    def test_serve_oversized_line_then_valid_request(self):
        script = Path(__file__).resolve().parents[1] / 'src' / 'room_service.py'
        with tempfile.TemporaryDirectory() as state:
            result = subprocess.run([sys.executable, str(script), '--serve', '--state-dir', state], input=b'{' + b'x' * 300000 + b'\n{"op":"capabilities"}\n', stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20, check=True)
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(2, len(responses))
        self.assertEqual({'ok': False, 'error': 'request_too_large'}, responses[0])
        self.assertTrue(responses[1]['ok'])
        self.assertEqual(1, responses[1]['result']['room_protocol'])


if __name__ == '__main__':
    unittest.main()
