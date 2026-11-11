import importlib.util
import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("broadcast", ROOT / "tools/agent-notifications/broadcast.py")
broadcast = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(broadcast)


def boxed(text):
    lines = ["\u2500" * 20]
    if text:
        lines.append("\u276f " + text)
    lines.append("\u2500" * 20)
    return "\n".join(lines) + "\n"


class FakeTmux:
    def __init__(self, drafts):
        self.drafts = list(drafts)
        self.calls = []

    def __call__(self, cmd, input_text=None, timeout=15):
        self.calls.append(list(cmd))
        if cmd[:3] == ["tmux", "capture-pane", "-e"]:
            text = self.drafts.pop(0) if len(self.drafts) > 1 else self.drafts[0]
            return boxed(text)
        if cmd[:2] == ["tmux", "send-keys"]:
            return ""
        return ""

    def send_keys(self):
        return [call for call in self.calls if call[:2] == ["tmux", "send-keys"]]


class WaitTest(unittest.TestCase):
    def test_message_waits_for_the_box_to_clear_and_never_clears_it(self):
        fake = FakeTmux(["half typed answer", "half typed answer", ""])
        with patch.object(broadcast, "run", fake):
            waited = broadcast.wait_for_clear("%1", 5.0, step=0.0)
            self.assertIsNotNone(waited)
            self.assertGreaterEqual(waited, 0.0)
            self.assertTrue(broadcast.type_into("%1", "[broadcast] hello"))
        sent = fake.send_keys()
        literals = [call for call in sent if "-l" in call]
        self.assertEqual(len(literals), 1)
        self.assertEqual(literals[0][-1], "[broadcast] hello")
        self.assertFalse(any("C-u" in call or "C-k" in call for call in sent))
        self.assertEqual(fake.drafts, [""])

    def test_dim_placeholder_text_is_not_treated_as_a_draft(self):
        placeholder = "\u2500" * 20 + "\n  \u276f \x1b[2mTry \"fix typecheck errors\"\n\x1b[0m" + "\u2500" * 20 + "\n"
        with patch.object(broadcast, "run", return_value=placeholder):
            self.assertEqual(broadcast.draft("%1"), "")

    def test_real_typing_in_the_box_is_a_draft(self):
        typed = "\u2500" * 20 + "\n  \u276f please check the build\n" + "\u2500" * 20 + "\n"
        with patch.object(broadcast, "run", return_value=typed):
            self.assertEqual(broadcast.draft("%1"), "pleasecheckthebuild")

    def test_a_full_box_is_left_alone(self):
        fake = FakeTmux(["half typed answer"])
        with patch.object(broadcast, "run", fake):
            self.assertIsNone(broadcast.wait_for_clear("%1", 0.0, step=0.0))
        self.assertEqual(fake.send_keys(), [])


class TargetsTest(unittest.TestCase):
    def test_a_session_seen_twice_is_listed_once(self):
        sessions = [dict(kind="interactive", sessionId="sid-1", name="triage", pid=10)]
        chats = {"sid-1": dict(sid="sid-1", name="term-abc", visible=True)}
        with patch.object(broadcast, "panes", return_value={"pts/1": dict(pane="%1", name="triage")}), \
             patch.object(broadcast, "tty_of", return_value="pts/1"), \
             patch.object(broadcast, "host_chats", return_value=chats), \
             patch.object(broadcast, "host_processes", return_value={sid: "claude" for sid in chats}), \
             patch.object(broadcast, "claude_sessions", return_value=sessions):
            rows = broadcast.targets()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["channel"], "terminal")

    def test_a_chat_with_no_terminal_is_a_chat_target(self):
        sessions = [dict(kind="interactive", sessionId="sid-2", name="Pecunia", pid=None)]
        chats = {"sid-2": dict(sid="sid-2", name="live-abc", visible=True)}
        with patch.object(broadcast, "panes", return_value={}), \
             patch.object(broadcast, "tty_of", return_value="?"), \
             patch.object(broadcast, "host_chats", return_value=chats), \
             patch.object(broadcast, "host_processes", return_value={sid: "claude" for sid in chats}), \
             patch.object(broadcast, "claude_sessions", return_value=sessions):
            rows = broadcast.targets()
        self.assertEqual([(row["name"], row["channel"]) for row in rows], [("Pecunia", "chat")])

    def test_a_chat_with_no_running_host_is_not_a_target(self):
        chats = {"sid-3": dict(sid="sid-3", name="live-old", visible=True)}
        with patch.object(broadcast, "panes", return_value={}), \
             patch.object(broadcast, "host_chats", return_value=chats), \
             patch.object(broadcast, "host_processes", return_value={}), \
             patch.object(broadcast, "claude_sessions", return_value=[]):
            self.assertEqual(broadcast.targets(), [])

    def test_a_live_chat_outside_the_agent_list_is_a_target(self):
        chats = {"sid-4": dict(sid="sid-4", name="live-abc")}
        with patch.object(broadcast, "panes", return_value={}), \
             patch.object(broadcast, "host_chats", return_value=chats), \
             patch.object(broadcast, "host_processes", return_value={"sid-4": "claude"}), \
             patch.object(broadcast, "claude_sessions", return_value=[]):
            rows = broadcast.targets()
        self.assertEqual([(row["name"], row["channel"], row["provider"]) for row in rows],
                         [("live-abc", "chat", "claude")])


class MainTest(unittest.TestCase):
    def run_main(self, rows, dry=False):
        output = io.StringIO()
        with patch.object(broadcast, "targets", return_value=rows), \
             patch.object(broadcast, "host_send", return_value="queued") as host, \
             patch.object(broadcast, "draft", return_value=""), \
             patch.object(broadcast, "type_into", return_value=True) as typed, \
             redirect_stdout(output):
            code = broadcast.main(["hello"] + (["--dry-run"] if dry else []))
        return code, output.getvalue(), host, typed

    def test_a_live_chat_goes_through_the_host_send_command(self):
        rows = [dict(name="Pecunia", sid="sid-2", channel="chat")]
        code, output, host, typed = self.run_main(rows)
        host.assert_called_once()
        self.assertEqual(host.call_args.args[:2], ("claude", "sid-2"))
        self.assertIn("[broadcast from", host.call_args.args[2])
        typed.assert_not_called()
        self.assertEqual(code, 0)
        self.assertIn("reached 1 of 1 live sessions", output)

    def test_a_terminal_broadcast_types_and_reports_one_line_per_session(self):
        rows = [dict(name="triage", sid="sid-1", channel="terminal", pane="%1")]
        code, output, host, typed = self.run_main(rows)
        typed.assert_called_once()
        host.assert_not_called()
        self.assertEqual(code, 0)
        self.assertEqual(output.count("triage ["), 1)

    def test_dry_run_touches_nothing(self):
        rows = [dict(name="triage", sid="sid-1", channel="terminal", pane="%1"),
                dict(name="Pecunia", sid="sid-2", channel="chat")]
        code, output, host, typed = self.run_main(rows, dry=True)
        host.assert_not_called()
        typed.assert_not_called()
        self.assertEqual(code, 0)
        self.assertIn("would reach 2 of 2 live sessions", output)

    def test_a_session_without_a_channel_is_reported(self):
        rows = [dict(name="orphan", sid="sid-9", channel="none")]
        code, output, host, typed = self.run_main(rows)
        self.assertIn("orphan [none] no terminal and no chat", output)
        self.assertEqual(code, 1)
