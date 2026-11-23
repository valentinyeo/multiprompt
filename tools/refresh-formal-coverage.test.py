import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
refresh = runpy.run_path(str(ROOT / 'tools/refresh-formal-coverage.py'))['refresh']


class RefreshCoverageTest(unittest.TestCase):
    def test_refresh_preserves_the_reviewed_mapping_and_hashes_exact_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'reader.py'
            source.write_bytes(b'first\r\nsecond\n')
            path = root / 'coverage.json'
            record = dict(sync_commit='old', files={'reader.py': 'stale'}, coverage={'reader.py': ['decision']})
            path.write_text(json.dumps(record))
            refresh(root, path, 'reviewed')
            updated = json.loads(path.read_text())
            self.assertEqual(updated['files'], {'reader.py': hashlib.sha256(source.read_bytes()).hexdigest()})
            self.assertEqual(updated['coverage'], record['coverage'])
            self.assertEqual(updated['sync_commit'], 'reviewed')
            before = path.read_bytes()
            refresh(root, path, 'reviewed')
            self.assertEqual(path.read_bytes(), before)

    def test_missing_source_does_not_change_the_record(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'coverage.json'
            path.write_text(json.dumps(dict(files={'missing.py': 'old'}, sync_commit='old')))
            before = path.read_bytes()
            with self.assertRaises(FileNotFoundError):
                refresh(root, path, 'reviewed')
            self.assertEqual(path.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
