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
                    PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""), STUB_SID="")
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


if __name__ == "__main__":
    unittest.main()