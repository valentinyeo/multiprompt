import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MP_SHELL = ROOT / "tools" / "mp-shell"

LISTING = dict(ok=True, hosts=["remote-1"], workspaces=[
    dict(id=0, name="Home", active=True, groups=[], tabs=[dict(id=40, title="Other", host="remote-1", tmux="live-other")]),
    dict(id=1, name="Research", active=False, groups=[dict(id=7, name="Ops", tabs=[dict(id=41, title="Lead", host="remote-1", tmux="live-parent")])], tabs=[]),
])

FAKE_ZSB = r'''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["MP_SHELL_TEST_LOG"], "a", encoding="utf-8") as stream:
    stream.write(json.dumps(["zsb", sys.argv[1:]]) + "\n")
if sys.argv[1] == "workspace-list":
    print(json.dumps(json.loads(os.environ.get("MP_SHELL_TEST_LIST", "{}"))))
elif sys.argv[1] == "shell-open" and os.environ.get("MP_SHELL_TEST_OFFLINE"):
    print(json.dumps(dict(ok=False, error="tunnel_down", message="down")))
elif sys.argv[1] == "shell-open":
    print(json.dumps(dict(ok=True, created=True, tab=52, state="connecting")))
else:
    print(json.dumps(dict(ok=True)))
'''


class MpShellTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.home = base / "home"
        self.bin = base / "bin"
        self.home.mkdir(parents=True)
        self.bin.mkdir(parents=True)
        self.log = base / "log.jsonl"
        zsb = self.bin / "zsb"
        zsb.write_text(FAKE_ZSB.replace("/usr/bin/env python3", sys.executable), encoding="utf-8")
        zsb.chmod(0o755)

    def env(self, **extra):
        base = dict(os.environ, HOME=str(self.home), MP_SHELL_TEST_LOG=str(self.log),
                    MP_SHELL_TEST_LIST=json.dumps(LISTING), MULTIPROMPT_TAB="live-parent",
                    PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""))
        for name in ("MULTIPROMPT_RUNTIME_DIR", "TMUX_PANE"):
            base.pop(name, None)
        base.update(extra)
        return {key: value for key, value in base.items() if value is not None}

    def run_shell(self, *args, **extra):
        return subprocess.run([sys.executable, str(MP_SHELL), *args], capture_output=True, text=True, env=self.env(**extra), timeout=60)

    def test_open_from_a_chat_sends_shell_open_with_attach(self):
        done = self.run_shell("open", "--attach", "projects-2", "--name", "Projects shell")
        self.assertEqual(done.returncode, 0, done.stderr)
        payload = json.loads(done.stdout)
        self.assertTrue(payload["ok"])
        zsb_calls = [json.loads(line)[1] for line in self.log.read_text(encoding="utf-8").splitlines() if line]
        opened = next(call for call in zsb_calls if call and call[0] == "shell-open")
        self.assertEqual(opened[opened.index("--attach") + 1], "projects-2")
        self.assertIn("--after-tab", opened)
        self.assertIn("--run", opened)
        self.assertIn("tmux attach", opened[opened.index("--run") + 1])

    def test_offline_desktop_exits_with_a_plain_reason(self):
        done = self.run_shell("open", MP_SHELL_TEST_OFFLINE="1")
        self.assertEqual(done.returncode, 4, done.stderr)
        self.assertIn("offline", done.stderr)


if __name__ == "__main__":
    unittest.main()