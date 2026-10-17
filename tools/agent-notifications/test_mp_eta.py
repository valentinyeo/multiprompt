import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mp_eta", Path(__file__).with_name("mp_eta.py"))
mp_eta = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mp_eta)
notify = mp_eta.notify


class Duration(unittest.TestCase):
    def test_accepts_every_documented_form(self):
        self.assertEqual(mp_eta.parse_duration("45s"), 45)
        self.assertEqual(mp_eta.parse_duration("20m"), 1200)
        self.assertEqual(mp_eta.parse_duration("1h"), 3600)
        self.assertEqual(mp_eta.parse_duration("1h20m"), 4800)
        self.assertEqual(mp_eta.parse_duration("90"), 5400)
        self.assertEqual(mp_eta.parse_duration(" 1H20M30S "), 4830)

    def test_rejects_invalid_durations(self):
        for value in ("", "x", "0", "0m", "20x", "1h20", "m", "-5m", "1.5h", "20m30"):
            self.assertIsNone(mp_eta.parse_duration(value), value)


class Estimates(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / "state"
        self.env = {
            "MULTIPROMPT_STATE_DIR": str(self.state),
            "CLAUDECODE": "1",
            "MP_AGENT": "",
            "PATH": os.environ.get("PATH", ""),
        }
        self.enter = patch.dict(os.environ, self.env)
        self.enter.start()
        self.addCleanup(self.enter.stop)
        self.quiet = patch("sys.stdout", new_callable=io.StringIO)
        self.quiet.start()
        self.addCleanup(self.quiet.stop)

    def patched(self):
        target = patch.object(notify, "target", return_value=("tab1", 19548, True))
        deliver = patch.object(notify, "deliver")
        return target, deliver

    def test_set_records_open_estimate_and_sends_the_wire_line(self):
        target, deliver = self.patched()
        with target, deliver as mocked:
            self.assertEqual(mp_eta.main(["20m", "Fix", "the", "login", "bug"], self.env, now=1000), 0)
        self.assertEqual(mocked.call_args.args[0], ["ETA:tab1:1200:Fix the login bug"])
        self.assertEqual(mocked.call_args.args[1], 19548)
        entry = notify.eta_open()["tab1"]
        self.assertEqual(entry["agent"], "claude")
        self.assertEqual(entry["est_seconds"], 1200)
        self.assertEqual(entry["started_at"], 1000)
        self.assertEqual(entry["desc"], "Fix the login bug")

    def test_bg_flag_marks_the_estimate_to_outlive_the_turn(self):
        target, deliver = self.patched()
        with target, deliver as mocked:
            self.assertEqual(mp_eta.main(["20m", "Build", "--bg", "it"], self.env, now=1000), 0)
        self.assertEqual(mocked.call_args.args[0], ["ETA:tab1:1200:Build it"])
        self.assertTrue(notify.eta_open()["tab1"]["background"])

    def test_bare_bg_keeps_the_current_estimate(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "Build"], self.env, now=1000)
            self.assertEqual(mp_eta.main(["--bg"], self.env, now=1100), 0)
        entry = notify.eta_open()["tab1"]
        self.assertTrue(entry["background"])
        self.assertEqual(entry["est_seconds"], 1200)

    def test_a_revision_keeps_the_bg_mark(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "Build", "--bg"], self.env, now=1000)
            mp_eta.main(["10m"], self.env, now=1300)
        self.assertTrue(notify.eta_open()["tab1"]["background"])

    def test_bare_bg_without_an_estimate_fails(self):
        target, deliver = self.patched()
        with target, deliver, patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(mp_eta.main(["--bg"], self.env, now=1000), 1)

    def test_description_is_cleaned_and_trimmed_to_eighty(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "line one\nline two\x07", "x" * 200], self.env, now=1000)
        self.assertEqual(notify.eta_open()["tab1"]["desc"][:18], "line one line two ")
        self.assertEqual(len(notify.eta_open()["tab1"]["desc"]), 80)

    def test_description_may_keep_a_colon(self):
        target, deliver = self.patched()
        with target, deliver as mocked:
            mp_eta.main(["1h", "fix: login"], self.env, now=1000)
        self.assertEqual(mocked.call_args.args[0], ["ETA:tab1:3600:fix: login"])

    def test_description_defaults_to_empty(self):
        target, deliver = self.patched()
        with target, deliver as mocked:
            mp_eta.main(["45s"], self.env, now=1000)
        self.assertEqual(mocked.call_args.args[0], ["ETA:tab1:45:"])

    def test_extend_adds_to_the_estimate_and_resends_remaining(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "Fix", "the", "login", "bug"], self.env, now=1000)
        with target, deliver as mocked:
            self.assertEqual(mp_eta.main(["+10m"], self.env, now=1300), 0)
        self.assertEqual(mocked.call_args.args[0], ["ETA:tab1:1500:Fix the login bug"])
        entry = notify.eta_open()["tab1"]
        self.assertEqual(entry["est_seconds"], 1800)
        self.assertEqual(entry["started_at"], 1000)

    def test_second_estimate_revises_and_keeps_the_first_one(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "Fix", "the", "login", "bug"], self.env, now=1000)
        with target, deliver as mocked:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(mp_eta.main(["10m"], self.env, now=1500), 0)
        self.assertEqual(mocked.call_args.args[0], ["ETA:tab1:600:Fix the login bug"])
        entry = notify.eta_open()["tab1"]
        self.assertEqual(entry["started_at"], 1000)
        self.assertEqual(entry["first_est_seconds"], 1200)
        self.assertEqual(entry["est_seconds"], 1100)
        self.assertEqual(entry["updated_at"], 1500)
        self.assertEqual(entry["revisions"], 1)
        self.assertEqual(entry["desc"], "Fix the login bug")
        self.assertEqual(out.getvalue(), "Estimate updated: 10m left (first estimate 20m) on tab1\n")

    def test_revisions_count_up_and_the_first_estimate_stays_frozen(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "first"], self.env, now=1000)
            mp_eta.main(["30m"], self.env, now=1200)
            mp_eta.main(["5m", "now much smaller"], self.env, now=2000)
        entry = notify.eta_open()["tab1"]
        self.assertEqual(entry["revisions"], 2)
        self.assertEqual(entry["first_est_seconds"], 1200)
        self.assertEqual(entry["est_seconds"], 1000 + 300)
        self.assertEqual(entry["updated_at"], 2000)
        self.assertEqual(entry["desc"], "now much smaller")

    def test_revision_keeps_the_old_description_when_none_is_given(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "Fix", "the", "login", "bug"], self.env, now=1000)
        with target, deliver as mocked:
            mp_eta.main(["10m"], self.env, now=1500)
        self.assertEqual(mocked.call_args.args[0], ["ETA:tab1:600:Fix the login bug"])
        self.assertEqual(notify.eta_open()["tab1"]["desc"], "Fix the login bug")

    def test_revision_backfills_a_first_estimate_from_an_old_entry(self):
        notify.set_eta_open("tab1", {"agent": "claude", "est_seconds": 1200,
                                     "started_at": 1000, "desc": "old"})
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["10m"], self.env, now=1500)
        entry = notify.eta_open()["tab1"]
        self.assertEqual(entry["first_est_seconds"], 1200)
        self.assertEqual(entry["started_at"], 1000)

    def test_extend_sets_updated_at_and_increments_revisions(self):
        target, deliver = self.patched()
        with target, deliver:
            mp_eta.main(["20m", "Fix", "the", "login", "bug"], self.env, now=1000)
        with target, deliver:
            mp_eta.main(["+10m"], self.env, now=1300)
        entry = notify.eta_open()["tab1"]
        self.assertEqual(entry["est_seconds"], 1800)
        self.assertEqual(entry["first_est_seconds"], 1200)
        self.assertEqual(entry["updated_at"], 1300)
        self.assertEqual(entry["revisions"], 1)

    def test_extend_without_an_open_estimate_fails(self):
        target, deliver = self.patched()
        with target, deliver as mocked, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(mp_eta.main(["+10m"], self.env, now=1000), 1)
        mocked.assert_not_called()

    def test_invalid_duration_prints_usage(self):
        target, deliver = self.patched()
        error = io.StringIO()
        with target, deliver as mocked, contextlib.redirect_stderr(error):
            self.assertEqual(mp_eta.main(["20x"], self.env, now=1000), 2)
        mocked.assert_not_called()
        self.assertIn("usage: mp-eta", error.getvalue())

    def test_unknown_tab_refuses_to_send(self):
        with patch.object(notify, "target", return_value=None), \
                patch.object(notify, "deliver") as mocked, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(mp_eta.main(["20m", "x"], self.env, now=1000), 1)
        mocked.assert_not_called()
        self.assertEqual(notify.eta_open(), {})
    def test_agent_identity(self):
        self.assertEqual(mp_eta.agent_name({"MP_AGENT": "Hax"}), "hax")
        self.assertEqual(mp_eta.agent_name({"CLAUDECODE": "1"}), "claude")
        self.assertEqual(mp_eta.agent_name({"CLAUDE_CODE_SESSION_ID": "s"}), "claude")
        self.assertEqual(mp_eta.agent_name({"CODEX_THREAD_ID": "s"}), "codex")
        self.assertEqual(mp_eta.agent_name({"HAX_PROVIDER": "zai"}), "hax")
        self.assertEqual(mp_eta.agent_name({}), "unknown")

    def test_wire_line_never_sends_a_negative_remaining(self):
        self.assertEqual(mp_eta.wire("tab1", -30, ""), "ETA:tab1:0:")


class Stats(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / "state"
        self.env = {"MULTIPROMPT_STATE_DIR": str(self.state)}

    def log(self, rows):
        path = self.state / "eta-log.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")

    def rows(self, agent, ratios):
        return [{"agent": agent, "est_seconds": 1000, "actual_seconds": int(1000 * ratio),
                 "finished_at": 0, "desc": ""} for ratio in ratios]

    def run_stats(self):
        out = io.StringIO()
        with patch.dict(os.environ, self.env), contextlib.redirect_stdout(out):
            self.assertEqual(mp_eta.main(["stats"]), 0)
        return out.getvalue()

    def test_no_data_yet(self):
        self.assertEqual(self.run_stats(), "no data yet\n")

    def test_median_of_finished_tasks(self):
        self.log(self.rows("claude", [1.0, 1.4, 1.5]))
        self.assertEqual(self.run_stats(), "claude: tasks take 1.4x the estimate (last 3)\n")

    def test_only_the_last_twenty_count(self):
        self.log(self.rows("claude", [10.0] * 5 + [1.0] * 20))
        self.assertEqual(self.run_stats(), "claude: tasks take 1.0x the estimate (last 20)\n")

    def test_groups_by_agent_and_skips_broken_rows(self):
        rows = self.rows("claude", [1.0, 1.4, 1.5]) + self.rows("codex", [2.0]) + [
            {"agent": "hax", "est_seconds": 0, "actual_seconds": 10},
            {"agent": "grok", "est_seconds": 10, "actual_seconds": "bad"},
        ]
        self.log(rows)
        self.assertEqual(self.run_stats(), "claude: tasks take 1.4x the estimate (last 3)\n")


if __name__ == "__main__":
    unittest.main()
