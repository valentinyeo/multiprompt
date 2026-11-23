import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
MP_SESSIONS = ROOT / "tools" / "mp-sessions"

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
    if state.get("listing"):
        listing = state["listing"]
    elif state.get("tabs"):
        listing["workspaces"][0]["tabs"] = state["tabs"]
    print(json.dumps(listing))
elif sys.argv[1] == "session-open":
    tmux = sys.argv[sys.argv.index("--tmux") + 1]
    title = sys.argv[sys.argv.index("--name") + 1]
    host = sys.argv[sys.argv.index("--host") + 1]
    tab_id = 55
    if "--workspace" in sys.argv:
        workspace = sys.argv[sys.argv.index("--workspace") + 1]
        if workspace == "Home" and not state.get("listing"):
            state.setdefault("tabs", [])
            state["tabs"].append(dict(id=tab_id, title=title, host=host, tmux=tmux))
            Path(state_file).write_text(json.dumps(state), encoding="utf-8")
            print(json.dumps(dict(ok=True, created=True, tab=tab_id)))
            raise SystemExit(0)
        listing = state.get("listing")
        if listing is None:
            listing = json.loads(os.environ.get("MP_SESSIONS_TEST_LIST", "{}"))
        tab_id = state.get("next_tab", 60)
        state["next_tab"] = tab_id + 1
        entry = dict(id=tab_id, title=title, host=host, tmux=tmux)
        placed = False
        for ws in listing.get("workspaces") or []:
            if ws.get("name") != workspace:
                continue
            if "--after-tab" in sys.argv:
                after = int(sys.argv[sys.argv.index("--after-tab") + 1])
                for group in ws.get("groups") or []:
                    gtabs = group.get("tabs") or []
                    if any(tab.get("id") == after for tab in gtabs):
                        index = next(i + 1 for i, tab in enumerate(gtabs) if tab.get("id") == after)
                        group.setdefault("tabs", []).insert(index, entry)
                        placed = True
                        break
                if not placed:
                    utabs = ws.setdefault("tabs", [])
                    index = next((i + 1 for i, tab in enumerate(utabs) if tab.get("id") == after), len(utabs))
                    utabs.insert(index, entry)
                    placed = True
            elif "--group" in sys.argv:
                group_name = sys.argv[sys.argv.index("--group") + 1]
                for group in ws.get("groups") or []:
                    if group.get("name") == group_name:
                        group.setdefault("tabs", []).append(entry)
                        placed = True
                        break
            if not placed:
                ws.setdefault("tabs", []).append(entry)
            break
        state["listing"] = listing
    else:
        state.setdefault("tabs", [])
        state["tabs"].append(dict(id=tab_id, title=title, host=host, tmux=tmux))
    Path(os.environ["MP_SESSIONS_TEST_STATE_FILE"]).write_text(json.dumps(state), encoding="utf-8")
    print(json.dumps(dict(ok=True, created=True, tab=tab_id)))
elif sys.argv[1] == "session-rename":
    tab_id = int(sys.argv[sys.argv.index("--tab") + 1])
    for tab in state.get("tabs", []):
        if tab["id"] == tab_id:
            tab["title"] = sys.argv[sys.argv.index("--name") + 1]
    Path(state_file).write_text(json.dumps(state), encoding="utf-8")
    print(json.dumps(dict(ok=True)))
elif sys.argv[1] == "session-close":
    tab_id = int(sys.argv[sys.argv.index("--tab") + 1])
    listing = state.get("listing")
    if listing is None:
        listing = json.loads(os.environ.get("MP_SESSIONS_TEST_LIST", "{}"))
    removed = False
    for ws in listing.get("workspaces") or []:
        before = len(ws.get("tabs") or [])
        ws["tabs"] = [tab for tab in (ws.get("tabs") or []) if tab.get("id") != tab_id]
        removed = removed or len(ws["tabs"]) != before
        for group in ws.get("groups") or []:
            before = len(group.get("tabs") or [])
            group["tabs"] = [tab for tab in (group.get("tabs") or []) if tab.get("id") != tab_id]
            removed = removed or len(group["tabs"]) != before
    state["listing"] = listing
    state["tabs"] = [tab for tab in state.get("tabs", []) if tab.get("id") != tab_id]
    Path(state_file).write_text(json.dumps(state), encoding="utf-8")
    print(json.dumps(dict(ok=True, closed=removed, tab=tab_id)))
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
        for name in ("MULTIPROMPT_RUNTIME_DIR", "TMUX_PANE", "MULTIPROMPT_TAB", "MULTIBOT_PROVIDER", "MULTIBOT_SID"):
            base.pop(name, None)
        base.update(extra)
        return {key: value for key, value in base.items() if value is not None}

    def run_sessions(self, *args, **extra):
        return subprocess.run([sys.executable, str(MP_SESSIONS), *args], capture_output=True, text=True,
                              env=self.env(**extra), cwd=str(self.work), timeout=60)

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

    def test_SOFT_2451_whoami_requires_a_live_desktop_name(self):
        self.identity_chat()
        for listing in (dict(ok=False, error="offline"), LISTING):
            with self.subTest(listing=listing):
                self.state_file.write_text("{}", encoding="utf-8")
                done = self.run_sessions("whoami", "--json", MULTIPROMPT_TAB="live-caller",
                                         MP_SESSIONS_TEST_LIST=json.dumps(listing))
                self.assertEqual(done.returncode, 2)
                self.assertEqual(done.stdout, "")

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

    def test_SOFT_3131_close_restart_restores_workspace_group_and_tab_order(self):
        away_listing = json.loads((ROOT / "tools" / "fixtures" / "SOFT-3131" / "away-listing.json").read_text(encoding="utf-8"))
        started = self.parsed(self.run_sessions("start", "--name", "Field chat", "--workspace", "Away", "--group", "Ops",
                                               MP_SESSIONS_TEST_LIST=json.dumps(away_listing)))
        key = hashlib.sha256(("claude:" + started["sid"]).encode()).hexdigest()[:32]
        config = json.loads((self.host / (key + ".config.json")).read_text(encoding="utf-8"))
        self.assertEqual(config.get("spawn_workspace"), "Away")
        self.assertEqual(config.get("spawn_group"), "Ops")
        self.mark_running(started)
        listing_with_chat = json.loads(self.state_file.read_text(encoding="utf-8"))["listing"]
        listing_after = json.dumps(listing_with_chat)
        closed = self.parsed(self.run_sessions("close", "Field chat", MP_SESSIONS_TEST_LIST=listing_after))
        self.assertTrue(closed.get("ok"))
        config = json.loads((self.host / (key + ".config.json")).read_text(encoding="utf-8"))
        self.assertEqual(config.get("spawn_workspace"), "Away")
        self.assertEqual(config.get("spawn_group"), "Ops")
        self.assertEqual(config.get("spawn_after_tab"), 31)
        restarted = self.parsed(self.run_sessions("restart", "Field chat", MP_SESSIONS_TEST_LIST=listing_after))
        self.assertEqual(restarted.get("status"), "restarted")
        reopen = [call for call in self.events("zsb") if call[0] == "session-open"][-1]
        self.assertIn("Away", reopen)
        self.assertIn("--after-tab", reopen)
        self.assertEqual(reopen[reopen.index("--after-tab") + 1], "31")
        self.assertNotIn("Home", reopen)

    def test_SOFT_3131_restart_uses_the_front_workspace_when_the_saved_one_is_gone(self):
        away_listing = json.loads((ROOT / "tools" / "fixtures" / "SOFT-3131" / "away-listing.json").read_text(encoding="utf-8"))
        started = self.parsed(self.run_sessions("start", "--name", "Gone home", "--workspace", "Away",
                                               MP_SESSIONS_TEST_LIST=json.dumps(away_listing)))
        self.mark_running(started)
        self.parsed(self.run_sessions("close", "Gone home",
                                      MP_SESSIONS_TEST_LIST=json.dumps(json.loads(self.state_file.read_text())["listing"])))
        only_home = dict(ok=True, hosts=["remote-1"], workspaces=[away_listing["workspaces"][0]])
        state = json.loads(self.state_file.read_text(encoding="utf-8"))
        state["listing"] = only_home
        self.state_file.write_text(json.dumps(state), encoding="utf-8")
        restarted = self.parsed(self.run_sessions("restart", "Gone home", MP_SESSIONS_TEST_LIST=json.dumps(only_home)))
        self.assertIn("placement_note", restarted)
        reopen = [call for call in self.events("zsb") if call[0] == "session-open"][-1]
        self.assertIn("Home", reopen)

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
                                       cwd=str(self.work), state="idle", link="@Hosted Lead{live-hosted}"))


if __name__ == "__main__":
    unittest.main()