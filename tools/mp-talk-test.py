import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MP_SEND = ROOT / "tools" / "mp-send"
MP_SESSIONS = ROOT / "tools" / "mp-sessions"
READER = ROOT / "src" / "chat_history_reader.py"
ALPHA = "aaaaaaaa-1111-2222-3333-444444444444"
BETA = "bbbbbbbb-1111-2222-3333-444444444444"
GAMMA = "cccccccc-1111-2222-3333-444444444444"
DEAD = "dddddddd-1111-2222-3333-444444444444"


class ChatsTalkTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.bin = Path(self.temp.name) / "bin"
        self.bin.mkdir(parents=True)
        self.host = self.home / ".local/state/multiprompt/agent-host"
        self.host.mkdir(parents=True)
        tmux = self.bin / "tmux"
        tmux.write_text("#!/bin/sh\nif [ \"$1\" = list-sessions ]; then printf 'live-alpha\\nlive-beta\\nlive-gamma\\nlive-dead\\n'; exit 0; fi\nexit 1\n")
        tmux.chmod(0o755)
        self.chat("k1", "live-alpha", ALPHA, os.getpid(), busy=False)
        self.chat("k2", "live-beta", BETA, os.getpid(), busy=True)
        self.chat("k3", "live-gamma", GAMMA, os.getpid(), busy=False)
        self.chat("k4", "live-dead", DEAD, 2 ** 22 + 12345, busy=False)
        self.publish({"live-alpha": "Alpha Lead", "live-beta": "Beta Runner", "live-dead": "Gone Chat"})

    def chat(self, key, tmux, sid, pid, busy):
        (self.host / (key + ".config.json")).write_text(json.dumps(dict(cwd="/work/" + tmux, enabled=True, permission_mode="bypassPermissions", tmux=tmux)))
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(sid=sid, pid=pid, provider="claude", started=1.0, inflight={"id": "x"} if busy else None)))

    def publish(self, names):
        path = self.home / ".local/state/multiprompt/chat-names.json"
        path.write_text(json.dumps({tmux: dict(name=name, at=1.0, sid=None) for tmux, name in names.items()}))

    def env(self, **extra):
        base = dict(os.environ, HOME=str(self.home), MULTIPROMPT_READER_SOURCE=str(READER), PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""))
        for name in ("MULTIPROMPT_RUNTIME_DIR", "MULTIPROMPT_TAB", "TMUX_PANE"):
            base.pop(name, None)
        base.update(extra)
        return base

    def run_tool(self, tool, *args, **extra):
        return subprocess.run([sys.executable, str(tool), *args], capture_output=True, text=True, env=self.env(**extra), timeout=120)

    def rows(self):
        store = self.home / ".local/state/multiprompt/shared-messages/store.sqlite3"
        if not store.is_file():
            return []
        with sqlite3.connect(store) as db:
            return db.execute("SELECT provider,sid,text FROM shared_messages ORDER BY position").fetchall()

    def test_IGSH_1865_sessions_lists_live_chats_by_desktop_name(self):
        done = self.run_tool(MP_SESSIONS, "--json")
        self.assertEqual(done.returncode, 0, done.stderr)
        chats = {chat["tmux"]: chat for chat in json.loads(done.stdout)}
        self.assertEqual(sorted(chats), ["live-alpha", "live-beta", "live-gamma"])
        self.assertEqual(chats["live-alpha"]["name"], "Alpha Lead")
        self.assertEqual(chats["live-alpha"]["sid"], ALPHA)
        self.assertEqual(chats["live-alpha"]["provider"], "claude")
        self.assertEqual(chats["live-alpha"]["cwd"], "/work/live-alpha")
        self.assertEqual(chats["live-alpha"]["state"], "idle")
        self.assertEqual(chats["live-beta"]["state"], "busy")
        self.assertIsNone(chats["live-gamma"]["name"])

    def test_IGSH_1865_sessions_prints_a_readable_table(self):
        done = self.run_tool(MP_SESSIONS)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("Alpha Lead", done.stdout)
        self.assertIn("live-beta", done.stdout)
        self.assertIn("busy", done.stdout)
        self.assertNotIn("Gone Chat", done.stdout)

    def test_IGSH_1865_send_by_name_reaches_that_chat_and_says_who_sent_it(self):
        done = self.run_tool(MP_SEND, "--to", "alpha lead", "check the build", MULTIPROMPT_TAB="live-beta")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.rows(), [("claude", ALPHA, "From Beta Runner: check the build")])

    def test_IGSH_1865_send_accepts_a_unique_prefix_in_any_case(self):
        done = self.run_tool(MP_SEND, "--to", "BETA", "hello", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.rows(), [("claude", BETA, "From Alpha Lead: hello")])

    def test_IGSH_1865_send_refuses_an_ambiguous_prefix(self):
        self.publish({"live-alpha": "Alpha Lead", "live-beta": "Alpha Runner", "live-gamma": "Gamma"})
        done = self.run_tool(MP_SEND, "--to", "alpha", "hello", MULTIPROMPT_TAB="live-gamma")
        self.assertEqual(done.returncode, 2)
        self.assertIn("more than one chat", done.stderr)
        self.assertEqual(self.rows(), [])

    def test_IGSH_1865_send_takes_the_mention_form_with_the_terminal_session(self):
        done = self.run_tool(MP_SEND, "--to", "@Whatever Name{live-beta}", "hello", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.rows(), [("claude", BETA, "From Alpha Lead: hello")])

    def test_IGSH_1865_send_labels_an_unnamed_sender_by_its_terminal_session(self):
        done = self.run_tool(MP_SEND, "--to", "alpha", "hello", MULTIPROMPT_TAB="live-gamma")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.rows(), [("claude", ALPHA, "From live-gamma: hello")])

    def test_IGSH_1865_send_needs_to_know_who_is_sending(self):
        done = self.run_tool(MP_SEND, "--to", "alpha", "hello")
        self.assertEqual(done.returncode, 2)
        self.assertIn("--from", done.stderr)
        self.assertEqual(self.rows(), [])

    def test_IGSH_1865_send_refuses_a_chat_that_is_not_live(self):
        done = self.run_tool(MP_SEND, "--to", "Gone Chat", "hello", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 2)
        self.assertIn("no live chat", done.stderr)

    def test_IGSH_1865_send_refuses_to_message_itself(self):
        done = self.run_tool(MP_SEND, "--to", "alpha", "hello", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 2)
        self.assertEqual(self.rows(), [])

    def test_IGSH_1865_old_send_form_still_works(self):
        done = self.run_tool(MP_SEND, "claude", ALPHA, "plain", "--tmux", "live-alpha")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.rows(), [("claude", ALPHA, "plain")])

    def test_IGSH_1865_reader_stores_names_the_desktop_publishes(self):
        script = (
            "import importlib.util,json,sys;"
            "spec=importlib.util.spec_from_file_location('r',sys.argv[1]);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);"
            "print(json.dumps(m.chat_names_publish([{'tmux':'live-zeta','name':' Zeta Chat ','sid':'" + GAMMA + "'},{'tmux':'bad name','name':'x'},{'tmux':'live-eta','name':''}])))"
        )
        done = subprocess.run([sys.executable, "-c", script, str(READER)], capture_output=True, text=True, env=self.env(), timeout=120)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(json.loads(done.stdout), {"status": "ok", "count": 1})
        stored = json.loads((self.home / ".local/state/multiprompt/chat-names.json").read_text())
        self.assertEqual(stored["live-zeta"]["name"], "Zeta Chat")
        self.assertEqual(stored["live-alpha"]["name"], "Alpha Lead")
        self.assertNotIn("bad name", stored)
        self.assertNotIn("live-eta", stored)


if __name__ == "__main__":
    unittest.main()
