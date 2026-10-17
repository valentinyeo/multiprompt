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
        self.run = systemctl.start()
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
