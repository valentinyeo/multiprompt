import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('reader', ROOT / 'src/chat_history_reader.py')
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


class SettleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / '.claude/projects/-work-demo/sid.jsonl'
        self.path.parent.mkdir(parents=True)
        self.query = dict(op='settle', id=7, codex=False, sid='sid', tmux='term-1', cwd='/work/demo',
                          texts=['/unlazy please check the build', 'please check the build',
                                 'please run the tests', 'please review the build'], after_ms=1792250520000)
        self.addCleanup(patch.stopall)
        patch.object(reader, 'HOME', self.home).start()

    def write(self, events):
        with self.path.open('w') as output:
            for event in events:
                output.write(json.dumps(event) + '\n')

    def user(self, text, timestamp='2026-10-17T15:22:09.790Z', **extra):
        return dict(type='user', timestamp=timestamp, message=dict(role='user', content=text), **extra)

    def serve(self, query=None):
        env = dict(os.environ, HOME=str(self.home))
        env.pop('CLAUDE_CONFIG_DIR', None)
        result = subprocess.run([sys.executable, str(ROOT / 'src/chat_history_reader.py'), '--serve'],
                                input=json.dumps(self.query if query is None else query) + '\n',
                                text=True, capture_output=True, env=env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        replies = result.stdout.splitlines()
        self.assertEqual(len(replies), 1)
        reply = json.loads(replies[0])
        self.assertEqual(reply['id'], 7)
        wire = reply['wire'].splitlines()
        self.assertEqual(wire[-1], reader.END)
        return wire

    def transcript(self, size):
        filler = dict(type='assistant', timestamp='2026-10-17T15:21:00Z',
                      message=dict(role='assistant', content='neutral build output ' * 180))
        encoded = json.dumps(filler) + '\n'
        count = size // len(encoded) + 1
        with self.path.open('w') as output:
            for _ in range(count):
                output.write(encoded)
            records = [
                dict(type='queue-operation', operation='enqueue', timestamp='2026-10-17T15:22:08.790Z', content=self.query['texts'][0]),
                dict(type='queue-operation', operation='dequeue', timestamp='2026-10-17T15:22:09Z', content=''),
                self.user('<command-message>unlazy</command-message>\n<command-name>/unlazy</command-name>\n<command-args>please check the build</command-args>'),
                dict(type='queue-operation', operation='enqueue', timestamp='2026-10-17T15:22:31.990Z', content=self.query['texts'][1]),
                dict(type='attachment', timestamp='2026-10-17T15:22:30.990Z', attachment=dict(type='queued_command', prompt=self.query['texts'][1])),
                dict(type='queue-operation', operation='remove', timestamp='2026-10-17T15:22:32Z', content=self.query['texts'][1]),
                dict(type='queue-operation', operation='enqueue', timestamp='2026-10-17T15:22:33Z', content=self.query['texts'][2]),
                self.user(self.query['texts'][3], timestamp='2026-10-17T15:21:54.999Z'),
                self.user(self.query['texts'][0]),
            ]
            for event in records:
                output.write(json.dumps(event) + '\n')
            for _ in range(400):
                output.write(encoded)
        return count

    def assert_deliveries(self, wire, count):
        self.assertEqual(wire[0], '@mp\t7\tsettle\tok\t-\t4')
        self.assertEqual([json.loads(line) for line in wire[1:-1]], [
            dict(i=0, delivered_ms=1792250529790, line=count + 3),
            dict(i=1, delivered_ms=1792250550990, line=count + 5),
            dict(i=2, delivered_ms=0, line=0),
            dict(i=3, delivered_ms=0, line=0),
        ])

    def test_full_stream_finds_old_deliveries_not_queue_operations(self):
        count = self.transcript(2 * 1024 * 1024 + 1)
        self.assert_deliveries(self.serve(), count)

    def test_30mb_serve_finishes_under_two_seconds(self):
        count = self.transcript(30 * 1024 * 1024)
        start = time.monotonic()
        wire = self.serve()
        elapsed = time.monotonic() - start
        self.assert_deliveries(wire, count)
        print(f'30 MB settle: {self.path.stat().st_size} bytes, {elapsed:.3f}s (limit 2s)', flush=True)
        self.assertLess(elapsed, 2)

    def test_invalid_texts_are_explicit_errors(self):
        for texts in (None, 'text', [], ['x'] * 17, [1], ['x' * 65537], ['日' * 21846]):
            with self.subTest(kind=type(texts).__name__):
                self.assertEqual(self.serve(dict(self.query, texts=texts)),
                                 ['@mp\t7\tsettle\terror\tinvalid_texts\t0', reader.END])

    def test_normalization_blocks_meta_sidechain_and_partial_records(self):
        self.query['texts'] = ['please check the build', 'please run the tests', 'please review the build']
        self.write([
            self.user('please check the build', isMeta=True),
            self.user('please check the build', isSidechain=True),
            self.user([dict(type='text', text='<pasted_content id="x">\nplease\tcheck'),
                       dict(type='text', text='the build\n</pasted_content id="x">')], timestamp='2026-10-17T15:21:55Z'),
            dict(type='attachment', isMeta=True, timestamp='2026-10-17T15:22:30Z',
                 attachment=dict(type='queued_command', prompt='please run the tests')),
            self.user('please run the tests', timestamp='bad'),
        ])
        with self.path.open('a') as output:
            output.write('not json\n')
            output.write(json.dumps(self.user('please review the build')))
        wire = self.serve()
        self.assertEqual([json.loads(line) for line in wire[1:-1]], [
            dict(i=0, delivered_ms=1792250515000, line=3),
            dict(i=1, delivered_ms=0, line=0),
            dict(i=2, delivered_ms=0, line=0),
        ])

    def test_missing_identity_and_after_errors_keep_settle_wire(self):
        for query, reason in ((self.query, 'session transcript not found'),
                              (dict(self.query, sid='../bad'), 'read_failed'),
                              (dict(self.query, after_ms='bad'), 'invalid_after_ms')):
            self.assertEqual(self.serve(query), [f'@mp\t7\tsettle\terror\t{reason}\t0', reader.END])

    def test_valid_text_limits_and_codex_user_records(self):
        self.query['texts'] = ['x' * 65536] + ['please check the build'] * 15
        self.write([self.user('please check the build')])
        wire = self.serve()
        self.assertEqual(wire[0], '@mp\t7\tsettle\tok\t-\t16')
        rows = [json.loads(line) for line in wire[1:-1]]
        self.assertEqual(rows[0]['delivered_ms'], 0)
        self.assertTrue(all(row['line'] == 1 for row in rows[1:]))
        self.query.update(codex=True, texts=['please check the build'])
        path = self.home / '.codex/sessions/2026/rollout-2026-sid.jsonl'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(dict(type='response_item', timestamp='2026-10-17T15:22:09.790Z',
                                       payload=dict(type='message', role='user', content=[dict(type='input_text', text='please check the build')]))) + '\n')
        self.assertEqual(json.loads(self.serve()[1]), dict(i=0, delivered_ms=1792250529790, line=1))

    def test_shared_tmux_resolution_and_owner_delegation(self):
        self.write([self.user('please check the build')])
        with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', self.path)) as resolve:
            wire = reader.settle_response(dict(self.query, sid=''))
            self.assertIn('"delivered_ms":1792250529790', wire)
            resolve.assert_called_once_with('claude', 'term-1')
        owner = ('other', Path('/home/other'))
        delegated = '@mp\t7\tsettle\tok\t-\t0\n@@MP_END@@\n'
        with patch.object(reader, 'conversation_path', side_effect=PermissionError), \
                patch.object(reader, 'conversation_owner', return_value=owner), \
                patch.object(reader, 'owner_response', return_value=delegated) as response:
            self.assertEqual(reader.settle_response(self.query, 'source'), delegated)
            response.assert_called_once_with(self.query, owner, 'source')


class StuckOutboxShapeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / '.claude/projects/-work-projects/sid.jsonl'
        self.path.parent.mkdir(parents=True)

    def pad(self, output, size):
        line = json.dumps(dict(type='assistant', timestamp='2026-10-17T15:00:00Z', message=dict(role='assistant', content='')))
        chunk = (line[:-1] + ',"pad":"' + 'x' * (1 << 20) + '"}\n').encode()
        written = 0
        while written < size:
            output.write(chunk)
            written += len(chunk)

    def command(self, args, timestamp):
        return dict(type='user', timestamp=timestamp, message=dict(role='user', content=(
            '<command-message>unlazy</command-message>\n<command-name>/unlazy</command-name>\n<command-args>' + args + '</command-args>')))

    def queue(self, operation, content, timestamp):
        return dict(type='queue-operation', operation=operation, content=content, timestamp=timestamp)

    def test_three_stuck_messages_settle_from_outside_the_loaded_window(self):
        first = '/unlazy please list which helper sessions are running and which ones can be closed now'
        second = '/unlazy https://example.com/one.png delivery looks unconfirmed https://example.com/two.png why is it showing that?'
        third = '/unlazy the chat is out of sync and shows delivery unconfirmed https://example.com/three.png'
        records = [
            self.queue('enqueue', first, '2026-10-17T15:22:08.790Z'),
            self.queue('enqueue', second, '2026-10-17T15:22:31.990Z'),
            self.queue('enqueue', '/unlazy https://example.com/zero.png ' + third, '2026-10-17T15:24:47.279Z'),
            self.queue('dequeue', '', '2026-10-17T15:27:43.673Z'),
            self.command(first[len('/unlazy '):], '2026-10-17T15:27:44.064Z'),
            self.queue('dequeue', '', '2026-10-17T15:30:07.374Z'),
            self.command(second[len('/unlazy '):], '2026-10-17T15:30:07.948Z'),
            self.queue('dequeue', '', '2026-10-17T15:30:52.479Z'),
            self.command('https://example.com/zero.png ' + third, '2026-10-17T15:30:53.275Z'),
        ]
        with self.path.open('wb') as output:
            self.pad(output, 2 << 20)
            for record in records:
                output.write((json.dumps(record) + '\n').encode())
            self.pad(output, 4 << 20)
        self.assertGreater(self.path.stat().st_size - reader.TAIL_BYTES, 3 << 20)
        query = dict(op='settle', id=349, codex=False, sid='sid', tmux='projects', cwd='/work/projects',
                     texts=[first, second, third], after_ms=1792250528437)
        env = dict(os.environ, HOME=str(self.home))
        env.pop('CLAUDE_CONFIG_DIR', None)
        result = subprocess.run([sys.executable, str(ROOT / 'src/chat_history_reader.py'), '--serve'],
                                input=json.dumps(query) + '\n', text=True, capture_output=True, env=env, timeout=20)
        wire = json.loads(result.stdout.splitlines()[0])['wire'].splitlines()
        self.assertEqual(wire[0], '@mp\t349\tsettle\tok\t-\t3')
        delivered = [json.loads(line)['delivered_ms'] for line in wire[1:-1]]
        self.assertEqual(delivered, [1792250864064, 1792251007948, 1792251053275])


class RealStuckOutboxTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / '.claude/projects/-work-projects/sid.jsonl'
        self.path.parent.mkdir(parents=True)
        self.fixture = json.loads((ROOT / 'tools/fixtures/igsh349/stuck-outbox.json').read_text())

    def pad(self, output, until):
        while output.tell() < until:
            line = json.dumps(dict(type='assistant', timestamp='2026-10-17T15:00:00Z', message=dict(role='assistant', content='')))
            body = min(until - output.tell(), 1 << 20)
            output.write((line[:-1] + ',"pad":"' + 'x' * max(0, body - len(line) - 10) + '"}\n').encode())

    def test_real_outbox_entries_settle_at_their_real_delivery_times(self):
        window = self.fixture['chatcache_window']
        with self.path.open('wb') as output:
            for row in self.fixture['transcript']:
                self.pad(output, row['byte_offset'])
                output.write((json.dumps(row['record'], ensure_ascii=False) + '\n').encode())
                self.assertLess(output.tell(), window['start'])
            self.pad(output, window['offset'])
        messages = self.fixture['outbox']['queues'][0]['messages']
        self.assertEqual([(m['s'], m['x']) for m in messages], [(2, 1)] * 3)
        query = dict(op='settle', id=349, codex=False, sid='sid', tmux='projects', cwd='/work/projects',
                     texts=[m['t'] for m in messages], after_ms=min(m['w'] for m in messages))
        env = dict(os.environ, HOME=str(self.home))
        env.pop('CLAUDE_CONFIG_DIR', None)
        result = subprocess.run([sys.executable, str(ROOT / 'src/chat_history_reader.py'), '--serve'],
                                input=json.dumps(query) + '\n', text=True, capture_output=True, env=env, timeout=20)
        wire = json.loads(result.stdout.splitlines()[0])['wire'].splitlines()
        self.assertEqual(wire[0], '@mp\t349\tsettle\tok\t-\t3')
        delivered = [json.loads(line)['delivered_ms'] for line in wire[1:-1]]
        self.assertEqual(delivered, [1792250864064, 1792251007948, 1792251053275])


class RealChainedRestartTest(unittest.TestCase):
    def test_chained_commands_delivered_in_the_previous_transcript_settle(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        home = Path(temp.name)
        folder = home / '.claude/projects/-work-marketing'
        folder.mkdir(parents=True)
        fixture = json.loads((ROOT / 'tools/fixtures/igsh349/chained-restart.json').read_text())
        old = folder / 'old.jsonl'
        old.write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in fixture['previous_transcript']))
        current = folder / 'sid.jsonl'
        current.write_text(json.dumps(dict(type='user', timestamp='2026-10-17T19:00:00Z', message=dict(role='user', content='later work'))) + '\n')
        later = time.time()
        os.utime(current, (later, later))
        os.utime(old, (later - 60, later - 60))
        message = fixture['outbox']['messages'][0]
        self.assertEqual((message['s'], message['x']), (2, 1))
        query = dict(op='settle', id=5, codex=False, sid='sid', tmux='ht-marketing', cwd='/work/marketing',
                     texts=[message['t']], after_ms=message['w'])
        env = dict(os.environ, HOME=str(home))
        env.pop('CLAUDE_CONFIG_DIR', None)
        result = subprocess.run([sys.executable, str(ROOT / 'src/chat_history_reader.py'), '--serve'],
                                input=json.dumps(query) + '\n', text=True, capture_output=True, env=env, timeout=20)
        wire = json.loads(result.stdout.splitlines()[0])['wire'].splitlines()
        self.assertEqual(json.loads(wire[1])['delivered_ms'], 1792249460969)

    def test_igsh363_first_of_two_messages_joined_into_one_turn_settles(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        home = Path(temp.name)
        folder = home / '.claude/projects/-work-project'
        folder.mkdir(parents=True)
        fixture = json.loads((ROOT / 'tools/fixtures/igsh363/joined-turn.json').read_text())
        (folder / 'sid.jsonl').write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in fixture['transcript']))
        message = fixture['outbox']['messages'][0]
        query = dict(op='settle', id=6, codex=False, sid='sid', tmux='project-10', cwd='/work/project',
                     texts=[message['t'], 'cant see which time frame selecte and preselct 24 pls', 'which time frame'],
                     after_ms=message['a'])
        env = dict(os.environ, HOME=str(home))
        env.pop('CLAUDE_CONFIG_DIR', None)
        result = subprocess.run([sys.executable, str(ROOT / 'src/chat_history_reader.py'), '--serve'],
                                input=json.dumps(query) + '\n', text=True, capture_output=True, env=env, timeout=20)
        wire = json.loads(result.stdout.splitlines()[0])['wire'].splitlines()
        rows = [json.loads(line) for line in wire[1:4]]
        self.assertEqual([row['delivered_ms'] for row in rows[:2]], [1792268895365, 1792268895365])
        self.assertEqual(rows[2]['delivered_ms'], 0)

    def test_unchained_keeps_the_first_command_and_the_text(self):
        self.assertEqual(reader.settle_unchained('/a /b do it'), '/a do it')
        self.assertIsNone(reader.settle_unchained('/a do it'))
        self.assertIsNone(reader.settle_unchained('/a /b'))
        self.assertIsNone(reader.settle_unchained('plain text'))


if __name__ == '__main__':
    unittest.main()
