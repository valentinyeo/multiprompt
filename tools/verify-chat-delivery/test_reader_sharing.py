import builtins
import ctypes
import io
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import types
import unittest
from unittest import mock


SCRIPT = """
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
with path.open("rb") as source:
    print("OPENED", flush=True)
    sys.stdin.readline()
    held = source.read().decode("utf-8")
print(json.dumps(dict(held=held, current=path.read_text(encoding="utf-8"))))
"""


class ReaderContract(unittest.TestCase):
    def test_shared_reader_preserves_path_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            target = str(Path(directory) / "session.jsonl")
            Path(target).write_bytes(b"original")
            windows = types.ModuleType("os")
            windows.__dict__.update(os.__dict__)
            windows.name = "nt"
            windows.O_BINARY = getattr(os, "O_BINARY", 0)
            kernel = mock.Mock()
            kernel.CreateFileW.side_effect = lambda file, *args: os.open(file, os.O_RDONLY)
            crt = types.ModuleType("msvcrt")
            crt.open_osfhandle = lambda handle, flags: handle
            original_io, original_builtin = io.open, builtins.open
            try:
                with mock.patch.dict(sys.modules, os=windows, msvcrt=crt), mock.patch.object(ctypes, "WinDLL", create=True, return_value=kernel):
                    adapter = runpy.run_path(str(Path(__file__).with_name("sitecustomize.py")))
                    with adapter["shared_open"](target, "rb") as source:
                        self.assertEqual(source.name, target)
                        self.assertEqual(source.read(), b"original")
                        source.seek(0)
                        self.assertEqual(source.read(), b"original")
            finally:
                io.open, builtins.open = original_io, original_builtin


@unittest.skipUnless(os.name == "nt", "Windows remote-reader boundary")
class ReaderSharing(unittest.TestCase):
    def replace_while_open(self, patched, suffix=".jsonl", reset=False):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / ("session" + suffix)
            replacement = Path(directory) / "replacement"
            original = "".join(f"message {index}\n" for index in range(22))
            tail = "".join(original.splitlines(keepends=True)[-20:])
            target.write_text(original, encoding="utf-8", newline="")
            replacement.write_text("replacement", encoding="utf-8")
            (Path(directory) / "state.json").write_text(json.dumps(dict(transcript=str(target))), encoding="utf-8")
            environment = os.environ.copy()
            environment.pop("PYTHONPATH", None)
            if patched:
                environment["PYTHONPATH"] = str(Path(__file__).resolve().parent)
            child = subprocess.Popen([sys.executable, "-u", "-c", SCRIPT, str(target)],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                     text=True, env=environment)
            try:
                self.assertEqual(child.stdout.readline().strip(), "OPENED")
                if reset:
                    command = [sys.executable, "-I", str(Path(__file__).with_name("boundary.py")), "shell", "retention-reset"]
                    result = subprocess.run(command, env={**environment, "MP_VERIFY_STATE": directory},
                                            capture_output=True, text=True, timeout=20)
                    if patched:
                        self.assertEqual(result.returncode, 0, result.stderr)
                        expected = tail
                    else:
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn("PermissionError", result.stderr)
                        expected = original
                else:
                    with self.assertRaises(PermissionError):
                        os.replace(replacement, target)
                    expected = original
                output, error = child.communicate("\n", timeout=20)
                self.assertEqual(child.returncode, 0, error)
                self.assertEqual(json.loads(output), dict(held=original, current=expected))
            finally:
                if child.poll() is None:
                    child.kill()
                    child.communicate()

    def test_original_reader_rejects_atomic_replacement(self):
        self.replace_while_open(False, reset=True)
        print("ORIGINAL_WINDOWS_READER_REJECTED", flush=True)

    def test_supplied_bootstrap_can_keep_reading_replaced_jsonl(self):
        self.replace_while_open(True, reset=True)
        print("POSIX_REPLACEMENT_WITH_HELD_READER_OK", flush=True)

    def test_delete_sharing_alone_does_not_fix_windows_replace(self):
        self.replace_while_open(True)
        print("LEGACY_REPLACE_REJECTS_SHARED_READER", flush=True)

    def test_nontranscript_files_keep_standard_windows_sharing(self):
        self.replace_while_open(True, ".txt")


if __name__ == "__main__":
    unittest.main(verbosity=2)
