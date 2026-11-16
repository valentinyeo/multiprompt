import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("reader", ROOT / "src/chat_history_reader.py")
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


class ClearOldMessagesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(patch.stopall)
        self.home = Path(self.temp.name)
        patch.object(reader, "HOME", self.home).start()
        connector = base64.b64encode((ROOT / "src/chat_connectors/claude.py").read_bytes()).decode()
        patch.object(reader, "CONNECTOR_SOURCES", dict(claude=connector), create=True).start()
        patch.object(reader, "open_hax_transcript", return_value=None).start()
        patch.object(reader, "read_process_cwd", return_value="/work/demo").start()
        patch.object(reader, "process_table", return_value={10: (1, ["bash"]), 99: (10, ["claude", "--resume", "old"])}).start()
        patch.object(reader.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "10\n", "")).start()
        self.old = self.home / ".claude/projects/-work-demo/old.jsonl"
        self.old.parent.mkdir(parents=True)
        self.write(self.old, "Before clear")
        self.new = self.old.with_name("new.jsonl")
        self.metadata = self.home / ".claude/sessions/99.json"
        self.metadata.parent.mkdir(parents=True)
        self.bind("old")
        patch.object(reader, "open_claude_transcript", return_value=self.old).start()
        self.query = dict(id=7, codex=False, sid="old", tmux="fixture", cwd="/work/demo", follow=True,
                          cached_sid="", inode=0, offset=0)

    def bind(self, sid):
        self.metadata.write_text(json.dumps(dict(sessionId=sid, cwd="/work/demo")))

    def write(self, path, text, role="assistant", **extra):
        path.write_text(json.dumps(dict(type=role, uuid=text, message=dict(role=role, content=text), **extra)) + "\n")

    def test_reload_follows_current_pid_session_even_with_old_transcript_open(self):
        self.assertIn("Before clear", reader.response(dict(self.query)))
        self.write(self.new, "After clear")
        self.bind("new")
        for _ in range(2):
            wire = reader.response(dict(self.query))
            self.assertIn("\thistory\tok\tnew\t", wire)
            self.assertIn("After clear", wire)
            self.assertNotIn("Before clear", wire)

    def test_watch_follows_pid_metadata_change(self):
        resolved = reader.resolve_response_path(dict(self.query), reader.READER_SOURCE, True)
        incoming, writer = os.pipe()
        self.addCleanup(os.close, incoming)
        self.addCleanup(os.close, writer)
        with patch.object(reader.sys, "stdin", types.SimpleNamespace(fileno=lambda: incoming)):
            events = reader.watch_changes(dict(self.query), resolved, reader.READER_SOURCE, True)
            self.addCleanup(events.close)
            self.assertEqual(next(events)[2], self.old)
            self.write(self.new, "After clear")
            self.bind("new")
            with self.old.open("a") as output:
                output.write("\n")
            current = next(events)
            wire = reader.response(dict(self.query), resolved=current)
            self.assertEqual(current[1:3], ("new", self.new))
            self.assertIn("After clear", wire)
            self.assertNotIn("Before clear", wire)

    def test_next_message_dispatches_and_gets_native_confirmation(self):
        self.write(self.new, "After clear")
        self.bind("new")
        sid = reader.response(dict(self.query)).splitlines()[0].split("\t")[4]
        token = "message_after_clear_0001"
        request = dict(message_protocol=1, provider="claude", sid=sid, tmux="fixture")
        reader.message_store_request(dict(request, op="message_submit", message_id=token, text="Next message"))

        def send(q):
            with self.new.open("a") as output:
                output.write(json.dumps(dict(type="user", uuid="native-next", sessionId="new",
                                             message=dict(role="user", content=q["text"] + "\n[mp:" + q["token"] + "]"))) + "\n")
            return dict(status="sent")

        with patch.object(reader, "send_response_preserve_draft", side_effect=send) as transport:
            result = reader.message_store_request(dict(request, op="message_dispatch"))
        self.assertEqual(result["message"]["state"], "sent")
        transport.assert_called_once()
        reader.message_poll("fixture", "claude", sid)
        result = reader.message_store_request(dict(request, op="message_status", message_id=token))
        self.assertEqual(result["message"]["state"], "accepted")
        self.assertEqual(result["message"]["sid"], "new")

    def test_current_metadata_without_a_file_never_falls_back_to_resume(self):
        self.bind("new")
        with patch.object(reader, "open_claude_transcript", return_value=None):
            self.assertIsNone(reader.resolve_tmux_agent("claude", "fixture", require_bound=True))


if __name__ == "__main__":
    unittest.main()
