import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("reader", ROOT / "src/chat_history_reader.py")
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)

SID = "0b6c1f5e-8d2a-4a37-9f10-5c3e2d4a7b19"


class FakeTmux:
    def __init__(self, pane_command):
        self.pane_command = pane_command
        self.calls = []

    def __call__(self, args, **kwargs):
        self.calls.append(list(args))
        stdout = self.pane_command + "\n" if "display" in args else ""
        return type("Done", (), dict(returncode=0, stdout=stdout, stderr=""))()

    def typed(self):
        return [call[-1] for call in self.calls if "-l" in call]


class ClearServerChatTest(unittest.TestCase):
    def send(self, text, pane="bash"):
        tmux = FakeTmux(pane)
        with patch.object(reader.subprocess, "run", tmux), patch.object(reader.time, "sleep"):
            wire = reader.send_response(dict(op="send", id=7, tmux="postbox", text=text))
        return wire, tmux

    def test_hosted_slash_clear_clears_and_does_not_type(self):
        tmux = FakeTmux("bash")
        with patch.object(reader.subprocess, "run", tmux), patch.object(reader, "host_pane_claimed", return_value=True), patch.object(reader, "host_sid_for_tmux", return_value=SID), patch.object(reader, "host_request", return_value=dict(status="ok")) as host:
            wire = reader.send_response(dict(op="send", id=7, tmux="postbox", text="/clear"))
        self.assertIn("\tsend\tok\t", wire)
        self.assertEqual(tmux.typed(), [])
        host.assert_called_once_with("claude", SID, dict(op="clear"))

    def test_hosted_other_text_stays_refused(self):
        with patch.object(reader, "host_pane_claimed", return_value=True):
            wire, tmux = self.send("rm -rf build")
        self.assertIn("\tsend\terror\thost_owns_chat\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_slash_clear_with_arguments_is_not_a_clear(self):
        with patch.object(reader, "host_pane_claimed", return_value=True):
            wire, tmux = self.send("/clear extra")
        self.assertIn("\tsend\terror\thost_owns_chat\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_a_bare_shell_asks_for_a_real_restart(self):
        with patch.object(reader, "host_pane_claimed", return_value=False), patch.object(reader, "resolve_tmux_agent", return_value=None):
            wire, tmux = self.send("/clear", "bash")
        self.assertIn("\tsend\terror\tneeds_restart\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_a_shell_that_still_has_claude_does_not_type_or_restart(self):
        with patch.object(reader, "host_pane_claimed", return_value=False), patch.object(reader, "resolve_tmux_agent", return_value=(SID, Path("/tmp/x"))):
            wire, tmux = self.send("/clear", "bash")
        self.assertIn("\tsend\terror\tpane_busy\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_a_running_claude_pane_receives_clear_as_typed_text(self):
        with patch.object(reader, "host_pane_claimed", return_value=False):
            wire, tmux = self.send("/clear", "claude")
        self.assertIn("\tsend\tok\t", wire)
        self.assertEqual(tmux.typed(), ["/clear"])

    def test_a_padded_clear_on_a_shell_is_still_a_clear(self):
        with patch.object(reader, "host_pane_claimed", return_value=False), patch.object(reader, "resolve_tmux_agent", return_value=None):
            wire, tmux = self.send("  /clear\n", "bash")
        self.assertIn("\tsend\terror\tneeds_restart\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_an_idle_hosted_clear_starts_a_new_context(self):
        session = dict(state=dict(context_session="old", native_session="native"), turn=None, sends=[], parked={}, inflight=None)
        with patch.object(reader, "host_state_write") as write, patch.object(reader, "host_log"):
            reply = reader.host_handle_request("claude", SID, "postbox", session, dict(op="clear"))
        self.assertEqual(reply.get("status"), "ok")
        self.assertTrue(session.get("clear_agent"))
        self.assertNotEqual(session["state"].get("context_session"), "old")
        self.assertNotIn("native_session", session["state"])
        write.assert_called_once()

    def test_a_busy_hosted_clear_is_refused(self):
        session = dict(state=dict(context_session="old", native_session="native"), turn="reply", sends=[], parked={})
        with patch.object(reader, "host_state_write") as write, patch.object(reader, "host_log"):
            reply = reader.host_handle_request("claude", SID, "postbox", session, dict(op="clear"))
        self.assertEqual(reply.get("reason"), "chat_busy")
        self.assertNotIn("clear_agent", session)
        self.assertEqual(session["state"].get("context_session"), "old")
        self.assertEqual(session["state"].get("native_session"), "native")
        write.assert_not_called()

    def test_the_host_loop_recycles_the_agent_after_a_clear(self):
        self.assertIn('session.pop("clear_agent"', (ROOT / "src/chat_history_reader.py").read_text())


if __name__ == "__main__":
    unittest.main()
