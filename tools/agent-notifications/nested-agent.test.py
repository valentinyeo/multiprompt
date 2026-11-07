import importlib.util
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("zigshell_notify", Path(__file__).with_name("notify.py"))
notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)


class NestedAgent(unittest.TestCase):
    def test_agent_started_inside_another_agent_never_rebinds_the_tab(self):
        tree = {40: ("sh", 30), 30: ("claude", 20), 20: ("bash", 10), 10: ("claude", 5), 5: ("python3", 1)}
        nested = getattr(notify, "nested_agent", lambda pid, parent=None: False)
        self.assertTrue(nested(40, tree.get))
        with patch.object(notify, "target", return_value=("live-1", 19548, True)), \
                patch.object(notify, "nested_agent", return_value=True, create=True), \
                patch.object(notify, "deliver") as deliver, \
                patch.object(notify, "record_tab_states"), \
                patch.object(notify, "eta_bookkeeping"), \
                patch.object(notify.subprocess, "Popen"), \
                patch.object(sys, "argv", ["notify.py", "claude", "session"]), \
                patch.object(sys, "stdin", io.StringIO('{"session_id":"child","cwd":"/repo"}')):
            notify.main()
        deliver.assert_not_called()

    def test_top_level_agent_and_its_own_wrapper_still_report(self):
        top = {40: ("sh", 30), 30: ("claude", 20), 20: ("python3", 1)}
        wrapped = {40: ("sh", 30), 30: ("cursor-agent", 20), 20: ("cursor-agent", 15), 15: ("timeout", 10), 10: ("bash", 1)}
        nested = getattr(notify, "nested_agent", lambda pid, parent=None: True)
        self.assertFalse(nested(40, top.get))
        self.assertFalse(nested(40, wrapped.get))

    def test_agent_launched_outside_the_tab_owner_never_rebinds_the_tab(self):
        with tempfile.TemporaryDirectory() as root:
            host = Path(root) / "agent-host"
            host.mkdir()
            (host / "a.config.json").write_text('{"tmux": "live-1"}')
            (host / "a.state.json").write_text('{"pid": 20}')
            tree = {50: ("sh", 40), 40: ("cursor-agent", 30), 30: ("python3", 1)}
            own = {50: ("sh", 40), 40: ("claude", 20), 20: ("python3", 1)}
            foreign = getattr(notify, "foreign_to_tab", lambda name, env, pid, parent=None: False)
            env = {"MULTIPROMPT_STATE_DIR": root, "TMUX_PANE": "%1"}
            with patch.object(notify.subprocess, "run", side_effect=OSError):
                self.assertTrue(foreign("live-1", env, 50, tree.get))
                self.assertFalse(foreign("live-1", env, 50, own.get))
                self.assertFalse(foreign("term-1", env, 50, tree.get))


if __name__ == "__main__":
    unittest.main()
