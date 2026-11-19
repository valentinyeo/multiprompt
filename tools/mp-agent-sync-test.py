import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SYNC = ROOT / "src" / "mp_agent_sync.py"
READER = ROOT / "src" / "chat_history_reader.py"
AGENT = "11111111-1111-4111-8111-111111111111"
OTHER = "aaaaaaaa-1111-2222-3333-444444444444"


class AgentSyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.state = self.home / ".local/state/multiprompt"
        self.state.mkdir(parents=True)
        self.bin = Path(self.temp.name) / "bin"
        self.bin.mkdir()
        self.log = Path(self.temp.name) / "hypertask.log"
        fake = self.bin / "hypertask"
        fake.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "open(os.environ['SYNC_LOG'], 'a', encoding='utf-8').write(json.dumps(sys.argv[1:]) + '\\n')\n"
            "if 'list' in sys.argv:\n"
            "    agents = json.loads(os.environ.get('SYNC_AGENTS', '[]'))\n"
            "    print(json.dumps({'success': True, 'agents': agents, 'total': len(agents), 'nextCursor': None}))\n"
            "raise SystemExit(0)\n"
        )
        fake.chmod(0o755)
        self.names = self.state / "chat-names.json"

    def env(self, agents):
        base = dict(os.environ, HOME=str(self.home), PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""), SYNC_LOG=str(self.log), SYNC_AGENTS=json.dumps(agents))
        return base

    def write_names(self, records):
        self.names.write_text(json.dumps(records), encoding="utf-8")

    def calls(self):
        if not self.log.is_file():
            return []
        return [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines() if line]

    def run_sync(self, *args, agents=None):
        return subprocess.run([sys.executable, str(SYNC), *args], capture_output=True, text=True, env=self.env(agents or []), timeout=30)

    def publish(self, entries):
        script = (
            "import importlib.util, json, sys\n"
            "spec = importlib.util.spec_from_file_location('reader', sys.argv[1])\n"
            "module = importlib.util.module_from_spec(spec)\n"
            "spec.loader.exec_module(module)\n"
            "print(json.dumps(module.chat_names_publish(json.loads(sys.argv[2]))))\n"
        )
        done = subprocess.run([sys.executable, "-c", script, str(READER), json.dumps(entries)], capture_output=True, text=True, env=self.env([]), timeout=30)
        self.assertEqual(done.returncode, 0, done.stderr)
        return json.loads(self.names.read_text(encoding="utf-8"))

    def assert_linked(self, stored, tmux, agent):
        entry = stored.get(tmux) if isinstance(stored.get(tmux), dict) else {}
        self.assertEqual(entry.get("agent"), agent)

    def test_rename_uses_the_stored_id_and_the_exact_chat_name(self):
        self.write_names({
            "live-beta": {"name": "New Name", "at": 1, "sid": None, "agent": AGENT},
            "@agents": {"live-beta": AGENT},
            "live-gamma": {"name": "Still Alone", "at": 1, "sid": None},
        })
        stored = self.publish([
            {"tmux": "live-beta", "name": "New Name", "sid": None},
            {"tmux": "live-gamma", "name": "Still Alone", "sid": None},
        ])
        self.assert_linked(stored, "live-beta", AGENT)
        done = self.run_sync(agents=[{"id": AGENT, "display_name": "Old Name"}])
        self.assertEqual(done.returncode, 0, done.stderr)
        renames = [call for call in self.calls() if "rename" in call]
        self.assertEqual(renames, [["agents", "rename", "--id", AGENT, "--name", "New Name"]])
        self.assertIn("rename\tNew Name\n", done.stdout)
        self.assertIn("unlinked\tStill Alone\n", done.stdout)
        again = self.run_sync(agents=[{"id": AGENT, "display_name": "New Name"}])
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual([call for call in self.calls() if "rename" in call], renames)
        self.assertNotIn("rename\t", again.stdout)

    def test_a_shared_agent_id_is_refused_and_renames_nothing(self):
        self.write_names({
            "live-beta": {"name": "New Name", "at": 1, "sid": None},
            "live-gamma": {"name": "Other Chat", "at": 1, "sid": None},
            "live-delta": {"name": "Honest Chat", "at": 1, "sid": None, "agent": OTHER},
            "@agents": {"live-beta": AGENT, "live-gamma": AGENT, "live-delta": OTHER},
        })
        stored = self.publish([
            {"tmux": "live-beta", "name": "New Name", "sid": None},
            {"tmux": "live-gamma", "name": "Other Chat", "sid": None},
            {"tmux": "live-delta", "name": "Honest Chat", "sid": None},
        ])
        self.assert_linked(stored, "live-beta", AGENT)
        self.assert_linked(stored, "live-gamma", AGENT)
        done = self.run_sync(agents=[
            {"id": AGENT, "display_name": "Old Name"},
            {"id": OTHER, "display_name": "Stale Honest"},
        ])
        self.assertEqual(done.returncode, 1, done.stderr)
        self.assertFalse(any("rename" in call for call in self.calls()))
        self.assertIn("clash\tNew Name\tOther Chat\n", done.stdout)

    def test_republish_keeps_the_stored_agent_id(self):
        self.write_names({
            "live-beta": {"name": "Old Name", "at": 1, "sid": None, "agent": AGENT},
            "@agents": {"live-beta": AGENT},
        })
        script = (
            "import importlib.util, json, sys\n"
            "spec = importlib.util.spec_from_file_location('reader', sys.argv[1])\n"
            "module = importlib.util.module_from_spec(spec)\n"
            "spec.loader.exec_module(module)\n"
            "print(json.dumps(module.chat_names_publish([{'tmux': 'live-beta', 'name': 'New Name', 'sid': None}])))\n"
        )
        done = subprocess.run([sys.executable, "-c", script, str(READER)], capture_output=True, text=True, env=self.env([]), timeout=30)
        self.assertEqual(done.returncode, 0, done.stderr)
        stored = json.loads(self.names.read_text(encoding="utf-8"))
        self.assertEqual(stored["live-beta"]["name"], "New Name")
        self.assert_linked(stored, "live-beta", AGENT)
        self.assertEqual(stored["@agents"]["live-beta"], AGENT)


if __name__ == "__main__":
    unittest.main()
