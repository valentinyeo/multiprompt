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
