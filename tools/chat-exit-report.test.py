import contextlib
import importlib.util
import io
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'tools/fixtures/SOFT-3071'
SPEC = importlib.util.spec_from_file_location('chat_exit_report', ROOT / 'tools/chat-exit-report.py')
report = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(report)

SINCE = '2026-11-20T00:00:00Z'
UNTIL = '2026-11-20T23:59:59Z'


def run(*args):
    stream = io.StringIO()
    with contextlib.redirect_stdout(stream):
        code = report.main(['--root', str(FIXTURE), *args])
    return code, stream.getvalue()


class ChatExitReportTest(unittest.TestCase):
    def test_counts_every_exit_cause_from_the_fixture_logs(self):
        code, shown = run('--since', SINCE, '--until', UNTIL)
        self.assertEqual(code, 1)
        self.assertIn('10 exits', shown)
        for line in ('3  idle_stop', '2  unexplained', '1  runtime/host update', '1  crash',
                     '1  killed by signal', '1  requested stop', '1  chat removed'):
            self.assertIn(line, shown)
        self.assertIn('Unexplained exits: 2', shown)

    def test_names_the_chat_and_the_sid_for_every_exit(self):
        code, shown = run('--since', SINCE, '--until', UNTIL)
        self.assertEqual(code, 1)
        self.assertIn('live-silent', shown)
        self.assertIn('c3d4e5f6', shown)
        self.assertIn('2026-11-20T03:20:30Z', shown)

    def test_reports_json_for_the_same_window(self):
        code, shown = run('--since', SINCE, '--until', UNTIL, '--json')
        self.assertEqual(code, 1)
        body = json.loads(shown)
        self.assertEqual(body['exits'], 10)
        self.assertEqual(body['counts']['idle_stop'], 3)
        self.assertEqual(body['counts']['unexplained'], 2)
        self.assertEqual(body['unexplained'], 2)
        self.assertEqual(body['rows'][0]['at'], '2026-11-20T00:30:06Z')

    def test_an_exit_after_the_window_is_left_out(self):
        code, shown = run('--since', SINCE, '--until', '2026-11-20T05:00:00Z')
        self.assertEqual(code, 1)
        self.assertIn('5 exits', shown)
        self.assertNotIn('live-crash', shown)

    def test_a_recorded_cause_is_used_before_the_nearby_events(self):
        code, shown = run('--since', '2026-11-20T11:00:00Z', '--until', UNTIL)
        self.assertEqual(code, 0)
        self.assertIn('1  requested stop', shown)
        self.assertIn('Unexplained exits: 0', shown)

    def test_only_idle_stops_leave_the_window_clean(self):
        code, shown = run('--since', '2026-11-20T00:00:00Z', '--until', '2026-11-20T01:00:00Z')
        self.assertEqual(code, 0)
        self.assertIn('1  idle_stop', shown)
        self.assertIn('Unexplained exits: 0', shown)


if __name__ == '__main__':
    unittest.main()
