import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
DRIVE = (ROOT / "tools/verify-session-restart/drive.ps1").read_text(encoding="utf-8")
MAP = (ROOT / ".claude/skills/verify-multiprompt/features/session-restart.md").read_text(encoding="utf-8")
CONTROL = (ROOT / ".claude/skills/verify-multiprompt/control.ps1").read_text(encoding="utf-8")


class SessionRestartJourneyTest(unittest.TestCase):
    def test_feature_map_lists_session_command_sources(self):
        for needle in ("src/mp_sessions.py", "src/mp_send.py", "src/mp_helper.py", "src/mp_fresh.py", "tools/mp-sessions"):
            self.assertIn(needle, MAP)

    def test_control_routes_session_restart(self):
        self.assertIn("'session-restart'", CONTROL)
        self.assertIn("verify-session-restart/drive.ps1", CONTROL)

    def test_driver_exercises_close_restart_and_chat_assertions(self):
        for needle in (
            "mp-sessions close",
            "mp-sessions restart",
            "cv=false",
            "before-restart",
            "after-app-restart",
            "Restart-DesktopApp",
        ):
            self.assertIn(needle, DRIVE)


if __name__ == "__main__":
    unittest.main()