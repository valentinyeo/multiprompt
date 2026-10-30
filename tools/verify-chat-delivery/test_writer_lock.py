"""Exercise the supplied reader's real cross-process writer lock."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile

SOURCE = Path(__file__).resolve().parents[2] / "src/chat_history_reader.py"


def load_reader(home):
    spec = importlib.util.spec_from_file_location("verified_remote_reader", SOURCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.HOME = Path(home)
    return module


def attempt(home, target):
    reader = load_reader(home)
    try:
        with reader.writer_guard(target, blocking=False):
            print("acquired")
    except BlockingIOError:
        print("busy")


def probe(home, target):
    result = subprocess.run([sys.executable, __file__, "attempt", str(home), target],
                            capture_output=True, text=True, timeout=15, check=True)
    return result.stdout.strip()


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "attempt":
        attempt(sys.argv[2], sys.argv[3])
    else:
        with tempfile.TemporaryDirectory() as temp:
            reader = load_reader(temp)
            with reader.writer_guard("alpha"):
                with reader.writer_guard("alpha", blocking=False):
                    assert probe(temp, "alpha") == "busy"
                    assert probe(temp, "beta") == "acquired"
            assert probe(temp, "alpha") == "acquired"
        print("WINDOWS_WRITER_LOCK_OK" if os.name == "nt" else "POSIX_WRITER_LOCK_OK")
