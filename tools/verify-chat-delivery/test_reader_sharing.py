import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = """
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
with path.open("rb") as source:
    print("OPENED", flush=True)
    sys.stdin.readline()
    held = source.read().decode("utf-8")
print(json.dumps(dict(held=held, current=path.read_text(encoding="utf-8"))))
"""


@unittest.skipUnless(os.name == "nt", "Windows remote-reader boundary")
class ReaderSharing(unittest.TestCase):
    def replace_while_open(self, patched, suffix=".jsonl"):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / ("session" + suffix)
            replacement = Path(directory) / "replacement"
            target.write_text("original", encoding="utf-8")
            replacement.write_text("replacement", encoding="utf-8")
            environment = os.environ.copy()
            environment.pop("PYTHONPATH", None)
            if patched:
                environment["PYTHONPATH"] = str(Path(__file__).resolve().parent)
            child = subprocess.Popen([sys.executable, "-u", "-c", SCRIPT, str(target)],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     text=True, env=environment)
            try:
                self.assertEqual(child.stdout.readline().strip(), "OPENED")
                if patched and suffix == ".jsonl":
                    os.replace(replacement, target)
                    expected = "replacement"
                else:
                    with self.assertRaises(PermissionError):
                        os.replace(replacement, target)
                    expected = "original"
                output, error = child.communicate("\n", timeout=20)
                self.assertEqual(child.returncode, 0, error)
                self.assertEqual(json.loads(output), dict(held="original", current=expected))
            finally:
                if child.poll() is None:
                    child.kill()
                    child.communicate()

    def test_original_reader_rejects_atomic_replacement(self):
        self.replace_while_open(False)
        print("ORIGINAL_WINDOWS_READER_REJECTED", flush=True)

    def test_supplied_bootstrap_can_keep_reading_replaced_jsonl(self):
        self.replace_while_open(True)
        print("POSIX_REPLACEMENT_WITH_HELD_READER_OK", flush=True)

    def test_nontranscript_files_keep_standard_windows_sharing(self):
        self.replace_while_open(True, ".txt")


if __name__ == "__main__":
    unittest.main(verbosity=2)
