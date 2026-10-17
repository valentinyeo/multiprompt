import base64
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import mp_complete as mp


class ConversationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent)
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.patch = patch.object(mp, 'HOME', self.home)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def file(self, agent, events, sid='abc-123'):
        if agent == 'claude':
            path = self.home / '.claude/projects/-work-demo' / (sid + '.jsonl')
        else:
            path = self.home / '.codex/sessions/2026/10/03' / ('rollout-2026-10-03-' + sid + '.jsonl')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('\n'.join(json.dumps(e) for e in events) + '\n', encoding='utf-8')
        return path

    def request(self, agent='claude', sid='abc-123'):
        with patch.object(mp, 'resolve_cwd', side_effect=AssertionError('no tmux')):
            return mp.request(f'7\ttranscript\t{agent}\tremote\t/work/demo\t{sid}\n')

    def test_claude_roles_markdown_unicode_and_timestamp(self):
        self.file('claude', [
            {'type': 'user', 'timestamp': '2026-10-03T09:12:00Z', 'message': {'role': 'user', 'content': 'A question'}},
            {'type': 'assistant', 'timestamp': '2026-10-03T09:13:00Z', 'message': {'role': 'assistant', 'content': [
                {'type': 'thinking', 'thinking': 'private'}, {'type': 'tool_use', 'input': 'secret'},
                {'type': 'text', 'text': '# Heading\n**bold** and Kraków\n```zig\nconst x = 1;\n```'}]}},
            {'type': 'user', 'message': {'role': 'user', 'content': [{'type': 'tool_result', 'content': 'not chat'}]}},
        ])
        wire = self.request()
        self.assertIn('@mp\t7\ttranscript\tok\tabc-123\t2', wire)
        row = wire.splitlines()[2].split('\t')
        self.assertEqual(row[1:3], ['assistant', '2026-10-03T09:13:00Z'])
        self.assertEqual(base64.b64decode(row[3]).decode(), '# Heading\n**bold** and Kraków\n```zig\nconst x = 1;\n```')

    def test_codex_excludes_duplicate_event_messages_and_tools(self):
        self.file('codex', [
            {'type': 'event_msg', 'payload': {'type': 'user_message', 'message': 'duplicate'}},
            {'type': 'response_item', 'timestamp': '2026-10-03T11:10:00Z', 'payload': {'type': 'message', 'role': 'user', 'content': [{'type': 'input_text', 'text': 'Question'}]}},
            {'type': 'response_item', 'payload': {'type': 'function_call', 'arguments': 'private'}},
            {'type': 'response_item', 'payload': {'type': 'message', 'role': 'assistant', 'content': [{'type': 'output_text', 'text': '*Answer*'}]}},
        ])
        wire = self.request('codex')
        self.assertRegex(wire, '\tok\tabc-123\t2\t[0-9]+[.][0-9]+\n')
        self.assertEqual(base64.b64decode(wire.splitlines()[2].split('\t')[3]), b'*Answer*')

    def test_missing_and_path_traversal_fail_closed(self):
        for sid in ['abc-123', '../private', '/etc/passwd', '-', '']:
            self.assertNotIn('\tok\t', self.request(sid=sid))

    def test_slash_command_markup_shows_as_typed_and_noise_is_hidden(self):
        cmd = ('<command-message>token-ladder</command-message>\n<command-name>/token-ladder</command-name>\n'
               '<command-args>we are behind\non  x</command-args>')
        self.file('claude', [
            {'type': 'user', 'timestamp': 't1', 'message': {'role': 'user', 'content': cmd}},
            {'type': 'user', 'timestamp': 't2', 'message': {'role': 'user', 'content': '<local-command-stdout>ok</local-command-stdout>'}},
            {'type': 'user', 'timestamp': 't3', 'message': {'role': 'user', 'content': '<local-command-caveat>Caveat: x</local-command-caveat>'}},
            {'type': 'user', 'timestamp': 't4', 'message': {'role': 'user', 'content': '<command-name>/clear</command-name><command-args></command-args>'}},
            {'type': 'user', 'timestamp': 't5', 'message': {'role': 'user', 'content': 'plain'}},
        ])
        rows = [line.split('\t') for line in self.request().splitlines() if line.startswith('M\t')]
        texts = [base64.b64decode(r[3]).decode() for r in rows]
        self.assertEqual(texts, ['/token-ladder we are behind\non  x', '/clear', 'plain'])

    def test_messages_sent_mid_turn_appear_as_user_rows(self):
        self.file('claude', [
            {'type': 'assistant', 'timestamp': '2026-10-08T09:44:20Z', 'message': {'role': 'assistant', 'content': 'working'}},
            {'type': 'queue-operation', 'operation': 'enqueue', 'content': 'not a row'},
            {'type': 'attachment', 'timestamp': '2026-10-08T09:44:33Z', 'attachment': {'type': 'queued_command', 'prompt': 'sent while busy'}},
            {'type': 'attachment', 'attachment': {'type': 'other', 'prompt': 'ignored'}},
        ])
        rows = [line.split('\t') for line in self.request().splitlines() if line.startswith('M\t')]
        self.assertEqual([r[1] for r in rows], ['assistant', 'user'])
        self.assertEqual(rows[1][2], '2026-10-08T09:44:33Z')
        self.assertEqual(base64.b64decode(rows[1][3]).decode(), 'sent while busy')

    def test_corruption_meta_and_sidechain_are_skipped(self):
        path = self.file('claude', [None, {'type': 'assistant', 'message': None},
            {'type': 'user', 'isMeta': True, 'message': {'role': 'user', 'content': 'hidden'}},
            {'type': 'assistant', 'isSidechain': True, 'message': {'role': 'assistant', 'content': 'hidden'}},
            {'type': 'assistant', 'message': {'role': 'assistant', 'content': 'visible'}}])
        with path.open('a') as f:
            f.write('{partial')
        self.assertRegex(self.request(), '\tok\tabc-123\t1\t[0-9]+[.][0-9]+\n')

    def test_newest_messages_fit_transport_budget(self):
        self.file('claude', [{'type': 'assistant', 'message': {'role': 'assistant', 'content': str(i) + 'x' * 20000}} for i in range(120)])
        wire = self.request()
        self.assertLess(len(wire), 384 * 1024)
        messages = [base64.b64decode(r.split('\t')[3]) for r in wire.splitlines()[1:-1]]
        self.assertTrue(messages[-1].startswith(b'119'))
        self.assertLessEqual(sum(map(len, messages)), mp.TRANSCRIPT_BYTES)

    def test_symlink_outside_provider_root_is_rejected(self):
        outside = self.home / 'private.jsonl'
        outside.write_text('{}')
        path = self.file('claude', [])
        path.unlink()
        path.symlink_to(outside)
        self.assertNotIn('\tok\t', self.request())

    def test_sentinel_and_tabs_inside_text_are_encoded(self):
        text = 'before\n@@MP_END@@\n\tafter'
        self.file('claude', [{'type': 'assistant', 'message': {'role': 'assistant', 'content': text}}])
        wire = self.request()
        self.assertEqual(wire.count(mp.END), 1)
        self.assertEqual(base64.b64decode(wire.splitlines()[1].split('\t')[3]).decode(), text)

    def test_claude_text_fragments_share_one_message(self):
        self.file('claude', [{'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': text}} for text in ['First', 'Second']])
        wire = self.request()
        self.assertRegex(wire, '\t1\t[0-9]+[.][0-9]+\n')
        self.assertEqual(base64.b64decode(wire.splitlines()[1].split('\t')[3]), b'First\nSecond')

    def test_incremental_offset_resets_on_truncation_replacement_and_rewrite(self):
        cached = {'identity': (1, 2), 'size': 100, 'mtime': 9, 'offset': 80}
        self.assertEqual(mp.transcript_read_offset(cached, (1, 2), 100, 9), 80)
        self.assertEqual(mp.transcript_read_offset(cached, (1, 2), 120, 10), 80)
        for identity, size, mtime in [((1, 3), 100, 9), ((1, 2), 99, 9), ((1, 2), 100, 10)]:
            self.assertIsNone(mp.transcript_read_offset(cached, identity, size, mtime))
        self.assertIsNone(mp.transcript_read_offset(None, (1, 2), 100, 9))

    def test_append_only_parses_new_complete_records_and_merges_fragments(self):
        event = lambda text: {'type': 'assistant', 'message': {'id': 'm1', 'role': 'assistant', 'content': text}}
        path = self.file('claude', [event('First')])
        self.assertEqual(mp.conversation_messages(path, 'claude')[0][2], b'First')
        with path.open('a') as f:
            f.write(json.dumps(event('Second')) + '\n')
        with patch.object(mp.json, 'loads', wraps=json.loads) as parse:
            self.assertEqual(mp.conversation_messages(path, 'claude')[0][2], b'First\nSecond')
            self.assertEqual(parse.call_count, 1)
        with patch.object(mp.json, 'loads', side_effect=AssertionError('unchanged records reparsed')):
            self.assertEqual(mp.conversation_messages(path, 'claude')[0][2], b'First\nSecond')

    def test_partial_record_is_retried_once_complete_without_duplicates(self):
        path = self.file('claude', [{'type': 'user', 'message': {'role': 'user', 'content': 'Question'}}])
        raw = json.dumps({'type': 'assistant', 'message': {'role': 'assistant', 'content': 'Answer'}})
        with path.open('a') as f:
            f.write(raw[:20])
        self.assertEqual(len(mp.conversation_messages(path, 'claude')), 1)
        with path.open('a') as f:
            f.write(raw[20:] + '\n')
        self.assertEqual([r[2] for r in mp.conversation_messages(path, 'claude')], [b'Question', b'Answer'])
        self.assertEqual(len(mp.conversation_messages(path, 'claude')), 2)

    def test_truncate_regrow_and_inode_replacement_drop_stale_rows(self):
        event = lambda text: {'type': 'assistant', 'message': {'role': 'assistant', 'content': text}}
        path = self.file('claude', [event('Old')])
        mp.conversation_messages(path, 'claude')
        path.write_text(json.dumps(event('A longer replacement')) + '\n')
        self.assertEqual([r[2] for r in mp.conversation_messages(path, 'claude')], [b'A longer replacement'])
        path.unlink()
        path.write_text(json.dumps(event('New inode')) + '\n')
        self.assertEqual([r[2] for r in mp.conversation_messages(path, 'claude')], [b'New inode'])
        path.write_text('{}\n')
        self.assertEqual(mp.conversation_messages(path, 'claude'), [])

    def test_incremental_cache_is_bounded_and_isolated_by_agent_and_path(self):
        with patch.object(mp, '_TRANSCRIPTS', mp.OrderedDict()), patch.object(mp, 'TRANSCRIPT_CACHE_LIMIT', 2):
            a = self.file('claude', [{'type': 'assistant', 'message': {'role': 'assistant', 'content': 'A'}}], 'a')
            b = self.file('claude', [{'type': 'assistant', 'message': {'role': 'assistant', 'content': 'B'}}], 'b')
            self.assertEqual(mp.conversation_messages(a, 'claude')[0][2], b'A')
            self.assertEqual(mp.conversation_messages(b, 'claude')[0][2], b'B')
            self.assertEqual(mp.conversation_messages(a, 'codex'), [])
            self.assertEqual(len(mp._TRANSCRIPTS), 2)
            self.assertNotIn((str(a), 'claude'), mp._TRANSCRIPTS)

    def test_unchanged_token_replies_same_and_changed_returns_rows_and_new_token(self):
        path = self.file('claude', [{'type': 'assistant', 'message': {'role': 'assistant', 'content': 'Answer'}}])
        token = f'{path.stat().st_size}.{path.stat().st_mtime_ns}'
        cwd = str(self.home / 'work/demo')
        with patch.object(mp, 'resolve_cwd', side_effect=AssertionError('no tmux')):
            same = mp.request(f'7\ttranscript\tclaude\t{token}\t{cwd}\tabc-123\n')
        self.assertIn(f'\tsame\tabc-123\t0\t{token}', same)
        self.assertEqual(len([line for line in same.splitlines() if line.startswith('M\t')]), 0)
        path.write_text(path.read_text(encoding='utf-8').replace('Answer', 'A longer answer'), encoding='utf-8')
        with patch.object(mp, 'resolve_cwd', side_effect=AssertionError('no tmux')):
            changed = mp.request(f'7\ttranscript\tclaude\t{token}\t{cwd}\tabc-123\n')
        self.assertIn('\tok\tabc-123\t1\t', changed)
        new_token = changed.splitlines()[0].split('\t')[6]
        self.assertNotEqual(token, new_token)


class TmuxResolutionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parent)
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.patch = patch.object(mp, 'HOME', self.home)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def test_process_table_reads_stat_and_cmdline(self):
        root = self.home / 'proc'
        (root / '100').mkdir(parents=True)
        (root / '100/stat').write_text('100 (tmux: server) S 1 100 100 0 -1 0', encoding='utf-8')
        (root / '100/cmdline').write_bytes(b'tmux\0new-session\0')
        (root / '101').mkdir()
        (root / '101/stat').write_text('101 (weird ) name) R 100 101 0', encoding='utf-8')
        (root / '101/cmdline').write_bytes(b'node\0/home/x/claude\0')
        table = mp.process_table(root)
        self.assertEqual(table[100], (1, ['tmux', 'new-session']))
        self.assertEqual(table[101][0], 100)
        self.assertEqual(table[101][1], ['node', '/home/x/claude'])

    def test_descendant_search_finds_nested_agent(self):
        table = {
            100: (1, ['tmux: server']),
            101: (100, ['-bash']),
            102: (101, ['node', '/home/x/.local/share/claude/versions/1/claude']),
            103: (101, ['codex']),
        }
        self.assertEqual(mp.agent_pid_for_panes([101], table, 'claude'), 102)
        self.assertEqual(mp.agent_pid_for_panes([101], table, 'codex'), 103)
        self.assertIsNone(mp.agent_pid_for_panes([101], table, 'cursor'))
        self.assertIsNone(mp.agent_pid_for_panes([999], table, 'claude'))

    def test_project_folder_encoding(self):
        self.assertEqual(mp.claude_project_folder('/home/user/projects/sample-project'),
                         '-home-user-projects-sample-project')
        self.assertEqual(mp.claude_project_folder('/a_b.c'), '-a-b-c')

    def test_newest_jsonl_picks_latest_mtime(self):
        first = self.home / 'a.jsonl'
        second = self.home / 'b.jsonl'
        first.write_text('{}', encoding='utf-8')
        second.write_text('{}', encoding='utf-8')
        os.utime(first, (1000, 1000))
        os.utime(second, (2000, 2000))
        self.assertEqual(mp.newest_jsonl([first, second]), second)
        self.assertIsNone(mp.newest_jsonl([]))

    def test_session_map_prefers_exact_sid_and_cwd(self):
        (self.home / '.claude/sessions').mkdir(parents=True)
        (self.home / '.claude/sessions/102.json').write_text(
            json.dumps({'pid': 102, 'sessionId': 'map-sid', 'cwd': '/work/mapped'}), encoding='utf-8')
        self.assertEqual(mp.claude_session_metadata(102), ('map-sid', '/work/mapped'))
        self.assertEqual(mp.claude_session_metadata(999), (None, None))

    def test_tmux_request_header_carries_resolved_sid_and_agent(self):
        path = self.home / '.claude/projects/-work-demo' / 'abc-123.jsonl'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(
            {'type': 'assistant', 'message': {'role': 'assistant', 'content': 'hi'}}) + '\n', encoding='utf-8')
        with patch.object(mp, 'resolve_tmux_agent', return_value=('abc-123', path)):
            wire = mp.request('7\ttranscript\tclaude\ttmux:term-1\t-\t-\n')
        self.assertRegex(wire, '@mp\t7\ttranscript\tok\tabc-123\t1\t[0-9]+[.][0-9]+\tclaude\tterm-1')

    def test_unresolved_tmux_request_reports_missing(self):
        with patch.object(mp, 'resolve_tmux_agent', return_value=None):
            wire = mp.request('7\ttranscript\tclaude\ttmux:term-1\t-\t-\n')
        self.assertIn('@mp\t7\ttranscript\tmissing\t-\t0\t-\tclaude\tterm-1', wire)

    def test_bad_tmux_name_is_rejected(self):
        for bad in ('tmux:bad name', 'tmux:' + 'x' * 80, 'tmux:term;1'):
            self.assertIn('\terror\t-\t0\n@@MP_END@@', mp.request(f'7\ttranscript\tclaude\t{bad}\t-\t-\n'))


if __name__ == '__main__':
    unittest.main()
