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
