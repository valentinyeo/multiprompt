import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools" / "fixtures" / "SOFT-3134"
MP_SESSIONS = ROOT / "tools" / "mp-sessions"

READER_STUB = r'''
import json, os
from pathlib import Path

HOME = Path.home()
HOST = HOME / ".local/state/multiprompt/agent-host"

def host_config_key(provider, sid):
    import hashlib
    return hashlib.sha256((provider + ":" + sid).encode()).hexdigest()[:32]

def host_root():
    return HOST

def host_cwd(provider, sid):
    path = HOST / (host_config_key(provider, sid) + ".config.json")
    if path.is_file():
        return json.loads(path.read_text()).get("cwd") or str(HOME)
    return str(HOME)

def host_session_state(provider, sid):
    key = host_config_key(provider, sid)
    state = HOST / (key + ".state.json")
    return json.loads(state.read_text()) if state.is_file() else {}

def host_dispatch_switch(provider, sid):
    return True

def pin_hosted_claude(q, agent, as_owner=False):
    return q

def empty_history_response(q, sid, tmux, agent="claude"):
    return "@empty"

def conversation_path(provider, sid, cwd, home=None):
    path = Path(cwd) / "transcripts" / (sid + ".jsonl")
    return path if path.is_file() else None

def conversation_event(event, agent):
    if event.get("type") == "assistant":
        msg = event.get("message") or {}
        parts = msg.get("content") if isinstance(msg.get("content"), list) else []
        text = next((p.get("text") for p in parts if isinstance(p, dict) and p.get("type") == "text"), "")
        return {"role": "assistant", "text": text or ""}
    return None

def resolve_tmux_agent(agent, name, pid=None, require_bound=False):
    key = host_config_key(agent, os.environ.get("STUB_SID", ""))
    config = HOST / (key + ".config.json")
    if not config.is_file():
        return None
    data = json.loads(config.read_text())
    sid = data.get("sid")
    path = conversation_path(agent, sid, data.get("cwd") or str(HOME))
    return (sid, path) if path else None

def resolve_response_path(q, source=None, as_owner=False):
    sid = q["sid"]
    path = conversation_path(q.get("provider") or "claude", sid, q.get("cwd") or str(HOME))
    return q.get("provider") or "claude", sid, path, None if path else empty_history_response(q, sid, q["tmux"])
'''


class MpSessionsHealthTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.home = base / "home"
        self.work = base / "work"
        self.bin = base / "bin"
        (self.home / "transcripts").mkdir(parents=True)
        self.work.mkdir(parents=True)
        self.bin.mkdir(parents=True)
        self.host = self.home / ".local/state/multiprompt/agent-host"
        self.host.mkdir(parents=True)
        self.reader = base / "reader.py"
        self.reader.write_text(READER_STUB, encoding="utf-8")

    def env(self, listing_path, **extra):
        listing = json.loads((FIXTURE / listing_path).read_text(encoding="utf-8"))
        zsb = self.bin / "zsb"
        zsb.write_text("#!" + sys.executable + "\nprint(" + repr(json.dumps(listing)) + ")\n", encoding="utf-8")
        zsb.chmod(0o755)
        base = dict(os.environ, HOME=str(self.home), MULTIPROMPT_READER_SOURCE=str(self.reader),
                    PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""), STUB_SID="",
                    MULTIPROMPT_HOST="0")
        base.update(extra)
        return base

    def seed_chat(self, tmux, sid, listing_name, cv_ok=True, tab_open=True):
        key = hashlib.sha256(("claude:" + sid).encode()).hexdigest()[:32]
        transcript = self.home / "transcripts" / (sid + ".jsonl")
        transcript.write_text(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "hello"}]}}) + "\n", encoding="utf-8")
        (self.host / (key + ".config.json")).write_text(json.dumps(dict(
            enabled=True, cwd=str(self.home), tmux=tmux, sid=sid, provider="claude", spawn_workspace="Home")), encoding="utf-8")
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(
            sid=sid, provider="claude", pid=os.getpid(), native_session=sid)), encoding="utf-8")
        listing = json.loads((FIXTURE / listing_name).read_text(encoding="utf-8"))
        if not tab_open:
            listing["workspaces"][0]["tabs"] = []
        elif listing["workspaces"][0]["tabs"]:
            listing["workspaces"][0]["tabs"][0]["tmux"] = tmux
            listing["workspaces"][0]["tabs"][0]["cv"] = cv_ok
        zsb = self.bin / "zsb"
        zsb.write_text("#!" + sys.executable + "\nprint(" + repr(json.dumps(listing)) + ")\n", encoding="utf-8")
        zsb.chmod(0o755)
        return dict(STUB_SID=sid)

    def run_health(self, listing_name="listing-healthy.json", **extra):
        return subprocess.run([sys.executable, str(MP_SESSIONS), "health", "--json"],
                              capture_output=True, text=True, env=self.env(listing_name, **extra),
                              cwd=str(self.work), timeout=60)

    def test_SOFT_3134_healthy_chat_reports_ok(self):
        extra = self.seed_chat("live-healthy", "healthy-sid", "listing-healthy.json")
        done = self.run_health(**extra)
        self.assertEqual(done.returncode, 0, done.stderr + done.stdout)
        rows = json.loads(done.stdout)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["status"], "OK")
        self.assertEqual(rows[0]["tab"], "ok")
        self.assertEqual(rows[0]["view"], "ok")

    def test_SOFT_3134_shell_tab_reports_broken(self):
        extra = self.seed_chat("live-broken", "broken-sid", "listing-shell-tab.json", cv_ok=False)
        done = self.run_health("listing-shell-tab.json", **extra)
        self.assertEqual(done.returncode, 1, done.stderr + done.stdout)
        rows = json.loads(done.stdout)
        self.assertEqual(rows[0]["status"], "BROKEN shell tab")

    def test_SOFT_3134_desktop_offline_marks_unknown_not_ok(self):
        extra = self.seed_chat("live-healthy", "healthy-sid", "listing-healthy.json")
        done = self.run_health("listing-offline.json", **extra)
        self.assertEqual(done.returncode, 1, done.stderr + done.stdout)
        rows = json.loads(done.stdout)
        self.assertEqual(rows[0]["status"], "BROKEN UNKNOWN desktop offline")
        self.assertEqual(rows[0]["tab"], "UNKNOWN desktop offline")

    def test_SOFT_3134_text_output_one_line_per_chat(self):
        extra = self.seed_chat("live-healthy", "healthy-sid", "listing-healthy.json")
        done = subprocess.run([sys.executable, str(MP_SESSIONS), "health"], capture_output=True, text=True,
                              env=self.env("listing-healthy.json", **extra), cwd=str(self.work), timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("OK", done.stdout)
        self.assertNotIn("BROKEN", done.stdout)

    def visibility_env(self, report=None):
        self.seed_chat("live-healthy", "healthy-sid", "listing-healthy.json")
        fixture = ROOT / "tools/fixtures/SOFT-3140/yeo-ux-missing.json"
        env = self.env(str(fixture), STUB_SID="healthy-sid")
        if report is not None:
            zsb = self.bin / "zsb"
            zsb.write_text("#!" + sys.executable + "\nprint(" + repr(json.dumps(report)) + ")\n", encoding="utf-8")
        return env

    def run_visibility(self, command, env, *flags):
        return subprocess.run([sys.executable, str(MP_SESSIONS), command, *flags],
                              capture_output=True, text=True, env=env, cwd=str(self.work), timeout=30)

    def test_SOFT_3140_yeo_ux_chat_in_layout_but_missing_from_sidebar_is_broken(self):
        env = self.visibility_env()
        for flags in (("--json",), ()):
            done = self.run_visibility("health", env, *flags)
            self.assertEqual(done.returncode, 1, done.stderr + done.stdout)
            if flags:
                row = json.loads(done.stdout)[0]
                self.assertEqual(row["status"], "BROKEN hidden: not in sidebar layout")
                self.assertEqual(row["workspace"], "Yeo UX")
                self.assertEqual(row["active_workspace"], "Yeo UX")
                self.assertTrue(row["in_layout"])
                self.assertFalse(row["visible"])
                self.assertFalse(row["waiting"])
            else:
                self.assertIn("BROKEN hidden: not in sidebar layout", done.stdout)

    def test_SOFT_3140_list_and_health_report_the_same_desktop_state(self):
        fixture = ROOT / "tools/fixtures/SOFT-3140"
        report = json.loads((fixture / "yeo-ux-missing.json").read_text())
        for state in json.loads((fixture / "states.json").read_text()):
            with self.subTest(state=state):
                tab = report["workspaces"][0]["tabs"][0]
                tab.update({key: value for key, value in state.items() if key != "broken"})
                env = self.visibility_env(report)
                listed = self.run_visibility("list", env, "--json")
                self.assertEqual(listed.returncode, 0, listed.stderr)
                healthy = self.run_visibility("health", env, "--json")
                self.assertEqual(healthy.returncode, int(state["broken"]), healthy.stderr + healthy.stdout)
                for row in (json.loads(listed.stdout)[0], json.loads(healthy.stdout)[0]):
                    for field in ("visible", "hidden_reason", "waiting", "pinned", "archived", "user_hidden"):
                        self.assertEqual(row[field], state[field], field)
                    self.assertEqual(row["active_workspace"], "Yeo UX")
                    self.assertEqual(row["sidebar_view"], "Yeo UX")
                    self.assertTrue(row["in_layout"])
                table = self.run_visibility("list", env)
                self.assertEqual(table.returncode, 0, table.stderr)
                self.assertIn("VISIBILITY", table.stdout)
                self.assertIn("WAITING", table.stdout)
                self.assertIn("PINNED", table.stdout)
                self.assertIn("ON SCREEN", table.stdout)
                if state["hidden_reason"]:
                    self.assertIn("hidden: " + state["hidden_reason"], table.stdout)
                text = self.run_visibility("health", env)
                self.assertEqual(text.returncode, int(state["broken"]), text.stderr + text.stdout)
                self.assertIn("waiting=" + ("yes" if state["waiting"] else "no"), text.stdout)
                self.assertIn("pinned=" + ("yes" if state["pinned"] else "no"), text.stdout)
                self.assertIn("workspace=Yeo UX", text.stdout)
                self.assertIn("on screen=Yeo UX", text.stdout)

    def test_SOFT_3140_offline_and_older_desktops_do_not_claim_visibility(self):
        report = json.loads((FIXTURE / "listing-healthy.json").read_text())
        for listing, reason, in_layout in ((report, "desktop visibility unavailable", True),
                                          ({"ok": False}, "desktop offline", None)):
            with self.subTest(reason=reason):
                done = self.run_visibility("list", self.visibility_env(listing), "--json")
                self.assertEqual(done.returncode, 0, done.stderr)
                row = json.loads(done.stdout)[0]
                self.assertIsNone(row["visible"])
                self.assertEqual(row["hidden_reason"], reason)
                self.assertEqual(row["in_layout"], in_layout)

    def test_SOFT_3140_visibility_belongs_to_this_server_not_a_namesake(self):
        report = json.loads((ROOT / "tools/fixtures/SOFT-3140/other-host.json").read_text())
        env = self.visibility_env(report)
        for command, status in (("list", 0), ("health", 1)):
            done = self.run_visibility(command, env, "--json")
            self.assertEqual(done.returncode, status, done.stderr + done.stdout)
            rows = json.loads(done.stdout)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["name"], "Design chat")
            self.assertEqual(rows[0]["workspace"], "Yeo UX")
            self.assertFalse(rows[0]["visible"])
            self.assertFalse(rows[0]["pinned"])
        report["workspaces"][1]["tabs"] = []
        done = self.run_visibility("list", self.visibility_env(report), "--json")
        self.assertEqual(done.returncode, 0, done.stderr)
        row = json.loads(done.stdout)[0]
        self.assertEqual(row["hidden_reason"], "not in layout")
        self.assertIsNot(row["archived"], True)

    def test_SOFT_3140_archived_chat_outside_layout_is_reported_as_archived(self):
        report = json.loads((FIXTURE / "listing-healthy.json").read_text())
        report["workspaces"][0]["tabs"] = []
        report["archived_sessions"] = [dict(tmux="live-healthy", host="remote-1", title="Archived chat")]
        env = self.visibility_env(report)
        for command in ("list", "health"):
            done = self.run_visibility(command, env, "--json")
            self.assertEqual(done.returncode, 0, done.stderr + done.stdout)
            row = json.loads(done.stdout)[0]
            self.assertTrue(row["archived"])
            self.assertFalse(row["in_layout"])
            self.assertFalse(row["visible"])
            self.assertEqual(row["hidden_reason"], "archived")

    def test_SOFT_3140_missing_tab_is_not_confused_with_hidden_sidebar_row(self):
        report = json.loads((FIXTURE / "listing-healthy.json").read_text())
        report["workspaces"][0]["tabs"] = []
        env = self.visibility_env(report)
        done = self.run_visibility("list", env, "--json")
        self.assertEqual(done.returncode, 0, done.stderr)
        row = json.loads(done.stdout)[0]
        self.assertFalse(row["in_layout"])
        self.assertFalse(row["visible"])
        self.assertEqual(row["hidden_reason"], "not in layout")
    def run_with_reply(self, reply, command="health", *flags, **extra):
        env = self.env("listing-healthy.json", **extra)
        zsb = self.bin / "zsb"
        zsb.write_text("#!" + sys.executable + "\nprint(" + repr(json.dumps(reply)) + ")\n", encoding="utf-8")
        zsb.chmod(0o755)
        return subprocess.run([sys.executable, str(MP_SESSIONS), command, *flags],
                              capture_output=True, text=True, env=env, cwd=str(self.work), timeout=60)

    def test_MUBO_566_health_names_the_port_holder_instead_of_a_bare_offline(self):
        extra = self.seed_chat("live-healthy", "healthy-sid", "listing-healthy.json")
        conflict = json.loads((ROOT / "tools/fixtures/MUBO-566/port-conflict.json").read_text(encoding="utf-8"))
        done = self.run_with_reply(conflict, "health", "--json", **extra)
        self.assertEqual(done.returncode, 1, done.stderr + done.stdout)
        row = json.loads(done.stdout)[0]
        self.assertEqual(row["status"], "BROKEN UNKNOWN desktop offline")
        self.assertTrue(row["offline_detail"].startswith("port_conflict: "))
        self.assertIn("19548", row["offline_detail"])
        self.assertIn("mp_notify_relay.py", row["offline_detail"])
        text = self.run_with_reply(conflict, "health", **extra)
        self.assertEqual(text.returncode, 1, text.stderr + text.stdout)
        self.assertIn("unreachable: port_conflict", text.stdout)
        self.assertIn("pid 4211", text.stdout)

    def test_MUBO_566_a_reachable_desktop_stays_ok_and_reports_no_offline_detail(self):
        extra = self.seed_chat("live-healthy", "healthy-sid", "listing-healthy.json")
        healthy = json.loads((ROOT / "tools/fixtures/MUBO-566/listing-current-desktop.json").read_text(encoding="utf-8"))
        tab = healthy["workspaces"][0]["groups"][0]["tabs"][0]
        tab["tmux"] = "live-healthy"
        tab["title"] = "Healthy chat"
        tab["host"] = healthy["hosts"][0]
        done = self.run_with_reply(healthy, "health", "--json", **extra)
        self.assertEqual(done.returncode, 0, done.stderr + done.stdout)
        row = json.loads(done.stdout)[0]
        self.assertIsNone(row["offline_detail"])


if __name__ == "__main__":
    unittest.main()
