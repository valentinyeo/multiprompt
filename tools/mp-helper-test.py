import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MP_HELPER = ROOT / "tools" / "mp-helper"

FAKE_READER = r'''
import json, os, sys
from pathlib import Path
LOG = Path(os.environ["MP_HELPER_TEST_LOG"])

def note(kind, value):
    with LOG.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps([kind, value]) + "\n")

def message_store_request(query):
    note("store", query)
    return dict(message=dict(id=query.get("message_id", "mp-x"), state="accepted"))

def message_poll(tmux, provider, sid):
    return None

def conversation_path(provider, sid, cwd):
    path = Path.home() / "transcripts" / (sid + ".jsonl")
    return path if path.is_file() else None

if __name__ == "__main__" and sys.argv[1:2] == ["host"]:
    note("host", sys.argv[2:])
    print(json.dumps(dict(status=dict(enable="enabled", start="started", disable="disabled").get(sys.argv[2], "error"))))
'''

FAKE_ZSB = r'''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["MP_HELPER_TEST_LOG"], "a", encoding="utf-8") as stream:
    stream.write(json.dumps(["zsb", sys.argv[1:]]) + "\n")
if sys.argv[1] == "workspace-list":
    print(os.environ.get("MP_HELPER_TEST_LIST", "{}"))
elif sys.argv[1] == "session-open":
    print(json.dumps(dict(ok=True, created=True, tab=44, state="connecting")))
else:
    print(json.dumps(dict(ok=True)))
'''

LISTING = dict(ok=True, hosts=["remote-1"], workspaces=[
    dict(id=0, name="Home", active=True, groups=[], tabs=[dict(id=40, title="Other", host="remote-1", tmux="live-other")]),
    dict(id=1, name="Research", active=False, groups=[dict(id=7, name="Ops", tabs=[dict(id=41, title="Lead", host="remote-1", tmux="live-parent")])], tabs=[]),
])


class MpHelperTest(unittest.TestCase):
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
        self.reader = base / "reader.py"
        self.reader.write_text(FAKE_READER, encoding="utf-8")
        zsb = self.bin / "zsb"
        zsb.write_text(FAKE_ZSB.replace("/usr/bin/env python3", sys.executable), encoding="utf-8")
        zsb.chmod(0o755)
        self.host = self.home / ".local/state/multiprompt/agent-host"

    def env(self, **extra):
        base = dict(os.environ, HOME=str(self.home), MULTIPROMPT_READER_SOURCE=str(self.reader), MP_HELPER_TEST_LOG=str(self.log),
                    MP_HELPER_TEST_LIST=json.dumps(LISTING), MULTIPROMPT_TAB="live-parent",
                    PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""))
        for name in ("MULTIPROMPT_RUNTIME_DIR", "TMUX_PANE"):
            base.pop(name, None)
        base.update(extra)
        return {key: value for key, value in base.items() if value is not None}

    def run_helper(self, *args, **extra):
        return subprocess.run([sys.executable, str(MP_HELPER), *args], capture_output=True, text=True, env=self.env(**extra), cwd=str(self.work), timeout=60)

    def events(self, kind):
        if not self.log.exists():
            return []
        return [value for name, value in (json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()) if name == kind]

    def configs(self):
        return {path: json.loads(path.read_text(encoding="utf-8")) for path in self.host.glob("*.config.json")}

    def helper(self, name, parent, sid, busy=False, pid=None):
        self.host.mkdir(parents=True, exist_ok=True)
        key = sid.replace("-", "")[:32]
        (self.host / (key + ".config.json")).write_text(json.dumps(dict(enabled=True, cwd=str(self.work), tmux="live-" + key, helper_parent=parent, helper_name=name, sid=sid, model="haiku")))
        (self.host / (key + ".state.json")).write_text(json.dumps(dict(sid=sid, provider="claude", pid=os.getpid() if pid is None else pid, inflight={"id": "x"} if busy else None)))
        return "live-" + key

    def transcript(self, sid, entries):
        folder = self.home / "transcripts"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / (sid + ".jsonl")).write_text("".join(json.dumps(entry) + "\n" for entry in entries), encoding="utf-8")

    def test_SOFT_2013_start_runs_the_chosen_model_under_the_parent_tab_and_sends_the_first_task(self):
        done = self.run_helper("start", "--name", "Research A", "--task", "find the bug", "--model", "sonnet", "--effort", "high")
        self.assertEqual(done.returncode, 0, done.stderr)
        result = json.loads(done.stdout)
        self.assertTrue(result["visible"])
        self.assertEqual(result["tab"], 44)
        self.assertEqual((result["model"], result["effort"], result["parent"]), ("sonnet", "high", "live-parent"))
        self.assertRegex(result["tmux"], r"\Alive-[0-9a-f]{32}\Z")
        configs = list(self.configs().values())
        self.assertEqual(len(configs), 1)
        config = configs[0]
        self.assertEqual((config["model"], config["effort"], config["helper_parent"], config["helper_name"]), ("sonnet", "high", "live-parent", "Research A"))
        self.assertEqual(config["cwd"], os.path.realpath(self.work))
        hosts = self.events("host")
        self.assertEqual([call[0] for call in hosts], ["enable", "start"])
        self.assertEqual(hosts[0][1:], ["claude", result["sid"], "--tmux", result["tmux"], "--cwd", os.path.realpath(self.work), "--permission-mode", "bypassPermissions"])
        opened = [call for call in self.events("zsb") if call[0] == "session-open"]
        self.assertEqual(opened, [["session-open", "--workspace", "Research", "--after-tab", "41", "--host", "remote-1", "--tmux", result["tmux"], "--name", "Research A"]])
        submitted = [query for query in self.events("store") if query["op"] == "message_submit"]
        self.assertEqual(len(submitted), 1)
        self.assertEqual((submitted[0]["text"], submitted[0]["sid"], submitted[0]["tmux"]), ("find the bug", result["sid"], result["tmux"]))
        self.assertEqual(submitted[0]["message_id"], "mp-helper-" + result["tmux"][5:])
        self.assertEqual(result["task"], dict(id=submitted[0]["message_id"], state="accepted"))

    def test_SOFT_2013_two_helpers_get_distinct_chats_and_a_repeat_reuses_one(self):
        first = json.loads(self.run_helper("start", "--name", "A", "--model", "haiku").stdout)
        second = json.loads(self.run_helper("start", "--name", "B", "--model", "opus").stdout)
        again = json.loads(self.run_helper("start", "--name", "a").stdout)
        self.assertNotEqual(first["sid"], second["sid"])
        self.assertEqual(first["sid"], again["sid"])
        self.assertEqual(again["model"], "haiku")
        self.assertEqual(len(self.configs()), 2)

    def test_SOFT_2013_start_needs_a_parent_chat_and_valid_choices(self):
        outside = self.run_helper("start", "--name", "A", MULTIPROMPT_TAB=None)
        self.assertEqual(outside.returncode, 2)
        self.assertIn("inside a chat", outside.stderr)
        wrong = self.run_helper("start", "--name", "A", "--model", "gpt")
        self.assertEqual(wrong.returncode, 2)
        self.assertEqual(self.configs(), {})
        self.assertEqual(self.events("host"), [])

    def test_SOFT_2013_start_reports_a_closed_parent_tab_without_failing_the_helper(self):
        done = self.run_helper("start", "--name", "A", MP_HELPER_TEST_LIST=json.dumps(dict(ok=True, hosts=[], workspaces=[])))
        self.assertEqual(done.returncode, 0, done.stderr)
        result = json.loads(done.stdout)
        self.assertFalse(result["visible"])
        self.assertEqual(result["visible_error"], "parent_tab_not_open")

    def test_SOFT_2013_read_returns_the_latest_reply_after_the_last_prompt(self):
        sid = "aaaaaaaa-1111-8222-8333-444444444444"
        self.helper("Research A", "live-parent", sid)
        self.transcript(sid, [
            dict(type="user", message=dict(role="user", content="first task")),
            dict(type="assistant", message=dict(content=[dict(type="text", text="old answer")])),
            dict(type="user", message=dict(role="user", content="From Lead: second task")),
            dict(type="assistant", message=dict(content=[dict(type="text", text="Looking.")])),
            dict(type="user", message=dict(role="user", content=[dict(type="tool_result", content="x")])),
            dict(type="assistant", message=dict(content=[dict(type="tool_use", name="Bash"), dict(type="text", text="Found it: line 12.")])),
        ])
        done = self.run_helper("read", "research a", "--json")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(json.loads(done.stdout), dict(name="Research A", state="idle", reply="Looking.\n\nFound it: line 12."))

    def test_SOFT_2013_read_wait_times_out_while_the_helper_is_busy(self):
        sid = "bbbbbbbb-1111-8222-8333-444444444444"
        self.helper("Busy", "live-parent", sid, busy=True)
        done = self.run_helper("read", "Busy", "--wait", "--timeout", "0.3")
        self.assertEqual(done.returncode, 4)
        self.assertIn("timed out", done.stderr)

    def test_SOFT_2013_list_send_and_close_touch_only_this_chats_helpers(self):
        mine = "cccccccc-1111-8222-8333-444444444444"
        tmux = self.helper("Mine", "live-parent", mine)
        self.helper("Theirs", "live-other", "dddddddd-1111-8222-8333-444444444444")
        listed = self.run_helper("list", "--json")
        self.assertEqual([row["name"] for row in json.loads(listed.stdout)], ["Mine"])
        self.assertEqual(self.run_helper("read", "Theirs").returncode, 2)
        sent = self.run_helper("send", "Mine", "check line 12")
        self.assertEqual(sent.returncode, 0, sent.stderr)
        submitted = [query for query in self.events("store") if query["op"] == "message_submit"]
        self.assertEqual((submitted[-1]["text"], submitted[-1]["sid"]), ("From live-parent: check line 12", mine))
        listing = dict(LISTING)
        listing["workspaces"] = LISTING["workspaces"] + [dict(id=2, name="X", active=False, groups=[], tabs=[dict(id=45, title="Mine", host="remote-1", tmux=tmux)])]
        closed = self.run_helper("close", "Mine", MP_HELPER_TEST_LIST=json.dumps(listing))
        self.assertEqual(closed.returncode, 0, closed.stderr)
        self.assertEqual(json.loads(closed.stdout)["tab_closed"], True)
        self.assertIn(["session-close", "--tab", "45"], self.events("zsb"))
        self.assertEqual(self.events("host")[-1], ["disable", "claude", mine])

    def test_SOFT_2013_installer_ships_mp_helper(self):
        target = Path(self.temp.name) / "installed"
        done = subprocess.run(["sh", str(ROOT / "tools/install-mp-talk.sh")], capture_output=True, text=True, timeout=60,
                              env=dict(os.environ, HOME=str(self.home), XDG_DATA_HOME=str(target / "share"), MP_TALK_BIN=str(target / "bin")))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertTrue((target / "share/multiprompt-talk/mp_helper.py").is_file())
        self.assertIn("mp_helper.py", (target / "bin/mp-helper").read_text())


if __name__ == "__main__":
    unittest.main()
