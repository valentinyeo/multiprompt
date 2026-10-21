import importlib.util
import os
from pathlib import Path
import socket
import tempfile
import threading
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("tmux_notify", Path(__file__).with_name("tmux_notify.py"))
watcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watcher)


class Titles(unittest.TestCase):
    def test_semantic_title_rules(self):
        for title, expected in (
            ("ordinary title", ""), ("Claude Code", ""), ("✳", ""),
            ("✳  Claude Code  ", ""), ("✳ tab", ""), ("✳   \t\n", ""),
            ("✳  Fix things  ", "Fix things"), ("✳Fix things", "Fix things"),
            ("✳ 💡répair\t\ncode 💡", "rpaircode"), ("✳ 💡", ""),
            ("✳ " + "a" * 100, "a" * 80), ("✳ a:b", "a:b"),
            ("✳ Claude💡 Code", "Claude Code"),
            ("✳ " + "💡" * 1000 + "a" * 100, "a" * 80),
        ):
            with self.subTest(title=title):
                self.assertEqual(watcher.semantic_title("tab", title), expected)

    def test_title_lookup_uses_only_the_explicit_scratch_or_hook_socket(self):
        with patch.object(watcher.subprocess, "run") as run:
            run.return_value.stdout = "✳ subject\n"
            self.assertEqual(watcher.pane_title("%3", "/tmp/example/socket"), "✳ subject")
            self.assertEqual(run.call_args.args[0], ["tmux", "-S", "/tmp/example/socket", "display-message", "-p", "-t", "%3", "#{pane_title}"])
            run.side_effect = OSError
            self.assertEqual(watcher.pane_title("%3", "/tmp/example/socket"), "")
            run.reset_mock()
            self.assertEqual(watcher.pane_title("invalid", "socket"), "")
            run.assert_not_called()


class Agents(unittest.TestCase):
    def test_script_detection_skips_options_not_prompts(self):
        for argv, expected in (
            (["/usr/bin/agent", "--use-system-ca", "/opt/cursor-agent/versions/v1/index.js"], "cursor"),
            (["/usr/bin/node", "/tmp/ordinary.js", "/opt/cursor-agent/versions/v1/index.js"], "none"),
            (["node", "/npm/pi-coding-agent/dist/cli.js"], "pi"),
            (["bun", "/npm/@openai/codex/bin/codex.js"], "codex"),
            (["bash", "-c", "claude"], "none"), (["node", "--eval", "claude"], "none"),
        ):
            with self.subTest(argv=argv):
                self.assertEqual(watcher.agent_from_argv(argv), expected)

    def process(self, proc, pid, comm="bash", args=("bash",), children=()):
        path = proc / str(pid)
        (path / "task" / str(pid)).mkdir(parents=True)
        (path / "comm").write_text(comm + "\n", encoding="utf-8")
        (path / "cmdline").write_bytes(("\0".join(args) + "\0").encode())
        (path / "task" / str(pid) / "children").write_text(" ".join(map(str, children)), encoding="utf-8")

    def test_pane_command_shortcut_and_invalid_pid(self):
        for agent in watcher.AGENTS:
            self.assertEqual(watcher.detect_agent(agent, "missing"), agent)
        self.assertEqual(watcher.detect_agent("bash", "../1"), "none")

    def test_proc_tree_three_levels_and_comm(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = Path(tmp)
            self.process(proc, 1, children=(2, 99))
            self.process(proc, 2, children=(3,))
            self.process(proc, 3, children=(4,))
            self.process(proc, 4, "hax", children=(5,))
            self.process(proc, 5, "claude")
            self.assertEqual(watcher.detect_agent("bash", "1", proc), "hax")
            (proc / "4/comm").write_text("bash", encoding="utf-8")
            self.assertEqual(watcher.detect_agent("bash", "1", proc), "none")

    def test_proc_script_and_disappearing_process(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = Path(tmp)
            self.process(proc, 1, children=(2, 3))
            self.process(proc, 3, "node", ("node", "--use-system-ca", "/opt/cursor-agent/versions/v1/index.js"))
            self.assertEqual(watcher.detect_agent("bash", "1", proc), "cursor")
            (proc / "3/cmdline").unlink()
            self.assertEqual(watcher.detect_agent("bash", "1", proc), "none")


class Markers(unittest.TestCase):
    def test_freshness_agent_mode_and_legacy_markers(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            path = directory / "zigshell-semantic-a_b"
            self.assertIsNone(watcher.marker_mode("a/b", "claude", directory))
            path.write_text("claude full\nignored second line", encoding="utf-8")
            now = path.stat().st_mtime
            self.assertEqual(watcher.marker_mode("a/b", "claude", directory, now), "full")
            self.assertIsNone(watcher.marker_mode("a/b", "hax", directory, now))
            self.assertIsNone(watcher.marker_mode("a/b", "claude", directory, now + watcher.MARKER_MAX_AGE))
            path.write_bytes(b"claude full extra\n")
            self.assertEqual(watcher.marker_mode("a/b", "claude", directory), "full extra")
            path.write_bytes(b"claude full\r\n")
            self.assertEqual(watcher.marker_mode("a/b", "claude", directory), "full\r")
            path.write_text("codex notify", encoding="utf-8")
            self.assertEqual(watcher.marker_mode("a/b", "codex", directory), "notify")
            path.write_text("", encoding="utf-8")
            for agent in ("claude", "codex"):
                self.assertEqual(watcher.marker_mode("a/b", agent, directory), "")
            self.assertIsNone(watcher.marker_mode("a/b", "hax", directory))


class Delivery(unittest.TestCase):
    def setUp(self):
        title = patch.object(watcher, "pane_title", side_effect=lambda pane, socket_path: pane)
        title.start()
        self.addCleanup(title.stop)

    def dispatch(self, fields, send):
        watcher.dispatch([*fields, "socket"], send)

    def test_suppression_matrix(self):
        for agent in ("claude", "codex", "hax", "none"):
            for mode in (None, "", "notify", "full"):
                for event in ("activity", "silence"):
                    with self.subTest(agent=agent, mode=mode, event=event), \
                            patch.object(watcher, "detect_agent", return_value=agent), \
                            patch.object(watcher, "marker_mode", return_value=mode):
                        messages = []
                        self.dispatch([event, "tab", "bash", "1", ""], messages.append)
                        deliver = mode != "full" if event == "activity" else agent == "none" or mode is None
                        expected = [("ACTIVE:" if event == "activity" else "DONE:") + "tab"] if deliver else []
                        self.assertEqual(messages, expected)

    def test_lifecycle_and_reconnect_title(self):
        messages = []
        with patch.object(watcher, "detect_agent", return_value="hax") as detect:
            self.dispatch(["session", "tab", "bash", "1", "✳ task"], messages.append)
            self.dispatch(["attach", "tab", "bash", "1", "✳ task"], messages.append)
            self.dispatch(["title", "tab", "bash", "1", "✳ new:task"], messages.append)
        self.assertEqual(detect.call_count, 2)
        self.assertEqual(messages, ["AGENT:tab:hax", "AGENT:tab:hax", "TITLE:tab:task", "TITLE:tab:new:task"])

    def test_none_agent_invalid_identity_and_nonsemantic_title(self):
        messages = []
        with patch.object(watcher, "detect_agent", return_value="none"):
            for name in ("", "a:b", "a|b", "a,b", "a;b", "a\nb", "a\rb", "a" * 121):
                self.dispatch(["activity", name, "bash", "1", ""], messages.append)
            self.dispatch(["session", "tab", "bash", "1", ""], messages.append)
            self.dispatch(["title", "tab", "bash", "1", "Claude Code"], messages.append)
            self.dispatch(["invalid", "tab", "bash", "1", ""], messages.append)
        self.assertEqual(messages, [])

    def test_tcp_contract_one_message_per_connection_without_newline(self):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen()
            listener.settimeout(2)
            connect = socket.create_connection
            address = listener.getsockname()
            for message in ("ACTIVE:tab", "DONE:tab", "TITLE:tab:fix: bug", "AGENT:tab:hax"):
                with patch.object(watcher.socket, "create_connection", side_effect=lambda target, timeout: connect(address, timeout)) as mocked:
                    watcher.notify(message)
                    mocked.assert_called_once_with(("127.0.0.1", 19548), timeout=0.2)
                with listener.accept()[0] as conn:
                    conn.settimeout(2)
                    received = b""
                    while chunk := conn.recv(1024):
                        received += chunk
                self.assertEqual(received, message.encode())

    def test_unavailable_tcp_is_silent(self):
        with patch.object(watcher.socket, "create_connection", side_effect=OSError):
            watcher.notify("DONE:tab")

    @unittest.skipIf(os.name == "nt", "FIFO sender runs on Linux")
    def test_fifo_partial_and_batched_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "events"
            os.mkfifo(path, 0o600)
            stop = threading.Event()
            delivered = threading.Event()
            messages = []

            def send(message):
                messages.append(message)
                if len(messages) == 2:
                    delivered.set()

            thread = threading.Thread(target=watcher.serve_events, args=(path, send, stop))
            thread.start()
            try:
                with open(path, "wb", buffering=0) as fifo:
                    fifo.write(b"title\0tab\0bash\0")
                    fifo.write(("1\0✳ first\0socket\0" + "title\0tab\0bash\0" + "1\0✳ second\0socket\0").encode())
                self.assertTrue(delivered.wait(2))
                self.assertEqual(messages, ["TITLE:tab:first", "TITLE:tab:second"])
            finally:
                stop.set()
                thread.join(2)
                self.assertFalse(thread.is_alive())

    @unittest.skipIf(os.name == "nt", "FIFO sender runs on Linux")
    def test_sender_reuses_fifo_repairs_permissions_and_starts_one_reader(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(watcher.threading, "Thread") as thread:
            directory = Path(tmp)
            path = directory / "tmux-events"
            os.mkfifo(path, 0o600)
            path.chmod(0o666)
            watcher.start_sender(directory)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            thread.assert_called_once_with(target=watcher.serve_events, args=(path,), daemon=True)
            thread.return_value.start.assert_called_once_with()

    @unittest.skipIf(os.name == "nt", "FIFO sender runs on Linux")
    def test_sender_rejects_regular_file_and_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            path = directory / "tmux-events"
            path.write_text("not a FIFO", encoding="utf-8")
            with self.assertRaises(PermissionError):
                watcher.start_sender(directory)
            path.unlink()
            target = directory / "actual"
            os.mkfifo(target)
            path.symlink_to(target)
            with self.assertRaises(PermissionError):
                watcher.start_sender(directory)


if __name__ == "__main__":
    unittest.main()
