import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
MP_SEND = ROOT / "tools" / "mp-send"
MP_SEND_SOURCE = ROOT / "src" / "mp_send.py"
READER = ROOT / "src" / "chat_history_reader.py"
SID = "11111111-2222-3333-4444-555555555555"


def load_mp_send():
    loader = importlib.machinery.SourceFileLoader("mp_send", str(MP_SEND_SOURCE))
    spec = importlib.util.spec_from_loader("mp_send", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class MpSendTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.home.mkdir(parents=True, exist_ok=True)

    def store(self):
        return self.home / ".local/state/multiprompt/shared-messages/store.sqlite3"

    def rows(self):
        with sqlite3.connect(self.store()) as db:
            return db.execute("SELECT id,provider,sid,text,state,receipt,position FROM shared_messages ORDER BY position").fetchall()

    def env(self, **extra):
        base = dict(os.environ, HOME=str(self.home), MULTIPROMPT_READER_SOURCE=str(READER))
        base.pop("MULTIPROMPT_RUNTIME_DIR", None)
        base.update(extra)
        return base

    def run_send(self, *args, **extra):
        return subprocess.run([sys.executable, str(MP_SEND), *args], capture_output=True, text=True, env=self.env(**extra), timeout=120)

    def test_SOFT_3085_unknown_session_is_refused_even_with_a_terminal_flag(self):
        done = self.run_send("claude", SID, "check the build", "--tmux", "mp-test-send")
        self.assertEqual(done.returncode, 2, done.stderr)
        self.assertEqual(done.stdout, "")
        self.assertIn("no live host or pane agent", done.stderr)
        self.assertFalse(self.store().exists())

    def test_SOFT_3085_wait_refuses_a_session_with_no_agent(self):
        done = self.run_send("claude", SID, "hello", "--tmux", "mp-test-nobody", "--wait", "--timeout", "20")
        self.assertEqual(done.returncode, 2, done.stderr)
        self.assertEqual(done.stdout, "")
        self.assertIn("no live host or pane agent", done.stderr)
        self.assertFalse(self.store().exists())

    def test_IGSH_1266_second_submit_with_the_same_id_adds_no_second_message(self):
        module = load_mp_send()
        with patch.dict(os.environ, self.env()):
            reader = module.reader_module()
        first = module.submit(reader, "claude", SID, "mp-test-once", "hello", "mp-0123456789abcdef0123")
        second = module.submit(reader, "claude", SID, "mp-test-once", "hello", "mp-0123456789abcdef0123")
        self.assertEqual(first["id"], second["id"])
        self.assertEqual(len(self.rows()), 1)
        self.assertEqual(self.rows()[0][1:4], ("claude", SID, "hello"))

    def test_SOFT_3085_a_stale_terminal_locator_is_not_a_live_destination(self):
        self.store().parent.mkdir(parents=True)
        with sqlite3.connect(self.store()) as db:
            db.execute("CREATE TABLE message_locators (provider TEXT, sid TEXT, tmux TEXT)")
            db.execute("INSERT INTO message_locators VALUES (?,?,?)", ("claude", SID, "mp-test-binding"))
        done = self.run_send("claude", SID, "hello")
        self.assertEqual(done.returncode, 2, done.stderr)
        self.assertEqual(done.stdout, "")
        self.assertIn("no live host or pane agent", done.stderr)
        with sqlite3.connect(self.store()) as db:
            self.assertEqual(db.execute("SELECT name FROM sqlite_master WHERE name='shared_messages'").fetchall(), [])

    def test_IGSH_1266_unknown_binding_fails_without_touching_the_store(self):
        done = self.run_send("claude", SID, "hello")
        self.assertEqual(done.returncode, 2)
        self.assertIn("no live host or pane agent", done.stderr)
        self.assertFalse(self.store().exists())

    def test_IGSH_1266_bad_identity_and_empty_text_are_refused(self):
        self.assertEqual(self.run_send("claude", "bad id", "hello", "--tmux", "mp-test-a").returncode, 2)
        self.assertEqual(self.run_send("claude", SID, "   ", "--tmux", "mp-test-a").returncode, 2)
        self.assertEqual(self.run_send("codex", SID, "hello", "--tmux", "mp-test-a", "--id", "short").returncode, 2)

    def test_IGSH_1266_installed_runtime_reader_is_preferred(self):
        runtime = self.home / ".multiprompt-runtime"
        runtime.mkdir(mode=0o700)
        installed = runtime / ("a" * 64 + ".py")
        installed.write_text(READER.read_text(encoding="utf-8"), encoding="utf-8")
        (runtime / "active.json").write_text(json.dumps(dict(protocol=1, generation=1, sha256="a" * 64)), encoding="utf-8")
        module = load_mp_send()
        os.environ["HOME"] = str(self.home)
        os.environ.pop("MULTIPROMPT_READER_SOURCE", None)
        try:
            self.assertEqual(module.reader_path(), installed)
        finally:
            os.environ["MULTIPROMPT_READER_SOURCE"] = str(READER)

    def test_IGSH_1266_wait_prints_an_accepted_state_and_exits_zero(self):
        module = load_mp_send()
        seen = {}

        class Fake:
            message_store_path = staticmethod(lambda: Path(self.temp.name) / "store.sqlite3")

            @staticmethod
            def message_store_request(query):
                seen.setdefault("ops", []).append(query["op"])
                state = "queued" if query["op"] == "message_submit" else "accepted"
                return dict(message=dict(id=query.get("message_id"), state=state, receipt=None))

            @staticmethod
            def message_poll(tmux, provider, sid):
                return None

        module._reader = Fake
        out, err = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = open(os.devnull, "w"), open(os.devnull, "w")
        try:
            with patch.object(module, "resolve_destination", return_value=(SID, "mp-test-fake")):
                code = module.main(["claude", SID, "hello", "--tmux", "mp-test-fake", "--wait", "--json", "--timeout", "5"])
        finally:
            sys.stdout.close()
            sys.stderr.close()
            sys.stdout, sys.stderr = out, err
        self.assertEqual(code, 0)
        self.assertEqual(seen["ops"], ["message_submit", "message_dispatch", "message_status"])


if __name__ == "__main__":
    unittest.main()
