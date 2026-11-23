import contextlib
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


def session(**overrides):
    value = dict(state=dict(context_session="old-context", native_session="old-native", mode="bypassPermissions"),
                 turn=None, sends=[], parked={}, inflight=None, agent=object())
    value.update(overrides)
    return value


class ClearServerChatTest(unittest.TestCase):
    def send(self, text, pane="bash", hosted=False):
        tmux = FakeTmux(pane)
        with patch.object(reader.subprocess, "run", tmux), patch.object(reader.time, "sleep"), \
                patch.object(reader, "host_pane_claimed", return_value=hosted), \
                patch.object(reader, "host_pane_is_shell", return_value=pane in reader.HOST_ADOPT_SHELLS):
            wire = reader.send_response(dict(op="send", id=7, tmux="postbox", text=text))
        return wire, tmux

    def hosted(self, reply=None, owned=True):
        stack = contextlib.ExitStack()
        stack.enter_context(patch.object(reader, "host_pane_claimed", return_value=True))
        stack.enter_context(patch.object(reader, "host_pane_is_shell", return_value=False))
        stack.enter_context(patch.object(reader, "host_sid_for_tmux", return_value=SID))
        stack.enter_context(patch.object(reader, "host_owned", return_value=owned))
        host = stack.enter_context(patch.object(reader, "host_request", return_value=reply or dict(status="ok")))
        stack.enter_context(patch.object(reader.subprocess, "run", FakeTmux("claude")))
        stack.enter_context(patch.object(reader.time, "sleep"))
        return stack, host

    def test_a_hosted_clear_asks_the_host_and_types_nothing(self):
        stack, host = self.hosted()
        with stack:
            wire = reader.send_response(dict(op="send", id=7, tmux="postbox", text="/clear"))
        self.assertIn("\tsend\tok\t-\t", wire)
        host.assert_called_once_with("claude", SID, dict(op="clear"))

    def test_a_hosted_clear_reports_the_plain_reason_it_was_refused(self):
        stack, _host = self.hosted(dict(status="refused", reason="chat_busy"))
        with stack:
            wire = reader.send_response(dict(op="send", id=7, tmux="postbox", text="/clear"))
        self.assertIn("\tsend\terror\tchat_busy\t", wire)

    def test_a_hosted_clear_without_a_running_host_is_refused(self):
        stack, _host = self.hosted(owned=False)
        with stack:
            wire = reader.send_response(dict(op="send", id=7, tmux="postbox", text="/clear"))
        self.assertIn("\tsend\terror\thost_not_running\t", wire)

    def test_a_hosted_message_that_is_not_a_clear_stays_refused(self):
        wire, tmux = self.send("rm -rf build", hosted=True)
        self.assertIn("\tsend\terror\thost_owns_chat\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_clear_with_arguments_is_not_a_clear(self):
        wire, tmux = self.send("/clear extra", hosted=True)
        self.assertIn("\tsend\terror\thost_owns_chat\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_a_bare_shell_asks_for_a_real_restart(self):
        with patch.object(reader, "resolve_tmux_agent", return_value=None):
            wire, tmux = self.send("/clear", "bash")
        self.assertIn("\tsend\terror\tneeds_restart\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_a_shell_that_still_has_claude_does_not_type_or_restart(self):
        with patch.object(reader, "resolve_tmux_agent", return_value=(SID, Path("/tmp/x"))):
            wire, tmux = self.send("/clear", "bash")
        self.assertIn("\tsend\terror\tpane_busy\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_a_running_claude_pane_receives_clear_as_typed_text(self):
        wire, tmux = self.send("/clear", "claude")
        self.assertIn("\tsend\tok\t", wire)
        self.assertEqual(tmux.typed(), ["/clear"])

    def test_a_padded_clear_on_a_shell_is_still_a_clear(self):
        with patch.object(reader, "resolve_tmux_agent", return_value=None):
            wire, tmux = self.send("  /clear\n", "bash")
        self.assertIn("\tsend\terror\tneeds_restart\t", wire)
        self.assertEqual(tmux.typed(), [])

    def test_an_idle_hosted_clear_starts_a_new_context_and_keeps_the_transcript(self):
        live = session()
        with patch.object(reader, "host_fresh_archive") as archive, patch.object(reader, "host_state_write") as write, \
                patch.object(reader, "host_log"):
            reply = reader.host_handle_request("claude", SID, "postbox", live, dict(op="clear"))
        self.assertEqual(reply.get("status"), "ok")
        self.assertEqual(live["state"]["fresh_start"]["phase"], "clear")
        self.assertEqual(live["state"].get("context_session"), "old-context")
        archive.assert_called_once()
        write.assert_called_once()

    def test_a_busy_hosted_clear_is_refused(self):
        for busy in (session(turn="reply"), session(sends=[dict(id="x")]), session(agent=None)):
            with patch.object(reader, "host_fresh_archive") as archive, patch.object(reader, "host_state_write") as write:
                reply = reader.host_handle_request("claude", SID, "postbox", busy, dict(op="clear"))
            self.assertEqual(reply.get("reason"), "chat_busy")
            self.assertNotIn("fresh_start", busy["state"])
            self.assertEqual(busy["state"].get("context_session"), "old-context")
            archive.assert_not_called()
            write.assert_not_called()

    def test_a_repeated_clear_waits_for_the_first_one_to_finish(self):
        live = session(state=dict(context_session="old-context", fresh_start=dict(phase="clear", started=0)))
        with patch.object(reader, "host_state_write") as write:
            reply = reader.host_handle_request("claude", SID, "postbox", live, dict(op="clear"))
        self.assertEqual(reply.get("reason"), "chat_busy")
        write.assert_not_called()

    def test_only_claude_has_a_clear(self):
        for provider in ("codex", "pi", "hax"):
            live = session()
            reply = reader.host_handle_request(provider, SID, "postbox", live, dict(op="clear"))
            self.assertEqual(reply.get("reason"), "unsupported_provider")

    def test_the_host_loop_recycles_the_agent_after_a_clear(self):
        loop = reader.host_loop.__code__.co_names
        self.assertIn("host_clear_reset_state", loop)
        self.assertIn("host_agent_start", loop)


if __name__ == "__main__":
    unittest.main(verbosity=2)
