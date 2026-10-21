import contextlib
import importlib.util
import io
import json
import os
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("zigshell_install", Path(__file__).with_name("install.py"))
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


def load_eta_hook():
    spec = importlib.util.spec_from_file_location("zigshell_eta_hook", Path(__file__).with_name("eta_hook.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Installation(unittest.TestCase):
    def setUp(self):
        systemctl = patch.object(installer.subprocess, "run")
        self.real_run = subprocess.run
        self.run = systemctl.start()
        self.run.return_value.returncode = 0
        self.addCleanup(systemctl.stop)

    def test_merge_preserves_other_handlers_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            p = Path(tmp) / "settings.json"
            p.write_text(json.dumps({"other": "keep", "hooks": {"Stop": [{"matcher": "", "hooks": [
                {"type": "command", "command": "unrelated-hook"},
                {"type": "command", "command": "bash ~/.claude/hooks/zigshell-done.sh"},
            ]}]}}), encoding="utf-8")
            command = 'python3 /home/test/.local/share/zigshell/notify.py claude done'
            installer.merge_hooks(p, {"Stop": command})
            first = p.read_text(encoding="utf-8")
            installer.merge_hooks(p, {"Stop": command})
            self.assertEqual(first, p.read_text(encoding="utf-8"))
            data = json.loads(first)
            commands = [h["command"] for g in data["hooks"]["Stop"] for h in g["hooks"]]
            self.assertEqual(commands, ["unrelated-hook", command])
            self.assertEqual(data["other"], "keep")
            self.assertEqual(len(list(Path(tmp).glob("*.pre-zigshell-*"))), 1)

    def test_cursor_merge_keeps_unrelated_events(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            p = Path(tmp) / "hooks.json"
            p.write_text(json.dumps({"version": 1, "hooks": {"afterFileEdit": [{"command": "format"}]}}), encoding="utf-8")
            installer.merge_hooks(p, {"stop": "python3 /x/zigshell/notify.py cursor done"}, cursor=True)
            self.assertEqual(json.loads(p.read_text(encoding="utf-8"))["hooks"]["afterFileEdit"], [{"command": "format"}])

    @unittest.skipIf(os.name == "nt", "tmux hooks are installed on Linux")
    def test_tmux_hooks_persist_and_migrate_without_replacing_other_config(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            config = home / ".tmux.conf"
            config.write_text("set -g history-limit 5000", encoding="utf-8")
            legacy = home / ".local/bin/zigshell-watcher.sh"
            legacy.parent.mkdir(parents=True)
            legacy.write_text("old watcher", encoding="utf-8")
            service = home / ".config/systemd/user/zigshell-watcher.service"
            service.parent.mkdir(parents=True)
            service.write_text("old service", encoding="utf-8")
            dest = home / ".local/share/zigshell"
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", dest):
                installer.install_tmux_hooks()
                first = config.read_text(encoding="utf-8")
                snippet = (dest / "tmux-notifications.conf").read_text(encoding="utf-8")
                installer.install_tmux_hooks()
            self.assertEqual(first, config.read_text(encoding="utf-8"))
            self.assertTrue(first.startswith("set -g history-limit 5000\nsource-file -q "))
            self.assertEqual(first.count("source-file"), 1)
            self.assertFalse(legacy.exists())
            self.assertFalse(service.exists())
            self.assertEqual(len(list(legacy.parent.glob("*.pre-zigshell-*"))), 1)
            self.assertEqual(len(list(service.parent.glob("*.pre-zigshell-*"))), 1)
            self.assertTrue((dest / "tmux_notify.py").exists())
            self.assertEqual(snippet, (dest / "tmux-notifications.conf").read_text(encoding="utf-8"))
            calls = [call.args[0] for call in self.run.call_args_list]
            self.assertIn(["systemctl", "--user", "disable", "--now", "zigshell-watcher.service"], calls)
            self.assertIn(["tmux", "source-file", str(dest / "tmux-notifications.conf")], calls)
            self.assertFalse(any("restart" in call and "zigshell-watcher" in " ".join(call) for call in calls))

    def test_tmux_hook_commands_cover_events_debounce_and_native_throttling(self):
        config = installer.tmux_config(Path("/tmp/mp-notify-test/tmux-events"))
        for option in ("-g monitor-activity on", "-gw monitor-silence 10", "-g activity-action any", "-g silence-action any"):
            self.assertIn("set-option " + option, config)
        for event in ("alert-activity", "alert-silence", "pane-title-changed", "session-created", "client-attached"):
            self.assertEqual(config.count("set-hook -g " + event + "[514]"), 1)
        for delay in (3, 15):
            self.assertIn(f'run-shell -bCd {delay} "set-environment -h -t #{{session_id}} MULTIPROMPT_NOTIFY_READY 1;', config)
        self.assertIn("set-environment -gh MULTIPROMPT_NOTIFY_STATE 0", config)
        self.assertIn("set-environment -gh MULTIPROMPT_NOTIFY_READY 1", config)
        self.assertIn("if-shell -F '#{MULTIPROMPT_NOTIFY_READY}' { if-shell -F '#{window_active}'", config)
        self.assertIn("set-environment -h MULTIPROMPT_NOTIFY_READY 0", config)
        for state in (0, 1, 2):
            self.assertIn(f"set-environment -h MULTIPROMPT_NOTIFY_STATE {state}", config)
        self.assertNotIn("capture-pane", config)
        self.assertNotIn("pgrep", config)
        self.assertNotIn("python", config)
        self.assertIn("#{q:session_name}", config)
        self.assertIn("#{pane_id}'' #{q:socket_path}''", config)

    def test_tmux_hooks_do_not_redraw_attached_status_bars(self):
        config = installer.tmux_config(Path("/tmp/mp-notify-test/tmux-events"))
        hooks = "\n".join(line for line in config.splitlines() if line.startswith("set-hook "))
        self.assertNotIn("set-option", hooks)
        self.assertNotIn("set-hook", hooks.replace("set-hook -g ", ""))
        for option in ("visual-activity", "visual-silence"):
            self.assertIn(f"set-option -g {option} off", config)
        self.assertIn("if-shell -F '#{==:#{session_attached},0}' { kill-session -C }", hooks)
        for delay in (3, 15):
            rearm = json.JSONDecoder().raw_decode(config.split(f"run-shell -bCd {delay} ", 1)[1])[0]
            self.assertIn("set-environment -h -t #{session_id} MULTIPROMPT_NOTIFY_READY 1", rearm)
            self.assertIn("if-shell -F -t #{session_id}: '##{==:##{session_attached},0}' { kill-session -C -t #{session_id} }", rearm)
            self.assertNotIn("set-option", rearm)
            self.assertNotIn("tmux -S", rearm)
        self.assertEqual(hooks.count("kill-session -C"), 3)

    @unittest.skipIf(os.name == "nt", "tmux hooks are installed on Linux")
    def test_no_running_tmux_still_saves_persistent_hooks(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            self.run.side_effect = FileNotFoundError("no server tools")
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", home / ".local/share/zigshell"):
                installer.install_tmux_hooks()
            self.assertIn("source-file -q", (home / ".tmux.conf").read_text(encoding="utf-8"))
            self.assertTrue((home / ".local/share/zigshell/tmux-notifications.conf").exists())

    @unittest.skipIf(os.name == "nt", "tmux hooks are installed on Linux")
    def test_failed_legacy_service_stop_preserves_the_unit_and_script(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            unit = home / ".config/systemd/user/zigshell-watcher.service"
            unit.parent.mkdir(parents=True)
            unit.write_text("old unit", encoding="utf-8")
            self.run.return_value.returncode = 1
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", home / ".local/share/zigshell"):
                with self.assertRaises(RuntimeError):
                    installer.install_tmux_hooks()
            self.assertEqual(unit.read_text(encoding="utf-8"), "old unit")

    @unittest.skipIf(os.name == "nt", "FIFO enqueue runs on Linux")
    def test_hook_enqueue_is_atomic_quoted_and_safe_without_a_reader(self):
        import shlex

        with tempfile.TemporaryDirectory() as tmp:
            fifo = Path(tmp) / "events"
            config = installer.tmux_config(fifo)
            command = json.JSONDecoder().raw_decode(config.split("run-shell -b ", 1)[1])[0]
            session = "tab $HOME `false`"
            command = command.replace("#{q:session_name}", shlex.quote(session))
            command = command.replace("#{q:pane_current_command}", "bash")
            command = command.replace("#{pane_pid}", "123")
            command = command.replace("#{pane_id}", "%4")
            command = command.replace("#{q:socket_path}", shlex.quote("/tmp/socket with spaces"))
            self.real_run(["/bin/sh", "-c", command], check=True, timeout=2)
            self.assertFalse(fifo.exists())
            os.mkfifo(fifo, 0o600)
            fd = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
            try:
                self.real_run(["/bin/sh", "-c", command], check=True, timeout=2)
                self.assertEqual(os.read(fd, 4096).split(b"\0"), [
                    b"activity", session.encode(), b"bash", b"123", b"%4", b"/tmp/socket with spaces", b"",
                ])
            finally:
                os.close(fd)
            self.real_run(["/bin/sh", "-c", command], check=True, timeout=2)

    def eta_commands(self, settings):
        return [h["command"] for groups in settings["hooks"].values() for group in groups for h in group["hooks"]]

    def test_with_eta_installs_the_tool_and_registers_both_hooks(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            (home / ".claude").mkdir()
            dest = home / ".local/share/zigshell"
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", dest):
                installer.install(with_eta=True)
                for filename in ("mp_complete.py", "claude_interactive_builtins.tsv", "codex_slash.txt", "harvest_tui.sh"):
                    self.assertTrue((dest / filename).exists())
                settings = json.loads((home / ".claude/settings.json").read_text(encoding="utf-8"))
                commands = self.eta_commands(settings)
                self.assertTrue(any('eta_hook.py" prompt' in c for c in commands))
                self.assertTrue(any('eta_hook.py" pretool' in c for c in commands))
                self.assertTrue(any('eta_hook.py" posttool' in c for c in commands))
                self.assertTrue(any('notify.py" claude active' in c for c in commands))
                self.assertTrue(any('notify.py" claude notify' in c for c in commands))
                self.assertIn("Notification", settings["hooks"])
                wrapper = home / (".local/bin/mp-eta.cmd" if os.name == "nt" else ".local/bin/mp-eta")
                self.assertTrue(wrapper.exists())
                self.assertTrue((dest / "mp_eta.py").exists())
                self.assertTrue((dest / "eta_hook.py").exists())
                if os.name != "nt":
                    self.assertTrue((dest / "mp_notify_relay.py").exists())
                    unit = (home / ".config/systemd/user/mp-notify-relay.service").read_text()
                    self.assertIn("RestartPreventExitStatus=78", unit)
                    self.assertEqual((home / ".local/state/multiprompt/relay-v1").read_text(), "1\n")
                    self.assertIn((["systemctl", "--user", "enable", "--now", "mp-notify-relay.service"],),
                                  [call.args for call in self.run.call_args_list])
                before = (home / ".claude/settings.json").read_text(encoding="utf-8")
                installer.install(with_eta=True)
                self.assertEqual(before, (home / ".claude/settings.json").read_text(encoding="utf-8"))
                installer.install()
                after = json.loads((home / ".claude/settings.json").read_text(encoding="utf-8"))
                self.assertTrue(any('eta_hook.py" pretool' in c for c in self.eta_commands(after)))
                self.assertTrue(any('eta_hook.py" posttool' in c for c in self.eta_commands(after)))

    @unittest.skipIf(os.name == "nt", "relay service is Linux-only")
    def test_failed_service_does_not_advertise_relay(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            self.run.side_effect = subprocess.CalledProcessError(1, "systemctl")
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", home / ".local/share/zigshell"):
                installer.install()
            self.assertFalse((home / ".local/state/multiprompt/relay-v1").exists())
            self.assertTrue((home / ".config/systemd/user/mp-notify-relay.service").exists())

    def test_plain_install_leaves_no_eta_files_behind(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            (home / ".claude").mkdir()
            dest = home / ".local/share/zigshell"
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", dest):
                installer.install()
                settings = json.loads((home / ".claude/settings.json").read_text(encoding="utf-8"))
                self.assertFalse(any("eta_hook.py" in c for c in self.eta_commands(settings)))
                self.assertFalse((dest / "mp_eta.py").exists())
                self.assertFalse((dest / "eta_hook.py").exists())


    def eta_hax_note(self, home):
        return (home / ".config/hax/zigshell-eta.md").read_text(encoding="utf-8")

    def test_with_eta_registers_codex_hooks_and_a_hax_note(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            (home / ".claude").mkdir()
            (home / ".codex").mkdir()
            (home / ".config/hax").mkdir(parents=True)
            (home / ".config/hax/config.json").write_text(json.dumps({"presets": {"keep": {"model": "m"}}}), encoding="utf-8")
            dest = home / ".local/share/zigshell"
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", dest), \
                    patch.dict(os.environ, {"XDG_CONFIG_HOME": ""}):
                installer.install(with_eta=True)
                hooks = json.loads((home / ".codex/hooks.json").read_text(encoding="utf-8"))["hooks"]
                codex_commands = [h["command"] for groups in hooks.values() for group in groups for h in group["hooks"]]
                self.assertTrue(any('eta_hook.py" prompt' in c for c in codex_commands))
                self.assertTrue(any('eta_hook.py" pretool' in c for c in codex_commands))
                self.assertTrue(any('eta_hook.py" posttool' in c for c in codex_commands))
                self.assertTrue(any('notify.py" codex active' in c for c in codex_commands))

                hax = json.loads((home / ".config/hax/config.json").read_text(encoding="utf-8"))
                self.assertEqual(hax["system_prompt_append"], "@zigshell-eta.md")
                self.assertEqual(hax["presets"], {"keep": {"model": "m"}})
                self.assertIn("mp-eta", self.eta_hax_note(home))

                before = (home / ".config/hax/config.json").read_text(encoding="utf-8")
                installer.install(with_eta=True)
                self.assertEqual(before, (home / ".config/hax/config.json").read_text(encoding="utf-8"))

    def test_hax_note_keeps_an_existing_append(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            (home / ".config/hax").mkdir(parents=True)
            (home / ".config/hax/config.json").write_text(
                json.dumps({"system_prompt_append": "@prompts/review.md"}), encoding="utf-8"
            )
            dest = home / ".local/share/zigshell"
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", dest), \
                    patch.dict(os.environ, {"XDG_CONFIG_HOME": ""}):
                installer.install(with_eta=True)
                hax = json.loads((home / ".config/hax/config.json").read_text(encoding="utf-8"))
                self.assertEqual(hax["system_prompt_append"], "@prompts/review.md\n@zigshell-eta.md")

    def test_plain_install_touches_no_hax_config(self):
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stdout(io.StringIO()):
            home = Path(tmp)
            (home / ".config/hax").mkdir(parents=True)
            (home / ".config/hax/config.json").write_text(json.dumps({"presets": {}}), encoding="utf-8")
            dest = home / ".local/share/zigshell"
            before = (home / ".config/hax/config.json").read_text(encoding="utf-8")
            with patch.object(installer, "HOME", home), patch.object(installer, "DEST", dest), \
                    patch.dict(os.environ, {"XDG_CONFIG_HOME": ""}):
                installer.install()
            self.assertEqual(before, (home / ".config/hax/config.json").read_text(encoding="utf-8"))
            self.assertFalse((home / ".config/hax/zigshell-eta.md").exists())

    def test_hax_note_matches_the_hook_instruction(self):
        eta = load_eta_hook()
        self.assertEqual(installer.HAX_ETA_NOTE.strip(), eta.PROMPT_CONTEXT.strip())


if __name__ == "__main__":
    unittest.main()
