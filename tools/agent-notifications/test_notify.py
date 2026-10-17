import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("zigshell_notify", Path(__file__).with_name("notify.py"))
notify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notify)


class Notifications(unittest.TestCase):
    def test_initialize_probe_never_targets_or_warms_a_session(self):
        with patch.dict(os.environ, {"MP_COMPLETE_PROBE": "1"}), \
                patch.object(notify, "target") as target, \
                patch.object(notify.subprocess, "Popen") as popen, \
                patch.object(sys, "argv", ["notify.py", "claude", "session"]):
            notify.main()
        target.assert_not_called()
        popen.assert_not_called()

    def test_remote_claude_session_warms_without_waiting_for_the_probe(self):
        with patch.object(notify, "target", return_value=("test", 19548, True)), \
                patch.object(notify, "deliver"), \
                patch.object(notify.subprocess, "Popen") as popen, \
                patch.object(sys, "argv", ["notify.py", "claude", "session"]), \
                patch.object(sys, "stdin", io.StringIO('{"session_id":"s1","cwd":"/repo"}')):
            notify.main()
        self.assertIn("--warm", popen.call_args.args[0])
        self.assertTrue(popen.call_args.kwargs["start_new_session"])

    def test_headless_never_asks_tmux_for_ambient_session(self):
        with patch.object(notify.subprocess, "run") as run:
            self.assertIsNone(notify.target({"ZSB_SESSION": "unrelated"}))
            self.assertIsNone(notify.target({"TMUX": "present"}))
            run.assert_not_called()

    def test_a_launcher_named_tab_without_tmux_is_targeted(self):
        self.assertEqual(notify.target({"MULTIPROMPT_TAB": "remote-3"}), ("remote-3", 19548, True))
        self.assertIsNone(notify.target({"MULTIPROMPT_TAB": "bad name;"}))

    def test_targets_exact_inherited_pane(self):
        with patch.object(notify.subprocess, "run") as run:
            run.return_value.stdout = "project-14\n"
            self.assertEqual(notify.target({"TMUX": "present", "TMUX_PANE": "%92"}), ("project-14", 19548, True))
            self.assertIn("%92", run.call_args.args[0])

    def test_rejects_protocol_delimiters(self):
        with patch.object(notify.subprocess, "run") as run:
            for name in ["tab|other", "tab:other", "tab;other", "tab\nDONE:other"]:
                run.return_value.stdout = name
                self.assertIsNone(notify.target({"TMUX": "yes", "TMUX_PANE": "%1"}))

    def test_six_agents_share_busy_and_done_contract(self):
        for agent in notify.AGENTS:
            self.assertEqual(notify.messages(agent, "active", {}, "test")[-1], "ACTIVE:test")
            self.assertEqual(notify.messages(agent, "done", {}, "test")[-1], "DONE:test")

    def test_codex_only_completes_on_supported_event(self):
        self.assertEqual(notify.messages("codex", "notify", {"type": "other"}, "test"), [])
        self.assertEqual(notify.messages("codex", "notify", {"type": "agent-turn-complete"}, "test")[-1], "DONE:test")

    def test_claude_permission_prompt_is_not_turn_completion(self):
        self.assertEqual(notify.messages("claude", "notify", {"notification_type": "permission_prompt"}, "test"), ["NOTIFICATION:test"])
        self.assertEqual(notify.messages("claude", "notify", {"notification_type": "idle_prompt"}, "test"), [])
        self.assertEqual(notify.messages("claude", "notify", {"type": "agent-turn-complete"}, "test")[-1], "DONE:test")

    def test_child_completion_cannot_mark_parent_done(self):
        self.assertEqual(notify.messages("claude", "done", {"agent_id": "child"}, "parent"), [])

    def test_grok_import_does_not_register_a_claude_resume_id(self):
        items = notify.messages("claude", "done", {"sessionId": "grok-id"}, "test")
        self.assertEqual(items, [])
        self.assertEqual(notify.messages("grok", "done", {"sessionId": "grok-id"}, "test"), ["AGENT:test:grok", "DONE:test"])

    def test_claude_resume_ignores_prompt_and_reply(self):
        items = notify.messages("claude", "done", {"session_id": "sid", "cwd": "/repo", "prompt": "private", "last_assistant_message": "private"}, "test")
        self.assertEqual(items[0], "SESSION:test:sid:/repo")
        self.assertNotIn("private", "".join(items))

    def test_tcp_delivery_is_separate_bounded_packets(self):
        with socket.socket() as server:
            server.bind(("127.0.0.1", 0))
            server.listen()
            server.settimeout(2)
            seen = []
            def receive():
                for _ in range(2):
                    with server.accept()[0] as client:
                        seen.append(client.recv(1024).decode())
            worker = threading.Thread(target=receive)
            worker.start()
            notify.deliver(["ACTIVE:test", "DONE:test"], server.getsockname()[1])
            worker.join(3)
            self.assertEqual(seen, ["ACTIVE:test", "DONE:test"])


class EstimateBookkeeping(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / "state"
        self.env = {"MULTIPROMPT_STATE_DIR": str(self.state)}
        self.enter = patch.dict(os.environ, self.env)
        self.enter.start()
        self.addCleanup(self.enter.stop)

    def open_estimate(self, name="tab1", est=1200, started=1000, **extra):
        notify.set_eta_open(name, {"agent": "claude", "est_seconds": est, "started_at": started,
                                  "desc": "fix login", **extra})

    def test_done_logs_the_actual_duration_and_closes_the_entry(self):
        self.open_estimate()
        notify.eta_bookkeeping(["DONE:tab1"], 1600)
        self.assertEqual(notify.eta_open(), {})
        row = json.loads(notify.eta_log_path().read_text(encoding="utf-8").strip())
        self.assertEqual(row, {"agent": "claude", "est_seconds": 1200, "final_est_seconds": 1200,
                               "revisions": 0, "actual_seconds": 600,
                               "finished_at": 1600, "desc": "fix login"})

    def test_done_logs_the_first_estimate_with_the_final_and_the_revision_count(self):
        self.open_estimate(est=2400, first_est_seconds=1200, updated_at=2500, revisions=2)
        notify.eta_bookkeeping(["DONE:tab1"], 3000)
        row = json.loads(notify.eta_log_path().read_text(encoding="utf-8").strip())
        self.assertEqual(row["est_seconds"], 1200)
        self.assertEqual(row["final_est_seconds"], 2400)
        self.assertEqual(row["revisions"], 2)
        self.assertEqual(row["actual_seconds"], 2000)

    def test_active_mid_turn_keeps_the_open_estimate(self):
        self.open_estimate()
        notify.eta_bookkeeping(["ACTIVE:tab1"], 1600)
        self.assertIn("tab1", notify.eta_open())
        self.assertFalse(notify.eta_log_path().exists())

    def test_active_resends_the_open_countdown(self):
        self.open_estimate()
        extra = notify.eta_bookkeeping(["ACTIVE:tab1"], 1600)
        self.assertEqual(extra, ["ETA:tab1:600:fix login"])

    def test_done_after_bg_keeps_the_job_open_once_and_resends_the_countdown(self):
        self.open_estimate(background=True)
        extra = notify.eta_bookkeeping(["DONE:tab1"], 1600)
        self.assertEqual(extra, ["ETA:tab1:600:fix login"])
        self.assertFalse(notify.eta_open()["tab1"]["background"])
        self.assertFalse(notify.eta_log_path().exists())
        self.assertEqual(notify.eta_bookkeeping(["DONE:tab1"], 1650), [])
        self.assertTrue(notify.eta_open()["tab1"]["carried"])
        self.assertFalse(notify.eta_log_path().exists())
        self.assertEqual(notify.eta_bookkeeping(["ACTIVE:tab1"], 1700), [])
        self.assertEqual(notify.eta_open(), {})

    def test_carried_resend_has_no_fresh_active_or_duplicate_done(self):
        self.open_estimate(name="project-7", est=5400, started=1000, background=True)
        payload = '{"session_id":"s1","cwd":"/repo"}'
        with patch.object(notify, "target", return_value=("project-7", 19548, False)), \
                patch.object(notify, "deliver") as deliver, \
                patch.object(notify.time, "time", return_value=1600), \
                patch.object(sys, "argv", ["notify.py", "claude", "done"]), \
                patch.object(sys, "stdin", io.StringIO(payload)):
            notify.main()
        self.assertEqual(deliver.call_args.args[0], [
            "SESSION:project-7:s1:/repo", "AGENT:project-7:claude",
            "DONE:project-7", "ETA:project-7:4800:fix login",
        ])
        self.assertTrue(notify.eta_open()["project-7"]["carried"])
        with patch.object(notify, "target", return_value=("project-7", 19548, False)), \
                patch.object(notify, "deliver") as deliver, \
                patch.object(sys, "argv", ["notify.py", "claude", "done"]), \
                patch.object(sys, "stdin", io.StringIO(payload)):
            notify.main()
        deliver.assert_not_called()
        with patch.object(notify, "target", return_value=("project-7", 19548, False)), \
                patch.object(notify, "deliver") as deliver, \
                patch.object(sys, "argv", ["notify.py", "claude", "notify"]), \
                patch.object(sys, "stdin", io.StringIO('{"type":"agent-turn-complete"}')):
            notify.main()
        deliver.assert_not_called()
        self.assertTrue(notify.eta_open()["project-7"]["carried"])
        self.assertEqual(notify.eta_bookkeeping(["ACTIVE:project-7"], 1700), [])
        self.assertEqual(notify.eta_open(), {})

    def test_self_resumed_claude_turn_can_complete_after_carried_background_done(self):
        self.open_estimate(background=True)
        payload = '{"session_id":"s1","cwd":"/repo"}'
        with patch.object(notify, "target", return_value=("tab1", 19548, False)), \
                patch.object(notify, "deliver") as deliver:
            with patch.object(sys, "argv", ["notify.py", "claude", "done", payload]):
                notify.main()
            self.assertEqual(notify.lifecycle_state("tab1", "s1"), "done")
            self.assertTrue(notify.eta_entry("tab1")["carried"])
            notify.set_lifecycle("tab1", "s1", "active")
            notify.drop_eta("tab1")
            with patch.object(sys, "argv", ["notify.py", "claude", "done", payload]):
                notify.main()
        self.assertEqual(deliver.call_count, 2)
        self.assertEqual(deliver.call_args.args[0][-1], "DONE:tab1")
        self.assertEqual(notify.lifecycle_state("tab1", "s1"), "done")

    def test_delivered_done_and_active_track_exact_session_for_self_resume(self):
        payload = '{"session_id":"s1","cwd":"/repo"}'
        with patch.object(notify, "target", return_value=("tab1", 19548, False)), \
                patch.object(notify, "deliver") as deliver:
            with patch.object(sys, "argv", ["notify.py", "claude", "done", payload]):
                notify.main()
            self.assertEqual(notify.lifecycle_state("tab1", "s1"), "done")
            self.assertIsNone(notify.lifecycle_state("tab1", "other"))
            with patch.object(sys, "argv", ["notify.py", "claude", "active", payload]):
                notify.main()
            self.assertEqual(notify.lifecycle_state("tab1", "s1"), "active")
        self.assertEqual(deliver.call_count, 2)

    def test_failed_done_delivery_does_not_claim_completion(self):
        with patch.object(notify, "target", return_value=("tab1", 19548, False)), \
                patch.object(notify, "deliver", side_effect=OSError("offline")), \
                patch.object(sys, "argv", ["notify.py", "claude", "done"]), \
                patch.object(sys, "stdin", io.StringIO('{"session_id":"s1"}')):
            with self.assertRaises(OSError):
                notify.main()
        self.assertIsNone(notify.lifecycle_state("tab1", "s1"))

    def test_a_new_prompt_after_a_bg_turn_drops_the_carried_countdown(self):
        self.open_estimate(background=True)
        notify.eta_bookkeeping(["DONE:tab1"], 1600)
        self.assertEqual(notify.eta_bookkeeping(["ACTIVE:tab1"], 1700), [])
        self.assertEqual(notify.eta_open(), {})
        self.assertFalse(notify.eta_log_path().exists())

    def test_an_overdue_background_job_resends_zero_left(self):
        self.open_estimate(background=True)
        self.assertEqual(notify.eta_bookkeeping(["DONE:tab1"], 5000), ["ETA:tab1:0:fix login"])

    def test_done_without_an_entry_writes_nothing(self):
        notify.eta_bookkeeping(["DONE:tab1"], 1600)
        self.assertFalse(notify.eta_log_path().exists())

    def test_a_failed_bookkeeping_step_never_blocks_delivery(self):
        payload = '{"session_id": "s1", "cwd": "/repo"}'
        with patch.object(notify, "target", return_value=("tab1", 19548, True)), \
                patch.object(notify, "deliver") as deliver, \
                patch.object(notify, "finish_eta", side_effect=RuntimeError), \
                patch.object(sys, "argv", ["notify.py", "claude", "done"]), \
                patch.object(sys, "stdin", io.StringIO(payload)):
            notify.main()
        deliver.assert_called_once()

    def test_an_unwritable_state_directory_never_blocks_delivery(self):
        blocked = Path(self.tmp.name) / "blocked"
        blocked.write_text("not a directory", encoding="utf-8")
        with patch.dict(os.environ, {"MULTIPROMPT_STATE_DIR": str(blocked / "state")}), \
                patch.object(notify, "target", return_value=("tab1", 19548, True)), \
                patch.object(notify, "deliver") as deliver, \
                patch.object(sys, "argv", ["notify.py", "claude", "done"]), \
                patch.object(sys, "stdin", io.StringIO('{"session_id": "s1", "cwd": "/repo"}')):
            notify.main()
        deliver.assert_called_once()

    def test_the_log_is_trimmed_when_it_grows_too_large(self):
        with patch.object(notify, "ETA_LOG_MAX", 3), patch.object(notify, "ETA_LOG_KEEP", 2):
            for index in range(4):
                notify.append_eta_log({"agent": "claude", "est_seconds": 10,
                                       "actual_seconds": index, "finished_at": index, "desc": ""})
        lines = notify.eta_log_path().read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(lines), 2)
        self.assertEqual(json.loads(lines[-1])["actual_seconds"], 3)

    def test_stats_read_old_rows_and_rows_with_revisions(self):
        rows = [
            {"agent": "claude", "est_seconds": 100, "actual_seconds": 140,
             "finished_at": 0, "desc": ""},
            {"agent": "claude", "est_seconds": 200, "final_est_seconds": 400,
             "revisions": 1, "actual_seconds": 240, "finished_at": 0, "desc": ""},
            {"agent": "claude", "est_seconds": 100, "final_est_seconds": 300,
             "revisions": 2, "actual_seconds": 140, "finished_at": 0, "desc": ""},
        ]
        notify.eta_log_path().parent.mkdir(parents=True, exist_ok=True)
        notify.eta_log_path().write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
        self.assertEqual(notify.eta_stats(), {"claude": (1.4, 3)})



    def test_lifecycle_state_is_written_for_the_phone(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            with patch.dict(os.environ, {"MULTIPROMPT_STATE_DIR": str(state)}):
                notify.record_tab_states(["AGENT:t1:claude", "ACTIVE:t1"], now=100)
                data = json.loads((state / "tab-state.json").read_text())
                self.assertEqual({"t1": {"state": "active", "at": 100}}, data)

                notify.record_tab_states(["DONE:t1"], now=200)
                data = json.loads((state / "tab-state.json").read_text())
                self.assertEqual({"t1": {"state": "done", "at": 200}}, data)

    def test_stale_state_is_pruned_and_other_events_are_ignored(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp)
            with patch.dict(os.environ, {"MULTIPROMPT_STATE_DIR": str(state)}):
                notify.record_tab_states(["DONE:old"], now=1000)
                later = 1000 + notify.TAB_STATE_STALE + 1
                notify.record_tab_states(["ACTIVE:new"], now=later)
                data = json.loads((state / "tab-state.json").read_text())
                self.assertEqual({"new": {"state": "active", "at": later}}, data)

                before = (state / "tab-state.json").read_text()
                notify.record_tab_states(["SESSION:t1:sid:/repo", "AGENT:t1:claude"], now=later + 10)
                self.assertEqual(before, (state / "tab-state.json").read_text())


if __name__ == "__main__":
    unittest.main()