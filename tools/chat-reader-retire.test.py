import importlib.util
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('reader_retire', ROOT / 'src/chat_history_reader.py')
reader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(reader)


class ReaderRetireTest(unittest.TestCase):
    def test_superseded_reader_finishes_open_requests_before_exit(self):
        exits = []
        exited = threading.Event()

        def fake_exit(code):
            exits.append(code)
            exited.set()
            raise SystemExit(code)

        work = getattr(reader, 'serve_work', lambda delta: None)
        if hasattr(reader, 'SERVE_WORK'):
            reader.SERVE_WORK.update(busy=0, last=time.monotonic())
        with patch.object(reader, 'superseded_engine', return_value=True), patch.object(reader.os, '_exit', fake_exit):
            work(1)
            thread = threading.Thread(target=reader.serve_retire, args=(0.02,), daemon=True)
            thread.start()
            exited.wait(0.3)
            self.assertEqual(exits, [], 'reader retired while a request was still open')
            work(-1)
            self.assertTrue(exited.wait(2), 'idle superseded reader never retired')
            thread.join(1)
        self.assertEqual(exits, [0])


if __name__ == '__main__':
    unittest.main()
