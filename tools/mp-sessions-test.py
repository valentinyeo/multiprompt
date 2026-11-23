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
import json, os, sys, time
from pathlib import Path
LOG = Path(os.environ["MP_SESSIONS_TEST_LOG"])

def note(kind, value):
    with LOG.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps([kind, value]) + "\n")

if __name__ == "__main__" and sys.argv[1:2] == ["host"]:
    note("host", sys.argv[2:])
    command = sys.argv[2]
    if command == "restart":
        key = sys.argv[3:5]
        root = Path(os.environ["HOME"]) / ".local/state/multiprompt/agent-host"
        digest = __import__("hashlib").sha256((key[0] + ":" + key[1]).encode()).hexdigest()[:32]
        marker = root / (digest + ".restart.json")
        if marker.is_file():
            print(json.dumps(dict(status="already", reason="restart_pending")))
        else:
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text(json.dumps(dict(at=time.time())), encoding="utf-8")
            print(json.dumps(dict(status="restarted", sid=key[1])))
    else:
        status = dict(enable="enabled", start="started", stop="stopped").get(command, "error")
        print(json.dumps(dict(status=status, sid=sys.argv[3] if len(sys.argv) > 3 else None)))
'''

FAKE_ZSB = (ROOT / "tools/fixtures/SOFT-3141/sessions-desktop.py").read_text()


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
        opened = [call for call in self.events("zsb") if call[0] == "tab-action"]
        self.assertEqual(len(opened), 1)

    def test_SOFT_3055_restart_reuses_sid_for_a_stopped_chat(self):
        started = self.parsed(self.run_sessions("start", "--name", "Ops"))
        closed = self.parsed(self.run_sessions("close", "Ops", "--json"))
        self.assertTrue(closed["ok"])
        restarted = self.parsed(self.run_sessions("restart", "Ops"))
        self.assertEqual(restarted["sid"], started["sid"])
        self.assertEqual(restarted["status"], "restarted")
        self.assertIn(["start", "claude", started["sid"]], self.events("host"))

    def test_SOFT_3130_restart_running_chat_keeps_sid_and_tab(self):
        fixture = ROOT / "tools" / "fixtures" / "SOFT-3130" / "listing.json"
        listing = json.loads(fixture.read_text(encoding="utf-8"))
        self.identity_chat(name="Pinned chat", tmux="live-caller")
        self.mark_running(dict(sid="caller-session"))
        tabs_before = json.loads(self.state_file.read_text(encoding="utf-8"))["tabs"]
        first = self.parsed(self.run_sessions("restart", "Pinned chat", MP_SESSIONS_TEST_LIST=json.dumps(listing)))
        self.assertEqual(first["sid"], "caller-session")
        self.assertEqual(first["status"], "resumed")
        self.assertEqual([call for call in self.events("host") if call[:2] == ["restart", "claude"]], [["restart", "claude", "caller-session"]])
        opened = [call for call in self.events("zsb") if call and call[0] == "session-open"]
        self.assertEqual(opened, [])
        tabs_after = json.loads(self.state_file.read_text(encoding="utf-8"))["tabs"]
        self.assertEqual(tabs_before, tabs_after)
        second = self.parsed(self.run_sessions("restart", "Pinned chat", MP_SESSIONS_TEST_LIST=json.dumps(listing)))
        self.assertEqual(second["sid"], first["sid"])
        self.assertEqual(second["status"], "already")
        self.assertEqual(len([call for call in self.events("host") if call[:2] == ["restart", "claude"]]), 1)

    def test_SOFT_3141_close_changes_desktop_only_and_preserves_reader_configuration(self):
        started = self.parsed(self.run_sessions("start", "--name", "Busy"))
        self.mark_running(started)
        configs = {path: path.read_text() for path in self.host.glob("*.config.json")}
        closed = self.parsed(self.run_sessions("close", "Busy", "--json"))
        self.assertTrue(closed["state"]["closed"])
        self.assertEqual(configs, {path: path.read_text() for path in self.host.glob("*.config.json")})
        self.assertFalse(any(call[0] == "stop" for call in self.events("host")))

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
        self.assertEqual(names, {"Anchor", "Caller", "Peer"})
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

    def test_SOFT_3131_close_restart_restores_the_one_desktop_record(self):
        listing = json.loads((ROOT / "tools/fixtures/SOFT-3131/away-listing.json").read_text())
        started = self.parsed(self.run_sessions("start", "--name", "Field chat", "--workspace", "Away", "--group", "Ops",
                                               MP_SESSIONS_TEST_LIST=json.dumps(listing)))
        closed = self.parsed(self.run_sessions("close", "Field chat", "--json"))
        self.assertTrue(closed["state"]["closed"])
        restarted = self.parsed(self.run_sessions("restart", "Field chat"))
        self.assertEqual(restarted["sid"], started["sid"])
        for field in ("host", "workspace", "group", "position", "kind", "sid"):
            self.assertEqual(restarted["state"][field], closed["state"][field], field)
        self.assertFalse(restarted["state"]["closed"])
        for config in self.host.glob("*.config.json"):
            self.assertFalse(any(key in json.loads(config.read_text()) for key in ("spawn_workspace", "spawn_group", "spawn_after_tab", "spawn_host_name", "spawn_tab_kind")))

    def test_SOFT_3131_list_shows_workspace_and_filters_case_insensitively(self):
        listing = json.loads((ROOT / "tools/fixtures/SOFT-3131/vstack-listing.json").read_text())
        self.parsed(self.run_sessions("start", "--name", "Field chat", "--workspace", "Vstack", "--group", "Build",
                                      MP_SESSIONS_TEST_LIST=json.dumps(listing)))
        table = self.run_sessions("list")
        self.assertEqual(table.returncode, 0, table.stderr)
        self.assertIn("Vstack", table.stdout)
        self.assertIn("Build", table.stdout)
        filtered = self.parsed(self.run_sessions("list", "--workspace", "vstack", "--json"))
        self.assertIn("Field chat", {row["name"] for row in filtered})
        self.assertTrue(all(row["workspace"] == "Vstack" for row in filtered))

    def test_SOFT_3131_restart_uses_server_placement_without_close(self):
        started = self.parsed(self.run_sessions("start", "--name", "Remote chat", "--workspace", "Away"))
        first = self.parsed(self.run_sessions("restart", "Remote chat"))
        self.assertEqual(first["state"]["workspace"], "Away")
        self.assertEqual(first["state"]["sid"], started["sid"])
        opens = [json.loads(call[1]) for call in self.events("zsb") if call[0] == "tab-action"]
        self.assertEqual(len(opens), 1)

    def test_SOFT_3131_restart_refuses_a_missing_workspace_before_starting_host(self):
        self.parsed(self.run_sessions("start", "--name", "Gone home", "--workspace", "Away"))
        self.parsed(self.run_sessions("close", "Gone home", "--json"))
        state = json.loads(self.state_file.read_text())
        state["listing"]["workspaces"] = [ws for ws in state["listing"]["workspaces"] if ws["name"] == "Home"]
        self.state_file.write_text(json.dumps(state))
        self.log.write_text("")
        restarted = self.run_sessions("restart", "Gone home")
        self.assertEqual(restarted.returncode, 2, restarted.stdout)
        self.assertIn("UnknownWorkspace", restarted.stderr)
        self.assertEqual(self.events("host"), [])

    def test_SOFT_3131_restart_refuses_a_shell_reopen_before_starting_host(self):
        self.parsed(self.run_sessions("start", "--name", "Shell risk"))
        self.parsed(self.run_sessions("close", "Shell risk", "--json"))
        self.log.write_text("")
        restarted = self.run_sessions("restart", "Shell risk", MP_SESSIONS_TEST_SHELL_TAB="1")
        self.assertEqual(restarted.returncode, 2, restarted.stdout)
        self.assertIn("did not confirm", restarted.stderr)
        self.assertEqual(self.events("host"), [])

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
        hosted = next(row for row in rows if row["tmux"] == "live-hosted")
        self.assertEqual(hosted["name"], "Hosted Lead")
        self.assertEqual(hosted["sid"], "hosted-session")
        self.assertTrue(hosted["running"])


if __name__ == "__main__":
    unittest.main()