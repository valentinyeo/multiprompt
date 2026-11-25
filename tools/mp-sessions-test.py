import hashlib
import json
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
MP_SESSIONS = ROOT / "tools" / "mp-sessions"
MUBO_194_FIXTURES = ROOT / "tools" / "fixtures" / "MUBO-194"

FAKE_READER = r'''
import json, os, sys
from pathlib import Path
LOG = Path(os.environ["MP_SESSIONS_TEST_LOG"])

def note(kind, value):
    with LOG.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps([kind, value]) + "\n")

if __name__ == "__main__" and sys.argv[1:2] == ["host"]:
    note("host", sys.argv[2:])
    status = dict(enable="enabled", start="started", stop="stopped").get(sys.argv[2], "error")
    print(json.dumps(dict(status=status, sid=sys.argv[3] if len(sys.argv) > 3 else None)))
'''

FAKE_ZSB = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ["MP_SESSIONS_TEST_LOG"], "a", encoding="utf-8") as stream:
    stream.write(json.dumps(["zsb", sys.argv[1:]]) + "\n")
state_file = os.environ.get("MP_SESSIONS_TEST_STATE_FILE")
state = {}
if state_file and os.path.exists(state_file):
    state = json.loads(open(state_file, encoding="utf-8").read())
if sys.argv[1] == "workspace-list":
    listing = json.loads(os.environ.get("MP_SESSIONS_TEST_LIST", "{}"))
    if state.get("tabs"):
        listing["workspaces"][0]["tabs"] = state["tabs"]
    print(json.dumps(listing))
elif sys.argv[1] == "session-open":
    tmux = sys.argv[sys.argv.index("--tmux") + 1]
    state.setdefault("tabs", [])
    state["tabs"].append(dict(id=55, title=sys.argv[sys.argv.index("--name") + 1], host="remote-1", tmux=tmux))
    Path(os.environ["MP_SESSIONS_TEST_STATE_FILE"]).write_text(json.dumps(state), encoding="utf-8")
    print(json.dumps(dict(ok=True, created=True, tab=55)))
elif sys.argv[1] == "session-rename":
    tab_id = int(sys.argv[sys.argv.index("--tab") + 1])
    for tab in state.get("tabs", []):
        if tab["id"] == tab_id:
            tab["title"] = sys.argv[sys.argv.index("--name") + 1]
    Path(state_file).write_text(json.dumps(state), encoding="utf-8")
    print(json.dumps(dict(ok=True)))
else:
    print(json.dumps(dict(ok=True)))
'''

LEGACY_SEND = '''
import os

class RateLimited(ValueError):
    pass

def live_chats():
    return [dict(name="Legacy Chat", provider="claude", sid="legacy-session", tmux="live-legacy",
                 cwd="/work", state="idle")]

def own_tmux():
    return os.environ.get("MULTIPROMPT_TAB")
'''

LISTING = dict(ok=True, hosts=["remote-1"], workspaces=[
    dict(id=0, name="Home", active=True, groups=[], tabs=[dict(id=40, title="Anchor", host="remote-1", tmux="live-anchor")]),
    dict(id=1, name="Away", active=False, groups=[], tabs=[]),
])
READER = ROOT / "src" / "chat_history_reader.py"


class MpSessionsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.home = base / "home"
        self.work = base / "work"
        self.bin = base / "bin"
        for folder in (self.home, self.work, self.bin):
            folder.mkdir(parents=True)
        self.log = base / "log.jsonl"
        self.state_file = base / "state.json"
        self.state_file.write_text("{}", encoding="utf-8")
        self.reader = base / "reader.py"
        self.reader.write_text(FAKE_READER, encoding="utf-8")
        zsb = self.bin / "zsb"
        zsb.write_text(FAKE_ZSB.replace("/usr/bin/env python3", sys.executable), encoding="utf-8")
        zsb.chmod(0o755)
        self.host = self.home / ".local/state/multiprompt/agent-host"
        (self.home / ".local/state/multiprompt").mkdir(parents=True, exist_ok=True)

    def env(self, **extra):
        base = dict(os.environ, HOME=str(self.home), MULTIPROMPT_READER_SOURCE=str(self.reader),
                    MP_SESSIONS_TEST_LOG=str(self.log), MP_SESSIONS_TEST_LIST=json.dumps(LISTING),
                    MP_SESSIONS_TEST_STATE_FILE=str(self.state_file),
                    PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""))
        for name in ("MULTIPROMPT_RUNTIME_DIR", "TMUX_PANE", "MULTIPROMPT_TAB", "MULTIBOT_PROVIDER",
                     "MULTIBOT_SID", "MULTIBOT_SESSION", "ZSB_SESSION", "MULTIPROMPT_LAYOUT_PATH",
                     "MULTIPROMPT_HOST"):
            base.pop(name, None)
        base["MULTIPROMPT_HOST"] = "0"
        base.update(extra)
        return {key: value for key, value in base.items() if value is not None}

    def run_sessions(self, *args, **extra):
        return subprocess.run([sys.executable, str(MP_SESSIONS), *args], capture_output=True, text=True,
                              env=self.env(**extra), cwd=str(self.work), timeout=60)

    def servers_file(self, slot=None, hostname=None):
        facts = json.loads((ROOT / "tools/fixtures/MUBO-294/servers.json").read_text(encoding="utf-8"))
        if hostname is not None:
            facts["servers"][0]["hostname"] = hostname
        if slot is not None:
            facts["servers"][0]["multiprompt_slot"] = slot
        path = self.home / "servers.json"
        path.write_text(json.dumps(facts), encoding="utf-8")
        return path

    def parsed(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def events(self, kind):
        if not self.log.exists():
            return []
        return [value for name, value in (json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()) if name == kind]

    def mark_running(self, started):
        key = hashlib.sha256(("claude:" + started["sid"]).encode()).hexdigest()[:32]
        path = self.host / (key + ".config.json")
        self.assertTrue(path.is_file(), str(path))
        config = json.loads(path.read_text(encoding="utf-8"))
        config["enabled"] = True
        (self.host / (key + ".config.json")).write_text(json.dumps(config), encoding="utf-8")
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(sid=started["sid"], provider="claude",
                                                                       pid=os.getpid())), encoding="utf-8")

    def identity_chat(self, provider="claude", sid="caller-session", tmux="live-caller", name="My Chat"):
        self.host.mkdir(parents=True, exist_ok=True)
        key = hashlib.sha256((provider + ":" + sid).encode()).hexdigest()[:32]
        (self.host / (key + ".config.json")).write_text(json.dumps(dict(
            provider=provider, sid=sid, tmux=tmux, spawn_display="Old launch name")), encoding="utf-8")
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(
            provider=provider, sid=sid, pid=os.getpid())), encoding="utf-8")
        state = json.loads(self.state_file.read_text(encoding="utf-8"))
        tabs = state.setdefault("tabs", [])
        if not any(tab["tmux"] == tmux for tab in tabs):
            tabs.append(dict(id=len(tabs) + 50, title=name, tmux=tmux, host="remote-1"))
        self.state_file.write_text(json.dumps(state), encoding="utf-8")

    def test_SOFT_2451_whoami_json_identifies_only_the_caller_for_every_host_provider(self):
        for provider in ("claude", "codex", "pi", "hax", "cursor"):
            self.identity_chat(provider, provider + "-session", "live-" + provider)
        for provider in ("claude", "codex", "pi", "hax", "cursor"):
            for hosted in (False, True):
                with self.subTest(provider=provider, hosted=hosted):
                    extra = dict(MULTIBOT_PROVIDER=provider, MULTIBOT_SID=provider + "-session") if hosted else {}
                    identity = self.parsed(self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-" + provider, **extra))
                    self.assertEqual(identity, dict(name="My Chat", sid=provider + "-session", provider=provider,
                                                    tmux="live-" + provider, link="@My Chat{live-" + provider + "}"))
        self.assertEqual(self.events("host"), [])
        self.assertTrue(all(call == ["workspace-list"] for call in self.events("zsb")))

    def test_SOFT_2451_whoami_text_prints_name_session_and_linked_agent(self):
        self.identity_chat("codex")
        done = self.run_sessions("whoami", MULTIPROMPT_TAB="live-caller")
        self.assertEqual(done.returncode, 0, done.stderr)
        for text in ("My Chat", "caller-session", "codex", "@My Chat{live-caller}"):
            self.assertIn(text, done.stdout)

    def test_SOFT_2451_whoami_reads_a_rename_immediately_without_using_cached_names(self):
        self.identity_chat()
        cached = self.home / ".local/state/multiprompt/chat-names.json"
        cached.write_text(json.dumps({"live-caller": dict(name="Stale published name", at=1)}), encoding="utf-8")
        first = self.parsed(self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-caller"))
        self.assertEqual(first["name"], "My Chat")
        before = time.monotonic()
        self.parsed(self.run_sessions("rename", "My Chat", "Renamed Chat"))
        renamed = self.parsed(self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-caller"))
        self.assertEqual(renamed["name"], "Renamed Chat")
        self.assertEqual(renamed["sid"], first["sid"])
        self.assertEqual(renamed["link"], "@Renamed Chat{live-caller}")
        self.assertLess(time.monotonic() - before, 60)

    def test_SOFT_2451_whoami_resolves_the_calling_tmux_pane(self):
        self.identity_chat()
        tmux = self.bin / "tmux"
        tmux.write_text("#!" + sys.executable + "\nimport sys\nif sys.argv[1:] == "
                        "['display-message', '-p', '-t', '%7', '#{session_name}']:\n print('live-caller')\n"
                        "else:\n sys.exit(1)\n", encoding="utf-8")
        tmux.chmod(0o755)
        identity = self.parsed(self.run_sessions("whoami", "--json", TMUX_PANE="%7"))
        self.assertEqual(identity["name"], "My Chat")
        self.assertEqual(identity["sid"], "caller-session")

    def test_SOFT_2451_whoami_refuses_to_guess_a_peer_without_a_caller(self):
        self.identity_chat()
        for extra in ({}, dict(MULTIPROMPT_TAB="live-missing")):
            with self.subTest(extra=extra):
                done = self.run_sessions("whoami", "--json", **extra)
                self.assertEqual(done.returncode, 2)
                self.assertEqual(done.stdout, "")
                self.assertIn("this chat", done.stderr)

    def test_SOFT_2451_whoami_falls_back_to_local_name_or_tmux_without_a_desktop_tab(self):
        self.identity_chat()
        self.state_file.write_text("{}", encoding="utf-8")
        cached = self.home / ".local/state/multiprompt/chat-names.json"
        for listing in (dict(ok=False, error="offline"), LISTING):
            for name in ("Published caller", "live-caller"):
                with self.subTest(listing=listing, name=name):
                    cached.write_text(json.dumps({"live-caller": dict(name=name)}), encoding="utf-8")
                    if name == "live-caller":
                        cached.unlink()
                    identity = self.parsed(self.run_sessions(
                        "whoami", "--json", MULTIPROMPT_TAB="live-caller",
                        MP_SESSIONS_TEST_LIST=json.dumps(listing)))
                    self.assertEqual(identity, dict(name=name, sid="caller-session", provider="claude",
                                                    tmux="live-caller", link=("@" if " " in name else "") + name + "{live-caller}"))

    def test_SOFT_2451_whoami_through_content_addressed_runtime_symlinks(self):
        self.identity_chat()
        cached = self.home / ".local/state/multiprompt/chat-names.json"
        cached.write_text(json.dumps({"live-caller": dict(name="Published caller")}), encoding="utf-8")
        runtime = self.home / ".multiprompt-runtime"
        runtime.mkdir()
        for name, body in (("mp-sessions", (ROOT / "src/mp_sessions.py").read_text(encoding="utf-8")),
                           ("mp-send", (ROOT / "src/mp_send.py").read_text(encoding="utf-8")),
                           ("mp-zsb", FAKE_ZSB.replace("/usr/bin/env python3", sys.executable))):
            target = runtime / (hashlib.sha256(body.encode()).hexdigest() + "-" + name)
            target.write_text(body, encoding="utf-8")
            target.chmod(0o700)
            (runtime / name).symlink_to(target.name)
        (self.bin / "zsb").unlink()
        for online, name in ((True, "My Chat"), (False, "Published caller")):
            with self.subTest(online=online):
                listing = dict(LISTING, ok=online)
                done = subprocess.run([sys.executable, str(runtime / "mp-sessions"), "whoami", "--json"],
                                      capture_output=True, text=True, cwd=str(self.work), timeout=10,
                                      env=self.env(MULTIPROMPT_TAB="live-caller",
                                                   MP_SESSIONS_TEST_LIST=json.dumps(listing)))
                self.assertEqual(self.parsed(done), dict(name=name, sid="caller-session", provider="claude",
                                                        tmux="live-caller", link="@" + name + "{live-caller}"))
        self.assertEqual(self.events("zsb"), [["workspace-list"], ["workspace-list"]])
        self.assertEqual(self.events("host"), [])

    def test_SOFT_2451_whoami_refuses_duplicate_terminal_names_across_hosts(self):
        self.identity_chat()
        state = json.loads(self.state_file.read_text(encoding="utf-8"))
        state["tabs"].append(dict(id=99, title="Another host's chat", tmux="live-caller", host="remote-2"))
        self.state_file.write_text(json.dumps(state), encoding="utf-8")
        done = self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-caller")
        self.assertEqual(done.returncode, 2)
        self.assertEqual(done.stdout, "")

    def test_SOFT_2451_whoami_does_not_borrow_a_peers_session_id(self):
        self.identity_chat()
        self.identity_chat("codex", "peer-session", "live-peer")
        for path in self.host.glob("*.json"):
            if json.loads(path.read_text(encoding="utf-8")).get("sid") == "caller-session":
                path.unlink()
        done = self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-caller")
        self.assertEqual(done.returncode, 2)
        self.assertEqual(done.stdout, "")

    def test_SOFT_2451_whoami_disambiguates_host_bindings_only_with_the_callers_identity(self):
        self.identity_chat()
        self.identity_chat("codex", "previous-session")
        ambiguous = self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-caller")
        self.assertEqual(ambiguous.returncode, 2)
        self.assertEqual(ambiguous.stdout, "")
        own = self.parsed(self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-caller",
                                            MULTIBOT_PROVIDER="claude", MULTIBOT_SID="caller-session"))
        self.assertEqual(own["sid"], "caller-session")
        self.assertEqual(own["provider"], "claude")

    def legacy_runtime(self):
        runtime = self.home / ".multiprompt-runtime"
        runtime.mkdir()
        for name, body in (("mp-sessions", (ROOT / "src/mp_sessions.py").read_text(encoding="utf-8")),
                           ("mp-send", LEGACY_SEND)):
            target = hashlib.sha256(body.encode()).hexdigest() + "-" + name
            (runtime / target).write_text(body, encoding="utf-8")
            (runtime / name).symlink_to(target)
        return runtime / "mp-sessions"

    def test_SOFT_3055_mixed_runtime_lists_without_desktop_helpers(self):
        sessions = self.legacy_runtime()
        for args in ([], ["list"], ["--json"], ["list", "--json"]):
            with self.subTest(args=args):
                done = subprocess.run([sys.executable, str(sessions), *args], capture_output=True, text=True,
                                      env=self.env(MULTIPROMPT_TAB="live-legacy"), timeout=10)
                self.assertEqual(done.returncode, 0, done.stderr)
                self.assertIn("Legacy Chat", done.stdout)
                self.assertEqual(done.stderr, "")
                if "--json" in args:
                    self.assertEqual(json.loads(done.stdout)[0]["sid"], "legacy-session")
                else:
                    self.assertIn("*Legacy Chat", done.stdout)
        self.assertEqual(self.events("zsb"), [])

    def test_SOFT_3055_mixed_runtime_session_commands_explain_the_helper_mismatch(self):
        sessions = self.legacy_runtime()
        commands = (["whoami"], ["list", "--workspace", "mine"], ["start", "--name", "New"],
                    ["restart", "Legacy Chat"], ["rename", "Legacy Chat", "New"],
                    ["move", "Legacy Chat", "--workspace", "Home"], ["close", "Legacy Chat"],
                    ["send", "Legacy Chat", "hello"])
        for args in commands:
            with self.subTest(args=args):
                done = subprocess.run([sys.executable, str(sessions), *args], capture_output=True, text=True,
                                      env=self.env(MULTIPROMPT_TAB="live-legacy"), timeout=10)
                self.assertEqual(done.returncode, 2, done.stderr)
                self.assertEqual(done.stdout, "")
                self.assertIn("mp-send", done.stderr)
                self.assertIn("update", done.stderr)
                self.assertNotIn("Traceback", done.stderr)
        self.assertEqual(self.events("zsb"), [])
        self.assertEqual(self.events("host"), [])

    def test_SOFT_3055_start_creates_once_and_is_idempotent(self):
        first = self.parsed(self.run_sessions("start", "--name", "Daily chat"))
        again = self.parsed(self.run_sessions("start", "--name", "daily chat"))
        self.assertEqual(first["sid"], again["sid"])
        self.assertEqual(again["status"], "already")
        configs = list(self.host.glob("*.config.json"))
        self.assertEqual(len(configs), 1)
        hosts = self.events("host")
        enables = [call for call in hosts if call[:2] == ["enable", "claude"]]
        self.assertGreaterEqual(len(enables), 1)
        self.assertGreaterEqual(len([call for call in hosts if call[:2] == ["start", "claude"]]), 1)
        opened = [call for call in self.events("zsb") if call[0] == "session-open"]
        self.assertEqual(len(opened), 1)

    def test_SOFT_3055_restart_reuses_sid_for_a_stopped_chat(self):
        started = self.parsed(self.run_sessions("start", "--name", "Ops"))
        closed = self.parsed(self.run_sessions("close", "Ops"))
        self.assertTrue(closed["ok"])
        restarted = self.parsed(self.run_sessions("restart", "Ops"))
        self.assertEqual(restarted["sid"], started["sid"])
        self.assertEqual(restarted["status"], "restarted")
        self.assertIn(["start", "claude", started["sid"]], self.events("host"))

    def test_SOFT_3055_close_refuses_a_busy_chat(self):
        started = self.parsed(self.run_sessions("start", "--name", "Busy"))
        key = hashlib.sha256(("claude:" + started["sid"]).encode()).hexdigest()[:32]
        config = json.loads((self.host / (key + ".config.json")).read_text(encoding="utf-8"))
        config["enabled"] = True
        (self.host / (key + ".config.json")).write_text(json.dumps(config), encoding="utf-8")
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(sid=started["sid"], provider="claude",
                                                                       pid=os.getpid(), inflight=dict(id="x"))), encoding="utf-8")
        refused = self.run_sessions("close", "Busy")
        self.assertEqual(refused.returncode, 2)
        self.assertIn("busy", refused.stderr)

    def test_SOFT_3055_unknown_name_reports_clearly(self):
        missing = self.run_sessions("restart", "No such chat")
        self.assertEqual(missing.returncode, 2)
        self.assertIn("no chat named", missing.stderr)

    def test_SOFT_3055_list_workspace_mine_filters_to_caller_workspace(self):
        caller = self.parsed(self.run_sessions("start", "--name", "Caller", "--workspace", "Home"))
        self.parsed(self.run_sessions("start", "--name", "Peer", "--workspace", "Home"))
        self.parsed(self.run_sessions("start", "--name", "Other", "--workspace", "Away"))
        listed = self.parsed(self.run_sessions("list", "--workspace", "mine", "--json",
                                               MULTIPROMPT_TAB=caller["tmux"]))
        names = {row.get("name") for row in listed}
        self.assertEqual(names, {"Caller", "Peer"})
        for row in listed:
            self.assertEqual(row.get("workspace"), "Home")

    def test_SOFT_3055_send_by_name_targets_the_named_chat(self):
        peer = self.parsed(self.run_sessions("start", "--name", "Peer", "--workspace", "Home"))
        self.mark_running(peer)
        done = self.run_sessions("send", "Peer", "hello there", MULTIPROMPT_READER_SOURCE=str(READER))
        self.assertIn(done.returncode, (0, 3), done.stderr)
        sent = json.loads(done.stdout)
        self.assertEqual(sent["sid"], peer["sid"])
        self.assertRegex(sent.get("id") or "", r"\Amp-[0-9a-f]{32}\Z")

    def test_SOFT_3055_send_workspace_mine_skips_the_caller(self):
        caller = self.parsed(self.run_sessions("start", "--name", "Caller", "--workspace", "Home"))
        peer = self.parsed(self.run_sessions("start", "--name", "Peer", "--workspace", "Home"))
        self.mark_running(caller)
        self.mark_running(peer)
        done = self.run_sessions("send", "--workspace", "mine", "team note", MULTIPROMPT_TAB=caller["tmux"],
                                 MULTIPROMPT_READER_SOURCE=str(READER))
        self.assertIn(done.returncode, (0, 3), done.stderr)
        payload = json.loads(done.stdout)
        self.assertIsInstance(payload, list)
        self.assertEqual(len(payload), 1)
        self.assertEqual(payload[0]["sid"], peer["sid"])
        self.assertNotEqual(payload[0]["sid"], caller["sid"])

    def test_SOFT_3055_send_unknown_name_errors_clearly(self):
        missing = self.run_sessions("send", "No such chat", "hello")
        self.assertEqual(missing.returncode, 2)
        self.assertIn("no chat named", missing.stderr)

    def test_MUBO_294_send_without_a_host_slot_still_reaches_the_chat(self):
        peer = self.parsed(self.run_sessions("start", "--name", "Peer", "--workspace", "Home"))
        self.mark_running(peer)
        servers = self.servers_file()
        done = self.run_sessions("send", "Peer", "hello there", MULTIPROMPT_HOST=None,
                                 MULTIPROMPT_SERVERS_FILE=str(servers), MULTIPROMPT_READER_SOURCE=str(READER))
        self.assertIn(done.returncode, (0, 3), done.stderr)
        sent = json.loads(done.stdout)
        self.assertEqual(sent["sid"], peer["sid"])
        self.assertRegex(sent.get("id") or "", r"\Amp-[0-9a-f]{32}\Z")

    def test_MUBO_294_start_takes_the_servers_file_slot_for_this_machine(self):
        servers = self.servers_file(slot=0, hostname=socket.gethostname())
        started = self.parsed(self.run_sessions("start", "--name", "Slot chat", MULTIPROMPT_HOST=None,
                                                MULTIPROMPT_SERVERS_FILE=str(servers)))
        self.assertEqual(started["host"], "remote-1")
        key = hashlib.sha256(("claude:" + started["sid"]).encode()).hexdigest()[:32]
        config = json.loads((self.host / (key + ".config.json")).read_text(encoding="utf-8"))
        self.assertEqual(config["spawn_host"], 0)

    def test_MUBO_294_start_falls_back_to_the_callers_recorded_slot(self):
        caller = self.parsed(self.run_sessions("start", "--name", "Caller", "--workspace", "Home"))
        servers = self.servers_file()
        started = self.parsed(self.run_sessions("start", "--name", "Neighbour", MULTIPROMPT_HOST=None,
                                                MULTIPROMPT_SERVERS_FILE=str(servers),
                                                MULTIPROMPT_TAB=caller["tmux"]))
        self.assertEqual(started["host"], "remote-1")

    def test_MUBO_294_start_without_any_slot_names_the_file_and_the_field(self):
        servers = self.servers_file()
        refused = self.run_sessions("start", "--name", "Homeless", MULTIPROMPT_HOST=None,
                                    MULTIPROMPT_SERVERS_FILE=str(servers))
        self.assertEqual(refused.returncode, 2)
        self.assertEqual(refused.stdout, "")
        self.assertIn("multiprompt_slot", refused.stderr)
        self.assertIn(str(servers), refused.stderr)
        self.assertIn("MULTIPROMPT_HOST", refused.stderr)

    def test_MUBO_294_the_env_slot_wins_over_the_servers_file(self):
        servers = self.servers_file(slot=2, hostname=socket.gethostname())
        started = self.parsed(self.run_sessions("start", "--name", "Env chat", MULTIPROMPT_HOST="0",
                                                MULTIPROMPT_SERVERS_FILE=str(servers)))
        self.assertEqual(started["host"], "remote-1")
        refused = self.run_sessions("start", "--name", "Slot two", MULTIPROMPT_HOST=None,
                                    MULTIPROMPT_SERVERS_FILE=str(servers))
        self.assertEqual(refused.returncode, 2)
        self.assertIn("desktop host list is unavailable", refused.stderr)

    def test_MUBO_294_a_machine_named_twice_in_the_servers_file_is_refused(self):
        servers = self.servers_file(slot=0, hostname=socket.gethostname())
        facts = json.loads(servers.read_text(encoding="utf-8"))
        facts["servers"][1]["hostname"] = socket.gethostname()
        servers.write_text(json.dumps(facts), encoding="utf-8")
        refused = self.run_sessions("start", "--name", "Ambiguous", MULTIPROMPT_HOST=None,
                                    MULTIPROMPT_SERVERS_FILE=str(servers))
        self.assertEqual(refused.returncode, 2)
        self.assertIn("more than one server", refused.stderr)

    def test_SOFT_3093_list_json_shows_a_hosted_chat_with_no_terminal(self):
        key = "a" * 32
        self.host.mkdir(parents=True, exist_ok=True)
        (self.host / (key + ".config.json")).write_text(json.dumps(dict(cwd=str(self.work), enabled=True, tmux="live-hosted")))
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(sid="hosted-session", pid=os.getpid(),
                                                                       provider="claude", started=2.0)))
        (self.home / ".local/state/multiprompt/chat-names.json").write_text(
            json.dumps({"live-hosted": dict(name="Hosted Lead", at=1)}))
        tmux = self.bin / "tmux"
        tmux.write_text("#!" + sys.executable + "\nimport sys\nif sys.argv[1:2] == ['list-sessions']:\n"
                        " print('live-other')\nelse:\n sys.exit(1)\n", encoding="utf-8")
        tmux.chmod(0o755)
        rows = self.parsed(self.run_sessions("list", "--json"))
        self.assertEqual([row["tmux"] for row in rows], ["live-hosted"])
        self.assertEqual(rows[0], dict(name="Hosted Lead", provider="claude", sid="hosted-session", tmux="live-hosted",
                                       cwd=str(self.work), state="idle", link="@Hosted Lead{live-hosted}",
                                       workspace=None, group=None, busy=False, running=True, self=False,
                                       in_layout=False, visible=False, hidden_reason="not in layout", waiting=None,
                                       pinned=None, archived=None, user_hidden=None, active_workspace="Home", sidebar_view=None))

    def seed_hosted_fixture(self, entries):
        self.host.mkdir(parents=True, exist_ok=True)
        for tmux, entry in entries.items():
            sid = entry["sid"]
            key = hashlib.sha256(("claude:" + sid).encode()).hexdigest()[:32]
            (self.host / (key + ".config.json")).write_text(json.dumps(dict(
                cwd=str(self.work), enabled=True, provider="claude", sid=sid, tmux=tmux)), encoding="utf-8")
            (self.host / (key + ".state.json")).write_text(json.dumps(dict(
                sid=sid, provider="claude", pid=os.getpid(), tmux=tmux)), encoding="utf-8")

    def message_rows(self):
        store = self.home / ".local/state/multiprompt/shared-messages/store.sqlite3"
        with sqlite3.connect(store) as db:
            return db.execute("SELECT id, provider, sid, text, origin FROM shared_messages ORDER BY position").fetchall()

    def test_MUBO_194_hosted_chat_lists_workspace_mine_from_synced_chat_names_when_zsb_offline(self):
        fixture = json.loads((MUBO_194_FIXTURES / "chat-names.json").read_text(encoding="utf-8"))
        self.seed_hosted_fixture(fixture)
        (self.home / ".local/state/multiprompt/chat-names.json").write_text(
            json.dumps(fixture), encoding="utf-8")
        offline = json.dumps(dict(ok=False, error="bridge_offline"))
        for extra in (dict(MULTIBOT_SESSION="live-1111aaaa"),
                      dict(MULTIBOT_PROVIDER="claude", MULTIBOT_SID="11111111-1111-4111-8111-111111111111")):
            with self.subTest(extra=extra):
                listed = self.parsed(self.run_sessions("list", "--workspace", "mine", "--json",
                                                       MP_SESSIONS_TEST_LIST=offline, **extra))
                self.assertEqual({row["name"] for row in listed}, {"Lead Chat", "Design Peer", "QA Peer"})
                for row in listed:
                    self.assertEqual(row["workspace"], "Studio")
                    self.assertEqual(row["self"], row["tmux"] == "live-1111aaaa")

    def test_MUBO_194_hosted_chat_lists_workspace_mine_from_synced_layout_when_zsb_offline(self):
        fixture = json.loads((MUBO_194_FIXTURES / "chat-names.json").read_text(encoding="utf-8"))
        self.seed_hosted_fixture(fixture)
        layout_dir = self.home / ".local/share/multiprompt"
        layout_dir.mkdir(parents=True, exist_ok=True)
        (layout_dir / "layout.json").write_text(
            (MUBO_194_FIXTURES / "layout.json").read_text(encoding="utf-8"), encoding="utf-8")
        offline = json.dumps(dict(ok=False, error="bridge_offline"))
        listed = self.parsed(self.run_sessions("list", "--workspace", "mine", "--json",
                                               MP_SESSIONS_TEST_LIST=offline,
                                               MULTIBOT_SESSION="live-1111aaaa"))
        self.assertEqual({row["name"] for row in listed}, {"Lead Chat", "Design Peer", "QA Peer"})
        for row in listed:
            self.assertEqual(row["workspace"], "Studio")
            self.assertEqual(row["self"], row["tmux"] == "live-1111aaaa")

    def write_synced_layout(self):
        layout_dir = self.home / ".local/share/multiprompt"
        layout_dir.mkdir(parents=True, exist_ok=True)
        (layout_dir / "layout.json").write_text(
            (MUBO_194_FIXTURES / "layout.json").read_text(encoding="utf-8"), encoding="utf-8")

    def start_configs(self):
        return [json.loads(path.read_text(encoding="utf-8")) for path in sorted(self.host.glob("*.config.json"))]

    def test_MUBO_194_start_without_a_desktop_creates_the_chat_in_a_synced_workspace(self):
        self.write_synced_layout()
        offline = json.dumps(dict(ok=False, error="bridge_offline"))
        first = self.parsed(self.run_sessions("start", "--name", "Late Lead", "--folder", str(self.work),
                                              "--workspace", "Studio", "--provider", "claude",
                                              MP_SESSIONS_TEST_LIST=offline))
        self.assertEqual(first["status"], "started")
        self.assertEqual(first["workspace"], "Studio")
        self.assertFalse(first["visible"])
        self.assertEqual(first["visible_error"], "desktop_offline")
        configs = self.start_configs()
        self.assertEqual(len(configs), 1)
        self.assertEqual((configs[0]["spawn_workspace"], configs[0]["spawn_name"], configs[0]["tmux"]),
                         ("Studio", "late lead", first["tmux"]))
        self.assertNotIn("session-open", [call[0] for call in self.events("zsb")])
        second = self.parsed(self.run_sessions("start", "--name", "Late Lead", "--folder", str(self.work),
                                               "--workspace", "Studio", "--provider", "claude",
                                               MP_SESSIONS_TEST_LIST=offline))
        self.assertEqual(second["status"], "already")
        self.assertEqual((second["tmux"], second["sid"], second["workspace"]),
                         (first["tmux"], first["sid"], "Studio"))
        self.assertEqual(len(self.start_configs()), 1)

    def test_MUBO_194_start_without_a_desktop_refuses_an_unknown_workspace_plainly(self):
        self.write_synced_layout()
        offline = json.dumps(dict(ok=False, error="bridge_offline"))
        failed = self.run_sessions("start", "--name", "Late Lead", "--folder", str(self.work),
                                   "--workspace", "Ghost Room", "--provider", "claude",
                                   MP_SESSIONS_TEST_LIST=offline)
        self.assertEqual(failed.returncode, 2)
        self.assertIn("mp-sessions: no workspace named 'Ghost Room'", failed.stderr)
        self.assertEqual(self.start_configs(), [])

    def serve_hosted_fixture(self, entries):
        self.seed_hosted_fixture(entries)
        sock_temp = tempfile.TemporaryDirectory(prefix="mp-", dir="/tmp")
        self.addCleanup(sock_temp.cleanup)
        sock_root = Path(sock_temp.name) / ("mp-agent-host-" + str(os.getuid()))
        sock_root.mkdir(mode=0o700, parents=True, exist_ok=True)
        sock_root.chmod(0o700)
        delivered = []
        stop = threading.Event()
        servers = []
        threads = []
        for tmux, entry in entries.items():
            sid = entry["sid"]
            key = hashlib.sha256(("claude:" + sid).encode()).hexdigest()[:32]
            (self.host / (key + ".owner.json")).write_text(json.dumps(dict(
                owner="host", pid=os.getpid())), encoding="utf-8")
            sock_path = sock_root / (key + ".sock")
            server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            server.bind(str(sock_path))
            server.listen(8)
            server.settimeout(0.1)
            servers.append((server, sock_path))

            def serve(listener=server, session_tmux=tmux):
                while not stop.is_set():
                    try:
                        conn, _ = listener.accept()
                    except socket.timeout:
                        continue
                    except OSError:
                        break
                    with conn:
                        conn.settimeout(2.0)
                        data = b""
                        while b"\n" not in data and len(data) <= 65536:
                            chunk = conn.recv(65536)
                            if not chunk:
                                break
                            data += chunk
                        if not data.strip():
                            continue
                        req = json.loads(data.split(b"\n", 1)[0].decode("utf-8"))
                        if req.get("op") == "ping":
                            reply = dict(status="ok", pid=os.getpid())
                        elif req.get("op") == "deliver":
                            delivered.append((session_tmux, req.get("id"), req.get("text")))
                            reply = dict(status="sent")
                        else:
                            reply = dict(status="ok")
                        conn.sendall((json.dumps(reply, separators=(",", ":")) + "\n").encode("utf-8"))

            worker = threading.Thread(target=serve, daemon=True)
            worker.start()
            threads.append(worker)

        def close_servers():
            stop.set()
            for server, sock_path in servers:
                try:
                    server.close()
                except OSError:
                    pass
                try:
                    sock_path.unlink()
                except OSError:
                    pass
            for worker in threads:
                worker.join(timeout=2.0)

        self.addCleanup(close_servers)
        return sock_temp.name, delivered

    def test_MUBO_194_send_workspace_mine_messages_peers_by_name_and_repeat_is_harmless(self):
        fixture = json.loads((MUBO_194_FIXTURES / "chat-names.json").read_text(encoding="utf-8"))
        tmp_dir, delivered = self.serve_hosted_fixture(fixture)
        (self.home / ".local/state/multiprompt/chat-names.json").write_text(
            json.dumps(fixture), encoding="utf-8")
        offline = json.dumps(dict(ok=False, error="bridge_offline"))
        extra = dict(MP_SESSIONS_TEST_LIST=offline, MULTIBOT_SESSION="live-1111aaaa",
                     MULTIPROMPT_READER_SOURCE=str(READER), TMPDIR=tmp_dir, TEMP=tmp_dir, TMP=tmp_dir)
        first = self.run_sessions("send", "--workspace", "mine", "sync up at noon", **extra)
        self.assertEqual(first.returncode, 0, first.stderr)
        first_payload = json.loads(first.stdout)
        self.assertEqual({row["name"] for row in first_payload}, {"Design Peer", "QA Peer"})
        self.assertEqual({row["sid"] for row in first_payload},
                         {"22222222-2222-4222-8222-222222222222", "33333333-3333-4333-8333-333333333333"})
        self.assertEqual({row["state"] for row in first_payload}, {"sent"})
        rows_after_first = self.message_rows()
        self.assertEqual(len(rows_after_first), 2)
        self.assertEqual(len(delivered), 2)
        for row in rows_after_first:
            self.assertEqual(row[3], "From Lead Chat: sync up at noon")
            self.assertEqual(row[4], "agent")
        second = self.run_sessions("send", "--workspace", "mine", "sync up at noon", **extra)
        self.assertEqual(second.returncode, 0, second.stderr)
        second_payload = json.loads(second.stdout)
        self.assertEqual({row["id"] for row in second_payload}, {row["id"] for row in first_payload})
        self.assertEqual(len(self.message_rows()), 2)
        self.assertEqual(len(delivered), 2)
        direct_first = self.run_sessions("send", "Design Peer", "direct ping", **extra)
        self.assertEqual(direct_first.returncode, 0, direct_first.stderr)
        direct_second = self.run_sessions("send", "Design Peer", "direct ping", **extra)
        self.assertEqual(direct_second.returncode, 0, direct_second.stderr)
        self.assertEqual(json.loads(direct_first.stdout)["id"], json.loads(direct_second.stdout)["id"])
        self.assertEqual(len(self.message_rows()), 3)
        self.assertEqual(len(delivered), 3)

    def test_MUBO_194_chat_names_publish_persists_workspace_and_group(self):
        script = (
            "import importlib.util,json,sys;"
            "spec=importlib.util.spec_from_file_location('r',sys.argv[1]);"
            "m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);"
            "print(json.dumps(m.chat_names_publish(["
            "{'tmux':'live-1111aaaa','name':'Lead Chat','sid':'11111111-1111-4111-8111-111111111111','workspace':'Studio','group':'Core'},"
            "{'tmux':'live-3333cccc','name':'QA Peer','sid':'33333333-3333-4333-8333-333333333333','workspace':'Studio','group':''}"
            "])))"
        )
        done = subprocess.run([sys.executable, "-c", script, str(READER)],
                              capture_output=True, text=True, env=self.env(), timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(json.loads(done.stdout), dict(status="ok", count=2))
        stored = json.loads((self.home / ".local/state/multiprompt/chat-names.json").read_text(encoding="utf-8"))
        self.assertEqual(stored["live-1111aaaa"]["workspace"], "Studio")
        self.assertEqual(stored["live-1111aaaa"]["group"], "Core")
        self.assertEqual(stored["live-3333cccc"]["workspace"], "Studio")
        self.assertNotIn("group", stored["live-3333cccc"])


if __name__ == "__main__":
    unittest.main()