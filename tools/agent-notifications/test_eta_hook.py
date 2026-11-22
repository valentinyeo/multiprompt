import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
import unittest.mock
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("eta_hook", Path(__file__).with_name("eta_hook.py"))
eta_hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(eta_hook)
notify = eta_hook.notify


def load_mp_eta():
    spec = importlib.util.spec_from_file_location("mp_eta", Path(__file__).with_name("mp_eta.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Hooks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / "state"
        self.env = {"MULTIPROMPT_STATE_DIR": str(self.state), "PATH": os.environ.get("PATH", ""), "TMUX": "", "TMUX_PANE": ""}
        self.enter = patch.dict(os.environ, self.env, clear=True)
        self.enter.start()
        self.addCleanup(self.enter.stop)
        self.target = patch.object(notify, "target", return_value=("tab1", 19548, True))
        self.target.start()
        self.addCleanup(self.target.stop)

    def prompt(self, now=100, **payload):
        payload.setdefault("session_id", "s1")
        return eta_hook.handle("prompt", payload, self.env, now)

    def call(self, tool="Bash", command="ls", now=101):
        return eta_hook.handle("pretool", {
            "session_id": "s1",
            "tool_name": tool,
            "tool_input": {"command": command},
        }, self.env, now)

    def test_prompt_returns_user_prompt_submit_context(self):
        self.assertEqual(self.prompt(), {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": eta_hook.PROMPT_CONTEXT,
            }
        })

    def test_prompt_adds_the_accuracy_sentence_when_stats_exist(self):
        path = self.state / "eta-log.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        row = json.dumps({"agent": "claude", "est_seconds": 100, "actual_seconds": 140})
        path.write_text((row + "\n") * 3, encoding="utf-8")
        context = self.prompt()["hookSpecificOutput"]["additionalContext"]
        self.assertTrue(context.endswith(" Your recent tasks took 1.4x your estimate; adjust for that."))

    def test_prompt_quotes_the_calling_agent_accuracy(self):
        path = self.state / "eta-log.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        row = json.dumps({"agent": "codex", "est_seconds": 100, "actual_seconds": 300})
        path.write_text((row + "\n") * 3, encoding="utf-8")
        env = dict(self.env, CODEX_SESSION_ID="s1")
        context = eta_hook.handle("prompt", {"session_id": "s1"}, env, 100)
        self.assertTrue(context["hookSpecificOutput"]["additionalContext"].endswith(
            " Your recent tasks took 3.0x your estimate; adjust for that."
        ))

    def test_prompt_does_not_gate_a_message_typed_mid_turn(self):
        with patch.object(notify, "eta_entry", return_value={"est_seconds": 600}):
            self.prompt()
        self.assertIsNone(self.call())

    def test_subagent_tool_calls_are_never_gated(self):
        self.prompt()
        result = eta_hook.handle("pretool", {"session_id": "s1", "agent_id": "a1", "tool_name": "Bash",
                                             "tool_input": {"command": "ls"}}, self.env, 101)
        self.assertIsNone(result)
        self.assertIsNotNone(self.call())

    def test_a_new_prompt_after_a_bg_turn_asks_for_a_fresh_estimate(self):
        notify.set_eta_open("tab1", {"agent": "claude", "est_seconds": 1800, "started_at": 50,
                                     "desc": "build", "carried": True})
        self.prompt()
        self.assertIsNone(notify.eta_entry("tab1"))
        self.assertIsNotNone(self.call())

    def test_a_mid_turn_message_keeps_the_open_estimate(self):
        notify.set_eta_open("tab1", {"agent": "claude", "est_seconds": 1800, "started_at": 50, "desc": "build"})
        self.prompt()
        self.assertIsNotNone(notify.eta_entry("tab1"))
        self.assertIsNone(self.call())

    def test_prompt_is_silent_for_a_detached_tmux_session(self):
        env = dict(self.env, TMUX="/tmp/tmux-1/default,1,0", TMUX_PANE="%3")
        done = unittest.mock.Mock(stdout="0\n")
        with patch.object(eta_hook.subprocess, "run", return_value=done):
            self.assertIsNone(eta_hook.handle("prompt", {"session_id": "s1"}, env, 100))

    def test_prompt_speaks_for_an_attached_tmux_session(self):
        env = dict(self.env, TMUX="/tmp/tmux-1/default,1,0", TMUX_PANE="%3")
        done = unittest.mock.Mock(stdout="1\n")
        with patch.object(eta_hook.subprocess, "run", return_value=done):
            self.assertIsNotNone(eta_hook.handle("prompt", {"session_id": "s1"}, env, 100))

    def test_prompt_is_silent_without_a_resolved_tab(self):
        with patch.object(notify, "target", return_value=None):
            self.assertIsNone(self.prompt())

    def test_pretool_denies_once_then_allows(self):
        self.assertIsNotNone(self.prompt())
        first = self.call()
        self.assertEqual(first, {"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": eta_hook.DENY_REASON,
        }})
        self.assertIsNone(self.call(now=102))
        self.assertIsNone(self.call(tool="Read", command="", now=103))

    def test_pretool_allows_the_mp_eta_call_itself(self):
        self.assertIsNotNone(self.prompt())
        self.assertIsNone(self.call(command='mp-eta 20m "fix login"'))
        self.assertIsNone(self.call(command="/home/test/.local/bin/mp-eta +10m"))
        self.assertIsNone(self.call(command="python3 mp_eta.py 20m"))
        denial = self.call(tool="Read", command="", now=102)
        self.assertEqual(denial["hookSpecificOutput"]["permissionDecision"], "deny")

    def test_pretool_allows_everything_without_a_prompt_entry(self):
        self.assertIsNone(self.call())

    def test_mp_eta_clears_the_pending_denial(self):
        self.assertIsNotNone(self.prompt())
        mp_eta_module = load_mp_eta()
        with patch.object(notify, "deliver"):
            self.assertEqual(mp_eta_module.main(["20m", "fix login"], self.env, now=110), 0)
        self.assertIsNone(self.call(tool="Read", command="", now=111))

    def test_pretool_falls_back_to_the_tab_name_without_a_session_id(self):
        payload = {"cwd": "/repo"}
        self.assertIsNotNone(eta_hook.handle("prompt", payload, self.env, 100))
        self.assertIsNotNone(eta_hook.handle("pretool", {"tool_name": "Read"}, self.env, 101))

    def test_stale_prompt_entries_stop_blocking(self):
        self.assertIsNotNone(self.prompt(now=100))
        self.assertIsNone(self.call(now=100 + 7 * 60 * 60))

    def test_a_broken_state_directory_never_blocks(self):
        blocked = Path(self.tmp.name) / "blocked"
        blocked.write_text("not a directory", encoding="utf-8")
        self.env["MULTIPROMPT_STATE_DIR"] = str(blocked / "state")
        with patch.dict(os.environ, self.env), patch.object(sys, "stdin", io.StringIO(json.dumps({"session_id": "s1"}))):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(eta_hook.main(["prompt"]), 0)
            self.assertEqual(output.getvalue(), "")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(eta_hook.main(["pretool"]), 0)

    def test_main_prints_the_hook_json(self):
        with patch.dict(os.environ, self.env), \
                patch.object(sys, "stdin", io.StringIO(json.dumps({"session_id": "s1"}))):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(eta_hook.main(["prompt"]), 0)
        data = json.loads(output.getvalue())
        self.assertEqual(data["hookSpecificOutput"]["hookEventName"], "UserPromptSubmit")

    def test_stop_never_blocks_or_reads_the_payload(self):
        with patch.object(sys, "stdin", side_effect=AssertionError("read Stop input")), \
                patch.object(notify, "deliver") as deliver:
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(eta_hook.main(["stop"]), 0)
        self.assertEqual(output.getvalue(), "")
        deliver.assert_not_called()

    def test_main_ignores_unknown_modes_and_bad_input(self):
        with patch.object(sys, "stdin", io.StringIO("not json")):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(eta_hook.main(["pretool"]), 0)
        self.assertEqual(output.getvalue(), "")
        self.assertEqual(eta_hook.main([]), 0)


class Nudges(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / "state"
        self.env = {"MULTIPROMPT_STATE_DIR": str(self.state), "PATH": os.environ.get("PATH", ""), "TMUX": "", "TMUX_PANE": ""}
        self.enter = patch.dict(os.environ, self.env, clear=True)
        self.enter.start()
        self.addCleanup(self.enter.stop)
        self.target = patch.object(notify, "target", return_value=("tab1", 19548, True))
        self.target.start()
        self.addCleanup(self.target.stop)

    def entry(self, **fields):
        data = {"agent": "claude", "est_seconds": 1200, "started_at": 1000,
                "updated_at": 1000, "desc": "fix login"}
        data.update(fields)
        return data

    def test_overdue_estimate_says_how_long_ago_it_ran_out(self):
        text = eta_hook.nudge_text(self.entry(), 1000 + 1200 + 13 * 60, None)
        self.assertEqual(text, "Your estimate for this request ran out 13m ago. "
                               "If you are still working, run: mp-eta <time left>.")

    def test_overdue_nudge_is_silent_within_five_minutes(self):
        now = 1000 + 1200 + 13 * 60
        self.assertIsNone(eta_hook.nudge_text(self.entry(), now, now - 60))
        self.assertIsNone(eta_hook.nudge_text(self.entry(), now, now - 299))
        self.assertIsNotNone(eta_hook.nudge_text(self.entry(), now, now - 300))

    def test_stale_estimate_asks_for_an_update(self):
        text = eta_hook.nudge_text(self.entry(est_seconds=1800), 1000 + 720, None)
        self.assertEqual(text, "12m since your last estimate (30m total). If what you "
                               "found changes the picture, run: mp-eta <time left>. "
                               "Otherwise carry on.")

    def test_stale_nudge_waits_for_the_ten_minute_rate_limit(self):
        now = 1000 + 720
        self.assertIsNone(eta_hook.nudge_text(self.entry(est_seconds=1800), now, now - 599))
        self.assertIsNotNone(eta_hook.nudge_text(self.entry(est_seconds=1800), now, now - 600))

    def test_short_estimates_use_the_ten_minute_floor(self):
        self.assertIsNone(eta_hook.nudge_text(self.entry(), 1000 + 599, None))
        self.assertIsNotNone(eta_hook.nudge_text(self.entry(), 1000 + 600, None))

    def test_a_long_estimate_uses_the_forty_percent_share(self):
        entry = self.entry(est_seconds=3600)
        self.assertIsNone(eta_hook.nudge_text(entry, 1000 + 1439, None))
        self.assertEqual(eta_hook.nudge_text(entry, 1000 + 1440, None),
                         "24m since your last estimate (1h total). If what you found "
                         "changes the picture, run: mp-eta <time left>. Otherwise carry on.")

    def test_a_fresh_estimate_is_left_alone(self):
        self.assertIsNone(eta_hook.nudge_text(self.entry(updated_at=2000), 2000, None))
        self.assertIsNone(eta_hook.nudge_text(self.entry(), 1000 + 60, None))

    def test_a_missing_updated_at_counts_from_the_start(self):
        entry = self.entry()
        del entry["updated_at"]
        self.assertIsNone(eta_hook.nudge_text(entry, 1000 + 599, None))
        self.assertIsNotNone(eta_hook.nudge_text(entry, 1000 + 600, None))

    def test_a_broken_entry_is_never_nudged(self):
        self.assertIsNone(eta_hook.nudge_text(None, 5000, None))
        self.assertIsNone(eta_hook.nudge_text({"started_at": 1000}, 5000, None))
        self.assertIsNone(eta_hook.nudge_text(self.entry(est_seconds=0), 5000, None))

    def test_posttool_returns_the_post_tool_use_context(self):
        notify.set_eta_open("tab1", self.entry())
        result = eta_hook.handle("posttool", {"session_id": "s1", "tool_name": "Bash"},
                                 self.env, 1600)
        self.assertEqual(result, {"hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "10m since your last estimate (20m total). If what "
                                 "you found changes the picture, run: mp-eta <time left>. "
                                 "Otherwise carry on.",
        }})
        self.assertEqual(eta_hook.read_state()["tab1"]["nudge"], 1600)

    def test_posttool_records_the_nudge_and_then_stays_quiet(self):
        notify.set_eta_open("tab1", self.entry())
        self.assertIsNotNone(eta_hook.handle("posttool", {}, self.env, 1600))
        self.assertIsNone(eta_hook.handle("posttool", {}, self.env, 1660))

    def test_posttool_reactivates_a_delivered_done_once_even_without_an_estimate(self):
        payload = {"session_id": "s1", "tool_name": "Bash"}
        notify.set_lifecycle("tab1", "s1", "done")
        with patch.object(notify, "deliver") as deliver:
            self.assertIsNone(eta_hook.handle("posttool", payload, self.env, 1600))
            self.assertIsNone(eta_hook.handle("posttool", payload, self.env, 1601))
        deliver.assert_called_once_with(["ACTIVE:tab1"], 19548, attempts=1)
        self.assertEqual(notify.lifecycle_state("tab1", "s1"), "active")

    def test_posttool_reactivates_after_a_blocked_stop_and_new_done(self):
        payload = {"session_id": "s1", "tool_name": "Bash"}
        notify.set_lifecycle("tab1", "s1", "done")
        with patch.object(notify, "deliver") as deliver:
            eta_hook.handle("posttool", payload, self.env, 1600)
            notify.set_lifecycle("tab1", "s1", "done")
            eta_hook.handle("posttool", payload, self.env, 1601)
        self.assertEqual(deliver.call_count, 2)

    def test_posttool_does_not_reactivate_a_different_session_or_subagent(self):
        notify.set_lifecycle("tab1", "old", "done")
        with patch.object(notify, "deliver") as deliver:
            eta_hook.handle("posttool", {"session_id": "new"}, self.env, 1600)
            eta_hook.handle("posttool", {"session_id": "old", "agent_id": "child"}, self.env, 1601)
        deliver.assert_not_called()

    def test_failed_reactivation_retries_without_claiming_active(self):
        notify.set_lifecycle("tab1", "s1", "done")
        with patch.object(notify, "deliver", side_effect=[OSError("offline"), None]) as deliver:
            eta_hook.handle("posttool", {"session_id": "s1"}, self.env, 1600)
            self.assertEqual(notify.lifecycle_state("tab1", "s1"), "done")
            eta_hook.handle("posttool", {"session_id": "s1"}, self.env, 1601)
        self.assertEqual(deliver.call_count, 2)
        self.assertEqual(notify.lifecycle_state("tab1", "s1"), "active")

    def test_background_done_posttool_and_later_done_form_a_new_turn(self):
        notify.set_eta_open("tab1", self.entry(background=True))
        payload = '{"session_id":"s1","cwd":"/repo"}'
        with patch.object(notify, "deliver") as deliver:
            with patch.object(sys, "argv", ["notify.py", "claude", "done", payload]):
                notify.main()
            self.assertEqual(notify.lifecycle_state("tab1", "s1"), "done")
            eta_hook.handle("posttool", {"session_id": "s1"}, self.env, 1600)
            self.assertIsNone(notify.eta_entry("tab1"))
            with patch.object(sys, "argv", ["notify.py", "claude", "done", payload]):
                notify.main()
        self.assertEqual(deliver.call_count, 3)
        self.assertEqual(deliver.call_args_list[1].args[0], ["ACTIVE:tab1"])
        self.assertEqual(deliver.call_args_list[2].args[0][-1], "DONE:tab1")

    def test_posttool_drops_carried_estimate_on_self_resume(self):
        notify.set_lifecycle("tab1", "s1", "done")
        notify.set_eta_open("tab1", self.entry(carried=True))
        with patch.object(notify, "deliver"):
            eta_hook.handle("posttool", {"session_id": "s1"}, self.env, 1600)
        self.assertIsNone(notify.eta_entry("tab1"))

    def test_posttool_is_silent_without_an_open_estimate(self):
        self.assertIsNone(eta_hook.handle("posttool", {}, self.env, 5000))
        self.assertEqual(eta_hook.read_state(), {})

    def test_posttool_is_silent_for_an_unwatched_session(self):
        notify.set_eta_open("tab1", self.entry())
        env = dict(self.env, TMUX="/tmp/tmux-1/default,1,0", TMUX_PANE="%3")
        done = unittest.mock.Mock(stdout="0\n")
        with patch.object(eta_hook.subprocess, "run", return_value=done):
            self.assertIsNone(eta_hook.handle("posttool", {}, env, 1600))
        self.assertEqual(eta_hook.read_state(), {})

    def test_main_prints_the_posttool_json(self):
        notify.set_eta_open("tab1", self.entry())
        payload = json.dumps({"session_id": "s1", "tool_name": "Bash"})
        with patch.dict(os.environ, self.env), patch.object(sys, "stdin", io.StringIO(payload)):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(eta_hook.main(["posttool"]), 0)
        data = json.loads(output.getvalue())
        self.assertEqual(data["hookSpecificOutput"]["hookEventName"], "PostToolUse")

    def test_main_is_silent_and_succeeds_on_a_posttool_error(self):
        notify.set_eta_open("tab1", self.entry())
        with patch.object(sys, "stdin", io.StringIO("not json")):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(eta_hook.main(["posttool"]), 0)
        self.assertEqual(output.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
