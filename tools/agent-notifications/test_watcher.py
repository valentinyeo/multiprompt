import os
from pathlib import Path
import subprocess
import unittest


@unittest.skipIf(os.name == "nt", "Bash watcher runs on the VPS hosts")
class Watcher(unittest.TestCase):
    def classify(self, args):
        source = Path(__file__).with_name("zigshell-watcher.sh").read_text(encoding="utf-8")
        fn = source.split("agent_from_argv() {", 1)[1].split("\n}\n", 1)[0]
        command = 'agent_from_argv() {' + fn + '\n}\nagent_from_argv "$@"'
        result = subprocess.run(["bash", "-c", command, "test", *args], capture_output=True, text=True, encoding="utf-8", check=True)
        return result.stdout.strip()

    def test_cursor_node_flag_does_not_hide_script(self):
        self.assertEqual(self.classify(["/home/test/.local/bin/agent", "--use-system-ca", "/home/test/.local/share/cursor-agent/versions/v1/index.js"]), "cursor")

    def test_agent_name_in_prompt_does_not_classify_ordinary_node(self):
        self.assertEqual(self.classify(["/usr/bin/node", "/tmp/ordinary.js", "/home/test/cursor-agent/versions/v1/index.js"]), "none")

    def test_pi_script_and_codex_script(self):
        self.assertEqual(self.classify(["/usr/bin/node", "/npm/@earendil-works/pi-coding-agent/dist/cli.js"]), "pi")
        self.assertEqual(self.classify(["/usr/bin/node", "/npm/@openai/codex/bin/codex.js"]), "codex")
