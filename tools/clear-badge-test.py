import importlib.util
import os
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("reader", ROOT / "src/chat_history_reader.py")
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)

SID = "0b6c1f5e-8d2a-4a37-9f10-5c3e2d4a7b19"


class ClearBadgeTest(unittest.TestCase):
    def test_a_live_pane_is_not_a_stopped_refusal_when_the_session_id_is_bad(self):
        with patch.object(reader, "host_pane_is_shell", return_value=False), patch.object(reader, "resolve_tmux_agent", return_value=("sid", "/tmp/x")):
            wire = reader.restart_ai_response(dict(id=3, tmux="postbox", sid="not a session", cwd="/tmp"))
        self.assertIn("\trestart_ai\terror\tpane_busy\t", wire)
        self.assertNotIn("invalid_session", wire)

    def test_claude_still_running_under_a_shell_is_not_a_stopped_refusal(self):
        with patch.object(reader, "host_pane_is_shell", return_value=True), patch.object(reader, "resolve_tmux_agent", return_value=("sid", "/tmp/x")):
            wire = reader.restart_ai_response(dict(id=3, tmux="postbox", sid="bad", cwd="/tmp"))
        self.assertIn("\trestart_ai\terror\tpane_busy\t", wire)
        self.assertNotIn("invalid_session", wire)

    def test_a_live_host_chat_reports_the_ai_not_the_shell(self):
        home = tempfile.TemporaryDirectory()
        self.addCleanup(home.cleanup)
        with patch.object(reader, "HOME", Path(home.name)), patch.object(reader.os, "kill", return_value=None), patch.object(reader.subprocess, "run", return_value=types.SimpleNamespace(stdout="postbox\n", returncode=0)):
            reader.host_cli(["enable", "claude", SID, "--tmux", "postbox", "--cwd", home.name])
            reader.host_write(reader.host_paths("claude", SID)["owner"], dict(owner="host", pid=os.getpid()))
            lines = reader.host_list_lines()
        self.assertIn("postbox|", lines)
        self.assertIn("|claude|", lines)


if __name__ == "__main__":
    unittest.main()
