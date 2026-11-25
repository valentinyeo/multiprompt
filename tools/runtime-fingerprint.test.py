import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'src/chat_history_reader.py').read_text()
BOOTSTRAP = 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))'


class RuntimeFingerprintTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.addCleanup(self.home.cleanup)
        self.env = dict(os.environ, HOME=self.home.name, PYTHONDONTWRITEBYTECODE='1')

    def info(self, source=SOURCE):
        payload = base64.b64encode(source.encode()).decode() + '\n' + json.dumps(dict(id=1, op='engine_info')) + '\n'
        result = subprocess.run([sys.executable, '-u', '-c', BOOTSTRAP, '--serve'], input=payload, text=True, capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        return json.loads(result.stdout)['engine_info']

    def test_reader_edit_changes_version_without_a_bump(self):
        first = self.info()
        changed = SOURCE.replace('PAGE_BYTES = 350000', 'PAGE_BYTES = 350001', 1)
        second = self.info(changed)
        self.assertNotEqual(first['generation'], second['generation'])
        self.assertNotEqual(first['sha256'], second['sha256'])
        active = Path(self.home.name) / '.multiprompt-runtime/active.json'
        before = active.stat().st_mtime_ns
        self.assertEqual(self.info(changed), second)
        self.assertEqual(active.stat().st_mtime_ns, before)

    def test_every_bundled_tool_and_connector_changes_the_fingerprint(self):
        first = self.info()
        for name in ('MP_SEND_SOURCE', 'FEEDBACK_SOURCE', 'MP_HELPER_SOURCE', 'MP_SHELL_SOURCE', 'MP_SESSIONS_SOURCE', 'MP_LAYOUT_SOURCE', 'MP_FRESH_SOURCE', 'ZSB_SOURCE', 'ROOM_SERVICE_SOURCE', 'ROOM_BRIDGE_SOURCE'):
            with self.subTest(name=name):
                bundled = name + ' = ' + repr(base64.b64encode(b'print(1)\n').decode()) + '\n' + SOURCE
                second = self.info(bundled)
                self.assertNotEqual(first['generation'], second['generation'])
                self.assertNotEqual(first['sha256'], second['sha256'])
        second = self.info("CONNECTOR_SOURCES = {'claude': 'cHJpbnQoMSkK'}\n" + SOURCE)
        self.assertNotEqual(first['generation'], second['generation'])
        self.assertNotEqual(first['sha256'], second['sha256'])

    def test_changed_tool_is_published_with_the_new_bundle(self):
        runtime = Path(self.home.name) / '.multiprompt-runtime'
        versions = []
        for body in (b'print(1)\n', b'print(2)\n'):
            source = 'MP_SEND_SOURCE = ' + repr(base64.b64encode(body).decode()) + '\n' + SOURCE
            versions.append(self.info(source))
            self.assertEqual((runtime / 'mp-send').read_bytes(), body)
        self.assertNotEqual(versions[0]['sha256'], versions[1]['sha256'])

    def test_connector_map_order_does_not_change_the_fingerprint(self):
        first = self.info("CONNECTOR_SOURCES = {'claude': 'YQ==', 'codex': 'Yg=='}\n" + SOURCE)
        self.assertEqual(self.info("CONNECTOR_SOURCES = {'codex': 'Yg==', 'claude': 'YQ=='}\n" + SOURCE), first)

    def test_fingerprint_order_does_not_prevent_replacement(self):
        sources = [SOURCE, SOURCE.replace('PAGE_BYTES = 350000', 'PAGE_BYTES = 350001', 1)]
        infos = [self.info(source) for source in sources]
        high = max(range(2), key=lambda index: infos[index]['generation'])
        low = 1 - high
        self.assertEqual(self.info(sources[high]), infos[high])
        self.assertEqual(self.info(sources[low]), infos[low])

    def test_legacy_loader_upgrades_and_cannot_downgrade_the_reader(self):
        legacy = (ROOT / 'tools/fixtures/SOFT-2524/legacy-reader.py').read_text()
        old = self.info(legacy)
        current = self.info()
        self.assertGreater(current['generation'], old['generation'])
        self.assertNotEqual(current['sha256'], old['sha256'])
        self.assertEqual(self.info(legacy), current)

    def test_app_version_is_not_part_of_the_bundle_identity(self):
        first = self.info("MULTIBOT_APP_VERSION = '0.28.1'\n" + SOURCE)
        self.assertEqual(self.info("MULTIBOT_APP_VERSION = '0.28.2'\n" + SOURCE), first)


if __name__ == '__main__':
    unittest.main()
