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

    def test_close_runs_only_with_the_chat_tab_in_the_background(self):
        before_close = DRIVE.split("Invoke-LinuxMpSessions @('close', $chatName)", 1)[0]
        self.assertIn("Ctrl+K: leave the chat tab in the background", before_close)
        self.assertIn("chat tab in the background", before_close)

    def test_uses_published_tools_and_keeps_reopened_view_untouched(self):
        self.assertIn("~/.multiprompt-runtime/mp-sessions", DRIVE)
        self.assertNotIn("MULTIPROMPT_READER_SOURCE=", DRIVE)
        reopened = DRIVE.split("$restartJson =", 1)[1]
        self.assertNotIn("Alt+C", reopened)
        self.assertIn(". Restart-DesktopApp", reopened)
        self.assertIn("$Evidence/$Stage.layout.json", DRIVE)


if __name__ == "__main__":
    unittest.main()