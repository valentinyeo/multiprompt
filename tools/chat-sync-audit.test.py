import contextlib
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('sync_audit', ROOT / 'tools/chat-sync-audit.py')
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class ChatSyncAuditTest(unittest.TestCase):
    def wire(self, rows):
        return '@mp\t1\thistory\tok\tsid\t0\t100\t9\t0\tclaude\t-\n' + ''.join(json.dumps(row) + '\n' for row in rows) + '@@MP_END@@\n'

    def run_audit(self, rows, *args):
        result = subprocess.run([str(ROOT / 'zig-out/bin/chat-audit'), *args], input=self.wire(rows), text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in result.stdout.splitlines()]

    def fact(self, operation, stamp, content='please check the build'):
        return dict(role='assistant', text='', timestamp=stamp, settlement=dict(operation=operation, content=content))

    def test_second_host_alternate_home_two_turns_and_resumed_session_have_zero_drift(self):
        reader = audit.load_reader()
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / 'secondary/home'
            folder = home / '.claude/projects/-work-demo'
            folder.mkdir(parents=True)
            metadata = home / '.claude/sessions/99.json'
            metadata.parent.mkdir(parents=True)
            saved = folder / 'saved.jsonl'
            saved.write_text(json.dumps(dict(type='assistant', message=dict(role='assistant', content='saved old reply'))) + '\n')
            query = dict(id=1, codex=False, sid='saved', tmux='remote-tab', cwd='/work/demo',
                         follow=True, cached_sid='', inode=0, offset=0)
            original_run = subprocess.run
            capture = ''
            def run(argv, **kwargs):
                if argv[:2] == ['tmux', 'capture-pane']:
                    return capture
                return original_run(argv, capture_output=True, text=True, timeout=60, check=True, **kwargs).stdout
            with patch.object(reader, 'HOME', home), \
                    patch.object(reader, 'open_claude_transcript', return_value=None), \
                    patch.object(reader, 'read_process_cwd', return_value='/work/demo'), \
                    patch.object(reader, 'process_table', return_value={99: (1, ['claude'])}), \
                    patch.object(reader.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '99\n', '')), \
                    patch.object(audit, 'run', side_effect=run):
                for turn in range(1, 4):
                    sid = 'first' if turn < 3 else 'resumed'
                    metadata.write_text(json.dumps(dict(sessionId=sid, cwd='/work/demo')))
                    question, answer = f'Remote neutral question number {turn}', f'Remote neutral answer number {turn}'
                    transcript = folder / (sid + '.jsonl')
                    with transcript.open('a') as output:
                        for role, text in [('user', question), ('assistant', answer)]:
                            output.write(json.dumps(dict(type=role, message=dict(role=role, content=text))) + '\n')
                    capture = f'❯ {question}\n● {answer}\n' + '\n' * 8
                    wire = reader.response(query, reader.READER_SOURCE)
                    self.assertIn(question, wire)
                    self.assertIn(answer, wire)
                    self.assertNotIn('saved old reply', wire)
                    self.assertEqual(audit.audit_pane(reader, '%1', 'remote-tab', 'claude', 99,
                                                     ROOT / 'zig-out/bin/chat-audit', sleep=lambda _: None), [])

    def test_crafted_wire_reports_each_drift_kind(self):
        rows = [
            dict(role='user', text='<command-name>neutral</command-name>', timestamp='2026-10-17T15:06:44Z'),
            dict(role='assistant', text='```zig', timestamp='2026-10-17T15:06:45Z'),
            self.fact('enqueue', '2026-10-17T15:06:46Z'),
            self.fact('remove', '2026-10-17T15:06:48Z'),
        ]
        findings = self.run_audit(rows)
        self.assertEqual({item['kind'] for item in findings}, {'raw_markup', 'turn_missing', 'pending_but_delivered'})
        pending = next(item for item in findings if item['kind'] == 'pending_but_delivered')
        self.assertEqual(pending['timestamp'], '2026-10-17T15:06:46Z')
        self.assertEqual(pending['row'], 3)

    def test_igsh263_tool_rows_are_not_conversation_drift(self):
        rows = [dict(role='tool', id='call', text='Ran tests', status='running', detail='<system-reminder>tool output'),
                dict(role='assistant', text='The tests are done'),
                dict(role='tool_result', id='call', text='', status='ok', detail='passed'),
                dict(role='tool_result', id='orphan', text='', status='error', detail='not on this page')]
        self.assertEqual(self.run_audit(rows), [])

    def test_clean_wire_and_probe(self):
        rows = [
            dict(role='assistant', text='# Neutral heading\n\n```text\nneutral example\n```', timestamp='2026-10-17T15:06:44Z'),
            self.fact('enqueue', '2026-10-17T15:06:45.089Z'),
            self.fact('remove', '2026-10-17T15:06:48.689Z'),
            dict(role='user', text='please check the build', timestamp='2026-10-17T15:06:48.689Z'),
        ]
        self.assertEqual(self.run_audit(rows), [])
        self.assertEqual(self.run_audit(rows, '--contains', 'please check the build', '--contains', 'not in this chat'),
                         [dict(probe=0, present=True), dict(probe=1, present=False)])

    def test_pending_anchor_includes_intervening_settlements(self):
        rows = [self.fact('enqueue', '2026-10-17T15:06:45Z', 'neutral other prompt'),
                self.fact('enqueue', '2026-10-17T15:06:46Z'),
                self.fact('remove', '2026-10-17T15:06:48Z'),
                dict(role='user', text='please check the build', timestamp='2026-10-17T15:06:44Z')]
        self.assertEqual([item['kind'] for item in self.run_audit(rows)], ['pending_but_delivered'])
        rows[-1]['timestamp'] = '2026-10-17T15:06:48Z'
        self.assertEqual(self.run_audit(rows), [])

    def test_findings_never_exceed_eighty_characters(self):
        findings = self.run_audit([dict(role='user', text='<system-reminder>' + 'é' * 100)])
        self.assertEqual(findings[0]['kind'], 'raw_markup')
        self.assertEqual(len(findings[0]['text']), 80)

    def test_pane_candidates_skip_tools_short_lines_and_live_tail(self):
        lines = ['● please check the neutral build output', '● Bash(please check the build)',
                 '❯ please check the neutral user prompt', '● short', '› please check the neutral codex prompt']
        candidates = audit.pane_candidates('\n'.join(lines + ['● in progress output is not settled'] * 8))
        self.assertEqual(len(candidates), 3)
        self.assertEqual([item['pane_line'] for item in candidates], [1, 3, 5])

    def test_igsh921_multi_word_tool_calls_are_not_chat_messages(self):
        capture = ['● The neutral summary is ready',
                   '● Web Search("neutral query about sandbox testing; second neutral query")',
                   '● Web Fetch(https://example.com/neutral/page)',
                   '● Another neutral paragraph follows the tools'] + [''] * 8
        candidates = audit.pane_candidates('\n'.join(capture) + '\n')
        self.assertEqual([item['pane_line'] for item in candidates], [1, 4])

    def test_pane_candidates_skips_running_tool_rows(self):
        capture = ['● The neutral summary is ready',
                   '● Inspecting the neutral inventory',
                   '  ⎿  $ list inventory',
                   '● This neutral paragraph follows a blank line', '',
                   '  ⎿  a separate neutral detail',
                   '● This neutral paragraph has continuation text',
                   '  another neutral sentence',
                   '  ⎿  a later neutral detail'] + [''] * 8
        candidates = audit.pane_candidates('\n'.join(capture) + '\n')
        self.assertEqual([item['pane_line'] for item in candidates], [1, 4, 7])
        self.assertEqual([item['text'] for item in candidates],
                         ['The neutral summary is ready', 'This neutral paragraph follows a blank line',
                          'This neutral paragraph has continuation text'])

    def test_igsh808_indented_tool_output_is_not_missing_chat(self):
        reader = audit.load_reader()
        text = "handleStatelessMcpRequest(new Request('http://localhost/mcp', {"
        event = dict(type='user', message=dict(role='user', content=[
            dict(type='tool_result', tool_use_id='neutral-call',
                 content='198  const reply = () => ' + text + "\n199    method: 'POST',")]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(json.dumps(event) + '\n')
            wire = self.wire(reader.conversation_rows(event, 'claude')).replace(
                '\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
            capture = '           > ' + text + '\n' + '\n' * 8
            def command(argv, **kwargs):
                return capture if argv[0] == 'tmux' else ''.join(
                    json.dumps(dict(probe=index, present=False)) + '\n' for index in range(argv.count('--contains')))
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', side_effect=command), \
                 patch.object(audit.time, 'sleep') as sleep:
                self.assertEqual(audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text=text)), [])
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep), [])
                for prefix in ('  > ', '\t› ', '  ❯ ', '  ● ', '\x1b[32m           > '):
                    with self.subTest(prefix=prefix):
                        capture = prefix + text + '\x1b[0m\n' + '\n' * 8
                        self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep), [])
                for prefix in ('> ', '› ', '❯ ', '\x1b[32m> '):
                    with self.subTest(prefix=prefix):
                        capture = prefix + text + '\x1b[0m\n' + '\n' * 8
                        findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep)
                        self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                        self.assertEqual(findings[0]['text'], text)
                        self.assertEqual(findings[0]['transcript_lines'], [])
                event = dict(type='assistant', message=dict(role='assistant', content=text))
                path.write_text(json.dumps(event) + '\n')
                wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
                reader.response.return_value = wire
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep)
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                self.assertEqual(findings[0]['transcript_lines'], [dict(line=1, timestamp='', location='in_window', record='conversation')])

    def test_igsh620_wrapped_running_tool_status_is_not_a_chat_turn(self):
        capture = ['● Filed IGSH-619 for flaky contract tests; waiting on release run ·',
                   '  5m 12s…',
                   '● Waiting up to 9 minutes for verify run · 59s',
                   '● This real assistant reply ends with a middle dot ·',
                   '  and keeps going on the next line.'] + [''] * 8
        candidates = audit.pane_candidates('\n'.join(capture) + '\n')
        self.assertEqual([item['text'] for item in candidates],
                         ['This real assistant reply ends with a middle dot ·'])
        self.assertEqual([item['pane_line'] for item in candidates], [4])

    def test_igsh633_status_summary_wrapped_over_rows_is_not_a_chat_turn(self):
        capture = ['● Skipping Valentin-blocked Multiprompt tickets; checking next ones',
                   '  · 38s…',
                   '● Scanning board; Multiprompt tickets blocked on Valentin, checking',
                   '  next ones · 1m 4s…',
                   '● This neutral reply wraps onto a second row and is real chat',
                   '  because it keeps going here.'] + [''] * 8
        candidates = audit.pane_candidates('\n'.join(capture) + '\n')
        self.assertEqual([item['text'] for item in candidates],
                         ['This neutral reply wraps onto a second row and is real chat'])
        self.assertEqual([item['pane_line'] for item in candidates], [5])

    def test_igsh634_single_file_tool_status_is_not_a_chat_turn(self):
        path = '~/projects/demo/tool-results/' + 'a' * 80 + '/result.txt'
        status = '● Reading ' + path + '…'
        reply = '● Reading ~/projects/app/src/main.zig, the bug sits in the pane'
        capture = [status, status[:100], '  ' + status[100:],
                   '● Reading ' + path + ', running 2 shell commands…',
                   reply, '  resize handler and I will fix it next.',
                   '● Checking 2 neutral builds before the release went out'] + [''] * 8
        candidates = audit.pane_candidates('\n'.join(capture) + '\n')
        self.assertEqual([item['text'] for item in candidates],
                         [reply[2:], 'Checking 2 neutral builds before the release went out'])
        self.assertEqual([item['pane_line'] for item in candidates], [5, 7])

    def test_igsh380_build_progress_banner_is_not_a_chat_turn(self):
        capture = ['● Build in progress (~7 min); preparing preview images',
                   '● Build in progress: the compiler found a real error',
                   '● The build is still running; I will check it shortly',
                   '❯ please check the actual build progress',
                   '❯ Build in progress (~7 min); keep this user prompt'] + [''] * 8
        candidates = audit.pane_candidates('\n'.join(capture) + '\n')
        self.assertEqual([item['pane_line'] for item in candidates], [2, 3, 4, 5])

    def test_igsh380_monitor_queue_records_are_not_missing_chat(self):
        reader = audit.load_reader()
        notice = 'Monitor "neutral helper" stream ended'
        content = '<task-notification><summary>' + notice + '</summary></task-notification>'
        events = [dict(type='queue-operation', operation=operation, content=content,
                       timestamp='2026-01-01T00:00:00Z') for operation in ('enqueue', 'remove')]
        events.append(dict(type='attachment', attachment=dict(type='queued_command', prompt=content)))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(''.join(json.dumps(event) + '\n' for event in events))
            wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
            capture = '● ' + notice + '\n' + '\n' * 8
            def command(argv, **kwargs):
                return capture if argv[0] == 'tmux' else '{"probe":0,"present":false}\n'
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', side_effect=command):
                evidence = audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text=notice))
                self.assertEqual([item['record'] for item in evidence], ['task_notification', 'task_notification'])
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit')), [])
                events.append(dict(type='assistant', message=dict(role='assistant', content=notice)))
                path.write_text(''.join(json.dumps(event) + '\n' for event in events))
                wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
                reader.response.return_value = wire
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'))
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                self.assertEqual(findings[0]['transcript_lines'][-1]['record'], 'conversation')

    def test_igsh643_queued_prompt_is_not_missing_chat_until_delivered(self):
        reader = audit.load_reader()
        prompt = 'please keep going on the neutral ticket now and report back'
        events = [dict(type='queue-operation', operation='enqueue', content=prompt,
                       timestamp='2026-01-01T00:00:00Z')]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(''.join(json.dumps(event) + '\n' for event in events))
            wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
            capture = '❯ ' + prompt + '\n' + '\n' * 8
            def command(argv, **kwargs):
                return capture if argv[0] == 'tmux' else '{"probe":0,"present":false}\n'
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', side_effect=command):
                evidence = audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text=prompt))
                self.assertEqual([item['record'] for item in evidence], ['queued_prompt'])
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit')), [])
                events.append(dict(type='queue-operation', operation='remove', content=prompt,
                                   reason='absorbed_mid_turn', timestamp='2026-01-01T00:00:01Z'))
                events.append(dict(type='attachment', attachment=dict(type='queued_command', prompt=prompt)))
                path.write_text(''.join(json.dumps(event) + '\n' for event in events))
                wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
                reader.response.return_value = wire
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'))
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                self.assertEqual(findings[0]['transcript_lines'][-1]['record'], 'conversation')

    def test_igsh912_queued_prompt_without_recorded_text_is_not_missing_chat_until_dequeued(self):
        reader = audit.load_reader()
        prompt = '[broadcast from neutral lead] rules updated: tag every ticket. Run the rules skill.'
        events = [dict(type='queue-operation', operation='enqueue', content='<task-notification>neutral</task-notification>',
                       timestamp='2026-01-01T00:00:00Z'),
                  dict(type='queue-operation', operation='dequeue', timestamp='2026-01-01T00:00:01Z'),
                  dict(type='queue-operation', operation='enqueue', timestamp='2026-01-01T00:00:02Z')]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(''.join(json.dumps(event) + '\n' for event in events))
            wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
            capture = {'prompt': '❯ ' + prompt, 'output': '● ' + prompt}
            shown = ['prompt']
            def command(argv, **kwargs):
                return capture[shown[0]] + '\n' * 9 if argv[0] == 'tmux' else '{"probe":0,"present":false}\n'
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', side_effect=command):
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep=lambda seconds: None), [])
                shown[0] = 'output'
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep=lambda seconds: None)
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                shown[0] = 'prompt'
                events.append(dict(type='queue-operation', operation='dequeue', timestamp='2026-01-01T00:00:03Z'))
                events.append(dict(type='user', message=dict(role='user', content=prompt), timestamp='2026-01-01T00:00:03Z'))
                path.write_text(''.join(json.dumps(event) + '\n' for event in events))
                wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
                reader.response.return_value = wire
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep=lambda seconds: None)
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                self.assertEqual(findings[0]['transcript_lines'][-1]['record'], 'conversation')

    def test_igsh739_cleared_session_without_transcript_is_not_drift(self):
        reader = audit.load_reader()
        with patch.object(reader, 'resolve_tmux_agent', return_value=None), \
             patch.object(reader, 'claude_session_metadata', return_value=('6aadb489-f042-40ba-a4f7-e4d6cf6e766f', '/home/valentin/projects')), \
             patch.object(reader, 'conversation_path', return_value=None), \
             patch.object(reader, 'read_process_cwd', return_value='/home/valentin/projects'), \
             patch.object(audit, 'run', return_value=''):
            self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep=lambda _: None), [])

    def test_igsh739_text_without_any_transcript_is_still_drift(self):
        reader = audit.load_reader()
        capture = '● This neutral assistant reply is real chat content\n' + '\n' * 8
        with patch.object(reader, 'resolve_tmux_agent', return_value=None), \
             patch.object(reader, 'claude_session_metadata', return_value=('6aadb489-f042-40ba-a4f7-e4d6cf6e766f', '/home/valentin/projects')), \
             patch.object(reader, 'conversation_path', return_value=None), \
             patch.object(reader, 'read_process_cwd', return_value='/home/valentin/projects'), \
             patch.object(audit, 'run', return_value=capture):
            findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep=lambda _: None)
            self.assertEqual(findings, [dict(kind='transcript_missing', session='neutral', pane='%1',
                                             text='Live agent transcript could not be resolved')])

    def test_igsh739_slow_transcript_resolution_is_not_drift(self):
        reader = audit.load_reader()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            wire = self.wire([]).replace('\t0\t100\t', '\t0\t0\t')
            with patch.object(reader, 'resolve_tmux_agent', side_effect=[None, ('sid', path)]), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', return_value=''):
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep=lambda _: None), [])

    def test_igsh662_text_before_running_advisor_is_not_missing_chat(self):
        reader = audit.load_reader()
        text = 'The neutral change is ready for an advisor review before the next step.'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            wire = self.wire([]).replace('\t0\t100\t', '\t0\t0\t')
            capture = '● ' + text + '\n\n● Advising using Claude Fable 5.1\n' + '\n' * 8
            def command(argv, **kwargs):
                return capture if argv[0] == 'tmux' else ''.join(
                    json.dumps(dict(probe=index, present=False)) + '\n' for index in range(argv.count('--contains')))
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', side_effect=command), \
                 patch.object(audit.time, 'sleep') as sleep:
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep), [])
                capture = '● ' + text + '\n\n● Read(src/main.zig)\n  ⎿  Read 20 lines\n' + '\n' * 8
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep)
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                self.assertEqual(findings[0]['text'], text)
                self.assertEqual(findings[0]['transcript_lines'], [])

    def test_igsh686_text_around_finished_advisor_waits_for_message_write(self):
        reader = audit.load_reader()
        texts = ['Calling the advisor before committing to the fix plan.',
                 'Advisor timed out; proceeding. Checking which GitHub check runs the send tests, so the proof gate can read it.']
        pending = '● ' + texts[0] + '\n\n● Advising using Claude Fable 5.1\n\n● ' + texts[1] + '\n\n'
        tool = '● Bash(grep -rn "chat-tmux-send" .github/workflows/)\n'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            wire = self.wire([]).replace('\t0\t100\t', '\t0\t0\t')
            capture = pending + tool + '\n' * 8
            def command(argv, **kwargs):
                return capture if argv[0] == 'tmux' else ''.join(
                    json.dumps(dict(probe=index, present=False)) + '\n' for index in range(argv.count('--contains')))
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', side_effect=command), \
                 patch.object(audit.time, 'sleep') as sleep:
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep), [])
                sleep.assert_called_once_with(audit.SETTLE_SECONDS)
                candidates = audit.pane_candidates(capture)
                self.assertEqual([item['text'] for item in candidates], [text[:80] for text in texts])
                self.assertTrue(all(item['advising'] for item in candidates))
                prompt = 'A new neutral prompt starts the next turn'
                capture = '❯ ' + prompt + '\n\n' + pending + tool + '\n' * 8
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep), [])
                for ending, expected in ((tool + '  ⎿  3 lines\n', texts), ('❯ ' + prompt + '\n', texts + [prompt])):
                    capture = pending + ending + '\n' * 8
                    findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep)
                    self.assertEqual([item['kind'] for item in findings], ['pane_missing'] * len(expected))
                    self.assertEqual([item['text'] for item in findings], [text[:80] for text in expected])
                    self.assertTrue(all(item['transcript_lines'] == [] for item in findings))
                capture = pending + tool + '\n' * 8
                event = dict(type='assistant', message=dict(role='assistant', content='\n\n'.join(texts)))
                path.write_text(json.dumps(event) + '\n')
                wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
                reader.response.return_value = wire
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep)
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'] * 2)
                self.assertEqual([item['text'] for item in findings], [text[:80] for text in texts])
                self.assertEqual([item['transcript_lines'] for item in findings],
                                 [[dict(line=1, timestamp='', location='in_window', record='conversation')]] * 2)
                evidence = findings[0]['transcript_lines']
                with patch.object(audit, 'transcript_evidence', side_effect=[[], [], evidence, evidence]):
                    self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep), findings)

    def test_settle_pending_drops_text_appended_during_wait(self):
        reader = audit.load_reader()
        text = 'The neutral assistant message is still being written'
        event = dict(type='assistant', message=dict(role='assistant', content=text))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            wire = self.wire([]).replace('\t0\t100\t', '\t0\t0\t')
            finding = dict(kind='pane_missing', text=text,
                           transcript_lines=audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text=text)))
            self.assertEqual(finding['transcript_lines'], [])
            def append(seconds):
                self.assertEqual(seconds, audit.SETTLE_SECONDS)
                with path.open('a') as source:
                    source.write(json.dumps(event) + '\n')
            with patch.object(audit, 'transcript_evidence', wraps=audit.transcript_evidence) as evidence:
                self.assertEqual(audit.settle_pending(reader, path, wire, [finding], append), [])
                evidence.assert_called_once_with(reader, path, wire, finding)
            self.assertEqual(finding['transcript_lines'][0]['location'], 'after_snapshot')

    def test_settle_pending_drops_text_appended_after_third_wait(self):
        reader = audit.load_reader()
        text = 'The neutral assistant message arrives after several waits'
        event = dict(type='assistant', message=dict(role='assistant', content=text))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            wire = self.wire([]).replace('\t0\t100\t', '\t0\t0\t')
            finding = dict(kind='pane_missing', text=text, transcript_lines=[])
            sleeps = []
            def append(seconds):
                sleeps.append(seconds)
                if len(sleeps) == 3:
                    with path.open('a') as source:
                        source.write(json.dumps(event) + '\n')
            self.assertEqual(audit.settle_pending(reader, path, wire, [finding], append), [])
            self.assertEqual(sleeps, [audit.SETTLE_SECONDS] * 3)
            self.assertEqual(sum(sleeps), 15)

    def test_settle_pending_keeps_text_that_never_lands_and_waits_until_limit(self):
        reader = audit.load_reader()
        findings = [dict(kind='pane_missing', text=text, transcript_lines=[]) for text in
                    ('The first neutral message never lands', 'The second neutral message never lands')]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            with patch.object(audit.time, 'sleep') as sleep:
                self.assertEqual(audit.settle_pending(reader, path, self.wire([]), findings, sleep), findings)
                self.assertEqual(sum(call.args[0] for call in sleep.call_args_list), audit.SETTLE_LIMIT_SECONDS)
            self.assertTrue(all(item['transcript_lines'] == [] for item in findings))

    def test_settle_pending_does_not_wait_without_empty_pane_evidence(self):
        findings = [dict(kind='pane_missing', transcript_lines=[dict(record='conversation', location='in_window')]),
                    dict(kind='turn_missing', transcript_lines=[])]
        with patch.object(audit.time, 'sleep') as sleep, patch.object(audit, 'transcript_evidence') as evidence:
            for items in ([], findings):
                self.assertEqual(audit.settle_pending(None, None, self.wire([]), items, sleep), items)
            sleep.assert_not_called()
            evidence.assert_not_called()

    def test_settle_pending_preserves_conversation_drift(self):
        cases = [([dict(record='conversation', location='in_window')], True),
                 ([dict(record='conversation', location='before_cold_tail')], True),
                 ([dict(record='thinking', location='in_window')], False),
                 ([dict(record='conversation', location='after_snapshot')], False),
                 ([dict(record='thinking', location='in_window'),
                   dict(record='conversation', location='in_window')], True)]
        for rows, kept in cases:
            with self.subTest(rows=rows):
                finding = dict(kind='pane_missing', text='neutral message', transcript_lines=[])
                other = dict(kind='turn_missing', transcript_lines=[])
                with patch.object(audit.time, 'sleep') as sleep, \
                     patch.object(audit, 'transcript_evidence', return_value=rows) as evidence:
                    result = audit.settle_pending(None, None, self.wire([]), [finding, other], sleep)
                    self.assertEqual(result, [finding, other] if kept else [other])
                    self.assertEqual(finding['transcript_lines'], rows)
                    sleep.assert_called_once_with(audit.SETTLE_SECONDS)
                    evidence.assert_called_once_with(None, None, self.wire([]), finding)

    def test_settle_pending_drops_older_evidence_above_user_row(self):
        wire = self.wire([dict(role='user', text='neutral question'), dict(role='assistant', text='neutral reply')])
        finding = dict(kind='pane_missing', text='neutral older message', transcript_lines=[])
        rows = [dict(record='conversation', location='before_cold_tail')]
        with patch.object(audit.time, 'sleep') as sleep, patch.object(audit, 'transcript_evidence', return_value=rows):
            self.assertEqual(audit.settle_pending(None, None, wire, [finding], sleep), [])
            self.assertEqual(finding['transcript_lines'], rows)

    def test_settle_pending_keeps_older_evidence_without_user_row(self):
        wire = self.wire([dict(role='assistant', text='neutral reply')])
        finding = dict(kind='pane_missing', text='neutral older message', transcript_lines=[])
        rows = [dict(record='conversation', location='before_cold_tail')]
        with patch.object(audit.time, 'sleep') as sleep, patch.object(audit, 'transcript_evidence', return_value=rows):
            self.assertEqual(audit.settle_pending(None, None, wire, [finding], sleep), [finding])
            self.assertEqual(finding['transcript_lines'], rows)

    def test_not_drift_keeps_in_window_conversation_with_user_row(self):
        wire = self.wire([dict(role='user', text='neutral question')])
        finding = dict(kind='pane_missing', transcript_lines=[dict(record='conversation', location='in_window')])
        self.assertFalse(audit.not_drift(finding, wire))

    def test_not_drift_explains_older_evidence_above_user_row(self):
        wire = self.wire([dict(role='user', text='neutral question')])
        finding = dict(kind='pane_missing', transcript_lines=[dict(record='conversation', location='before_cold_tail')])
        self.assertTrue(audit.not_drift(finding, wire))

    def test_not_drift_skips_non_object_wire_lines(self):
        finding = dict(kind='pane_missing', transcript_lines=[dict(record='conversation', location='before_cold_tail')])
        wire = self.wire([None, [], 'neutral text', 1]).replace('@@MP_END@@', 'not json\n@@MP_END@@')
        self.assertFalse(audit.not_drift(finding, wire))
        wire = wire.replace('@@MP_END@@', json.dumps(dict(role='user', text='neutral question')) + '\n@@MP_END@@')
        self.assertTrue(audit.not_drift(finding, wire))

    def test_audit_pane_settles_pending_against_original_snapshot(self):
        reader = audit.load_reader()
        text = 'The neutral assistant message is still being written'
        event = dict(type='assistant', message=dict(role='assistant', content=text))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            wire = self.wire([]).replace('\t0\t100\t', '\t0\t0\t')
            capture = '● ' + text + '\n' + '\n' * 8
            def command(argv, **kwargs):
                return capture if argv[0] == 'tmux' else '{"probe":0,"present":false}\n'
            def append(seconds):
                self.assertEqual(seconds, audit.SETTLE_SECONDS)
                with path.open('a') as source:
                    source.write(json.dumps(event) + '\n')
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire) as response, \
                 patch.object(audit, 'run', side_effect=command), \
                 patch.object(audit, 'transcript_evidence', wraps=audit.transcript_evidence) as evidence:
                self.assertEqual(audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), append), [])
                response.assert_called_once()
                self.assertEqual(evidence.call_count, 2)
                self.assertTrue(all(call.args[2] == wire for call in evidence.call_args_list))

    def test_ticket_deduplication_keeps_open_tickets_and_refiles_done(self):
        finding = dict(kind='raw_markup', session='neutral-session', transcript='/neutral.jsonl',
                       transcript_lines=[dict(line=12, timestamp='2026-10-17T15:06:45Z')], text='neutral example')
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / 'state.json'
            with patch.object(audit, 'run', return_value='{"ticketNumber":"DEMO-900"}') as command:
                audit.file_tickets([finding, finding], state)
                self.assertEqual(command.call_count, 1)
                argv = command.call_args.args[0]
                self.assertIn('2060', argv)
                self.assertIn('Filed by the chat sync audit.', argv[-1])
                self.assertEqual(json.loads(state.read_text()), {'raw_markup': 'DEMO-900'})
            with patch.object(audit, 'run', return_value=json.dumps(dict(task=dict(section=dict(name='Todo'))))) as command:
                audit.file_tickets([finding], state)
                self.assertEqual(command.call_count, 1)
            with patch.object(audit, 'run', side_effect=[json.dumps(dict(task=dict(section=dict(name='Done')))), '{"ticketNumber":"DEMO-901"}']):
                audit.file_tickets([finding], state)
                self.assertEqual(json.loads(state.read_text()), {'raw_markup': 'DEMO-901'})

    def test_markdown_and_terminal_quotes_do_not_create_pane_drift(self):
        rows = [dict(role='assistant', text="It’s a **neutral build** with `neutral output`.")]
        self.assertEqual(self.run_audit(rows, '--contains', "It's a neutral build with neutral output."),
                         [dict(probe=0, present=True)])

    def test_igsh686_user_prompt_markdown_does_not_create_pane_drift(self):
        rows = [dict(role='user', text='> - **One question:** should high-risk flags (money, login/access, data deletion, customer email) also skip your review?\n\nyes',
                     timestamp='2026-10-23T13:38:13.100Z')]
        self.assertEqual(self.run_audit(rows, '--contains', '> - One question: should high-risk flags (money, login/acc'),
                         [dict(probe=0, present=True)])
        self.assertEqual(self.run_audit(rows, '--contains', '> - **One question:** should high-risk'),
                         [dict(probe=0, present=True)])

    def test_protocol_queue_deliveries_are_not_desktop_pending_messages(self):
        rows = []
        for content in ['<task-notification>neutral status</task-notification>',
                        '<cross-session-message from-name="Neutral">neutral notice</cross-session-message>']:
            rows.extend([self.fact('enqueue', '2026-10-17T15:06:45Z', content),
                         self.fact('remove', '2026-10-17T15:06:48Z', content)])
        self.assertEqual(self.run_audit(rows), [])

    def test_terminal_metadata_and_activity_are_not_user_prompts(self):
        capture = ['❯ Message from @Neutral: please check the build',
                   '● Background command "neutral build" completed (exit code 0)',
                   '● Running 2 shell commands…', '● Waiting for neutral build · 2m 54s',
                   '● Listing 1 directory, running 2 shell commands…',
                   '● Making 1 scratchpad edit +8, running 4 shell commands…',
                   '● Reading 3 files, searching 2 patterns',
                   '● Checking 2 neutral builds before the release went out',
                   '❯ please check the actual neutral prompt'] + [''] * 8
        candidates = audit.pane_candidates('\n'.join(capture) + '\n')
        self.assertEqual([c['text'] for c in candidates], ['Checking 2 neutral builds before the release went out', 'please check the actual neutral prompt'])

    def test_ISSUE_571_background_task_status_lines_are_not_chat_turns(self):
        statuses = ['Task "Wait for laptop2 to come online" still running in background',
                    'Task "Wait for revert check results" still running in background',
                    'Task "Wait for combined PR check results" still running in background',
                    'Task "Wait for the 7510 or chained click helper" still running in background']
        message = 'The neutral assistant summary is ready'
        for prefix in ('● ', ''):
            with self.subTest(issue='ISSUE-571', prefix=prefix):
                capture = [prefix + text for text in statuses] + ['● ' + message] + [''] * 8
                candidates = audit.pane_candidates('\n'.join(capture) + '\n')
                self.assertEqual([item['text'] for item in candidates], [message])
                self.assertEqual([item['pane_line'] for item in candidates], [5])

    def test_igsh848_short_background_task_notice_is_not_chat(self):
        notice = 'Task "Wait for the limit to recover then check 2198" still running'
        message = 'The neutral assistant summary is ready'
        for suffix in ('', ' in background'):
            with self.subTest(suffix=suffix):
                capture = '\n'.join(['● ' + notice + suffix, '● ' + message] + [''] * 8) + '\n'
                candidates = audit.pane_candidates(capture)
                self.assertEqual([item['text'] for item in candidates], [message])
                self.assertEqual([item['pane_line'] for item in candidates], [2])

    def test_igsh848_real_messages_about_running_tasks_remain_candidates(self):
        messages = ['● Task "neutral check" still running; I will investigate',
                    '● Task "neutral check" is still running',
                    '● The Task "neutral check" still running needs attention',
                    '❯ Task "neutral check" still running']
        candidates = audit.pane_candidates('\n'.join(messages + [''] * 8) + '\n')
        self.assertEqual([item['text'] for item in candidates], [text[2:] for text in messages])

    def test_igsh867_wrapped_background_task_suffix_is_not_chat(self):
        message = 'The neutral assistant summary is ready'
        for suffix, continuation in [('still running in', 'background'),
                                     ('still running', 'in background'),
                                     ('still', 'running in background')]:
            with self.subTest(suffix=suffix):
                capture = ['● Task "neutral release check" ' + suffix,
                           '  ' + continuation, '● ' + message] + [''] * 8
                candidates = audit.pane_candidates('\n'.join(capture) + '\n')
                self.assertEqual([item['text'] for item in candidates], [message])
                self.assertEqual([item['pane_line'] for item in candidates], [3])

    def test_igsh867_wrapped_task_conversation_remains_chat(self):
        for prefix in ('● ', '❯ '):
            with self.subTest(prefix=prefix):
                text = 'Task "neutral release check" still running in'
                capture = [prefix + text, '  background; I will investigate'] + [''] * 8
                candidates = audit.pane_candidates('\n'.join(capture) + '\n')
                self.assertEqual([item['text'] for item in candidates], [text])

    def test_IGSH_735_wrapped_background_task_row_is_not_chat(self):
        capture = ['● Task "while pgrep -f "cut the Windows RAM" >/dev/null; do sleep 30; done; echo',
                   'done" still running in background'] + [''] * 8
        self.assertEqual(audit.pane_candidates('\n'.join(capture) + '\n'), [])
        capture = ['● Task "neutral check" still running in background'] + [''] * 8
        self.assertEqual(audit.pane_candidates('\n'.join(capture) + '\n'), [])
        message = '● Task "neutral check" still running in background; I will wait'
        candidates = audit.pane_candidates('\n'.join([message] + [''] * 8) + '\n')
        self.assertEqual([item['text'] for item in candidates], [message[2:]])

    def test_pane_candidates_skip_background_agent_status_rows(self):
        reader = audit.load_reader()
        message = 'The neutral assistant summary is ready'
        capture = '\n'.join(['● ' + message, '● All background agents stopped',
                             '● All background agents running', '● 2 background agents stopped',
                             '● 3 background agents running'] + [''] * 8) + '\n'
        candidates = audit.pane_candidates(capture)
        self.assertEqual([item['text'] for item in candidates], [message])
        self.assertEqual([item['pane_line'] for item in candidates], [1])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(b'')
            wire = self.wire([]).replace('\t0\t100\t', '\t0\t0\t')
            def command(argv, **kwargs):
                return capture if argv[0] == 'tmux' else ''.join(
                    json.dumps(dict(probe=index, present=False)) + '\n' for index in range(argv.count('--contains')))
            with patch.object(reader, 'resolve_tmux_agent', return_value=('sid', path)), \
                 patch.object(reader, 'claude_session_metadata', return_value=(None, None)), \
                 patch.object(reader, 'read_process_cwd', return_value=''), \
                 patch.object(reader, 'response', return_value=wire), patch.object(audit, 'run', side_effect=command), \
                 patch.object(audit.time, 'sleep') as sleep:
                findings = audit.audit_pane(reader, '%1', 'neutral', 'claude', 1, Path('neutral-audit'), sleep)
                self.assertEqual([item['kind'] for item in findings], ['pane_missing'])
                self.assertEqual([item['text'] for item in findings], [message])
                self.assertEqual(findings[0]['transcript_lines'], [])

    def test_background_agent_status_wording_in_real_messages_remains_candidates(self):
        messages = ['● All background agents stopped; I will check the results',
                    '● The 2 background agents stopped unexpectedly',
                    '● 3 background agents running need attention',
                    '❯ All background agents stopped', '› 2 background agents stopped']
        candidates = audit.pane_candidates('\n'.join(messages + [''] * 8) + '\n')
        self.assertEqual([item['text'] for item in candidates], [text[2:] for text in messages])

    def test_ISSUE_571_real_messages_about_background_tasks_remain_candidates(self):
        messages = ['● The Task "neutral check" still running in background needs attention',
                    '● Task "neutral check" still running in background; I will wait',
                    '● Task neutral check still running in background',
                    '● Task "neutral check" is still running in background',
                    '❯ Task "neutral check" still running in background']
        candidates = audit.pane_candidates('\n'.join(messages + [''] * 8) + '\n')
        self.assertEqual([item['text'] for item in candidates], [text[2:] for text in messages])

    def test_thinking_is_proven_protocol_activity_not_silently_dropped_prose(self):
        reader = audit.load_reader()
        content = 'please check the neutral build status'
        event = dict(type='assistant', timestamp='2026-10-17T15:06:44Z', message=dict(role='assistant', content=[dict(type='thinking', thinking=content)]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(json.dumps(event) + '\n')
            wire = self.wire([])
            evidence = audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text=content))
            self.assertEqual(evidence[0]['record'], 'thinking')

    def test_igsh730_read_tool_path_status_is_tool_activity(self):
        reader = audit.load_reader()
        file = Path.home() / 'demo-config/projects/-demo' / ('a' * 40) / 'tool-results/result.txt'
        event = dict(type='assistant', cwd=str(Path.home() / 'demo-config'), timestamp='2026-01-01T00:00:00Z',
                     message=dict(role='assistant', content=[dict(type='tool_use', name='Read', input=dict(file_path=str(file)))]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(json.dumps(event) + '\n')
            wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
            text = ('Reading ~/demo-config/projects/-demo/' + 'a' * 40)[:80]
            finding = dict(kind='pane_missing', text=text)
            finding['transcript_lines'] = audit.transcript_evidence(reader, path, wire, finding)
            self.assertEqual(finding['transcript_lines'], [dict(line=1, timestamp=event['timestamp'],
                                                              location='in_window', record='tool_activity')])
            self.assertTrue(audit.not_drift(finding, wire))
            self.assertEqual(audit.transcript_evidence(reader, path, wire,
                             dict(kind='pane_missing', text='Reading ~/demo-config/projects/-demo/aaaa, the log shows the cut')), [])
            evidence = audit.transcript_evidence(reader, path, wire,
                                                dict(kind='pane_missing', text='Reading projects/-demo/aaaa'))
            self.assertEqual(evidence, [dict(line=1, timestamp=event['timestamp'],
                                            location='in_window', record='tool_activity')])

    def test_transcript_evidence_system_notice(self):
        reader = audit.load_reader()
        notice = 'A neutral worker is now idle'
        reply = 'The neutral summary is ready'
        events = [dict(type='system', subtype='informational', content=notice,
                       timestamp='2026-01-01T00:00:00Z'),
                  dict(type='assistant', message=dict(role='assistant', content=reply),
                       timestamp='2026-01-01T00:00:01Z')]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(''.join(json.dumps(event) + '\n' for event in events))
            wire = self.wire([]).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
            evidence = audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text=notice))
            self.assertEqual(evidence, [dict(line=1, timestamp=events[0]['timestamp'],
                                            location='in_window', record='system_notice')])
            evidence = audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text=reply))
            self.assertEqual(evidence, [dict(line=2, timestamp=events[1]['timestamp'],
                                            location='in_window', record='conversation')])
            self.assertEqual(audit.transcript_evidence(reader, path, wire,
                             dict(kind='pane_missing', text='An unrelated neutral notice')), [])

    def test_igsh402_evidence_matches_each_ordered_text_segment(self):
        reader = audit.load_reader()
        event = dict(type='assistant', timestamp='2026-10-17T15:06:44Z',
                     message=dict(role='assistant', id='reply-402', content=[dict(type='text', text='Before the tool'),
                         dict(type='tool_use', id='call-402', name='Read', input={}), dict(type='text', text='After the tool')]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_text(json.dumps(event) + '\n')
            rows = reader.conversation_rows(event, 'claude')
            wire = self.wire(rows).replace('\t0\t100\t', f'\t0\t{path.stat().st_size}\t')
            for row in (1, 3):
                evidence = audit.transcript_evidence(reader, path, wire, dict(kind='turn_missing', row=row))
                self.assertEqual(evidence, [dict(line=1, timestamp=event['timestamp'], location='in_window', record='conversation')])
            evidence = audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text='After the tool'))
            self.assertEqual(len(evidence), 1)
            self.assertEqual(audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text='not in this event')), [])

    def test_actual_hypertask_tasks_response_shape(self):
        with patch.object(audit, 'run', return_value=json.dumps(dict(success=True, tasks=[dict(section='Todo')]))):
            self.assertTrue(audit.ticket_is_open('DEMO-900'))

    def test_chat_agent_excludes_only_codex_cloud_browser(self):
        cases = [(['codex', 'cloud'], False),
                 (['/usr/local/bin/codex', 'cloud'], False),
                 (['node', '/x/codex.js', 'cloud'], False),
                 (['codex'], True),
                 (['codex', 'resume', 'abc'], True),
                 (['node', '/x/codex.js'], True),
                 (['claude', '--resume', 'abc'], True),
                 (['codex', 'exec', 'cloud'], True),
                 (['bun', '/x/codex.js', 'cloud'], False),
                 (['/usr/local/bin/bun', '/x/codex.js'], True)]
        for argv, expected in cases:
            with self.subTest(argv=argv):
                self.assertIs(audit.chat_agent(argv), expected)

    def test_cli_skips_codex_cloud_browser(self):
        class Reader:
            def process_table(self):
                return {10: (1, ['codex', 'cloud'])}

            def agent_pid_for_panes(self, panes, table, agent):
                return 10 if agent == 'codex' else None

        output = io.StringIO()
        with patch('sys.argv', ['chat-sync-audit.py', '--json']), \
             patch.object(audit, 'load_reader', return_value=Reader()), \
             patch.object(audit, 'run', return_value='%1\tigsh506-1\t1\n') as command, \
             patch.object(audit, 'audit_pane', side_effect=AssertionError('Cloud browser must not be audited')), \
             contextlib.redirect_stdout(output):
            self.assertIsNone(audit.main())
        command.assert_called_once_with(['tmux', 'list-panes', '-a', '-F', '#{pane_id}\t#{session_name}\t#{pane_pid}'])
        rows = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(rows, [dict(summary='0 drift findings', findings=0, panes=0)])

    def test_cli_reports_execution_errors_without_nonzero_exit(self):
        output = io.StringIO()
        with patch('sys.argv', ['chat-sync-audit.py', '--json']), patch.object(audit, 'load_reader', side_effect=OSError()), contextlib.redirect_stdout(output):
            self.assertIsNone(audit.main())
        rows = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(rows[0]['kind'], 'audit_error')
        self.assertEqual(rows[-1]['summary'], '1 drift findings')

    def test_evidence_keeps_older_turns_as_real_cold_tail_drift(self):
        reader = audit.load_reader()
        old = dict(type='user', timestamp='2026-10-17T15:06:44Z', message=dict(role='user', content='please check the older neutral prompt'))
        new = dict(type='assistant', timestamp='2026-10-17T15:06:48Z', message=dict(role='assistant', content='neutral newer reply'))
        prefix = json.dumps(old).encode() + b'\n'
        suffix = json.dumps(new).encode() + b'\n'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'neutral.jsonl'
            path.write_bytes(prefix + suffix + b'{\"type\":')
            wire = '@mp\t1\thistory\tok\tsid\t' + str(len(prefix)) + '\t' + str(len(prefix + suffix)) + '\t9\t0\tclaude\t-\n@@MP_END@@\n'
            evidence = audit.transcript_evidence(reader, path, wire, dict(kind='pane_missing', text='please check the older neutral prompt'))
            self.assertEqual(evidence, [dict(line=1, timestamp=old['timestamp'], location='before_cold_tail', record='conversation')])

    def test_ambiguous_ticket_lookup_cannot_create_a_duplicate(self):
        with patch.object(audit, 'run', return_value='{}'):
            with self.assertRaises(ValueError):
                audit.ticket_is_open('DEMO-900')


if __name__ == '__main__':
    unittest.main()
