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
PI = "eeeeeeee-1111-2222-3333-444444444444"
CODEX = "ffffffff-1111-2222-3333-444444444444"


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
        self.bin.joinpath("tmux").write_text("#!/bin/sh\nif [ \"$1\" = list-sessions ]; then printf 'live-alpha\\nlive-beta\\nlive-gamma\\nlive-dead\\nlive-pi\\nlive-codex\\n'; exit 0; fi\nexit 1\n")
        self.chat("k1", "live-alpha", ALPHA, os.getpid(), busy=False)
        self.chat("k2", "live-beta", BETA, os.getpid(), busy=True)
        self.chat("k3", "live-gamma", GAMMA, os.getpid(), busy=False)
        self.chat("k4", "live-dead", DEAD, 2 ** 22 + 12345, busy=False)
        self.chat("k5", "live-pi", PI, os.getpid(), busy=False, provider="pi", cwd="/work/pi")
        self.chat("k6", "live-codex", CODEX, os.getpid(), busy=False, provider="codex", cwd="/work/codex")
        self.publish({"live-alpha": "Alpha Lead", "live-beta": "Beta Runner", "live-dead": "Gone Chat", "live-pi": "Pi Helper", "live-codex": "Codex Helper"})

    def chat(self, key, tmux, sid, pid, busy, provider="claude", cwd=None):
        (self.host / (key + ".config.json")).write_text(json.dumps(dict(cwd=cwd or "/work/" + tmux, enabled=True, permission_mode="bypassPermissions", tmux=tmux)))
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(sid=sid, pid=pid, provider=provider, started=1.0, inflight={"id": "x"} if busy else None)))

    def publish(self, names):
        path = self.home / ".local/state/multiprompt/chat-names.json"
        path.write_text(json.dumps({tmux: dict(name=name, at=1.0, sid=None) for tmux, name in names.items()}))

    def env(self, **extra):
        base = dict(os.environ, HOME=str(self.home), MULTIPROMPT_READER_SOURCE=str(READER), PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""), CLAUDE_CONFIG_DIR="", PI_CODING_AGENT_SESSION_DIR="")
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
        self.assertEqual(sorted(chats), ["live-alpha", "live-beta", "live-codex", "live-gamma", "live-pi"])
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
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertEqual(self.rows(), [("claude", ALPHA, "From Beta Runner: check the build")])

    def test_IGSH_1865_send_accepts_a_unique_prefix_in_any_case(self):
        done = self.run_tool(MP_SEND, "--to", "BETA", "hello", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertEqual(self.rows(), [("claude", BETA, "From Alpha Lead: hello")])

    def test_IGSH_1865_send_refuses_an_ambiguous_prefix(self):
        self.publish({"live-alpha": "Alpha Lead", "live-beta": "Alpha Runner", "live-gamma": "Gamma"})
        done = self.run_tool(MP_SEND, "--to", "alpha", "hello", MULTIPROMPT_TAB="live-gamma")
        self.assertEqual(done.returncode, 2)
        self.assertIn("more than one chat", done.stderr)
        self.assertEqual(self.rows(), [])

    def test_IGSH_1865_send_takes_the_mention_form_with_the_terminal_session(self):
        done = self.run_tool(MP_SEND, "--to", "@Whatever Name{live-beta}", "hello", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertEqual(self.rows(), [("claude", BETA, "From Alpha Lead: hello")])

    def test_IGSH_1865_send_labels_an_unnamed_sender_by_its_terminal_session(self):
        done = self.run_tool(MP_SEND, "--to", "alpha", "hello", MULTIPROMPT_TAB="live-gamma")
        self.assertEqual(done.returncode, 3, done.stderr)
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
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertEqual(self.rows(), [("claude", ALPHA, "plain")])

    def write_lines(self, path, lines):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(json.dumps(line) for line in lines) + "\n")

    def transcripts(self):
        folder = "".join(c if c.isalnum() else "-" for c in "/work/live-alpha")
        self.write_lines(self.home / ".claude/projects" / folder / (ALPHA + ".jsonl"), [
            {"type": "user", "uuid": "u1", "message": {"role": "user", "content": "question"}},
            {"type": "assistant", "uuid": "a1", "message": {"role": "assistant", "content": [{"type": "text", "text": "old claude answer"}]}},
            {"type": "assistant", "uuid": "a2", "message": {"role": "assistant", "content": [{"type": "text", "text": "newest claude answer"}]}},
            {"type": "user", "uuid": "u2", "message": {"role": "user", "content": "follow up"}},
        ])
        self.write_lines(self.home / ".pi/agent/sessions/--work-pi--" / ("2026-01-01T00-00-00_" + PI + ".jsonl"), [
            {"type": "session", "id": PI, "cwd": "/work/pi"},
            {"type": "message", "id": "p1", "message": {"role": "assistant", "content": [{"type": "text", "text": "pi says hello"}]}},
        ])
        self.write_lines(self.home / ".codex/sessions/2026/01/01" / ("rollout-2026-01-01T00-00-00-" + CODEX + ".jsonl"), [
            {"type": "response_item", "payload": {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "codex says hello"}]}},
        ])

    def test_IGSH_2279_a_pi_chat_and_a_codex_chat_are_in_the_roster(self):
        done = self.run_tool(MP_SESSIONS, "--json")
        chats = {chat["tmux"]: chat for chat in json.loads(done.stdout)}
        self.assertEqual(chats.get("live-pi", {}).get("provider"), "pi")
        self.assertEqual(chats.get("live-pi", {}).get("name"), "Pi Helper")
        self.assertEqual(chats.get("live-pi", {}).get("cwd"), "/work/pi")
        self.assertEqual(chats.get("live-codex", {}).get("provider"), "codex")

    def test_IGSH_2279_a_pi_chat_lists_every_open_chat_with_the_same_tool(self):
        done = self.run_tool(MP_SEND, "list", "--json", MULTIPROMPT_TAB="live-pi")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(sorted(chat["tmux"] for chat in json.loads(done.stdout)), ["live-alpha", "live-beta", "live-codex", "live-gamma", "live-pi"])
        self.assertIn("Alpha Lead", self.run_tool(MP_SEND, "list").stdout)

    def test_IGSH_2279_a_codex_chat_messages_a_claude_chat_and_a_claude_chat_messages_pi(self):
        done = self.run_tool(MP_SEND, "--to", "alpha lead", "ping", MULTIPROMPT_TAB="live-codex")
        self.assertEqual(done.returncode, 3, done.stderr)
        done = self.run_tool(MP_SEND, "--to", "pi helper", "pong", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertEqual(self.rows(), [("claude", ALPHA, "From Codex Helper: ping"), ("pi", PI, "From Alpha Lead: pong")])

    def test_IGSH_2279_read_gives_the_last_answer_of_a_claude_chat(self):
        self.transcripts()
        done = self.run_tool(MP_SEND, "read", "alpha lead", MULTIPROMPT_TAB="live-codex")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(done.stdout.strip(), "newest claude answer")

    def test_IGSH_2279_read_gives_the_last_answer_of_a_pi_and_a_codex_chat(self):
        self.transcripts()
        self.assertEqual(self.run_tool(MP_SEND, "read", "pi helper", MULTIPROMPT_TAB="live-alpha").stdout.strip(), "pi says hello")
        self.assertEqual(self.run_tool(MP_SEND, "read", "codex helper", MULTIPROMPT_TAB="live-pi").stdout.strip(), "codex says hello")

    def test_IGSH_2279_read_says_so_when_a_chat_has_no_answer_yet(self):
        done = self.run_tool(MP_SEND, "read", "beta runner", MULTIPROMPT_TAB="live-alpha")
        self.assertEqual(done.returncode, 3)
        self.assertIn("no answer yet", done.stderr)

    def test_IGSH_2279_a_chat_stops_getting_messages_past_the_cap_per_minute(self):
        for number in range(6):
            done = self.run_tool(MP_SEND, "--to", "alpha lead", "m" + str(number), MULTIPROMPT_TAB="live-gamma")
            self.assertEqual(done.returncode, 3, done.stderr)
        done = self.run_tool(MP_SEND, "--to", "alpha lead", "one too many", MULTIPROMPT_TAB="live-beta")
        self.assertEqual(done.returncode, 5)
        self.assertIn("slow down", done.stderr)
        self.assertEqual(len(self.rows()), 6)

    def test_IGSH_2279_one_sender_is_capped_across_all_chats(self):
        targets = ["alpha lead", "pi helper", "codex helper", "beta runner"]
        for number in range(12):
            done = self.run_tool(MP_SEND, "--to", targets[number % 4], "m" + str(number), MULTIPROMPT_TAB="live-gamma")
            self.assertEqual(done.returncode, 3, done.stderr)
        done = self.run_tool(MP_SEND, "--to", "alpha lead", "again", MULTIPROMPT_TAB="live-gamma")
        self.assertEqual(done.returncode, 5, done.stderr)
        self.assertEqual(len(self.rows()), 12)

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
