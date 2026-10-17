import base64
import importlib.util
import json
import os
import selectors
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('reader', ROOT / 'src/chat_history_reader.py')
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


class HistoryReaderTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.addCleanup(patch.stopall)
        patch.object(reader, 'HOME', self.home).start()
        self.path = self.home / '.claude/projects/-work-demo/sid.jsonl'
        self.path.parent.mkdir(parents=True)
        self.query = dict(id=7, codex=False, sid='sid', tmux='term-1', cwd='/work/demo',
                          cached_sid='', inode=0, offset=0)

    def event(self, text='hello', **extra):
        return dict(type='assistant', message=dict(role='assistant', content=[dict(type='text', text=text)]), **extra)

    def write(self, *events):
        self.path.write_text(''.join(json.dumps(e) + '\n' for e in events))

    def read(self):
        wire = reader.response(self.query)
        lines = wire.splitlines()
        self.assertEqual(lines[-1], reader.END)
        fields = lines[0].split('\t')
        self.assertEqual(fields[:4], ['@mp', '7', 'history', 'ok'])
        if fields[13] != 'older':
            self.query.update(cached_sid=fields[4], inode=int(fields[7]), offset=int(fields[6]), mtime=int(fields[11]), probe=fields[12])
        self.query['start'] = int(fields[14])
        self.query.pop('before', None)
        return fields, [json.loads(line) for line in lines[1:-1]]

    def owner(self, name='secondary', uid=1001, home='/home/secondary'):
        return types.SimpleNamespace(pw_name=name, pw_uid=uid, pw_dir=home)

    def test_owner_is_only_a_nonroot_account_matching_an_unambiguous_home(self):
        with patch.object(reader.pwd, 'getpwnam', return_value=self.owner()):
            self.assertEqual(reader.conversation_owner('/home/secondary/projects/demo'), ('secondary', Path('/home/secondary')))
            for cwd in ['/work/demo', '/home/secondary/../root/demo', '/home/-root/demo', '/home/secondary']:
                self.assertIsNone(reader.conversation_owner(cwd))
        with patch.object(reader.pwd, 'getpwnam', return_value=self.owner(uid=0)):
            self.assertIsNone(reader.conversation_owner('/home/secondary/demo'))
        with patch.object(reader.pwd, 'getpwnam', return_value=self.owner(home='/root')):
            self.assertIsNone(reader.conversation_owner('/home/secondary/demo'))
        with patch.object(reader.pwd, 'getpwnam', side_effect=KeyError):
            self.assertIsNone(reader.conversation_owner('/home/unknown/demo'))

    def test_configured_and_xdg_claude_roots_and_safe_symlink_containment(self):
        for directory in [self.home / 'custom-config', self.home / '.config/claude']:
            path = directory / 'projects/-work-demo/configured.jsonl'
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(self.event('configured')) + '\n')
            with patch.dict('os.environ', {'CLAUDE_CONFIG_DIR': str(directory)}):
                self.assertEqual(reader.conversation_path('claude', 'configured', '/work/demo'), path)
            path.unlink()
        with patch.dict('os.environ', {'CLAUDE_CONFIG_DIR': ''}):
            path.write_text(json.dumps(self.event('xdg')) + '\n')
            self.assertEqual(reader.conversation_path('claude', 'configured', '/work/demo'), path)
        outside = self.home / 'outside.jsonl'
        outside.write_text('{}\n')
        self.path.symlink_to(outside)
        self.assertIsNone(reader.conversation_path('claude', 'sid', '/work/demo'))

    def test_owner_home_is_read_directly_before_sudo(self):
        owner_home = self.home / 'owner'
        path = owner_home / '.claude/projects/-work-demo/sid.jsonl'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(self.event('owner readable')) + '\n')
        with patch.object(reader, 'conversation_owner', return_value=('secondary', owner_home)), \
                patch.object(reader.subprocess, 'run', side_effect=AssertionError('no sudo for readable files')):
            wire = reader.response(self.query, source='reader source')
        self.assertIn('owner readable', wire)
        self.write(self.event('own readable'))
        with patch.object(reader, 'conversation_owner', return_value=('secondary', owner_home)):
            self.assertIn('own readable', reader.response(self.query))

    def test_path_probe_distinguishes_denied_from_missing_and_tries_other_roots(self):
        self.write(self.event('denied'))
        original_open = Path.open
        def denied_open(path, *args, **kwargs):
            if path == self.path:
                raise PermissionError('not readable')
            return original_open(path, *args, **kwargs)
        with patch.object(Path, 'open', denied_open):
            with self.assertRaises(PermissionError):
                reader.conversation_path('claude', 'sid', '/work/demo')
        alternate = self.home / '.config/claude/projects/-work-demo/sid.jsonl'
        alternate.parent.mkdir(parents=True)
        alternate.write_text(json.dumps(self.event('alternative readable')) + '\n')
        with patch.object(Path, 'open', denied_open):
            self.assertEqual(reader.conversation_path('claude', 'sid', '/work/demo'), alternate)

    def test_permission_denied_reexecutes_same_source_and_query_without_shell_or_prompt(self):
        expected = '@mp\t7\thistory\tok\tsid\t0\n{"text":"owner rows"}\n@@MP_END@@\n'
        with patch.object(reader, 'conversation_owner', return_value=('secondary', Path('/home/secondary'))), \
                patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                patch.object(reader.subprocess, 'run', side_effect=[subprocess.CompletedProcess([], 0), subprocess.CompletedProcess([], 0, expected, '')]) as run:
            self.assertEqual(reader.response(self.query, source=reader.READER_SOURCE), expected)
        self.assertEqual(run.call_args_list[0].args[0], ['sudo', '-n', '-u', 'secondary', '--', 'true'])
        command = run.call_args_list[1].args[0]
        self.assertEqual(command[:8], ['sudo', '-n', '-H', '-u', 'secondary', '--', 'python3', '-'])
        self.assertEqual(json.loads(base64.b64decode(command[8])), self.query)
        self.assertEqual(command[9], '--owner')
        self.assertEqual(run.call_args_list[1].kwargs['input'], reader.READER_SOURCE)
        self.assertNotIn('shell', run.call_args_list[1].kwargs)

    def test_sudo_unavailable_timeout_and_owner_reexec_never_prompt_or_loop(self):
        for failure in [subprocess.CompletedProcess([], 1), FileNotFoundError(), subprocess.TimeoutExpired('sudo', 3)]:
            effect = failure if isinstance(failure, Exception) else [failure]
            with patch.object(reader, 'conversation_owner', return_value=('secondary', Path('/home/secondary'))), \
                    patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                    patch.object(reader.subprocess, 'run', side_effect=effect) as run:
                wire = reader.response(self.query, source=reader.READER_SOURCE)
            self.assertIn('\thistory\tmissing\t', wire)
            self.assertIn('permission denied', wire)
            self.assertEqual(run.call_count, 1)
        with patch.object(reader, 'conversation_owner', return_value=('secondary', Path('/home/secondary'))), \
                patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                patch.object(reader, 'resolve_tmux_agent', return_value=None), \
                patch.object(reader.subprocess, 'run', side_effect=AssertionError('must not loop')):
            self.assertIn('permission denied', reader.response(self.query, reader.READER_SOURCE, as_owner=True))

    def test_missing_reason_and_stdin_source_can_reexecute_without_a_local_reader_file(self):
        self.query['tmux'] = ''
        self.assertIn('session transcript not found', reader.response(self.query))
        self.write(self.event('reexecuted stdin'))
        with patch.dict('os.environ', {'HOME': str(self.home)}):
            encoded = base64.b64encode(json.dumps(self.query).encode()).decode()
            result = subprocess.run([sys.executable, '-', encoded, '--owner'], input=reader.READER_SOURCE,
                                    capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('reexecuted stdin', result.stdout)

    def test_complete_history_pages_then_only_new_bytes(self):
        self.write(*(self.event(f'message {i} ' + 'x' * 4000) for i in range(500)))
        fields, rows = self.read()
        self.assertGreater(int(fields[5]), 0)
        self.assertTrue(rows[-1]['text'].startswith('message 499 '))
        latest_offset = self.query['offset']
        pages = 1
        while self.query['start']:
            self.query['before'] = self.query['start']
            fields, page = self.read()
            rows = page + rows
            pages += 1
            self.assertEqual(self.query['offset'], latest_offset)
        self.assertGreater(pages, 1)
        self.assertEqual(len(rows), 500)
        self.assertTrue(rows[0]['text'].startswith('message 0 '))
        self.assertTrue(rows[-1]['text'].startswith('message 499 '))
        offset = self.query['offset']
        fields, page = self.read()
        self.assertEqual(int(fields[5]), offset)
        self.assertEqual(page, [])
        with self.path.open('a') as f:
            f.write(json.dumps(self.event('new delta')) + '\n')
        fields, page = self.read()
        self.assertEqual(int(fields[5]), offset)
        self.assertEqual([r['text'] for r in page], ['new delta'])

    def test_long_message_is_sent_whole_not_trimmed_to_180kb(self):
        text = 'start ' + 'ę' * 400000 + ' end'
        self.write(self.event(text))
        fields, rows = self.read()
        self.assertEqual(rows, [])
        self.query['before'] = int(fields[14])
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], text)

    def test_partial_utf8_record_does_not_advance_cursor(self):
        self.write(self.event('first'))
        _, rows = self.read()
        offset = self.query['offset']
        raw = (json.dumps(self.event('ę second'), ensure_ascii=False) + '\n').encode()
        with self.path.open('ab') as f:
            f.write(raw[:-2])
        fields, rows = self.read()
        self.assertEqual(self.query['offset'], offset)
        self.assertEqual(rows, [])
        with self.path.open('ab') as f:
            f.write(raw[-2:])
        fields, rows = self.read()
        self.assertEqual([r['text'] for r in rows], ['ę second'])

    def test_tool_only_pages_advance_without_dropping_next_message(self):
        self.write(self.event('first'))
        self.read()
        tool = json.dumps(dict(type='progress', text='large tool data')) + '\n'
        with self.path.open('a') as source:
            source.write(tool + json.dumps(self.event('reply')) + '\n')
        with patch.object(reader, 'SCAN_BYTES', len(tool)):
            fields, rows = self.read()
        self.assertEqual(rows, [])
        self.assertEqual(fields[8], '1')
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], 'reply')

    def test_replaced_file_and_wrong_cached_sid_restart_at_zero(self):
        self.write(self.event('old'))
        self.read()
        fresh = self.path.with_suffix('.tmp')
        fresh.write_text(json.dumps(self.event('new inode')) + '\n')
        fresh.replace(self.path)
        fields, rows = self.read()
        self.assertEqual(fields[5], '0')
        self.assertEqual(rows[0]['text'], 'new inode')
        self.query['cached_sid'] = 'another'
        self.assertEqual(self.read()[0][5], '0')

    def test_shrunken_source_during_scroll_resets_to_tail_instead_of_retrying_stale_page_forever(self):
        self.write(self.event('x' * (reader.TAIL_BYTES + 100)), self.event('old latest'))
        self.read()
        self.assertGreater(self.query['start'], reader.TAIL_BYTES)
        self.query['before'] = self.query['start']
        self.write(self.event('new smaller source'))
        fields, rows = self.read()
        self.assertEqual(fields[13], 'tail')
        self.assertEqual([row['text'] for row in rows], ['new smaller source'])

    def test_same_inode_rewrites_and_changed_append_boundary_restart_at_zero(self):
        self.write(self.event('old reply'))
        self.read()
        self.write(self.event('new reply'))
        fields, rows = self.read()
        self.assertEqual(fields[5], '0')
        self.assertEqual(rows[0]['text'], 'new reply')
        self.write(self.event('newer reply'), self.event('appended'))
        fields, rows = self.read()
        self.assertEqual(fields[5], '0')
        self.assertEqual([r['text'] for r in rows], ['newer reply', 'appended'])

    def test_missing_sid_uses_exact_tmux_process_metadata(self):
        self.write(self.event('mapped history'))
        self.query['sid'] = 'stale'
        with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', self.path)) as resolve:
            fields, rows = self.read()
        resolve.assert_called_once_with('claude', 'term-1')
        self.assertEqual(fields[4], 'sid')
        self.assertEqual(rows[0]['text'], 'mapped history')
        with patch.object(reader, 'resolve_tmux_agent', side_effect=AssertionError('exact sid does not scan proc')):
            self.query['sid'] = 'sid'
            self.read()

    def test_claude_pid_map_resolves_its_exact_jsonl(self):
        self.write(self.event())
        metadata = self.home / '.claude/sessions/99.json'
        metadata.parent.mkdir(parents=True)
        metadata.write_text(json.dumps(dict(sessionId='sid', cwd='/work/demo')))
        with patch.object(reader.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '10\n', '')), \
                patch.object(reader, 'process_table', return_value={10: (1, ['bash']), 99: (10, ['claude'])}), \
                patch.object(reader, 'read_process_cwd', return_value='/wrong'):
            self.assertEqual(reader.resolve_tmux_agent('claude', 'term-1'), ('sid', self.path))

    def test_descends_sudo_su_and_runtime_without_mistaking_arguments_for_agents(self):
        table = {10: (1, ['bash']), 11: (10, ['sudo', '-u', 'secondary', 'claude']),
                 12: (11, ['su', 'secondary', '-c', 'claude']),
                 13: (12, ['node', '/opt/bin/claude.js']),
                 20: (1, ['claude'])}
        self.assertEqual(reader.agent_pid_for_panes([10], table, 'claude'), 13)
        self.assertIsNone(reader.agent_pid_for_panes([99], table, 'claude'))
        self.assertIsNone(reader.agent_pid_for_panes([10], {10: (1, ['python3', '-c', 'claude'])}, 'claude'))
        old = subprocess.CompletedProcess([], 0, (ROOT / 'tools/fixtures/reader-before-7a02ac9.py').read_text(), '')
        control = types.ModuleType('reader708')
        exec(compile(old.stdout, 'reader708.py', 'exec'), control.__dict__)
        self.assertNotEqual(control.agent_pid_for_panes([10], table, 'claude'), 13)

    def test_local_ssh_socket_join_separates_same_user_same_cwd_sessions(self):
        table = {10: (1, ['bash']), 11: (10, ['ssh', '-t', 'secondary@localhost']),
                 20: (1, ['ssh', '-t', 'secondary@localhost']),
                 30: (2, ['sshd: secondary [priv]']), 31: (30, ['sshd: secondary@pts/1']),
                 32: (31, ['bash']), 33: (32, ['claude']),
                 40: (2, ['sshd: secondary [priv]']), 41: (40, ['bash']), 42: (41, ['claude'])}
        client = ('0100007F:ABCD', '0100007F:0016')
        other = ('0100007F:ABCE', '0100007F:0016')
        connections = {11: [client], 20: [other], 30: [client[::-1]], 31: [client[::-1]], 40: [other[::-1]]}
        self.assertIsNone(reader.agent_pid_for_panes([10], table, 'claude'))
        linked = reader.link_local_ssh(table.copy(), connections)
        self.assertEqual(reader.agent_pid_for_panes([10], linked, 'claude'), 33)
        self.assertEqual(reader.agent_pid_for_panes([20], linked, 'claude'), 42)
        self.assertIsNone(reader.agent_pid_for_panes([10], reader.link_local_ssh(table.copy(), {11: [client], 30: [other[::-1]]}), 'claude'))
        ipv6 = ('00000000000000000000000001000000:ABCD', '00000000000000000000000001000000:0016')
        self.assertEqual(reader.agent_pid_for_panes([10], reader.link_local_ssh(table.copy(), {11: [ipv6], 30: [ipv6[::-1]]}), 'claude'), 33)

    def test_proc_snapshot_reads_tcp_socket_inodes_and_tolerates_inaccessible_fds(self):
        root = self.home / 'proc'
        (root / 'net').mkdir(parents=True)
        (root / 'net/tcp').write_text('header\n0: 0100007F:ABCD 0100007F:0016 01 0 0 0 0 0 100\n0: 0100007F:0016 0100007F:ABCD 01 0 0 0 0 0 101\n')
        (root / 'net/tcp6').write_text('header\n')
        for pid, inode in [(10, 100), (30, 101)]:
            (root / str(pid) / 'fd').mkdir(parents=True)
            (root / str(pid) / 'fd/3').symlink_to(f'socket:[{inode}]')
        table = {10: (1, ['ssh']), 30: (2, ['sshd: secondary [priv]']), 31: (30, ['claude']), 40: (2, ['sshd: unrelated'])}
        with patch.object(reader, 'process_table', return_value=table):
            linked = reader.local_ssh_process_table(root)
        self.assertEqual(reader.agent_pid_for_panes([10], linked, 'claude'), 31)

    def test_open_transcript_is_exact_newest_and_excludes_subagents_and_outside_paths(self):
        self.write(self.event('open transcript'))
        newer = self.path.with_name('newer.jsonl')
        newer.write_text(json.dumps(self.event('newest')) + '\n')
        import os
        os.utime(self.path, (1, 1))
        os.utime(newer, (2, 2))
        subagent = self.path.parent / 'sid/subagents/agent-other.jsonl'
        subagent.parent.mkdir(parents=True)
        subagent.write_text('{}\n')
        outside = self.home / 'outside.jsonl'
        outside.write_text('{}\n')
        fd = self.home / 'fd'
        fd.mkdir()
        for index, target in enumerate([self.path, newer, subagent, outside]):
            (fd / str(index)).symlink_to(target)
        original_iterdir = Path.iterdir
        def proc_fds(path):
            return fd.iterdir() if str(path) == '/proc/99/fd' else original_iterdir(path)
        with patch.object(Path, 'iterdir', proc_fds), patch.object(reader, 'read_process_cwd', return_value='/wrong'), \
                patch.object(reader, 'claude_session_metadata', side_effect=AssertionError('open transcript wins')):
            self.assertEqual(reader.resolve_tmux_agent('claude', 'term-1', 99), ('newer', newer))

    def test_empty_identity_discovers_owner_then_reads_same_source_as_owner_once(self):
        self.query.update(sid='', cwd='')
        expected = '@mp\t7\thistory\tok\tsid\t0\n{"text":"cross-user"}\n@@MP_END@@\n'
        with patch.object(reader, 'resolve_tmux_agent', return_value=None), \
                patch.object(reader, 'tmux_owner_process', return_value=(99, ('secondary', Path('/home/secondary')))), \
                patch.object(reader, 'owner_response', return_value=expected) as read_owner:
            self.assertEqual(reader.response(self.query, reader.READER_SOURCE), expected)
        owner_query = dict(self.query, discovery_pid=99)
        read_owner.assert_called_once_with(owner_query, ('secondary', Path('/home/secondary')), reader.READER_SOURCE)
        self.write(self.event('owner process map'))
        with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', self.path)) as resolve, \
                patch.object(reader, 'tmux_owner_process', side_effect=AssertionError('no recursive sudo')):
            self.assertIn('owner process map', reader.response(owner_query, reader.READER_SOURCE, as_owner=True))
        resolve.assert_called_once_with('claude', 'term-1', 99)

    def test_stale_saved_sid_returns_to_the_callers_tmux_server_for_owner_discovery(self):
        missing = reader.missing_response(self.query, 'session transcript not found')
        expected = '@mp\t7\thistory\tok\tlive-sid\t0\n{"text":"live rows"}\n@@MP_END@@\n'
        owner = ('secondary', Path('/home/secondary'))
        with patch.object(reader, 'conversation_owner', return_value=owner), \
                patch.object(reader, 'conversation_path', side_effect=[None, PermissionError()]), \
                patch.object(reader, 'owner_response', side_effect=[missing, expected]) as read_owner, \
                patch.object(reader, 'resolve_tmux_agent', return_value=None), \
                patch.object(reader, 'tmux_owner_process', return_value=(99, owner)):
            self.assertEqual(reader.response(self.query, reader.READER_SOURCE), expected)
        self.assertEqual(read_owner.call_count, 2)
        self.assertEqual(read_owner.call_args.args[0], dict(self.query, sid='', discovery_pid=99))

    def test_privileged_discovery_is_noninteractive_stdin_only_and_cannot_select_root(self):
        outputs = [subprocess.CompletedProcess([], 0, '10\n', ''),
                   subprocess.CompletedProcess([], 0, '{"pid":99,"user":"secondary"}', '')]
        with patch.object(reader.subprocess, 'run', side_effect=outputs) as run, \
                patch.object(reader.pwd, 'getpwnam', return_value=self.owner()):
            self.assertEqual(reader.tmux_owner_process('claude', 'remote-3', reader.READER_SOURCE), (99, ('secondary', Path('/home/secondary'))))
        self.assertEqual(run.call_args_list[0].args[0][3], '=remote-3')
        command = run.call_args_list[1].args[0]
        self.assertEqual(command[:5], ['sudo', '-n', '--', 'python3', '-'])
        self.assertEqual(json.loads(base64.b64decode(command[5])), dict(agent='claude', panes=[10]))
        self.assertEqual(command[6], '--discover')
        self.assertEqual(run.call_args_list[1].kwargs['input'], reader.READER_SOURCE)
        self.assertNotIn('shell', run.call_args_list[1].kwargs)
        for failure in [subprocess.CompletedProcess([], 1, '', 'denied'), subprocess.TimeoutExpired('sudo', 8),
                        subprocess.CompletedProcess([], 0, 'not json', '')]:
            with patch.object(reader.subprocess, 'run', side_effect=[outputs[0], failure]):
                self.assertIsNone(reader.tmux_owner_process('claude', 'remote-3', reader.READER_SOURCE))
        with patch.object(reader.subprocess, 'run', side_effect=outputs), \
                patch.object(reader.pwd, 'getpwnam', return_value=self.owner(uid=0)):
            self.assertIsNone(reader.tmux_owner_process('claude', 'remote-3', reader.READER_SOURCE))

    def test_filtering_keeps_queued_prompt_and_plain_text_only(self):
        self.write(dict(type='attachment', attachment=dict(type='queued_command', prompt='queued')),
                   dict(type='user', message=dict(role='user', content='<command-name>/test</command-name><command-args>foo</command-args>')),
                   self.event('sidechain', isSidechain=True),
                   dict(type='assistant', message=dict(role='assistant', content=[dict(type='tool_use', input='private')])),
                   self.event('answer', timestamp='2026-10-03T12:34:00Z'))
        _, rows = self.read()
        self.assertEqual([r['text'] for r in rows], ['queued', '/test foo', 'answer'])

    def test_refused_slash_command_facts_are_opt_in_and_additive(self):
        prompt = '/hormozi-skills:audit-offer can you use this also to review my own offer'
        enqueue = dict(type='queue-operation', operation='enqueue', timestamp='2026-10-13T11:06:22.591Z', content=prompt)
        refused = dict(type='system', subtype='informational', level='warning',
                       timestamp='2026-10-13T11:06:59.442Z', content='Unknown command: /hormozi-skills:audit-offer')
        args = dict(refused, content='Args from unknown skill: can you use this also to review my own offer')
        self.write(enqueue, refused, args, self.event('normal reply'))
        _, legacy = self.read()
        self.assertEqual([r['text'] for r in legacy], ['normal reply'])
        self.query.update(settlement=True, offset=0, cached_sid='')
        _, rows = self.read()
        self.assertEqual(rows[-1], legacy[0])
        self.assertEqual([r['settlement']['operation'] for r in rows[:-1]], ['enqueue', 'rejected', 'rejected'])
        self.assertEqual(rows[0]['settlement']['content'], prompt)
        self.assertEqual(rows[1]['timestamp'], refused['timestamp'])
        self.assertEqual(rows[1]['settlement']['content'], refused['content'])
        self.assertIsNone(reader.settlement_event(dict(refused, isSidechain=True), 'claude'))
        self.assertIsNone(reader.settlement_event(dict(refused, content='Compacted while idle'), 'claude'))
        self.assertIsNone(reader.settlement_event(refused, 'codex'))

    def test_queue_removal_and_contentless_dequeue_popall_survive_delta_paging(self):
        self.query['settlement'] = True
        enqueue = dict(type='queue-operation', operation='enqueue', content='please review my offer', timestamp='2026-10-13T11:06:22.591Z')
        self.write(enqueue)
        _, rows = self.read()
        self.assertEqual(rows[0]['settlement']['operation'], 'enqueue')
        with self.path.open('a') as output:
            for event in [dict(enqueue, operation='remove'),
                          dict(type='queue-operation', operation='dequeue', timestamp='2026-10-13T11:06:59Z'),
                          dict(type='queue-operation', operation='popAll', timestamp='2026-10-13T11:07:00Z')]:
                output.write(json.dumps(event) + '\n')
        _, rows = self.read()
        self.assertEqual([r['settlement']['operation'] for r in rows], ['remove', 'dequeue', 'popAll'])
        self.assertEqual(rows[0]['settlement']['content'], enqueue['content'])
        self.assertEqual(rows[1]['settlement']['content'], '')

    def test_enqueued_command_delivered_midturn_and_normal_user_remain_user_rows(self):
        self.query['settlement'] = True
        prompt = 'please review my offer'
        self.write(dict(type='queue-operation', operation='enqueue', content=prompt, timestamp='2026-10-13T11:06:22.591Z'),
                   dict(type='queue-operation', operation='remove', content=prompt, timestamp='2026-10-13T11:06:59.442Z'),
                   dict(type='attachment', timestamp='2026-10-13T11:06:59.443Z',
                        attachment=dict(type='queued_command', prompt=prompt)),
                   dict(type='user', timestamp='2026-10-13T11:07:00Z', message=dict(role='user', content='normal user message')))
        _, rows = self.read()
        self.assertEqual([r['text'] for r in rows[2:]], [prompt, 'normal user message'])
        self.assertEqual([r['role'] for r in rows[2:]], ['user', 'user'])
        self.assertEqual(rows[2]['timestamp'], '2026-10-13T11:06:59.443Z')

    def test_codex_rollout_and_input_output_text(self):
        path = self.home / '.codex/sessions/2026/rollout-day-sid.jsonl'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(dict(type='response_item', payload=dict(type='message', role='user', content=[dict(type='input_text', text='codex prompt')]))) + '\n')
        self.query['codex'] = True
        _, rows = self.read()
        self.assertEqual(rows[0]['text'], 'codex prompt')

    def test_untrusted_identity_and_corrupt_records_fail_not_partial_success(self):
        self.query['sid'] = '../escape'
        with self.assertRaises(ValueError):
            reader.response(self.query)
        self.query['sid'] = 'sid'
        self.path.write_text('{invalid}\n')
        with self.assertRaises(ValueError):
            reader.response(self.query)

    def test_50mb_cold_start_reads_only_tail_and_rejects_706_positive_control(self):
        self.path.write_text(json.dumps(dict(type='progress', text='x' * (40 * 1024 * 1024))) + '\n')
        row = json.dumps(self.event('latest ' + 'y' * 2000)) + '\n'
        with self.path.open('a') as source:
            while source.tell() < 50 * 1024 * 1024:
                source.write(row)
            source.write(json.dumps(self.event('LATEST-50MB')) + '\n')
        size = self.path.stat().st_size
        original_open = Path.open

        def measure(module):
            read_bytes = 0

            class Counted:
                def __init__(self, source):
                    self.source = source

                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    return self.source.__exit__(*args)

                def __getattr__(self, name):
                    return getattr(self.source, name)

                def read(self, *args):
                    nonlocal read_bytes
                    data = self.source.read(*args)
                    read_bytes += len(data)
                    return data

                def readline(self, *args):
                    nonlocal read_bytes
                    data = self.source.readline(*args)
                    read_bytes += len(data)
                    return data

            def counted_open(path, *args, **kwargs):
                source = original_open(path, *args, **kwargs)
                return Counted(source) if path == self.path and args == ('rb',) else source

            start = time.monotonic()
            with patch.object(Path, 'open', counted_open):
                wire = module.response(self.query)
            fields = wire.splitlines()[0].split('\t')
            elapsed = time.monotonic() - start
            return read_bytes, elapsed, fields, wire

        def bounded(result):
            count, elapsed, fields, wire = result
            self.assertLessEqual(count, reader.TAIL_BYTES + 64)
            self.assertGreaterEqual(int(fields[5]), size - reader.TAIL_BYTES)
            self.assertEqual(int(fields[6]), size)
            self.assertIn('LATEST-50MB', wire)
            self.assertLess(elapsed, 2.0)

        result = measure(reader)
        bounded(result)
        print(f'CPU707 first-load source_bytes={size} read_bytes={result[0]} ms={result[1] * 1000:.1f}')
        old = subprocess.CompletedProcess([], 0, (ROOT / 'tools/fixtures/reader-before-5880899.py').read_text(), '')
        control = types.ModuleType('reader706')
        exec(compile(old.stdout, 'reader706.py', 'exec'), control.__dict__)
        control.HOME = self.home
        with self.assertRaises(AssertionError):
            bounded(measure(control))

    def start_server(self):
        bootstrap = "import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))"
        server = subprocess.Popen([sys.executable, '-u', '-c', bootstrap, '--serve'],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  env=dict(os.environ, HOME=str(self.home)))
        def cleanup():
            server.stdin.close()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)
            server.stdout.close()
            server.stderr.close()
        self.addCleanup(cleanup)
        server.stdin.write(base64.b64encode((ROOT / 'src/chat_history_reader.py').read_bytes()) + b'\n')
        server.stdin.flush()
        return server

    def server_request(self, server, query):
        line = query if isinstance(query, bytes) else json.dumps(query).encode()
        server.stdin.write(line + b'\n')
        server.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(server.stdout, selectors.EVENT_READ)
            self.assertTrue(selector.select(timeout=5), 'reader reply timed out')
        reply = json.loads(server.stdout.readline())
        self.assertTrue(reply['wire'].endswith(reader.END + '\n'))
        return reply

    def test_serve_multiple_requests_observe_appends_and_eof_in_one_process(self):
        self.write(self.event('first reply'))
        server = self.start_server()
        first = self.server_request(server, self.query)
        self.assertEqual(first['id'], 7)
        self.assertIn('first reply', first['wire'])
        fields = first['wire'].splitlines()[0].split('\t')
        self.query.update(id=8, cached_sid=fields[4], inode=int(fields[7]), offset=int(fields[6]))
        with self.path.open('a') as output:
            output.write(json.dumps(self.event('second reply')) + '\n')
        second = self.server_request(server, self.query)
        self.assertEqual(second['id'], 8)
        self.assertIn('second reply', second['wire'])
        self.assertNotIn('first reply', second['wire'])
        self.assertIsNone(server.poll())
        server.stdin.close()
        self.assertEqual(server.wait(timeout=5), 0)
        self.assertEqual(server.stderr.read(), b'')

    def test_serve_malformed_requests_do_not_poison_next_request(self):
        self.write(self.event('after malformed'))
        server = self.start_server()
        for malformed in [b'not json', b'null', b'[]', b'{}', b'{"id":9}',
                          b'{"id":true}', b'{"id":-1}', b'{"id":"bad"}']:
            reply = self.server_request(server, malformed)
            self.assertIn('\thistory\terror\t', reply['wire'])
            self.assertEqual(reply['id'], 9 if malformed == b'{"id":9}' else 0)
        self.assertIn('after malformed', self.server_request(server, self.query)['wire'])
        self.assertIsNone(server.poll())

    def test_serve_large_transcript_and_oversized_older_reply_remain_framed(self):
        giant = 'large \" \\ \n 雪 ' * 120000
        self.write(self.event(giant), *(self.event('new ' + str(i) + 'x' * 4000) for i in range(300)))
        server = self.start_server()
        reply = self.server_request(server, self.query)
        fields = reply['wire'].splitlines()[0].split('\t')
        self.assertIn('new 299', reply['wire'])
        self.query.update(id=8, cached_sid=fields[4], inode=int(fields[7]), offset=int(fields[6]),
                          before=int(fields[14]))
        saw_giant = False
        for rid in range(8, 16):
            self.query['id'] = rid
            reply = self.server_request(server, self.query)
            self.assertEqual(reply['id'], rid)
            rows = reply['wire'].splitlines()
            messages = [json.loads(row) for row in rows[1:-1]]
            saw_giant = any(message['text'] == giant for message in messages)
            self.query['before'] = int(rows[0].split('\t')[14])
            if saw_giant:
                self.assertGreater(len(reply['wire']), 1024 * 1024)
                break
        self.assertTrue(saw_giant)
        self.query.update(id=99, before=0)
        self.assertEqual(self.server_request(server, self.query)['id'], 99)

    def test_embedded_stdin_transaction_without_remote_helper_install(self):
        with patch.dict('os.environ', {'HOME': str(self.home)}):
            self.write(self.event('stdin history'))
            encoded = base64.b64encode(json.dumps(self.query).encode()).decode()
            p = subprocess.run([sys.executable, '-', encoded], input=(ROOT / 'src/chat_history_reader.py').read_text(), text=True, capture_output=True, timeout=5)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('stdin history', p.stdout)
        self.assertTrue(p.stdout.endswith('@@MP_END@@\n'))


if __name__ == '__main__':
    unittest.main()
