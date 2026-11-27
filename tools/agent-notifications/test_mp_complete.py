import base64
import importlib.util
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

    def test_folder_skills_use_a_mtime_cache(self):
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as repo:
            with patch.object(complete, "HOME", Path(home)):
                project = Path(repo)
                skill = project / ".claude/skills/verify-multiprompt/SKILL.md"
                skill.parent.mkdir(parents=True)
                skill.write_text("---\nname: verify-multiprompt\ndescription: check\n---\n", encoding="utf-8")
                complete.PROJECT_SCAN_CACHE.clear()
                rows = complete.project_and_plugins(project, {})
                self.assertIn("verify-multiprompt", [row[1] for row in rows])
                self.assertIn(str(project), complete.PROJECT_SCAN_CACHE)

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

    def test_antigravity_returns_skills_workspace_and_builtins(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)):
            home = Path(tmp)
            project = home / "projects/demo/sub"
            project.mkdir(parents=True)
            entries = {
                home / ".gemini/antigravity-cli/skills/valentin-mode/SKILL.md":
                    "---\nname: valentin-mode\ndescription: Load standing rules\ndisable-model-invocation: true\n---\n",
                home / ".agents/skills/poteto-mode/SKILL.md":
                    "---\nname: poteto-mode\ndescription: Pstack driver\ndisable-model-invocation: true\n---\n",
                home / ".agents/skills/architect/SKILL.md":
                    "---\nname: architect\ndescription: Shape the fix\n---\n",
                home / ".gemini/config/skills/config-skill/SKILL.md":
                    "---\nname: config-skill\ndescription: From config\n---\n",
                home / ".gemini/skills/gemini-skill/SKILL.md":
                    "---\nname: gemini-skill\ndescription: From gemini\n---\n",
                home / ".agents/skills/hidden-skill/SKILL.md":
                    "---\nname: hidden-skill\ndescription: Hidden\nuser-invocable: false\n---\n",
                home / "projects/demo/.agents/skills/repo-agent-skill/SKILL.md":
                    "---\nname: repo-agent-skill\ndescription: Repo agent skill\n---\n",
                home / "projects/demo/.agent/skills/repo-dotagent-skill/SKILL.md":
                    "---\nname: repo-dotagent-skill\ndescription: Repo dotagent skill\n---\n",
                home / "projects/demo/.claude/skills/repo-claude-skill/SKILL.md":
                    "---\nname: repo-claude-skill\ndescription: Repo claude skill\n---\n",
                home / "projects/demo/.claude/commands/ship.md":
                    "---\ndescription: Ship command\n---\n",
            }
            for path, content in entries.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            response = complete.request(f"23\tslash\tantigravity\t-\t{project}\t\n")
            lines = response.splitlines()
            self.assertTrue(lines[0].startswith("@mp\t23\tslash\tok\t"))
            self.assertEqual(lines[-1], "@@MP_END@@")
            parsed = {parts[1]: (parts[0], parts[3]) for parts in (line.split("\t") for line in lines[1:-1])}
            self.assertEqual(parsed["valentin-mode"], ("S", "Load standing rules"))
            self.assertEqual(parsed["poteto-mode"], ("S", "Pstack driver"))
            self.assertEqual(parsed["architect"], ("S", "Shape the fix"))
            self.assertEqual(parsed["config-skill"], ("S", "From config"))
            self.assertEqual(parsed["gemini-skill"], ("S", "From gemini"))
            self.assertEqual(parsed["repo-agent-skill"], ("J", "Repo agent skill"))
            self.assertEqual(parsed["repo-dotagent-skill"], ("J", "Repo dotagent skill"))
            self.assertEqual(parsed["repo-claude-skill"], ("J", "Repo claude skill"))
            self.assertEqual(parsed["ship"], ("J", "Ship command"))
            self.assertNotIn("hidden-skill", parsed)
            for builtin in ("compact", "plan", "goal", "schedule", "browser", "grill-me", "teamwork", "learn", "boost"):
                self.assertEqual(parsed[builtin][0], "B")
                self.assertTrue(parsed[builtin][1])

    def test_pi_returns_skills_prompts_workspace_and_builtins(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(complete, "HOME", Path(tmp)):
            home = Path(tmp)
            project = home / "projects/demo/sub"
            project.mkdir(parents=True)
            entries = {
                home / ".pi/agent/skills/valentin-mode/SKILL.md":
                    "---\nname: valentin-mode\ndescription: Load standing rules\ndisable-model-invocation: true\n---\n",
                home / ".agents/skills/poteto-mode/SKILL.md":
                    "---\nname: poteto-mode\ndescription: Pstack driver\ndisable-model-invocation: true\n---\n",
                home / ".agents/skills/architect/SKILL.md":
                    "---\nname: architect\ndescription: Shape the fix\n---\n",
                home / ".pi/agent/prompts/review.md":
                    "---\ndescription: Review patch\n---\n",
                home / ".agents/skills/hidden-skill/SKILL.md":
                    "---\nname: hidden-skill\ndescription: Hidden\nuser-invocable: false\n---\n",
                home / "projects/demo/.pi/skills/repo-pi-skill/SKILL.md":
                    "---\nname: repo-pi-skill\ndescription: Repo pi skill\n---\n",
                home / "projects/demo/.pi/prompts/repo-prompt.md":
                    "---\ndescription: Repo pi prompt\n---\n",
                home / "projects/demo/.agents/skills/repo-agent-skill/SKILL.md":
                    "---\nname: repo-agent-skill\ndescription: Repo agent skill\n---\n",
                home / "projects/demo/.claude/skills/repo-claude-skill/SKILL.md":
                    "---\nname: repo-claude-skill\ndescription: Repo claude skill\n---\n",
                home / "projects/demo/.claude/commands/ship.md":
                    "---\ndescription: Ship command\n---\n",
            }
            for path, content in entries.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
            response = complete.request(f"24\tslash\tpi\t-\t{project}\t\n")
            lines = response.splitlines()
            self.assertTrue(lines[0].startswith("@mp\t24\tslash\tok\t"))
            self.assertEqual(lines[-1], "@@MP_END@@")
            parsed = {parts[1]: (parts[0], parts[3]) for parts in (line.split("\t") for line in lines[1:-1])}
            self.assertEqual(parsed["valentin-mode"], ("S", "Load standing rules"))
            self.assertEqual(parsed["poteto-mode"], ("S", "Pstack driver"))
            self.assertEqual(parsed["architect"], ("S", "Shape the fix"))
            self.assertEqual(parsed["review"], ("C", "Review patch"))
            self.assertEqual(parsed["repo-pi-skill"], ("J", "Repo pi skill"))
            self.assertEqual(parsed["repo-prompt"], ("J", "Repo pi prompt"))
            self.assertEqual(parsed["repo-agent-skill"], ("J", "Repo agent skill"))
            self.assertEqual(parsed["repo-claude-skill"], ("J", "Repo claude skill"))
            self.assertEqual(parsed["ship"], ("J", "Ship command"))
            self.assertNotIn("hidden-skill", parsed)
            for builtin in ("model", "login", "logout", "compact", "new", "thinking", "reload", "name", "session"):
                self.assertEqual(parsed[builtin][0], "B")
                self.assertTrue(parsed[builtin][1])
            skills_only = complete.request(f"25\tskills\tpi\t-\t{project}\t\n")
            self.assertIn("@mp\t25\tskills\tok\t", skills_only)
            self.assertIn("\t0\n@@MP_END@@\n", skills_only)


if __name__ == "__main__":
    unittest.main()
