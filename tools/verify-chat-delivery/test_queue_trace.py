import base64
import contextlib
import io
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

from queue_trace import install


class TraceTest(unittest.TestCase):
    def test_isolated_watch_and_serve_bootstraps(self):
        boundary = Path(__file__).with_name('boundary.py').resolve()
        source = '''import subprocess
READER_SOURCE = 'inner'
def start_held_worker(*args):
    raise AssertionError('worker enabled')
def watch(source):
    start_held_worker()
    print('watch output', source)
def serve(source):
    start_held_worker()
    print('serve output', source)
'''
        for mode in ('watch', 'serve'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                bootstrap = ("import importlib.util;"
                             f"s=importlib.util.spec_from_file_location('fixture_boundary',{str(boundary)!r});"
                             "m=importlib.util.module_from_spec(s);s.loader.exec_module(m);"
                             f"m.{mode}_reader()")
                env = dict(os.environ, MP_VERIFY_STATE=directory, PYTHONPATH='')
                if mode == 'watch':
                    (Path(directory) / 'state.json').write_text('{"name":"fake"}')
                    command = [sys.executable, '-I', str(boundary), 'ssh', 'python3 -u -c fake --watch']
                else:
                    command = [sys.executable, '-I', '-c', bootstrap, '--serve']
                result = subprocess.run(command,
                                        input=base64.b64encode(source.encode()) + b'\n',
                                        capture_output=True, env=env)
                self.assertEqual(result.returncode, 0, result.stderr.decode())
                self.assertEqual(result.stdout, f'{mode} output inner\n'.encode())
                rows = [json.loads(line) for line in (Path(directory) / 'queue-trace.jsonl').read_text().splitlines()]
                self.assertTrue(any(row['event'] == 'bootstrap' for row in rows))
                self.assertTrue(any(row['event'] == 'stdout' for row in rows))

    def test_transparent_results_errors_capture_and_readonly_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'queue.sqlite3'
            with sqlite3.connect(path) as db:
                db.execute('CREATE TABLE messages (key, sid, text, queued_at, state, origin, source_inode, scan, recovery_scan, receipt, created)')
                db.execute('CREATE TABLE held_receipts (sid, inode, offset, key, digest)')
                db.execute("INSERT INTO messages VALUES ('key','sid','fake',1,'queued',2,3,4,5,'',6)")
            before = path.read_bytes()
            result = object()
            error = ValueError('fake error')
            capture = subprocess.CompletedProcess(['tmux', 'capture-pane'], 0, stdout='exact pane\n', stderr='')
            class FakeSubprocess:
                @staticmethod
                def run(*args, **kwargs):
                    return capture
            ns = dict(__name__='verified_remote_reader', READER_SOURCE='inner', RUNTIME_GENERATION=3,
                      subprocess=FakeSubprocess, held_queue_path=lambda name: path,
                      enqueue_response=lambda q: result,
                      drain_held_queue=lambda *args: (_ for _ in ()).throw(error))
            install(ns, 'full', root)
            self.assertIs(ns['enqueue_response']({'tmux': 'fake', 'id': 1}), result)
            with self.assertRaises(ValueError) as caught:
                ns['drain_held_queue']('fake', 'sid', path)
            self.assertIs(caught.exception, error)
            self.assertIs(ns['subprocess'].run(['tmux', 'capture-pane']), capture)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                ns['print']('unchanged', end='!')
            self.assertEqual(output.getvalue(), 'unchanged!')
            self.assertEqual(path.read_bytes(), before)
            rows = [json.loads(line) for line in (root / 'queue-trace.jsonl').read_text().splitlines()]
            self.assertEqual(len([row for row in rows if row['event'] == 'snapshot']), 1)
            self.assertEqual(next(row for row in rows if row['event'] == 'capture-pane')['stdout'], 'exact pane\n')
            self.assertEqual(next(row for row in rows if row['event'] == 'snapshot')['rows'][0][0][2], 'fake')


if __name__ == '__main__':
    unittest.main()
