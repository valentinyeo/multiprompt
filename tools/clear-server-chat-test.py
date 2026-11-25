import importlib.util
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('reader', ROOT / 'src/chat_history_reader.py')
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


class HostedClearTest(unittest.TestCase):
    sid = '11111111-2222-4333-8444-555555555555'
    native = '66666666-7777-4888-8999-aaaaaaaaaaaa'
    tmux = 'live-clear'

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.addCleanup(patch.stopall)
        patch.object(reader, 'HOME', self.home).start()
        patch.object(reader, 'resolve_tmux_agent', return_value=None).start()
        patch.object(reader, 'host_layout_publish_conversation').start()
        self.cwd = str(self.home / 'work')
        Path(self.cwd).mkdir()
        self.paths = reader.host_paths('claude', self.sid)
        reader.host_write(self.paths['config'], dict(enabled=True, provider='claude', sid=self.sid,
                          tmux=self.tmux, cwd=self.cwd, native_session=self.sid))
        self.old = self.home / '.claude/projects' / reader.claude_project_folder(self.cwd) / (self.sid + '.jsonl')
        self.old.parent.mkdir(parents=True)
        self.old.write_bytes((ROOT / 'tools/fixtures/MUBO-136/old.jsonl').read_bytes())
        self.state = dict(native_session=self.sid)
        self.session = dict(state=self.state)
        reader.host_session_reset(self.session, types.SimpleNamespace(stdin=io.BytesIO()))
        self.session['ready'] = True
        reader.host_state_write('claude', self.sid, self.state)
        self.query = dict(id=7, provider='claude', codex=False, sid=self.sid, tmux=self.tmux,
                          cwd=self.cwd, follow=True, cached_sid='', inode=0, offset=0, start=0)
        self.addCleanup(self.close_db)

    def close_db(self):
        if self.session.get('db') is not None:
            self.session['db'].close()

    def clear(self):
        with patch.object(reader.uuid, 'uuid4', return_value=self.native):
            reply = reader.host_handle_request('claude', self.sid, self.tmux, self.session, dict(op='clear'))
        self.assertEqual(reply.get('status'), 'ok', reply)

    def test_clear_returns_only_the_new_conversation_and_accepts_the_next_send(self):
        before = reader.response(dict(self.query))
        self.assertIn('old conversation marker', before)
        self.clear()
        for query in (self.query, dict(self.query, cached_sid=self.sid,
                      inode=self.old.stat().st_ino, offset=self.old.stat().st_size)):
            wire = reader.response(dict(query))
            self.assertIn('\thistory\tok\t' + self.sid + '\t', wire)
            self.assertNotIn('old conversation marker', wire)
            self.assertFalse([json.loads(line) for line in wire.splitlines()[1:-1]
                              if json.loads(line).get('role') in ('user', 'assistant')])
        self.assertEqual(reader.host_config('claude', self.sid)['native_session'], self.native)
        self.assertEqual(reader.host_sid_for_tmux('claude', self.tmux), self.sid)
        reader.host_session_reset(self.session, types.SimpleNamespace(stdin=io.BytesIO()))
        reader.host_claude_event('claude', self.sid, self.tmux, self.session,
                                dict(type='system', subtype='init', session_id=self.native))
        request = dict(op='message_submit', message_protocol=1, provider='claude', sid=self.sid,
                       tmux=self.tmux, message_id='desktop_clear_next_message', text='new conversation prompt')
        queued = reader.message_store_request(request)
        message = queued['message']
        delivered = reader.host_handle_request('claude', self.sid, self.tmux, self.session,
                    dict(op='deliver', id=message['id'], attempt=message['attempt'], epoch=queued['epoch'], text=request['text']))
        self.assertEqual(delivered['status'], 'sent', delivered)
        events = [json.loads(line) for line in (ROOT / 'tools/fixtures/MUBO-136/new.jsonl').read_text().splitlines()]
        for event in events:
            reader.host_claude_event('claude', self.sid, self.tmux, self.session, event)
        status = reader.message_store_request(dict(request, op='message_status'))
        self.assertIn(status['message']['state'], ('accepted', 'started'))
        for _ in range(2):
            wire = reader.response(dict(self.query))
            self.assertIn('new conversation prompt', wire)
            self.assertIn('new conversation reply', wire)
            self.assertNotIn('old conversation marker', wire)
        self.assertIn('old conversation marker', self.old.read_text())

    def test_cleared_other_user_chat_stream_reads_host_history_not_the_old_owner_transcript(self):
        self.clear()
        incoming = types.SimpleNamespace(buffer=io.BytesIO((json.dumps(self.query) + '\n').encode()))
        output = io.StringIO()
        resolved = ('claude', self.sid, self.paths['history'], None)
        with patch.object(reader.sys, 'stdin', incoming), patch.object(reader.sys, 'stdout', output), \
                patch.object(reader, 'conversation_owner', return_value=('secondary', self.home / 'secondary')), \
                patch.object(reader, 'tmux_owner_process', return_value=None), \
                patch.object(reader, 'watch_changes', return_value=iter([resolved])), \
                patch.object(reader.subprocess, 'Popen', side_effect=AssertionError('clear history belongs to the host')):
            reader.watch(reader.READER_SOURCE)
        frames = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(len(frames), 1)
        self.assertIn('\thistory\tok\t' + self.sid + '\t', frames[0]['wire'])
        self.assertNotIn('old conversation marker', frames[0]['wire'])

    def test_busy_clear_leaves_the_original_conversation_untouched(self):
        self.session['turn'] = 'running-turn'
        reply = reader.host_handle_request('claude', self.sid, self.tmux, self.session, dict(op='clear'))
        self.assertEqual(reply.get('reason'), 'chat_busy', reply)
        self.assertIn('old conversation marker', reader.response(dict(self.query)))
        self.assertEqual(reader.host_config('claude', self.sid)['native_session'], self.sid)

    def test_restart_keeps_the_new_context_and_does_not_resume_the_old_one(self):
        self.clear()
        argv = reader.host_claude_argv('claude', self.sid, ['claude'])
        self.assertEqual(argv[-2:], ['--session-id', self.native])
        self.assertNotIn('old conversation marker', reader.response(dict(self.query)))


if __name__ == '__main__':
    unittest.main()
