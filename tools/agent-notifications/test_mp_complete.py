import base64
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mp_complete", Path(__file__).with_name("mp_complete.py"))
complete = importlib.util.module_from_spec(spec)
spec.loader.exec_module(complete)


class Completion(unittest.TestCase):
    def test_frontmatter_block_scalar_and_hidden_skill(self):
        with tempfile.TemporaryDirectory() as tmp:
            skill = Path(tmp) / "skills/test/SKILL.md"
            skill.parent.mkdir(parents=True)
            skill.write_text("---\nname: test\ndescription: >\n  Two lines\n  of text\nuser-invocable: false\n---\nbody", encoding="utf-8")
            fields, body = complete.frontmatter(skill)
            self.assertEqual(fields["description"], " Two lines of text")
            self.assertEqual(body.strip(), "body")
            self.assertEqual(complete.scan(skill.parent.parent, "", "S", {}), [])
            skill.write_text(skill.read_text(encoding="utf-8").replace("false", "true"), encoding="utf-8")
            self.assertEqual(complete.scan(skill.parent.parent, "", "S", {})[0][3], "Two lines of text")
            self.assertEqual(complete.scan(skill.parent.parent, "", "S", {"test": "off"}), [])
            self.assertTrue(complete.off({"test": False}, "test"))
            self.assertTrue(complete.off({"test": "disabled"}, "test"))

    def test_pi_models_come_from_pi_own_list(self):
        table = ("provider      model                                  context  max-out  thinking  images\n"
                 "baseten       deepseek-ai/DeepSeek-V4-Pro-0813           1.0M     262.1K   yes       no    \n"
                 "openai-codex  gpt-5.6-sol                              272K     128K     yes       yes   \n")
        complete.PI_MODELS_CACHE["rows"] = None
        finished = type("Finished", (), {"stdout": table})()
        with patch.object(complete.subprocess, "run", return_value=finished):
            status, rows = complete.pi_model_rows()
        self.assertEqual("ok", status)
        self.assertEqual(("M", "deepseek-ai/DeepSeek-V4-Pro-0813", "baseten", "1.0M"), rows[0])
        self.assertEqual("gpt-5.6-sol", rows[1][1])
        result = complete.request("9\tmodels\tpi\t-\t-\t\n")
        self.assertIn("@mp\t9\tmodels\tok\t", result)
        self.assertIn("M\tgpt-5.6-sol\topenai-codex\t272K", result)
        self.assertIn("M\tdeepseek-ai/DeepSeek-V4-Pro-0813\tbaseten\t1.0M", result)
        self.assertIn("@@MP_END@@", result)
        with patch.object(complete.subprocess, "run", side_effect=OSError("no pi")):
            complete.PI_MODELS_CACHE["rows"] = None
            self.assertEqual(("error", []), complete.pi_model_rows())

    def test_validation_and_framing(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)):
            with patch.object(complete, "claude_rows", return_value=("ok", [("B", "copy", "", "Copy\tlast\nreply")])):
                request = f"17\tslash\tclaude\t-\t{tmp}\tco\n"
                result = complete.request(request)
                self.assertIn("@mp\t17\tslash\tok\t", result)
                self.assertIn("B\tcopy\t\tCopy last reply\n@@MP_END@@\n", result)
                self.assertEqual(result, complete.request(base64.b64decode(base64.b64encode(request.encode())).decode()))
            for bad in ("x\tslash\tclaude\t-\t-\t\n", "1\tslash\tclaude\tbad;name\t-\t\n",
                        "1\tslash\tclaude\t-\trelative\t\n", "1\tslash\tclaude\t-\t-\tab\tcd\n",
                        "1\tslash\tclaude\t-\t-\t" + "x" * 201 + "\n"):
                self.assertIn("\terror\t-\t0\n@@MP_END@@", complete.request(bad))

    def test_chat_folder_skills_survive_a_different_tmux_cwd(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)):
            home = Path(tmp)
            cwd = home / "projects/app"
            definitions = {
                home / ".claude/skills/user-skill/SKILL.md": "User skill",
                cwd / ".claude/skills/verify-multiprompt/SKILL.md": "Verify the app",
                cwd / ".claude/commands/check/folder.md": "Check the folder",
                home / "plugin/skills/plugin-skill/SKILL.md": "Plugin skill",
            }
            for path, description in definitions.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"---\ndescription: {description}\n---\n", encoding="utf-8")
            plugins = home / ".claude/plugins/installed_plugins.json"
            plugins.parent.mkdir(parents=True)
            plugins.write_text(json.dumps({"plugins": {"test@market": [{"installPath": str(home / "plugin")}]}}), encoding="utf-8")
            (home / ".claude/settings.json").write_text(json.dumps({"enabledPlugins": {"test@market": True}}), encoding="utf-8")
            with patch.object(complete.subprocess, "run") as run, \
                    patch.object(complete, "warm_async"), patch.object(complete, "CACHE", home / "empty-cache.json"):
                run.return_value.stdout = str(home) + "\n"
                request = f"17\tslash\tclaude\tchat-session\t{cwd}\tverify-mul\n"
                legacy = dict(complete.__dict__)
                fixture = Path(__file__).parents[1] / "fixtures/SOFT-3102/resolve_cwd.py"
                exec(fixture.read_text(encoding="utf-8"), legacy)
                with patch.object(complete, "resolve_cwd", legacy["resolve_cwd"]):
                    self.assertNotIn("J\tverify-multiprompt\t", complete.request(request))
                response = complete.request(request)
            self.assertIn(f"\t{cwd}\t", response)
            for row in ("S\tuser-skill\t", "J\tverify-multiprompt\t", "J\tcheck:folder\t", "P\ttest:plugin-skill\t"):
                self.assertIn(row, response)

    def test_project_scan_cache_refreshes_edits_additions_and_removals(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)):
            home = Path(tmp)
            cwd = home / "app"
            skill = cwd / ".claude/skills/verify-app/SKILL.md"
            skill.parent.mkdir(parents=True)
            skill.write_text("---\ndescription: Before\n---\n", encoding="utf-8")
            other = home / "other"
            other.mkdir()
            first = complete.project_and_plugins(cwd, {})
            self.assertIn(("J", "verify-app", "", "Before"), first)
            with patch.object(complete, "frontmatter", side_effect=AssertionError("unchanged skills must not be reread")):
                self.assertEqual(first, complete.project_and_plugins(cwd, {}))
            self.assertNotIn("verify-app", [r[1] for r in complete.project_and_plugins(other, {})])
            skill.write_text("---\ndescription: After editing\n---\n", encoding="utf-8")
            self.assertIn(("J", "verify-app", "", "After editing"), complete.project_and_plugins(cwd, {}))
            command = cwd / ".claude/commands/check/nested.md"
            command.parent.mkdir(parents=True)
            command.write_text("Run the check", encoding="utf-8")
            self.assertIn("check:nested", [r[1] for r in complete.project_and_plugins(cwd, {})])
            command.write_text("An edited command", encoding="utf-8")
            self.assertIn(("J", "check:nested", "", "An edited command"), complete.project_and_plugins(cwd, {}))
            second = command.with_name("another.md")
            second.write_text("Another command", encoding="utf-8")
            self.assertIn("check:another", [r[1] for r in complete.project_and_plugins(cwd, {})])
            added = cwd / ".claude/skills/verify-new/SKILL.md"
            added.parent.mkdir()
            added.write_text("New skill", encoding="utf-8")
            self.assertIn("verify-new", [r[1] for r in complete.project_and_plugins(cwd, {})])
            self.assertNotIn("verify-new", [r[1] for r in complete.project_and_plugins(cwd, {"skillOverrides": {"verify-new": "off"}})])
            skill.unlink()
            command.unlink()
            names = [r[1] for r in complete.project_and_plugins(cwd, {})]
            self.assertNotIn("verify-app", names)
            self.assertNotIn("check:nested", names)

    def test_persistent_server_keeps_folder_catalogs_separate_and_fresh(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)), \
                patch.object(complete, "CACHE", Path(tmp) / "empty-cache.json"), patch.object(complete, "warm_async"):
            home = Path(tmp)
            first = home / "first"
            second = home / "second"
            for cwd, name in ((first, "verify-first"), (second, "verify-second")):
                skill = cwd / f".claude/skills/{name}/SKILL.md"
                skill.parent.mkdir(parents=True)
                skill.write_text("Verify this folder", encoding="utf-8")

            def requests():
                yield f"1\tslash\tclaude\t-\t{first}\t\n"
                skill = first / ".claude/skills/verify-new/SKILL.md"
                skill.parent.mkdir()
                skill.write_text("Added while serving", encoding="utf-8")
                yield f"2\tslash\tclaude\t-\t{first}\t\n"
                yield f"3\tslash\tclaude\t-\t{second}\t\n"

            output = io.StringIO()
            with patch.object(complete.sys, "argv", ["mp_complete.py", "--serve"]), \
                    patch.object(complete.sys, "stdin", requests()), patch.object(complete.sys, "stdout", output):
                complete.main()
            frames = output.getvalue().split(complete.END)
            self.assertIn("J\tverify-first\t", frames[0])
            self.assertNotIn("J\tverify-new\t", frames[0])
            self.assertIn("J\tverify-new\t", frames[1])
            self.assertIn("J\tverify-second\t", frames[2])
            self.assertNotIn("J\tverify-first\t", frames[2])
            self.assertNotIn("J\tverify-new\t", frames[2])
            once = io.StringIO()
            encoded = base64.b64encode(f"4\tslash\tclaude\t-\t{second}\t\n".encode()).decode()
            with patch.object(complete.sys, "argv", ["mp_complete.py", "--once", encoded]), \
                    patch.object(complete.sys, "stdout", once):
                complete.main()
            self.assertEqual(frames[2].lstrip("\n").replace("@mp\t3\t", "@mp\t4\t") + complete.END + "\n", once.getvalue())

    def test_missing_claude_cwd_uses_tmux_then_home(self):
        with tempfile.TemporaryDirectory() as tmp, tempfile.TemporaryDirectory() as other, \
                patch.object(complete, "HOME", Path(tmp)):
            missing = Path(tmp) / "removed"
            with patch.object(complete.subprocess, "run") as run:
                run.return_value.stdout = other + "\n"
                self.assertEqual(complete.resolve_cwd("session", str(missing)), Path(other))
                run.return_value.stdout = str(missing) + "\n"
                self.assertEqual(complete.resolve_cwd("session", str(missing)), Path(tmp))
            with patch.object(complete, "claude_rows", return_value=("ok", [])):
                self.assertIn("\tok\t" + tmp + "\t0", complete.request(
                    f"17\tslash\tclaude\t-\t{missing}\t\n"))

    @unittest.skipIf(os.name == "nt", "VPS-only")
    def test_codex_reads_lines_already_received_in_one_chunk(self):
        read_fd, write_fd = os.pipe()
        try:
            os.write(write_fd, b'{"id":1,"result":{}}\n{"id":2,"result":{"skills":[]}}\n')
            with os.fdopen(read_fd, "rb", closefd=False) as output, \
                    patch.object(complete, "SERVER", type("Server", (), {"stdout": output})()), \
                    patch.object(complete, "SERVER_BUFFER", b""):
                self.assertEqual(complete.wait_codex(1)["id"], 1)
                with patch.object(complete.select, "select", side_effect=AssertionError("buffer should be read first")):
                    self.assertEqual(complete.wait_codex(2)["id"], 2)
        finally:
            os.close(read_fd)
            os.close(write_fd)

    def test_sdk_slashes_are_stripped_and_hidden_entries_stay_hidden(self):
        fake_cache = {"key": ["same"], "at": 99999999999, "commands": [
            {"name": "/compact", "description": "Summarize"},
            {"name": "/__remote-workflow", "description": "Hidden"}]}
        with patch.object(complete, "cache_key", return_value=["same"]), \
                patch.object(complete, "read_json", return_value=fake_cache), \
                patch.object(complete, "project_and_plugins", return_value=[]):
            status, rows = complete.claude_rows(Path("/tmp"))
        self.assertEqual(status, "ok")
        self.assertIn(("B", "compact", "", "Summarize"), rows)
        self.assertNotIn("__remote-workflow", [r[1] for r in rows])

    def test_probe_parsing_and_cache_key(self):
        fake = '\n'.join((json.dumps({"type": "system", "subtype": "hook"}),
                          json.dumps({"type": "control_response", "response": {"response": {"commands": [
                              {"name": "compact", "description": "Summarize", "argumentHint": "[hint]"}]}}})))
        with patch.object(complete.subprocess, "run") as run:
            run.return_value.stdout = fake
            self.assertEqual(complete.probe_claude()[0]["name"], "compact")
            self.assertNotIn("TMUX", run.call_args.kwargs["env"])
            self.assertEqual(run.call_args.kwargs["env"]["MP_COMPLETE_PROBE"], "1")

    def test_seed_counts_and_scratch_harvest_guard(self):
        self.assertEqual(len(complete.seeds("claude_interactive_builtins.tsv")), 57)
        self.assertEqual(len(complete.seeds("codex_slash.txt")), 49)
        self.assertEqual(complete.seeds("codex_slash.txt")[0][0], "model")
        self.assertIn("choose", complete.seeds("codex_slash.txt")[0][2])
        with patch.object(complete.sys, "argv", ["mp_complete.py", "--harvest", "live-session", "claude"]):
            with self.assertRaises(SystemExit):
                complete.main()

    def test_cross_owner_chat_errors_when_delegate_fails(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)):
            with patch.object(complete, "owner_for_cwd", return_value="inne"), \
                    patch.object(complete, "owner_response", return_value=None):
                result = complete.request("11\tslash\tclaude\t-\t/home/inne/projects/app\t\n")
            self.assertIn("@mp\t11\tslash\terror\t", result)
            self.assertNotIn("@@MP_END@@\n", result.split("\n")[1:2])

    def test_only_current_enabled_plugin_is_scanned(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)):
            home = Path(tmp)
            plugins = home / ".claude/plugins"
            plugins.mkdir(parents=True)
            old = plugins / "cache/old/skills/obsolete/SKILL.md"
            new = plugins / "cache/new/skills/current/SKILL.md"
            disabled = plugins / "cache/disabled/skills/bad/SKILL.md"
            for item in (old, new, disabled):
                item.parent.mkdir(parents=True)
                item.write_text("---\ndescription: test\n---\n", encoding="utf-8")
            (plugins / "installed_plugins.json").write_text(json.dumps({"plugins": {
                "hello@market": [{"installPath": str(old.parents[2])}, {"installPath": str(new.parents[2])}],
                "no@market": [{"installPath": str(disabled.parents[2])}]}}), encoding="utf-8")
            settings = {"enabledPlugins": {"hello@market": True, "no@market": False}}
            rows = complete.project_and_plugins(home, settings)
            self.assertEqual([r[1] for r in rows], ["hello:current"])
            settings["skillOverrides"] = {"hello:current": "off"}
            self.assertEqual(complete.project_and_plugins(home, settings), [])


if __name__ == "__main__":
    unittest.main()
