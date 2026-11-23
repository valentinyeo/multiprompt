import argparse
import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("mp_tab_state", ROOT / "src/mp_tab_state.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
FIXTURE = json.loads((ROOT / "tools/fixtures/SOFT-3141/pc-state.json").read_text())
VERBS = ("open", "close", "move", "pin", "unpin", "archive", "unarchive", "wait", "restore")


class Desktop:
    def __init__(self, mode="applied"):
        self.view = copy.deepcopy(FIXTURE)
        self.mode = mode
        self.writes = []
        self.reads = 0

    def zsb(self, verb, *args):
        if verb == "pc-state":
            self.reads += 1
            if self.mode == "offline" or (self.mode == "lost_readback" and self.reads > 1):
                return dict(ok=False, error="desktop_offline")
            return copy.deepcopy(self.view)
        if verb != "tab-action":
            raise AssertionError(verb)
        request = json.loads(args[0])
        if self.mode in ("refused", "conflict"):
            return dict(ok=False, error=self.mode)
        if self.mode != "ignored":
            self.view["tabs"] = [request["state"]]
            self.writes.append(request)
        return dict(ok=True, state=request["state"])


class TabVerbs(unittest.TestCase):
    def invoke(self, desktop, verb, **kwargs):
        args = argparse.Namespace(command=verb, name="Fixture", json=True, host=None, workspace=None,
                                  group=None, position=None, kind=None, sid=None, tmux=None, title=None,
                                  user=None, **kwargs)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = MODULE.tab_command(desktop, args)
        self.assertEqual(code, 0)
        result = json.loads(output.getvalue())
        self.assertTrue(result["ok"])
        return result["state"]

    def prepare(self, desktop, verb):
        tab = desktop.view["tabs"][0]
        if verb in ("open", "restore"):
            tab.update(closed=True, visible=False, hidden_reason="closed")
        if verb == "unarchive":
            tab.update(archived=True, visible=False, hidden_reason="archived")
        if verb == "unpin":
            tab["pinned"] = True

    def test_every_verb_applied_and_idempotent(self):
        for verb in VERBS:
            with self.subTest(verb=verb):
                desktop = Desktop()
                self.prepare(desktop, verb)
                args = {"workspace": "Home", "position": 0} if verb == "move" else {}
                first = self.invoke_with(desktop, verb, args)
                writes = len(desktop.writes)
                second = self.invoke_with(desktop, verb, args)
                self.assertEqual(first, second)
                self.assertEqual(len(desktop.writes), writes)
                self.assertEqual(first["host"], "remote-1")
                self.assertEqual(first["workspace"], "Home" if verb == "move" else "Research")
                self.assertEqual(first["sid"], FIXTURE["tabs"][0]["sid"])
                self.assertEqual(first["kind"], "chat")
                self.assertGreaterEqual(desktop.reads, 3)

    def invoke_with(self, desktop, verb, changes):
        args = dict(command=verb, name="Fixture", json=True, host=None, workspace=None, group=None,
                    position=None, kind=None, sid=None, tmux=None, title=None, user=None)
        args.update(changes)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = MODULE.tab_command(desktop, argparse.Namespace(**args))
        self.assertEqual(code, 0)
        return json.loads(output.getvalue())["state"]

    def test_refused_offline_and_conflict_leave_state_unchanged(self):
        for verb in VERBS:
            for mode in ("refused", "offline", "conflict"):
                with self.subTest(verb=verb, mode=mode):
                    desktop = Desktop(mode)
                    self.prepare(desktop, verb)
                    before = copy.deepcopy(desktop.view)
                    with self.assertRaises(ValueError):
                        self.invoke_with(desktop, verb, {"workspace": "Home"} if verb == "move" else {})
                    self.assertEqual(desktop.view, before)
                    self.assertEqual(desktop.writes, [])

    def test_ack_without_pc_readback_is_not_success(self):
        for verb in VERBS:
            for mode in ("ignored", "lost_readback"):
                with self.subTest(verb=verb, mode=mode):
                    desktop = Desktop(mode)
                    self.prepare(desktop, verb)
                    with self.assertRaises(ValueError):
                        self.invoke_with(desktop, verb, {"workspace": "Home"} if verb == "move" else {})

    def test_closed_chats_are_only_revived_explicitly(self):
        for verb in VERBS:
            desktop = Desktop()
            desktop.view["tabs"][0].update(closed=True, visible=False, hidden_reason="closed")
            result = self.invoke_with(desktop, verb, {"workspace": "Home"} if verb == "move" else {})
            self.assertEqual(result["closed"], verb not in ("open", "restore"), verb)

    def test_plain_output_is_one_line(self):
        desktop = Desktop()
        args = argparse.Namespace(command="pin", name="Fixture", json=False, host=None)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            MODULE.tab_command(desktop, args)
        self.assertEqual(output.getvalue(), "pin Fixture\n")

    def test_plain_shell_has_a_durable_key_through_close_and_restore(self):
        desktop = Desktop()
        desktop.view.update(instance=7, next_shell_id=42, users=["agent", "agent", "agent", ""])
        desktop.view["hosts"].append("local")
        opened = self.invoke_with(desktop, "open", dict(name=None, title="Local shell", kind="shell", host="3", workspace="Research"))
        self.assertEqual(opened["tmux"], "@shell-7-42")
        self.assertEqual(opened["host"], "local")
        self.assertIsNone(opened["sid"])
        closed = self.invoke_with(desktop, "close", dict(name="Local shell", host="3"))
        self.assertTrue(closed["closed"])
        restored = self.invoke_with(desktop, "restore", dict(name="Local shell", host="3"))
        self.assertEqual(restored["tmux"], opened["tmux"])
        self.assertFalse(restored["closed"])
        self.assertEqual(restored["kind"], "shell")

    def test_open_refuses_a_different_requested_placement(self):
        desktop = Desktop()
        before = copy.deepcopy(desktop.view)
        with self.assertRaisesRegex(ValueError, "open keeps the existing workspace"):
            self.invoke_with(desktop, "open", {"workspace": "Home"})
        self.assertEqual(desktop.view, before)
        self.assertEqual(desktop.writes, [])

    def test_ambiguous_target_never_writes(self):
        desktop = Desktop()
        other = copy.deepcopy(desktop.view["tabs"][0])
        other["host"] = "remote-2"
        desktop.view["tabs"].append(other)
        with self.assertRaises(ValueError):
            self.invoke(desktop, "pin")
        self.assertEqual(desktop.writes, [])


if __name__ == "__main__":
    unittest.main()
