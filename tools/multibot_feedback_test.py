import base64
import datetime
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

FAKE_CLI = r'''#!/usr/bin/env python3
import datetime, json, os, sys
from pathlib import Path
state_path = Path(os.environ['FAKE_BOARD'])
state = json.loads(state_path.read_text())
args = sys.argv[1:]
with open(os.environ['FAKE_CALLS'], 'a') as stream:
    stream.write(json.dumps(args) + '\n')
if os.environ.get('FAKE_MALFORMED'):
    print('{')
    sys.exit(0)
if os.environ.get('FAKE_FAIL'):
    sys.exit(1)
if not args or args.pop(0) != '--json':
    sys.exit(2)
def option(name, default=None):
    return args[args.index(name) + 1] if name in args else default
def page(key, values):
    offset = int(option('--cursor', '0'))
    selected = values[offset:offset + 1]
    more = offset + 1 < len(values)
    cursor = str(offset + 1) if more or (key == 'comments' and selected) else None
    response = dict(success=True, nextCursor=cursor, **{key:selected})
    if key == 'comments':
        response['has_more'] = more
    print(json.dumps(response))
if args == ['status']:
    human = os.environ.get('FAKE_HUMAN') == '1'
    print(json.dumps(dict(authenticated=True, hasToken=True, identity='user' if human else 'agent', agentId=None if human else os.environ['HT_TOKEN'].replace('credential-', 'agent-'))))
elif args[:2] == ['labels', 'list']:
    page('labels', [dict(name='Multiprompt'), dict(name='Agent Feedback')])
elif args[:2] == ['task', 'list']:
    page('tasks', [task for task in state['tasks'] if task['status'] == option('--status')])
elif args[:2] == ['task', 'create']:
    number = 1000 + len(state['tasks'])
    task = dict(title=option('--title'), ticketNumber='IGSH-' + str(number), status='Normal', labels=[dict(name=name) for name in option('--labels').split(',')], description=option('--description'))
    state['tasks'].append(task)
    state_path.write_text(json.dumps(state))
    print(json.dumps(dict(success=True, task=task)))
elif args[:2] == ['comment', 'list']:
    if '--include-activity' not in args: sys.exit(2)
    activity = state['comments'].get(args[2], [])
    if os.environ.get('FAKE_BAD_ACTIVITY'): activity = {'text': 'bad'}
    print(json.dumps(dict(success=True, comments=[], agent_activity=activity, nextCursor=None, has_more=False)))
elif args[:2] == ['comment', 'add']:
    if os.environ.get('FAKE_FAIL_VOTE'):
        sys.exit(1)
    if '--kind' in args: sys.exit(2)
    comment = dict(id='activity-id', runId='run-id', type='thought', text='multibot-feedback-vote:v1', agentId=os.environ['HT_TOKEN'].replace('credential-', 'agent-'), agentName='Agent', createdAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
    state['comments'].setdefault(args[2], []).append(comment)
    state_path.write_text(json.dumps(state))
    print(json.dumps(dict(success=True, routedTo='log')))
else:
    sys.exit(2)
'''


class BoardFeedbackTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.work = self.home / 'private-workspace'
        self.work.mkdir()
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        fake = self.bin / 'hypertask'
        fake.write_text(FAKE_CLI)
        fake.chmod(0o700)
        self.board = self.home / 'board.json'
        self.calls = self.home / 'calls.jsonl'
        self.log = self.home / 'state' / 'multibot' / 'feedback.jsonl'
        self.write_board(dict(tasks=[], comments={}))

    def write_board(self, state):
        self.board.write_text(json.dumps(state))

    def read_board(self):
        return json.loads(self.board.read_text())

    def run_cli(self, *args, token='credential-one', **extra):
        env = {key: value for key, value in os.environ.items() if key not in ('HT_TOKEN', 'XDG_STATE_HOME', 'ZSB_SESSION', 'TMUX', 'MULTIBOT_FEEDBACK_LOG')}
        env.update(HOME=str(self.home), XDG_STATE_HOME=str(self.home / 'state'), PATH=str(self.bin) + os.pathsep + env.get('PATH', ''), FAKE_BOARD=str(self.board), FAKE_CALLS=str(self.calls), MULTIBOT_PROVIDER='codex', MULTIBOT_SESSION='private-chat', MULTIBOT_APP_VERSION='1.2.3')
        if token is not None:
            env['HT_TOKEN'] = token
        env.update(extra)
        return subprocess.run([sys.executable, str(ROOT / 'src/multibot_feedback.py'), *args], cwd=self.work, env=env, capture_output=True, text=True, timeout=60)

    def task(self, number, title, labels=('Multiprompt', 'Agent Feedback'), status='Normal'):
        return dict(ticketNumber='IGSH-' + str(number), title=title, status=status, labels=[dict(name=name) for name in labels])

    def vote(self, agent, date):
        return dict(id='activity-id', runId='run-id', type='thought', text='multibot-feedback-vote:v1', agentId=agent, agentName='Agent', createdAt=date.isoformat())

    def test_reader_bundle_installs_the_real_tool_and_missing_source_is_a_negative_control(self):
        source = (ROOT / 'src/chat_history_reader.py').read_text()
        feedback = (ROOT / 'src/multibot_feedback.py').read_bytes()
        bootstrap = "import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline());exec(compile(s,'<bundle>','exec'))"
        for include in (False, True):
            home = self.home / ('bundled' if include else 'missing')
            home.mkdir()
            prefix = 'MULTIBOT_APP_VERSION = "1.2.3"\n'
            if include:
                prefix += 'FEEDBACK_SOURCE = ' + repr(base64.b64encode(feedback).decode()) + '\n'
            payload = base64.b64encode((prefix + source).encode()) + b'\n' + b'{"id":1,"op":"engine_info"}\n'
            env = dict(os.environ, HOME=str(home))
            result = subprocess.run([sys.executable, '-c', bootstrap, '--serve'], input=payload,
                                    capture_output=True, env=env, timeout=60)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(b'engine_info', result.stdout)
            installed = home / '.multiprompt-runtime' / 'multibot-feedback'
            self.assertEqual(installed.exists(), include)
            if include:
                self.assertEqual(installed.read_bytes(), feedback)
                self.assertEqual(installed.stat().st_mode & 0o777, 0o700)

    def test_create_repeat_other_agent_and_safe_metadata(self):
        first = self.run_cli('Browser  screenshots', '--why', 'Capture is slow')
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertIn('Feedback submitted:', first.stdout)
        second = self.run_cli(' browser screenshots ', token='credential-two')
        again = self.run_cli('BROWSER screenshots', token='credential-two')
        self.assertIn('Feedback voted:', second.stdout)
        self.assertIn('Feedback voted:', again.stdout)
        board = self.read_board()
        self.assertEqual(len(board['tasks']), 1)
        task = board['tasks'][0]
        self.assertEqual(task['title'], 'Multibot wish: browser screenshots')
        self.assertEqual({label['name'] for label in task['labels']}, {'Multiprompt', 'Agent Feedback'})
        self.assertEqual(len(board['comments'][task['ticketNumber']]), 2)
        self.assertIn('1.2.3', task['description'])
        self.assertIn('codex', task['description'])
        for private in ('private-workspace', 'private-chat', 'credential-one', str(self.home)):
            self.assertNotIn(private, json.dumps(board))
        self.assertEqual(len(self.log.read_text().splitlines()), 3)
        self.assertIn('private-chat', self.log.read_text())

    def test_wrong_app_exact_title_pagination_and_deleted(self):
        state = dict(tasks=[self.task(1, 'Multibot wish: capture', ('Other', 'Agent Feedback')), self.task(2, 'Multibot wish: capture more'), self.task(3, 'Multibot wish: capture', status='Archive')], comments={})
        self.write_board(state)
        result = self.run_cli('capture')
        self.assertEqual(result.stdout.strip(), 'Feedback voted: https://app.hypertask.ai/detail/project-2060/3')
        self.assertEqual(len(self.read_board()['tasks']), 3)
        state['tasks'].append(self.task(4, 'Multibot wish: deleted', status='Deleted'))
        self.write_board(state)
        result = self.run_cli('deleted')
        self.assertIn('Board submission not confirmed', result.stdout)
        self.assertEqual(len(self.read_board()['tasks']), 4)

    def test_weekly_rank_counts_distinct_agents_and_sorts_ties(self):
        now = datetime.datetime.now(datetime.timezone.utc)
        start = (now - datetime.timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
        state = dict(tasks=[self.task(1, 'Multibot wish: beta'), self.task(2, 'Multibot wish: alpha'), self.task(3, 'Multibot wish: old'), self.task(4, 'Multibot wish: leading')], comments={'IGSH-1': [self.vote('a', start), self.vote('a', start)], 'IGSH-2': [self.vote('b', start)], 'IGSH-3': [self.vote('c', start - datetime.timedelta(seconds=1))], 'IGSH-4': [self.vote('d', start), self.vote('e', start)]})
        self.write_board(state)
        result = self.run_cli('--weekly')
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertEqual(len(lines), 3)
        self.assertIn('2\tMultibot wish: leading', lines[0])
        self.assertIn('1\tMultibot wish: alpha', lines[1])
        self.assertIn('1\tMultibot wish: beta', lines[2])
        self.assertNotIn('old', result.stdout)

    def test_failed_vote_after_creation_is_not_reported_as_success_and_retry_converges(self):
        failed = self.run_cli('a safe feature', FAKE_FAIL_VOTE='1')
        self.assertIn('Board submission not confirmed', failed.stdout)
        self.assertNotIn('Feedback submitted:', failed.stdout)
        self.assertEqual(len(self.read_board()['tasks']), 1)
        retry = self.run_cli('a safe feature')
        self.assertIn('Feedback voted:', retry.stdout)
        self.assertEqual(len(self.read_board()['tasks']), 1)
        self.assertEqual(len(next(iter(self.read_board()['comments'].values()))), 1)

    def test_simultaneous_submissions_and_retry_share_one_ticket_and_vote(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            results = list(pool.map(lambda _: self.run_cli('concurrent capability'), range(3)))
        results.append(self.run_cli('concurrent capability'))
        self.assertTrue(all('Feedback ' in result.stdout and 'Board submission not confirmed' not in result.stdout for result in results))
        board = self.read_board()
        self.assertEqual(len(board['tasks']), 1)
        self.assertEqual(len(board['comments'][board['tasks'][0]['ticketNumber']]), 1)

    def test_full_activity_window_refuses_unverifiable_vote(self):
        task = self.task(1, 'Multibot wish: crowded')
        self.write_board(dict(tasks=[task], comments={'IGSH-1': [self.vote('a', datetime.datetime.now(datetime.timezone.utc))] * 100}))
        result = self.run_cli('crowded')
        self.assertIn('activity limit reached', result.stdout)
        self.assertEqual(len(self.read_board()['comments']['IGSH-1']), 100)

    def test_malformed_activity_fails_closed(self):
        task = self.task(1, 'Multibot wish: bad activity')
        self.write_board(dict(tasks=[task], comments={}))
        result = self.run_cli('bad activity', FAKE_BAD_ACTIVITY='1')
        self.assertIn('invalid activity response', result.stdout)
        self.assertEqual(self.read_board()['comments'], {})

    def test_secret_is_neither_saved_nor_printed(self):
        result = self.run_cli('credential-one')
        self.assertEqual(result.returncode, 2)
        self.assertNotIn('credential-one', result.stdout + result.stderr)
        self.assertFalse(self.log.exists())
        self.assertFalse(self.calls.exists())

    def test_missing_token_does_not_invoke_default_login(self):
        result = self.run_cli('a capability', token=None)
        self.assertIn('Board submission not confirmed', result.stdout)
        self.assertFalse(self.calls.exists())
        self.assertTrue(self.log.exists())

    def test_missing_token_human_failure_malformed_and_private_text_stay_local(self):
        for token, extra, wish in [(None, {}, 'no token'), ('agent-one', {'FAKE_HUMAN': '1'}, 'human login'), ('agent-one', {'FAKE_FAIL': '1'}, 'failed call'), ('agent-one', {'FAKE_MALFORMED': '1'}, 'bad reply'), ('agent-one', {}, 'open /private/notes')]:
            with self.subTest(wish=wish):
                result = self.run_cli(wish, token=token, **extra)
                self.assertEqual(result.returncode, 0)
                self.assertIn('Board submission not confirmed', result.stdout)
                self.assertNotIn('agent-one', result.stdout + result.stderr)
        self.assertEqual(self.read_board()['tasks'], [])
        self.assertEqual(len(self.log.read_text().splitlines()), 5)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertFalse(any(call[1:3] in (['task', 'create'], ['comment', 'add']) for call in calls))
