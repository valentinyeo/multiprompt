import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
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
    if state.get("tabs"):
        listing["workspaces"][0]["tabs"] = state["tabs"]
    print(json.dumps(listing))
elif sys.argv[1] == "session-open":
    tmux = sys.argv[sys.argv.index("--tmux") + 1]
    state.setdefault("tabs", [])
    state["tabs"].append(dict(id=55, title=sys.argv[sys.argv.index("--name") + 1], host="remote-1", tmux=tmux))
    Path(os.environ["MP_SESSIONS_TEST_STATE_FILE"]).write_text(json.dumps(state), encoding="utf-8")
    print(json.dumps(dict(ok=True, created=True, tab=55)))
else:
    print(json.dumps(dict(ok=True)))
'''

LISTING = dict(ok=True, hosts=["remote-1"], workspaces=[
    dict(id=0, name="Home", active=True, groups=[], tabs=[dict(id=40, title="Anchor", host="remote-1", tmux="live-anchor")]),
])


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
        for name in ("MULTIPROMPT_RUNTIME_DIR", "TMUX_PANE", "MULTIPROMPT_TAB"):
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


if __name__ == "__main__":
    unittest.main()