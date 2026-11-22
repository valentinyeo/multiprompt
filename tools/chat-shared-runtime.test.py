import base64
import hashlib
import http.server
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'src/chat_history_reader.py').read_text()
GENERATION = int(re.search(r'^RUNTIME_GENERATION = (\d+)$', SOURCE, re.MULTILINE).group(1))
BOOTSTRAP = 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))'


class RuntimeTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.addCleanup(self.home.cleanup)
        self.env = dict(os.environ, HOME=self.home.name, PYTHONDONTWRITEBYTECODE='1')

    def invoke(self, source=SOURCE, client='desktop', mode='--serve', request=None):
        request = request or {'id': 7, 'op': 'engine_info'}
        payload = json.dumps(request) + '\n'
        if client == 'desktop':
            args = [sys.executable, '-u', '-c', BOOTSTRAP, mode]
            payload = base64.b64encode(source.encode()).decode() + '\n' + payload
        else:
            args = [sys.executable, '-', mode]
            payload = source
        result = subprocess.run(args, input=payload, text=True, capture_output=True, env=self.env, timeout=10)
        return result

    def info(self, source=SOURCE):
        result = self.invoke(source)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)['engine_info']

    def newer(self):
        return SOURCE.replace(f'RUNTIME_GENERATION = {GENERATION}\n', f'RUNTIME_GENERATION = {GENERATION + 1}\n', 1).replace('END = "@@MP_END@@"', 'END = "@@MP_NEW_END@@"', 1)

    def test_selection_and_idempotence_across_bootstraps(self):
        first = self.info()
        active = Path(self.home.name) / '.multiprompt-runtime' / 'active.json'
        before = active.stat().st_mtime_ns
        self.assertEqual(self.info(), first)
        self.assertEqual(active.stat().st_mtime_ns, before)
        newer = self.info(self.newer())
        self.assertEqual(newer['generation'], GENERATION + 1)
        self.assertNotEqual(first['sha256'], newer['sha256'])
        self.assertEqual(self.info(), newer)
        query = {'id': 9, 'cwd': '', 'sid': 'missing', 'tmux': '', 'codex': False}
        request = base64.b64encode(json.dumps(query).encode()).decode()
        result = subprocess.run([sys.executable, '-', request], input=SOURCE, text=True, capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, '@mp\t9\thistory\tmissing\t-\t0\tsession transcript not found\n@@MP_NEW_END@@\n')
        self.assertEqual(json.loads(active.read_text()), newer)

    def test_same_generation_different_source_replaces_the_stale_selection(self):
        first = self.info()
        conflict = SOURCE.replace('PAGE_BYTES = 350000', 'PAGE_BYTES = 350001', 1)
        replaced = self.info(conflict)
        self.assertEqual(replaced['generation'], GENERATION)
        self.assertNotEqual(replaced['sha256'], first['sha256'])
        self.assertEqual(self.info(conflict), replaced)
        self.assertEqual(self.info()['sha256'], first['sha256'])

    def test_corruption_fails_closed(self):
        first = self.info()
        path = Path(self.home.name) / '.multiprompt-runtime' / (first['sha256'] + '.py')
        path.write_text('corrupt')
        self.assertIn('history\\terror', self.invoke().stdout)

    def test_unsafe_selection_fails_closed(self):
        self.info()
        active = Path(self.home.name) / '.multiprompt-runtime' / 'active.json'
        active.unlink()
        active.symlink_to('/dev/null')
        self.assertIn('history\\terror', self.invoke().stdout)

    def test_boolean_protocol_fails_closed(self):
        self.info()
        active = Path(self.home.name) / '.multiprompt-runtime' / 'active.json'
        metadata = json.loads(active.read_text())
        metadata['protocol'] = True
        active.write_text(json.dumps(metadata))
        self.assertIn('history\\terror', self.invoke().stdout)

    def test_null_selection_cannot_downgrade(self):
        self.assertEqual(self.info(self.newer())['generation'], GENERATION + 1)
        active = Path(self.home.name) / '.multiprompt-runtime' / 'active.json'
        active.write_text('null')
        self.assertIn('history\\terror', self.invoke().stdout)
        self.assertEqual(active.read_text(), 'null')

    def test_thread_pool_executor_loads_before_retire_thread(self):
        prelude = SOURCE.split('def serve(', 1)[0]
        serve_head = SOURCE.split('def serve(', 1)[1].split('chats = {}', 1)[0]
        self.assertIn('from concurrent.futures import ThreadPoolExecutor', prelude)
        self.assertNotIn('from concurrent.futures import ThreadPoolExecutor', serve_head)

    def test_concurrent_generations_cannot_downgrade(self):
        for attempt in range(50):
            with self.subTest(attempt=attempt):
                processes = []
                for source in (SOURCE, self.newer(), SOURCE, self.newer()):
                    process = subprocess.Popen([sys.executable, '-u', '-c', BOOTSTRAP, '--serve'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=self.env)
                    process.stdin.write(base64.b64encode(source.encode()).decode() + '\n' + json.dumps({'id': 7, 'op': 'engine_info'}) + '\n')
                    process.stdin.flush()
                    processes.append(process)
                for process in processes:
                    output, error = process.communicate(timeout=10)
                    self.assertEqual(process.returncode, 0, error)
                    self.assertTrue(output.strip(), 'superseded reader dropped an open reply before ThreadPoolExecutor load')
                    self.assertIn(json.loads(output)['engine_info']['generation'], (GENERATION, GENERATION + 1))
                self.assertEqual(self.info()['generation'], GENERATION + 1)

    def test_mp_send_ships_inside_the_runtime(self):
        body = "#!/usr/bin/env python3\nprint('mp-send')\n"
        source = "MP_SEND_SOURCE = '%s'\n%s" % (base64.b64encode(body.encode()).decode(), SOURCE)
        self.info(source)
        published = Path(self.home.name) / '.multiprompt-runtime' / 'mp-send'
        self.assertTrue(published.is_symlink())
        self.assertEqual(published.read_text(), body)
        self.assertTrue(os.access(published, os.X_OK))

    def test_zsb_ships_inside_the_runtime_as_an_executable_copy(self):
        body = "#!/bin/sh\necho zsb\n"
        source = "ZSB_SOURCE = '%s'\n%s" % (base64.b64encode(body.encode()).decode(), SOURCE)
        self.info(source)
        published = Path(self.home.name) / '.multiprompt-runtime' / 'mp-zsb'
        self.assertTrue(published.is_symlink())
        self.assertEqual(published.read_text(), body)
        self.assertTrue(os.access(published, os.X_OK))
        self.assertFalse((Path(self.home.name) / '.multiprompt-runtime' / 'zsb').exists())

    def test_reader_tool_is_a_symlink(self):
        info = self.info()
        reader = Path(self.home.name) / '.multiprompt-runtime' / 'reader.py'
        self.assertTrue(reader.is_symlink())
        self.assertEqual(os.readlink(reader), info['sha256'] + '.py')

    def test_hand_copied_reader_is_repaired(self):
        info = self.info()
        runtime = Path(self.home.name) / '.multiprompt-runtime'
        reader = runtime / 'reader.py'
        reader.unlink()
        reader.write_text('broken hand copy')
        self.assertFalse(reader.is_symlink())
        self.assertEqual(self.info()['sha256'], info['sha256'])
        self.assertTrue(reader.is_symlink())
        self.assertEqual(reader.read_text(), (runtime / (info['sha256'] + '.py')).read_text())

    def bundle(self):
        sources = (
            ('MP_SEND_SOURCE', 'src/mp_send.py'),
            ('MP_FRESH_SOURCE', 'src/mp_fresh.py'),
            ('MP_HELPER_SOURCE', 'src/mp_helper.py'),
            ('MP_SHELL_SOURCE', 'src/mp_shell.py'),
            ('MP_SESSIONS_SOURCE', 'src/mp_sessions.py'),
            ('MP_LAYOUT_SOURCE', 'src/mp_layout.mjs'),
            ('ZSB_SOURCE', 'src/mp_zsb.sh'),
        )
        prelude = ''.join("%s = '%s'\n" % (name, base64.b64encode((ROOT / file).read_bytes()).decode()) for name, file in sources if (ROOT / file).is_file())
        return prelude + SOURCE

    def test_mp_fresh_ships_inside_the_runtime_as_an_executable_copy(self):
        self.info(self.bundle())
        published = Path(self.home.name) / '.multiprompt-runtime' / 'mp-fresh'
        self.assertTrue(published.is_symlink())
        self.assertTrue(os.access(published, os.X_OK))

    def test_mp_sessions_and_mp_layout_ship_inside_the_runtime(self):
        self.info(self.bundle())
        runtime = Path(self.home.name) / '.multiprompt-runtime'
        for name, file in (('mp-sessions', 'src/mp_sessions.py'), ('mp-layout', 'src/mp_layout.mjs')):
            published = runtime / name
            self.assertTrue(published.is_symlink(), name)
            self.assertEqual(published.read_text(), (ROOT / file).read_text(), name)
            self.assertTrue(os.access(published, os.X_OK), name)
        self.assertTrue(os.readlink(runtime / 'mp-layout').endswith('.mjs'), 'node must see the module extension')

    def test_published_mp_sessions_lists_chats_from_the_runtime_copy(self):
        self.info(self.bundle())
        sessions = Path(self.home.name) / '.multiprompt-runtime' / 'mp-sessions'
        self.assertTrue(sessions.is_file(), 'mp-sessions must be published')
        listed = subprocess.run([str(sessions)], text=True, capture_output=True, env=self.env, timeout=30)
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertIn('STATE', listed.stdout)

    def test_published_mp_layout_answers_help_from_the_runtime_copy(self):
        self.info(self.bundle())
        layout = Path(self.home.name) / '.multiprompt-runtime' / 'mp-layout'
        self.assertTrue(layout.is_file(), 'mp-layout must be published')
        usage = subprocess.run([str(layout)], text=True, capture_output=True, env=self.env, timeout=30)
        self.assertIn('usage: mp-layout', usage.stdout)

    def test_mp_send_is_not_published_without_a_bundle(self):
        self.info()
        runtime = Path(self.home.name) / '.multiprompt-runtime'
        self.assertFalse((runtime / 'mp-send').exists())
        self.assertFalse((runtime / 'mp-sessions').exists())
        self.assertFalse((runtime / 'mp-layout').exists())

    def test_import_does_not_install(self):
        code = "import importlib.util,sys; s=importlib.util.spec_from_file_location('reader',sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); assert m.READER_SOURCE"
        result = subprocess.run([sys.executable, '-c', code, str(ROOT / 'src/chat_history_reader.py')], env=self.env, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((Path(self.home.name) / '.multiprompt-runtime').exists())

    def test_watch_uses_selected_engine(self):
        self.info(self.newer())
        result = self.invoke(mode='--watch', request={'id': 8, 'cwd': '', 'sid': 'missing', 'tmux': '', 'codex': False})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {'id': 8, 'wire': '@mp\t8\thistory\tmissing\t-\t0\tsession transcript not found\n@@MP_NEW_END@@\n'})

    def test_selected_source_reaches_worker(self):
        newer = self.info(self.newer())
        code = "import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline()).decode();exec(compile(s,'<held-queue-worker>','exec'),dict(__name__='__main__',READER_SOURCE=s))"
        active = Path(self.home.name) / '.multiprompt-runtime'
        payload = (active / (newer['sha256'] + '.py')).read_text()
        source = 'ENGINE_INFO = ' + repr(newer) + '\n' + payload
        result = subprocess.run([sys.executable, '-c', code, '--serve'], input=base64.b64encode(source.encode()).decode() + '\n' + json.dumps({'id': 3, 'op': 'engine_info'}) + '\n', text=True, capture_output=True, env=self.env, timeout=10)
        self.assertEqual(json.loads(result.stdout)['engine_info'], newer)


class ReaderRetireTest(unittest.TestCase):
    def test_superseded_reader_finishes_open_requests_before_exit(self):
        exits = []
        exited = threading.Event()

        def fake_exit(code):
            exits.append(code)
            exited.set()
            raise SystemExit(code)

        spec = importlib.util.spec_from_file_location('reader_retire', ROOT / 'src/chat_history_reader.py')
        reader = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(reader)
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


class ReleaseHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.server.hits.append(self.path)
        payload = self.server.files.get(self.path)
        if payload is None:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header('Content-Length', str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


@unittest.skipUnless(shutil.which('openssl'), 'openssl signs the release fixture')
class ReleaseRuntimeTest(unittest.TestCase):
    tag = 'v9.9.9'

    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.addCleanup(self.home.cleanup)
        self.runtime = Path(self.home.name) / '.multiprompt-runtime'
        self.runtime.mkdir(mode=0o700)
        self.keys = tempfile.TemporaryDirectory()
        self.addCleanup(self.keys.cleanup)
        self.private = os.path.join(self.keys.name, 'key.pem')
        subprocess.run(['openssl', 'genpkey', '-algorithm', 'ed25519', '-out', self.private], check=True, capture_output=True, timeout=30)
        public = subprocess.run(['openssl', 'pkey', '-in', self.private, '-pubout', '-outform', 'DER'], check=True, capture_output=True, timeout=30).stdout
        self.public = base64.b64encode(public[-32:]).decode()
        self.files = {}
        self.hits = []
        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), ReleaseHandler)
        self.server.files = self.files
        self.server.hits = self.hits
        self.addCleanup(self.server.server_close)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.server.shutdown)
        self.base = 'http://127.0.0.1:%d/' % self.server.server_address[1]
        self.reader = self.load(re.sub(r'^RUNTIME_RELEASE_SIGNING_KEY = "[^"]+"$', 'RUNTIME_RELEASE_SIGNING_KEY = "%s"' % self.public, SOURCE, count=1, flags=re.MULTILINE))
        self.reader.RUNTIME_RELEASE_LATEST = self.base + 'latest'
        self.reader.RUNTIME_RELEASE_DOWNLOAD = self.base + 'download/'

    def load(self, source=SOURCE):
        module = types.ModuleType('reader_release')
        with patch.dict(os.environ, {'HOME': self.home.name}):
            exec(compile(source, '<reader-release>', 'exec'), module.__dict__)
        return module

    def sign(self, manifest):
        signed = os.path.join(self.keys.name, 'SHA256SUMS.txt')
        proof = os.path.join(self.keys.name, 'SHA256SUMS.txt.sig')
        Path(signed).write_bytes(manifest)
        subprocess.run(['openssl', 'pkeyutl', '-sign', '-inkey', self.private, '-rawin', '-in', signed, '-out', proof], check=True, capture_output=True, timeout=30)
        return Path(proof).read_bytes()

    def payload(self, generation, marker=''):
        return ('RUNTIME_GENERATION = %d\nPAGE_BYTES = 350000%s\n' % (generation, marker)).encode()

    def release(self, payload=None, manifest=None, signature=None):
        payload = self.payload(135) if payload is None else payload
        digest = hashlib.sha256(payload).hexdigest()
        manifest = ('%s  multiprompt-runtime.py\n' % digest).encode() if manifest is None else manifest
        signature = self.sign(manifest) if signature is None else signature
        base = 'download/%s/' % self.tag
        self.files = {'/latest': json.dumps({'tag_name': self.tag}).encode(),
                      '/' + base + 'SHA256SUMS.txt': manifest,
                      '/' + base + 'SHA256SUMS.txt.sig': signature,
                      '/' + base + 'multiprompt-runtime.py': payload}
        self.server.files = self.files
        return payload, digest

    def current(self, generation):
        payload = self.payload(generation, ' selected')
        digest = hashlib.sha256(payload).hexdigest()
        for name, data in ((digest + '.py', payload), ('active.json', json.dumps(dict(protocol=1, generation=generation, sha256=digest)).encode())):
            (self.runtime / name).write_bytes(data)
            os.chmod(self.runtime / name, 0o600)
        (self.runtime / 'lock').write_bytes(b'')
        os.chmod(self.runtime / 'lock', 0o600)
        (self.runtime / 'reader.py').symlink_to(digest + '.py')
        return digest

    def state(self):
        return json.loads((self.runtime / 'active.json').read_text())

    def test_the_newer_released_runtime_is_installed(self):
        self.current(134)
        payload, digest = self.release()
        self.assertTrue(self.reader.runtime_release_update())
        self.assertEqual(self.state(), dict(protocol=1, generation=135, sha256=digest))
        self.assertEqual((self.runtime / (digest + '.py')).read_bytes(), payload)
        self.assertEqual(os.readlink(self.runtime / 'reader.py'), digest + '.py')
        self.assertEqual(json.loads((self.runtime / 'release-check.json').read_text())['tag'], self.tag)

    def test_an_older_release_never_downgrades(self):
        selected = self.current(140)
        payload, _ = self.release(self.payload(139))
        self.assertFalse(self.reader.runtime_release_update())
        self.assertEqual(self.state()['generation'], 140)
        self.assertEqual(self.state()['sha256'], selected)
        self.assertFalse((self.runtime / (hashlib.sha256(payload).hexdigest() + '.py')).exists())

    def test_the_same_generation_is_not_swapped(self):
        selected = self.current(140)
        self.release(self.payload(140, ' released'))
        self.assertFalse(self.reader.runtime_release_update())
        self.assertEqual(self.state()['sha256'], selected)

    def test_a_bad_signature_keeps_the_running_runtime(self):
        selected = self.current(134)
        digest = hashlib.sha256(self.payload(135)).hexdigest()
        manifest = ('%s  multiprompt-runtime.py\n' % digest).encode()
        self.release(manifest=manifest, signature=self.sign(manifest + b' '))
        self.assertFalse(self.reader.runtime_release_update())
        self.assertEqual(self.state()['sha256'], selected)
        self.assertEqual(self.state()['generation'], 134)

    def test_a_manifest_without_the_runtime_keeps_the_running_runtime(self):
        selected = self.current(134)
        self.release(manifest=b'%s  release-notes.json\n' % hashlib.sha256(b'notes').hexdigest().encode())
        self.assertFalse(self.reader.runtime_release_update())
        self.assertEqual(self.state()['sha256'], selected)

    def test_a_payload_that_misses_its_digest_is_rejected(self):
        selected = self.current(134)
        self.release(manifest=('%s  multiprompt-runtime.py\n' % ('0' * 64)).encode())
        self.assertFalse(self.reader.runtime_release_update())
        self.assertEqual(self.state()['sha256'], selected)

    def test_a_corrupt_selection_blocks_the_swap(self):
        self.current(134)
        (self.runtime / 'active.json').write_text('null')
        os.chmod(self.runtime / 'active.json', 0o600)
        self.release()
        self.assertFalse(self.reader.runtime_release_update())
        self.assertEqual((self.runtime / 'active.json').read_text(), 'null')

    def test_releases_are_checked_on_an_interval(self):
        self.current(134)
        self.release()
        self.assertTrue(self.reader.runtime_release_update())
        after = len(self.hits)
        self.release(self.payload(136))
        self.assertFalse(self.reader.runtime_release_update())
        self.assertEqual(len(self.hits), after)
        (self.runtime / 'release-check.json').unlink()
        self.assertTrue(self.reader.runtime_release_update())
        self.assertEqual(self.state()['generation'], 136)

    def test_openssl_verifies_without_the_cryptography_package(self):
        payload, digest = self.release()
        manifest = ('%s  multiprompt-runtime.py\n' % digest).encode()
        with patch.dict(sys.modules, {'cryptography': None, 'cryptography.exceptions': None, 'cryptography.hazmat': None, 'cryptography.hazmat.primitives': None, 'cryptography.hazmat.primitives.asymmetric': None, 'cryptography.hazmat.primitives.asymmetric.ed25519': None}):
            self.assertTrue(self.reader.runtime_release_signed(manifest, self.sign(manifest)))
            self.assertFalse(self.reader.runtime_release_signed(manifest + b' ', self.sign(manifest)))
        self.assertEqual(hashlib.sha256(payload).hexdigest(), digest)


if __name__ == '__main__':
    unittest.main()
