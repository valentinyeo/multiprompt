from collections import Counter
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

shapes = None


def profile(completeness='complete-host-log'):
    return dict(name='chat-1', source_completeness=completeness, source_bytes=8192,
                source_records=10, conversation_messages=3,
                lengths_utf16=dict(user=[[150, 2]], assistant=[[300, 1]], tool=[], tool_result=[]),
                tool_record_bytes=[[400, 2]], max_tool_record_bytes=400,
                runner_lengths_utf16=[[150, 1]],
                layout_totals=dict(messages=3, lines=12, code_fences=2, table_lines=2, list_lines=2))


class ChatShapesTest(unittest.TestCase):
    def setUp(self):
        global shapes
        path = Path(__file__).with_name('chat-shapes.py')
        self.assertTrue(path.is_file(), 'Native switching requires its measured-size transcript generator')
        spec = importlib.util.spec_from_file_location('chat_shapes', path)
        shapes = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(shapes)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.path = self.root / 'fixture.jsonl'

    def generate(self, value=None, seed=1):
        result = shapes.generate(value or profile(), self.path, 'fixture-session', seed)
        rows = [json.loads(line) for line in self.path.read_bytes().splitlines()]
        return result, rows

    def test_complete_source_keeps_its_byte_budget_including_markers(self):
        result, rows = self.generate()
        self.assertEqual(self.path.stat().st_size, 8192)
        self.assertEqual(result['generated_bytes'], 8192)
        self.assertEqual(result['sha256'], hashlib.sha256(self.path.read_bytes()).hexdigest())
        self.assertEqual(rows[-1]['message']['content'][0]['text'], result['last_marker'])

    def test_complete_source_preserves_record_density_plus_two_markers(self):
        result, rows = self.generate()
        self.assertEqual(len(rows), 12)
        self.assertEqual(result['generated_records'], 12)
        self.assertEqual(sum(r['type'] == 'system' for r in rows), 5)

    def test_conversation_roles_and_lengths_survive_generation(self):
        result, rows = self.generate()
        observed = {'user': Counter(), 'assistant': Counter()}
        for row in rows[1:-1]:
            parts = row.get('message', {}).get('content', [])
            for part in parts:
                if part['type'] == 'text':
                    observed[row['type']][len(part['text'].encode('utf-16-le')) // 2] += 1
        self.assertEqual(observed, {'user': Counter({150: 2}), 'assistant': Counter({300: 1})})
        self.assertEqual(result['generated_conversation_messages'], 5)

    def test_generated_runner_messages_keep_the_measured_length_distribution(self):
        result, rows = self.generate()
        runner = Counter(len(p['text'].encode('utf-16-le')) // 2 for r in rows
                         for p in r.get('message', {}).get('content', [])
                         if p['type'] == 'text' and p['text'].startswith('[from '))
        self.assertEqual(runner, Counter({150: 1}))
        self.assertEqual(result['runner_messages'], 1)

    def test_partial_cache_is_not_inflated_to_its_source_cursor(self):
        value = profile('partial-desktop-cache-sample')
        value['source_bytes'] = 123652526
        result, rows = self.generate(value)
        self.assertLess(result['generated_bytes'], 8192)
        self.assertEqual(result['ignored_source_padding_bytes'], 0)
        self.assertFalse(any(row['type'] == 'system' for row in rows))
        self.assertEqual(result['source_completeness'], 'partial-desktop-cache-sample')

    def test_tool_records_keep_their_raw_byte_sizes(self):
        result, rows = self.generate()
        tools = [line for line in self.path.read_bytes().splitlines(keepends=True)
                 if any(p['type'] in ('tool_use', 'tool_result') for p in json.loads(line).get('message', {}).get('content', []))]
        self.assertEqual([len(raw) for raw in tools], [400, 400])
        self.assertEqual(result['tool_records'], 2)
        self.assertEqual(result['tool_records_expanded_to_valid_json'], 0)

    def test_too_small_tool_records_report_valid_json_expansion(self):
        value = profile()
        value['tool_record_bytes'] = [[1, 1]]
        value['max_tool_record_bytes'] = 1
        result, rows = self.generate(value)
        self.assertEqual(result['tool_records_expanded_to_valid_json'], 1)
        self.assertEqual(result['tool_records'], 1)
        self.assertTrue(any(p['type'] == 'tool_use' for r in rows for p in r.get('message', {}).get('content', [])))

    def test_oversized_tool_record_is_complete_and_newline_terminated(self):
        value = profile()
        value['tool_record_bytes'] = [[595494, 1]]
        value['max_tool_record_bytes'] = 595494
        value['source_bytes'] = 600000
        result, rows = self.generate(value)
        lines = self.path.read_bytes().splitlines(keepends=True)
        self.assertTrue(all(line.endswith(b'\n') for line in lines))
        self.assertEqual(max(map(len, lines)), 595494)
        self.assertEqual(result['tool_records'], 1)

    def test_same_seed_reproduces_bytes_and_different_seed_changes_markers(self):
        first, _ = self.generate(seed=1)
        raw = self.path.read_bytes()
        repeated, _ = self.generate(seed=1)
        self.assertEqual(raw, self.path.read_bytes())
        self.assertEqual(first, repeated)
        different, _ = self.generate(seed=2)
        self.assertNotEqual(first['sha256'], different['sha256'])
        self.assertNotEqual(first['last_marker'], different['last_marker'])

    def test_impossible_byte_budget_is_rejected_instead_of_silently_expanded(self):
        value = profile()
        value['source_bytes'] = 1
        with self.assertRaises(ValueError):
            self.generate(value)

    def test_empty_conversation_is_not_a_valid_switch_fixture(self):
        value = profile()
        value['conversation_messages'] = 0
        value['lengths_utf16']['user'] = []
        value['lengths_utf16']['assistant'] = []
        with self.assertRaises(ValueError):
            self.generate(value)

    def test_count_mismatch_is_rejected(self):
        value = profile()
        value['conversation_messages'] = 2
        with self.assertRaises(ValueError):
            self.generate(value)

    def test_runner_histogram_must_fit_the_measured_messages(self):
        value = profile()
        value['runner_lengths_utf16'] = [[151, 1]]
        with self.assertRaises(ValueError):
            self.generate(value)

    def test_seed_requires_five_sessions(self):
        state = self.root / 'state.json'
        state.write_text(json.dumps(dict(home=str(self.root / 'home'), sessions=['fixture-1'], sids={'fixture-1': 'sid-1'})))
        shape = self.root / 'shapes.json'
        shape.write_text(json.dumps(dict(schema=1, content_policy=shapes.POLICY, sessions=[profile()])))
        with self.assertRaises(ValueError):
            shapes.seed(shape, state)

    def test_seed_writes_five_actual_transcripts_and_a_matching_manifest(self):
        names = ['fixture-' + str(i) for i in range(5)]
        state = self.root / 'state.json'
        state.write_text(json.dumps(dict(home=str(self.root / 'home'), sessions=names, sids={name: 'sid-' + str(i) for i, name in enumerate(names)})), encoding='utf-8-sig')
        value = dict(schema=1, content_policy=shapes.POLICY, sessions=[profile() for _ in names])
        shape = self.root / 'shapes.json'
        shape.write_text(json.dumps(value))
        manifest = shapes.seed(shape, state)
        self.assertEqual(len(manifest['sessions']), 5)
        self.assertEqual(manifest, json.loads(state.with_name('chat-shape-manifest.json').read_text()))
        for i, item in enumerate(manifest['sessions']):
            path = self.root / 'home' / '.claude/projects' / ('C--verify-work' + str(i)) / ('sid-' + str(i) + '.jsonl')
            raw = path.read_bytes()
            self.assertEqual(len(raw), 8192)
            self.assertEqual(hashlib.sha256(raw).hexdigest(), item['sha256'])

    def test_command_line_seeds_the_saved_sessions_and_prints_its_manifest(self):
        names = ['fixture-' + str(i) for i in range(5)]
        state = self.root / 'state.json'
        state.write_text(json.dumps(dict(home=str(self.root / 'home'), sessions=names, sids={name: 'sid-' + str(i) for i, name in enumerate(names)})))
        shape = self.root / 'shapes.json'
        shape.write_text(json.dumps(dict(schema=1, content_policy=shapes.POLICY, sessions=[profile() for _ in names])))
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('chat-shapes.py')), str(shape), str(state)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(result.stdout)
        self.assertEqual(manifest, json.loads(state.with_name('chat-shape-manifest.json').read_text()))
        self.assertEqual(len(manifest['sessions']), 5)
        self.assertTrue(all(item['generated_bytes'] == 8192 and item['runner_messages'] == 1 for item in manifest['sessions']))

    def test_boundary_seed_shapes_keeps_process_metadata_and_generates_real_files(self):
        names = ['fixture-' + str(i) for i in range(5)]
        value = dict(name='shape-proof', fake=True, suggestion='generated suggestion', home=str(self.root / 'home'),
                     procRoot=str(self.root / 'proc'), sessions=names,
                     panes={name: 4300 + i for i, name in enumerate(names)},
                     sids={name: 'sid-' + str(i) for i, name in enumerate(names)})
        (self.root / 'state.json').write_text(json.dumps(value))
        shape = self.root / 'shapes.json'
        shape.write_text(json.dumps(dict(schema=1, content_policy=shapes.POLICY, sessions=[profile() for _ in names])))
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('boundary.py')), 'shell', 'seed-shapes', str(shape)],
                                env=dict(os.environ, MP_VERIFY_STATE=str(self.root)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads((self.root / 'chat-shape-manifest.json').read_text())
        self.assertEqual(len(manifest['sessions']), 5)
        for i in range(5):
            meta = json.loads((self.root / 'home' / '.claude/sessions' / (str(4300 + i) + '.json')).read_text())
            self.assertEqual(meta['sessionId'], 'sid-' + str(i))
            self.assertEqual(meta['cwd'], 'C:/verify/work' + str(i))
            self.assertEqual((self.root / 'proc' / str(4300 + i) / 'cmdline').read_bytes(), b'claude\0')
            self.assertEqual((self.root / 'home' / '.claude/projects' / ('C--verify-work' + str(i)) / ('sid-' + str(i) + '.jsonl')).stat().st_size, 8192)
        self.assertEqual(json.loads((self.root / 'claude.json').read_text())['mode'], 'idle')

    def test_public_statistics_contain_only_anonymous_names_and_numeric_shapes(self):
        path = Path(__file__).parents[1] / 'fixtures/IGSH-1040/chat-shapes.json'
        value = json.loads(path.read_text())
        self.assertEqual(set(value), {'schema', 'content_policy', 'sessions', 'limitations'})
        self.assertEqual(value['schema'], 1)
        self.assertEqual(value['content_policy'], shapes.POLICY)
        self.assertEqual(len(value['sessions']), 5)
        for index, item in enumerate(value['sessions'], 1):
            self.assertEqual(item['name'], 'chat-' + str(index))
            self.assertEqual(set(item), set(profile()))
            self.assertIn(item['source_completeness'], ('complete-host-log', 'partial-desktop-cache-sample'))
            self.assertEqual(set(item['lengths_utf16']), {'user', 'assistant', 'tool', 'tool_result'})
            histograms = [*item['lengths_utf16'].values(), item['tool_record_bytes'], item['runner_lengths_utf16']]
            for histogram in histograms:
                self.assertEqual(histogram, sorted(histogram))
                self.assertEqual(len({size for size, count in histogram}), len(histogram))
                self.assertTrue(all(type(size) is int and size >= 0 and type(count) is int and count > 0 for size, count in histogram))
            self.assertTrue(all(type(v) is int and v >= 0 for v in item['layout_totals'].values()))
            for key in ('source_bytes', 'source_records', 'conversation_messages', 'max_tool_record_bytes'):
                self.assertIs(type(item[key]), int)
                self.assertGreater(item[key], 0)
            self.assertEqual(sum(count for role in ('user', 'assistant') for _, count in item['lengths_utf16'][role]), item['conversation_messages'])
            available = Counter()
            for role in ('user', 'assistant'):
                available.update(dict(item['lengths_utf16'][role]))
            self.assertTrue(all(available[size] >= count for size, count in item['runner_lengths_utf16']))


if __name__ == '__main__':
    unittest.main()
