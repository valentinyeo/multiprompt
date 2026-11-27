import hashlib
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

    def test_SOFT_3060_stopped_hosted_chats_still_appear_in_the_session_list(self):
        module = load_mp_send()
        host = self.home / ".local/state/multiprompt/agent-host"
        host.mkdir(parents=True)
        tmux, sid = "live-stopped", SID
        (host / "k1.config.json").write_text(json.dumps(dict(cwd="/work/x", enabled=True, tmux=tmux)))
        (host / "k1.state.json").write_text(json.dumps(dict(sid=sid, pid=99999999, provider="claude", started=1.0)))
        names = self.home / ".local/state/multiprompt/chat-names.json"
        names.write_text(json.dumps({tmux: dict(name="Paused Lead", at=1.0)}))
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        tmux_sh = bin_dir / "tmux"
        tmux_sh.write_text("#!/bin/sh\nif [ \"$1\" = list-sessions ]; then printf 'live-stopped\\n'; exit 0; fi\nexit 1\n")
        tmux_sh.chmod(0o755)
        os.environ["HOME"] = str(self.home)
        os.environ["PATH"] = str(bin_dir) + os.pathsep + os.environ.get("PATH", "")
        chats = {row["tmux"]: row for row in module.live_chats()}
        self.assertIn(tmux, chats)
        self.assertEqual(chats[tmux]["state"], "stopped")
        self.assertEqual(chats[tmux]["name"], "Paused Lead")

    def hosted_fixture(self, tmux, sid, name, pid, physical=(), provider="claude"):
        host = self.home / ".local/state/multiprompt/agent-host"
        host.mkdir(parents=True, exist_ok=True)
        key = "k" + str(len(list(host.glob("*.config.json"))))
        (host / (key + ".config.json")).write_text(json.dumps(dict(cwd="/work/x", enabled=True, tmux=tmux)))
        (host / (key + ".state.json")).write_text(json.dumps(dict(sid=sid, pid=pid, provider=provider, started=1.0)))
        names = self.home / ".local/state/multiprompt/chat-names.json"
        known = json.loads(names.read_text()) if names.is_file() else {}
        known[tmux] = dict(name=name, at=1.0)
        names.write_text(json.dumps(known))
        bin_dir = self.home / "bin"
        bin_dir.mkdir(exist_ok=True)
        tmux_sh = bin_dir / "tmux"
        tmux_sh.write_text("#!/bin/sh\nif [ \"$1\" = list-sessions ]; then printf '%s\\n' " + " ".join(physical) +
                           "; exit 0; fi\nexit 1\n")
        tmux_sh.chmod(0o755)
        return dict(HOME=str(self.home), PATH=str(bin_dir) + os.pathsep + os.environ.get("PATH", ""))

    def test_SOFT_3093_a_hosted_chat_without_a_terminal_is_listed(self):
        module = load_mp_send()
        env = self.hosted_fixture("live-no-terminal", SID, "Hosted Lead", os.getpid(), physical=("live-other",))
        with patch.dict(os.environ, env):
            chats = {row["tmux"]: row for row in module.live_chats()}
        self.assertIn("live-no-terminal", chats)
        self.assertEqual(chats["live-no-terminal"]["name"], "Hosted Lead")
        self.assertEqual(chats["live-no-terminal"]["state"], "idle")
        self.assertEqual(chats["live-no-terminal"]["sid"], SID)
        self.assertEqual(chats["live-no-terminal"]["cwd"], "/work/x")

    def test_SOFT_3093_a_terminal_chat_without_a_host_is_listed(self):
        module = load_mp_send()
        env = self.hosted_fixture("live-pane", "22222222-3333-4444-5555-666666666666", "Pane Lead", 99999999,
                                  physical=("live-pane",))
        with patch.dict(os.environ, env):
            chats = {row["tmux"]: row for row in module.live_chats()}
        self.assertIn("live-pane", chats)
        self.assertEqual(chats["live-pane"]["name"], "Pane Lead")
        self.assertEqual(chats["live-pane"]["state"], "stopped")

    def test_SOFT_3093_a_chat_with_no_host_and_no_terminal_is_left_out(self):
        module = load_mp_send()
        env = self.hosted_fixture("live-gone", "33333333-4444-5555-6666-777777777777", "Gone Lead", 99999999,
                                  physical=("live-other",))
        with patch.dict(os.environ, env):
            chats = {row["tmux"]: row for row in module.live_chats()}
        self.assertNotIn("live-gone", chats)

    def test_MUBO_583_antigravity_is_a_supported_provider_like_the_reader(self):
        module = load_mp_send()
        reader = module.reader_module(str(READER))
        self.assertIn("antigravity", module.PROVIDERS)
        self.assertEqual(set(reader.HOST_PROVIDERS), set(module.PROVIDERS))

    def test_MUBO_583_an_antigravity_chat_is_listed_and_the_send_form_accepts_it(self):
        env = self.hosted_fixture("live-antigravity", SID, "Antigravity Lead", os.getpid(), provider="antigravity")
        listed = self.run_send("list", "--json", **env)
        self.assertEqual(listed.returncode, 0, listed.stderr)
        chats = {row["tmux"]: row for row in json.loads(listed.stdout)}
        self.assertEqual(chats["live-antigravity"]["provider"], "antigravity")
        refused = self.run_send("antigravity", SID, "hello", "--tmux", "mp-test-antigravity")
        self.assertEqual(refused.returncode, 2, refused.stderr)
        self.assertIn("no live host or pane agent", refused.stderr)

    def test_MUBO_583_read_returns_the_last_antigravity_answer(self):
        env = self.hosted_fixture("live-antigravity", SID, "Antigravity Lead", os.getpid(), provider="antigravity")
        host = self.home / ".local/state/multiprompt/agent-host"
        key = hashlib.sha256(("antigravity:" + SID).encode()).hexdigest()[:32]
        (host / (key + ".state.json")).write_text(json.dumps(dict(sid=SID, provider="antigravity", pid=os.getpid(),
                                                                  display_history=True)))
        rows = (dict(role="user", text="hello"), dict(role="assistant", text="first answer"),
                dict(role="user", text="again"), dict(role="assistant", text="newest answer"))
        (host / (key + ".history.jsonl")).write_text(
            "\n".join(json.dumps(dict(type="multiprompt_history", row=row)) for row in rows), encoding="utf-8")
        done = self.run_send("read", "Antigravity Lead", **env)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(done.stdout.strip(), "newest answer")

    def test_MUBO_583_an_unknown_provider_is_still_refused(self):
        done = self.run_send("gemini", SID, "hello", "--tmux", "mp-test-gemini")
        self.assertEqual(done.returncode, 2)
        self.assertIn("invalid choice", done.stderr)

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
