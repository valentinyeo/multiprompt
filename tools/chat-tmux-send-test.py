import importlib.util
import json
import os
from pathlib import Path
import selectors
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("reader", ROOT / "src/chat_history_reader.py")
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


REAL_PROMPT_BOX_TEXT = reader.prompt_box_text


class SendTest(unittest.TestCase):
    def setUp(self):
        box = patch.object(reader, "prompt_box_text", return_value="")
        box.start()
        self.addCleanup(box.stop)

    def send(self, name="term-1", text="please check the build"):
        return reader.send_response(dict(op="send", id=7, tmux=name, text=text))

    def test_IGSH_266_permission_sends_one_digit_without_enter(self):
        with patch.object(reader.subprocess, "run") as run:
            self.assertIn("\tpermission\tok\t", reader.stop_response(dict(op="permission", id=8, tmux="term-1", digit=50)))
            run.assert_called_once_with(["tmux", "send-keys", "-t", "=term-1:", "2"], check=True, capture_output=True, timeout=5)
        for digit in (None, "2", 0, 27, 48, 58, True):
            with patch.object(reader.subprocess, "run") as run:
                self.assertIn("invalid_permission_digit", reader.stop_response(dict(op="permission", id=8, tmux="term-1", digit=digit)))
                run.assert_not_called()

    def test_IGSH_265_stop_sends_only_escape_to_exact_tmux(self):
        with patch.object(reader.subprocess, "run") as run:
            self.assertEqual(reader.stop_response(dict(id=8, tmux="term-1")), "@mp\t8\tstop\tok\t-\t0\n@@MP_END@@\n")
            run.assert_called_once_with(["tmux", "send-keys", "-t", "=term-1:", "Escape"], check=True, capture_output=True, timeout=5)
        for name in ("a;b", "$(x)", "", "a" * 65, None):
            with patch.object(reader.subprocess, "run") as run:
                self.assertIn("invalid_tmux_name", reader.stop_response(dict(id=8, tmux=name)))
                run.assert_not_called()
        with patch.object(reader.subprocess, "run", side_effect=OSError):
            self.assertIn("stop\terror\ttmux_stop_failed", reader.stop_response(dict(id=8, tmux="term-1")))

    def test_IGSH_564_force_send_presses_claude_keys_in_order_without_enter(self):
        with patch.object(reader.subprocess, "run") as run:
            self.assertIn("\tsend_queued\tok\t", reader.stop_response(dict(op="send_queued", id=8, tmux="term-1")))
            run.assert_called_once_with(["tmux", "send-keys", "-t", "=term-1:", "C-x", "C-s"], check=True, capture_output=True, timeout=5)
        with patch.object(reader.subprocess, "run") as run:
            self.assertIn("invalid_tmux_name", reader.stop_response(dict(op="send_queued", id=8, tmux="bad;name")))
            run.assert_not_called()
        with patch.object(reader.subprocess, "run", side_effect=OSError):
            self.assertIn("send_queued\terror\t", reader.stop_response(dict(op="send_queued", id=8, tmux="term-1")))

    def test_name_validation(self):
        for name in ("a;b", "$(x)", "", "a" * 65, "x\n", None, 4):
            with self.subTest(name=name), patch.object(reader.subprocess, "run") as run:
                self.assertEqual(self.send(name), "@mp\t7\tsend\terror\tinvalid_tmux_name\t0\n@@MP_END@@\n")
                run.assert_not_called()
        for name in ("a" * 64, "name._:-09"):
            with patch.object(reader.subprocess, "run"), patch.object(reader.time, "sleep"):
                self.assertIn("\tsend\tok\t-\t0\n", self.send(name))

    def test_literal_send_and_enter_are_separate_argument_lists(self):
        text = 'please check "the build" $HOME \\path'
        with patch.object(reader.subprocess, "run") as run, patch.object(reader.time, "sleep") as pause:
            self.assertEqual(self.send(text=text), "@mp\t7\tsend\tok\t-\t0\n@@MP_END@@\n")
            self.assertEqual(run.call_args_list[0].args[0], ["tmux", "send-keys", "-t", "=term-1:", "-l", "--", text])
            self.assertEqual(run.call_args_list[1].args[0], ["tmux", "send-keys", "-t", "=term-1:", "Enter"])
            self.assertEqual([call.args[0] for call in pause.call_args_list], [0.15, 0.4])
            self.assertTrue(all("shell" not in call.kwargs for call in run.call_args_list))

    def test_multiline_bracketed_buffer_and_unsupported_paste_fallback(self):
        text = "please check the build\nand the tests"
        for supported in (True, False):
            def command(args, **kwargs):
                return subprocess.CompletedProcess(args, 0 if args[1] != "paste-buffer" or supported else 1)
            with self.subTest(supported=supported), patch.object(reader.subprocess, "run", side_effect=command) as run, patch.object(reader.time, "sleep"):
                self.assertIn("\tsend\tok\t", self.send(text=text))
                calls = run.call_args_list
                self.assertEqual(calls[0].args[0][1], "load-buffer")
                self.assertEqual(calls[0].kwargs["input"], text.encode())
                self.assertEqual(calls[1].args[0][1:4], ["paste-buffer", "-p", "-d"])
                literal = [call for call in calls if call.args[0][1] == "send-keys" and "-l" in call.args[0]]
                self.assertEqual(len(literal), int(not supported))
                if literal:
                    self.assertEqual(literal[0].args[0][-1], text)
                self.assertEqual(calls[-1].args[0][-1], "Enter")
                self.assertTrue(any(call.args[0][1] == "delete-buffer" for call in calls))

    def test_text_already_in_the_box_is_never_typed_again(self):
        with patch.object(reader, "prompt_box_text", return_value="please check the build"), \
                patch.object(reader.subprocess, "run") as run, patch.object(reader.time, "sleep"):
            self.assertIn("\tsend\tok\t", self.send())
            self.assertFalse(any("-l" in call.args[0] for call in run.call_args_list))
            self.assertTrue(all(call.args[0][-1] == "Enter" for call in run.call_args_list))

    def test_enter_is_pressed_again_only_while_the_text_stays_in_the_box(self):
        for after, enters in (("", 1), ("please check the build", 2)):
            with self.subTest(after=after), patch.object(reader, "prompt_box_text", side_effect=["", after]), \
                    patch.object(reader.subprocess, "run") as run, patch.object(reader.time, "sleep"):
                self.send()
                self.assertEqual(sum(call.args[0][-1] == "Enter" for call in run.call_args_list), enters)

    def test_prompt_box_text_reads_only_the_input_box(self):
        screen = "\u25cf earlier answer mentions please check the build\n\u2500\u2500\u2500\n\u276f please check\n  the build\n\u2500\u2500\u2500\n  Opus 5.5 status\n"
        with patch.object(reader.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, stdout=screen)):
            self.assertEqual(REAL_PROMPT_BOX_TEXT("=term-1:"), "please check the build")
        with patch.object(reader.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, stdout="$ plain shell\n")):
            self.assertEqual(REAL_PROMPT_BOX_TEXT("=term-1:"), "")

    def test_failures_do_not_send_enter(self):
        for error in (OSError("missing"), subprocess.CalledProcessError(1, "tmux"), subprocess.TimeoutExpired("tmux", 5)):
            with patch.object(reader.subprocess, "run", side_effect=error) as run:
                self.assertIn("\tsend\terror\ttmux_send_failed\t0\n", self.send())
                self.assertEqual(run.call_count, 1)
        for text in ("", None, "bad\x00text"):
            with patch.object(reader.subprocess, "run") as run:
                self.assertIn("invalid_text", self.send(text=text))
                run.assert_not_called()

    def test_serve_invalid_name_and_error_envelope(self):
        result = subprocess.run([sys.executable, str(ROOT / "src/chat_history_reader.py"), "--serve"], input=json.dumps(dict(op="send", id=91, tmux="a;b", text="please check the build")) + "\n", text=True, capture_output=True, check=True, timeout=5)
        self.assertEqual(json.loads(result.stdout), dict(id=91, wire="@mp\t91\tsend\terror\tinvalid_tmux_name\t0\n@@MP_END@@\n"))


class DetachedSendTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("tmux"), "tmux is not installed; detached delivery cannot run")
    def test_detached_serve_literal_and_multiline_exactly_once(self):
        name = "mp-test-" + uuid.uuid4().hex
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        tmp = temp.name
        output = Path(tmp) / "received"
        env = dict(os.environ, TMUX_TMPDIR=tmp)
        env.pop("TMUX", None)
        subprocess.run(["tmux", "new-session", "-d", "-s", name, "cat >> " + shlex.quote(str(output))], check=True, capture_output=True, timeout=5, env=env)
        def kill_session():
            subprocess.run(["tmux", "kill-session", "-t", "=" + name], capture_output=True, timeout=5, env=env, check=True)
            remaining = subprocess.run(["tmux", "has-session", "-t", "=" + name], capture_output=True, timeout=5, env=env)
            self.assertNotEqual(remaining.returncode, 0)
            print("detached tmux cleanup PASS: test session removed before its socket directory", flush=True)
        self.addCleanup(kill_session)
        process = subprocess.Popen([sys.executable, str(ROOT / "src/chat_history_reader.py"), "--serve"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
        def close_reader():
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)
        self.addCleanup(close_reader)
        messages = ["please check the build", "please check the build\nand the tests", 'please check "the build" $HOME \\path', "please check the café build"]
        expected = ""
        for rid, text in enumerate(messages, 1):
            process.stdin.write(json.dumps(dict(op="send", id=rid, tmux=name, text=text)) + "\n")
            process.stdin.flush()
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                self.assertTrue(selector.select(10), "reader send response timed out")
            reply = json.loads(process.stdout.readline())
            self.assertEqual(reply, dict(id=rid, wire=f"@mp\t{rid}\tsend\tok\t-\t0\n@@MP_END@@\n"))
            expected += text + "\n"
        process.stdin.close()
        process.stdin = None
        stdout, stderr = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(stdout, "")
        self.assertEqual(output.read_text(), expected)
        attached = subprocess.run(["tmux", "display-message", "-p", "-t", "=" + name + ":", "#{session_attached}"], check=True, capture_output=True, text=True, timeout=5, env=env)
        self.assertEqual(attached.stdout.strip(), "0")
        print("detached tmux delivery PASS: 4 messages exactly once, multiline, quotes, dollar, backslash, UTF-8; never attached", flush=True)


if __name__ == "__main__":
    integration = "--integration" in sys.argv
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(DetachedSendTest if integration else SendTest)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if result.wasSuccessful() and not integration:
        print("reader send validation PASS", flush=True)
    sys.exit(not result.wasSuccessful())
