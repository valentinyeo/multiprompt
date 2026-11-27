import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'src/chat_history_reader.py').read_text()
READER = {'__name__': 'runtime_self_update_test'}
exec(compile(SOURCE, '<runtime-self-update>', 'exec'), READER)
NODE = os.environ.get('NODE', 'node')

KEYGEN = '''
import { generateKeyPairSync } from 'node:crypto';
const { publicKey, privateKey } = generateKeyPairSync('ed25519');
console.log(JSON.stringify({
  public: publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('base64'),
  private: privateKey.export({ format: 'der', type: 'pkcs8' }).subarray(-32).toString('base64'),
}));
'''

SIGNER = '''
import fs from 'node:fs';
import { createPrivateKey, sign } from 'node:crypto';
const [manifest, seed, out] = process.argv.slice(2);
const key = createPrivateKey({ key: Buffer.concat([Buffer.from('302e020100300506032b657004220420', 'hex'), Buffer.from(fs.readFileSync(seed, 'utf8').trim(), 'base64')]), format: 'der', type: 'pkcs8' });
fs.writeFileSync(out, sign(null, fs.readFileSync(manifest), key));
'''


class RuntimeSelfUpdateTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.runtime = self.home / '.multiprompt-runtime'
        self.keypair = self.make_keypair()
        self.public = base64.b64decode(self.keypair['public'])

    def symbol(self, name):
        self.assertIn(name, READER, 'src/chat_history_reader.py must define ' + name)
        return READER[name]

    def make_keypair(self):
        return json.loads(self.node(KEYGEN))

    def node(self, script, *arguments):
        path = self.write('script-' + hashlib.sha256(script.encode()).hexdigest()[:12] + '.mjs', script)
        result = subprocess.run([NODE, str(path), *map(str, arguments)], capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def write(self, name, data):
        path = self.root / name
        path.write_bytes(data if isinstance(data, bytes) else data.encode())
        return path

    def build(self, name, version, reader=None, send=None):
        out = self.root / name
        command = [NODE, 'tools/build-runtime-bundle.mjs', str(out), '--version', version]
        if reader is not None:
            command += ['--reader', str(reader)]
        if send is not None:
            command += ['--source', 'mp_send=' + str(send)]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr)
        return out.read_bytes()

    def changed_reader(self, name='changed-reader.py'):
        changed = SOURCE.replace('PAGE_BYTES = 350000', 'PAGE_BYTES = 350001', 1)
        self.assertNotEqual(changed, SOURCE)
        return self.write(name, changed)

    def install(self, bundle, home=None):
        home = self.home if home is None else home
        path = self.write('install-' + hashlib.sha256(bundle).hexdigest()[:16] + '.py', bundle)
        environment = dict(os.environ, HOME=str(home), PYTHONDONTWRITEBYTECODE='1')
        request = json.dumps({'id': 1, 'op': 'engine_info'}) + '\n'
        result = subprocess.run([sys.executable, '-u', str(path), '--serve'], input=request, text=True,
                                capture_output=True, env=environment, timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)['engine_info']

    def manifest(self, bundle, extra=''):
        return (hashlib.sha256(bundle).hexdigest() + '  multiprompt-runtime.py\n' + extra).encode()

    def sign(self, manifest, keypair=None):
        name = 'SHA256SUMS-' + hashlib.sha256(manifest).hexdigest()[:12] + '.txt'
        signed = self.node(SIGNER, self.write(name, manifest), self.write(name + '.seed', (keypair or self.keypair)['private']), self.root / (name + '.sig'))
        self.assertEqual(signed, '')
        return (self.root / (name + '.sig')).read_bytes()

    def release(self, tag, bundle, manifest=None, signature=None, author='github-actions[bot]', draft=False, prerelease=False, urls=None):
        names = ('multiprompt-runtime.py', 'SHA256SUMS.txt', 'SHA256SUMS.txt.sig')
        download = dict((name, 'https://github.com/valentinyeo/multiprompt/releases/download/' + tag + '/' + name) for name in names)
        files = {download[names[0]]: bundle, download[names[1]]: manifest, download[names[2]]: signature}
        document = dict(tag_name=tag, draft=draft, prerelease=prerelease, author=dict(login=author),
                        assets=[dict(name=name, browser_download_url=(urls or {}).get(name, download[name])) for name in names])
        calls = []

        def fetch(url, limit):
            calls.append(url)
            if url == self.symbol('RUNTIME_UPDATE_API'):
                return json.dumps(document).encode()
            value = files[url]
            data = value.read_bytes() if isinstance(value, Path) else value
            if len(data) > limit:
                raise ValueError('asset too large for ' + url)
            return data

        return calls, fetch

    def publish(self, tag, bundle, manifest=None, signature=None, **options):
        manifest = self.manifest(bundle) if manifest is None else manifest
        signature = self.sign(manifest) if signature is None else signature
        return self.release(tag, bundle, manifest, signature, **options)

    def snapshot(self):
        record = {'active.mtime': (self.runtime / 'active.json').stat().st_mtime_ns}
        for path in self.runtime.iterdir():
            if path.name == 'lock':
                continue
            record[path.name] = os.readlink(path) if path.is_symlink() else path.read_bytes()
        return record

    def update(self, fetch, version, check=False, key=None, home=None):
        return self.symbol('runtime_update_run')(check=check, fetch=fetch, home=self.home if home is None else home,
                                                key=self.public if key is None else key, version=version)

    def installed(self):
        return json.loads((self.runtime / 'active.json').read_text())

    def test_the_embedded_public_key_is_the_release_signing_key(self):
        public = self.symbol('RELEASE_SIGNING_PUBLIC_KEY')
        key = self.symbol('runtime_update_key')
        asset = self.symbol('RUNTIME_UPDATE_ASSET')
        self.assertEqual(public.strip(), (ROOT / 'src/release_signing_public_key.txt').read_text().strip())
        self.assertEqual(len(key()), 32)
        self.assertEqual(asset, 'multiprompt-runtime.py')

    def test_the_default_download_reads_an_asset_and_stops_at_its_limit(self):
        download = self.symbol('runtime_update_download')
        asset = self.write('asset.bin', b'payload')
        self.assertEqual(download(asset.as_uri(), 16), b'payload')
        with self.assertRaises(ValueError):
            download(asset.as_uri(), 4)

    def test_the_manifest_signature_matches_the_release_signer(self):
        valid = self.symbol('release_signature_valid')
        message = b'0123456789abcdef  multiprompt-runtime.py\n'
        signature = self.sign(message)
        self.assertTrue(valid(message, signature, self.public))
        self.assertFalse(valid(message + b'\n', signature, self.public))
        self.assertFalse(valid(message, signature, base64.b64decode(self.make_keypair()['public'])))
        self.assertFalse(valid(message, signature[:-1], self.public))
        self.assertFalse(valid(message, b'\x00' * 64, self.public))

    def test_a_server_without_the_desktop_installs_the_published_bundle(self):
        old = self.build('old-bundle.py', '0.28.900', send=self.write('old-mp-send.py', 'print("old")\n'))
        new = self.build('new-bundle.py', '0.28.901', reader=self.changed_reader(), send=self.write('new-mp-send.py', 'print("new")\n'))
        first = self.install(old)
        self.assertEqual(self.installed()['sha256'], first['sha256'])
        self.assertEqual(os.readlink(self.runtime / 'reader.py'), first['sha256'] + '.py')
        self.assertEqual((self.runtime / 'mp-send').read_text(), 'print("old")\n')
        calls, fetch = self.publish('v0.28.901', new)
        result = self.update(fetch, '0.28.900')
        self.assertEqual(result['status'], 'updated', result)
        active = self.installed()
        self.assertNotEqual(active['sha256'], first['sha256'])
        self.assertEqual(active['sha256'], result['sha256'])
        self.assertNotEqual(active['generation'], first['generation'])
        self.assertEqual(os.readlink(self.runtime / 'reader.py'), active['sha256'] + '.py')
        self.assertEqual((self.runtime / 'mp-send').read_text(), 'print("new")\n')
        self.assertTrue(os.access(self.runtime / 'mp-send', os.X_OK))
        self.assertEqual(json.loads((self.runtime / 'self-update.json').read_text())['tag'], 'v0.28.901')
        self.assertEqual(self.symbol('runtime_update_active')(self.home)['sha256'], active['sha256'])
        self.assertEqual(self.symbol('runtime_update_selected_version')(self.home), '0.28.901')
        self.assertIn(self.symbol('RUNTIME_UPDATE_ORIGIN') + 'v0.28.901/multiprompt-runtime.py', calls)

    def test_the_same_bundle_fingerprint_is_a_clean_no_op(self):
        old = self.build('noop-old.py', '0.28.900', send=self.write('noop-old-send.py', 'print("old")\n'))
        new = self.build('noop-new.py', '0.28.901', reader=self.changed_reader('noop-reader.py'), send=self.write('noop-new-send.py', 'print("new")\n'))
        self.install(old)
        calls, fetch = self.publish('v0.28.901', new)
        self.assertEqual(self.update(fetch, '0.28.900')['status'], 'updated')
        before = self.snapshot()
        downloaded = len(calls)
        result = self.update(fetch, '0.28.901')
        self.assertEqual(result['status'], 'current', result)
        self.assertEqual(len(calls), downloaded + 1)
        self.assertEqual(self.snapshot(), before)
        self.install(new)
        self.assertEqual(self.snapshot(), before)

    def expect_refused(self, fetch, reason, version='0.28.900'):
        before = self.snapshot()
        result = self.update(fetch, version)
        self.assertEqual(result['status'], 'failed', result)
        self.assertIn(reason, result['reason'])
        self.assertEqual(self.snapshot(), before)
        return result

    def test_a_bad_checksum_is_refused_and_leaves_the_runtime_untouched(self):
        old = self.build('bad-old.py', '0.28.900')
        new = self.build('bad-new.py', '0.28.901', reader=self.changed_reader('bad-reader.py'))
        self.install(old)
        manifest = hashlib.sha256(b'not the bundle').hexdigest() + '  multiprompt-runtime.py\n'
        calls, fetch = self.publish('v0.28.901', new, manifest=manifest.encode())
        self.expect_refused(fetch, 'checksum')

    def test_a_missing_checksum_entry_is_refused(self):
        old = self.build('missing-old.py', '0.28.900')
        new = self.build('missing-new.py', '0.28.901', reader=self.changed_reader('missing-reader.py'))
        self.install(old)
        manifest = hashlib.sha256(new).hexdigest() + '  multiprompt-runtime.py.bak\n'
        calls, fetch = self.publish('v0.28.901', new, manifest=manifest.encode())
        self.expect_refused(fetch, 'checksum')

    def test_a_tampered_bundle_is_refused(self):
        old = self.build('tampered-old.py', '0.28.900')
        new = self.build('tampered-new.py', '0.28.901', reader=self.changed_reader('tampered-reader.py'))
        self.install(old)
        manifest = self.manifest(new)
        signature = self.sign(manifest)
        calls, fetch = self.release('v0.28.901', new + b'\n', manifest, signature)
        self.expect_refused(fetch, 'checksum')

    def test_a_bad_manifest_signature_is_refused(self):
        old = self.build('unsigned-old.py', '0.28.900')
        new = self.build('unsigned-new.py', '0.28.901', reader=self.changed_reader('unsigned-reader.py'))
        self.install(old)
        manifest = self.manifest(new)
        calls, fetch = self.publish('v0.28.901', new, manifest=manifest, signature=self.sign(manifest, self.make_keypair()))
        self.expect_refused(fetch, 'signature')

    def test_an_untrusted_release_is_refused(self):
        old = self.build('untrusted-old.py', '0.28.900')
        new = self.build('untrusted-new.py', '0.28.901', reader=self.changed_reader('untrusted-reader.py'))
        self.install(old)
        manifest = self.manifest(new)
        signature = self.sign(manifest)
        for options, reason in ((dict(author='someone-else'), 'author'), (dict(draft=True), 'channel'), (dict(prerelease=True), 'channel')):
            with self.subTest(reason=reason, options=options):
                calls, fetch = self.release('v0.28.901', new, manifest, signature, **options)
                self.expect_refused(fetch, reason)
        calls, fetch = self.release('v0.28.901', new, manifest, signature,
                                    urls={'multiprompt-runtime.py': 'https://example.test/multiprompt-runtime.py'})
        self.expect_refused(fetch, 'url')
        calls, fetch = self.release('latest', new, manifest, signature)
        self.expect_refused(fetch, 'version')

    def test_an_older_release_never_downgrades_the_installed_helpers(self):
        old = self.build('downgrade-old.py', '0.28.900')
        new = self.build('downgrade-new.py', '0.28.901', reader=self.changed_reader('downgrade-reader.py'))
        self.install(new)
        before = self.snapshot()
        calls, fetch = self.publish('v0.28.900', old)
        result = self.update(fetch, None)
        self.assertEqual(result['status'], 'current', result)
        self.assertEqual(self.snapshot(), before)

    def test_a_reader_only_update_moves_the_recorded_version_forward(self):
        old = self.build('reader-only-old.py', '0.28.900')
        new = self.build('reader-only-new.py', '0.28.901', reader=self.changed_reader('reader-only-reader.py'))
        first = self.install(old)
        tools = (self.runtime / 'tools.json').read_bytes()
        self.assertEqual(self.symbol('runtime_update_version')(self.home), '0.28.900')
        calls, fetch = self.publish('v0.28.901', new)
        result = self.update(fetch, None)
        self.assertEqual(result['status'], 'updated', result)
        self.assertNotEqual(self.installed()['sha256'], first['sha256'])
        self.assertEqual(self.symbol('runtime_update_selected_version')(self.home), '0.28.901')
        self.assertEqual(self.symbol('runtime_update_version')(self.home), '0.28.901')
        self.assertEqual((self.runtime / 'tools.json').read_bytes(), tools, 'a reader-only update leaves the tools alone')
        before = self.snapshot()
        for tag, bundle in (('v0.28.901', new), ('v0.28.900', old)):
            with self.subTest(tag=tag):
                calls, fetch = self.publish(tag, bundle)
                self.assertEqual(self.update(fetch, None, check=True)['status'], 'current')
                self.assertEqual(self.update(fetch, None)['status'], 'current')
        self.assertEqual(self.snapshot(), before)

    def test_the_installed_version_comes_from_the_selected_reader(self):
        old = self.build('detect-old.py', '0.28.900')
        self.install(old)
        self.assertEqual(self.symbol('runtime_update_version')(self.home), '0.28.900')
        self.assertEqual(self.symbol('runtime_update_selected_version')(self.home), '0.28.900')
        older = self.build('detect-older.py', '0.28.899', reader=self.changed_reader('detect-reader.py'))
        calls, fetch = self.publish('v0.28.899', older)
        self.assertEqual(self.update(fetch, None)['status'], 'current')

    def test_the_periodic_check_runs_only_when_it_is_due(self):
        due = self.symbol('runtime_update_due')
        self.assertTrue(due(self.home))
        self.symbol('runtime_update_stamp')(self.home, 'v0.28.901')
        self.assertFalse(due(self.home))
        self.assertTrue(due(self.home, now=self.installed_time() + self.symbol('RUNTIME_UPDATE_INTERVAL')))
        self.assertEqual(json.loads((self.runtime / 'self-update.json').read_text())['tag'], 'v0.28.901')

    def installed_time(self):
        return json.loads((self.runtime / 'self-update.json').read_text())['checked']

    def test_a_read_only_update_check_reports_what_is_offered(self):
        old = self.build('check-old.py', '0.28.900')
        new = self.build('check-new.py', '0.28.901', reader=self.changed_reader('check-reader.py'))
        self.install(old)
        before = self.snapshot()
        calls, fetch = self.publish('v0.28.901', new)
        result = self.update(fetch, '0.28.900', check=True)
        self.assertEqual(result, {'status': 'available', 'tag': 'v0.28.901'})
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.update(fetch, '0.28.901', check=True)['status'], 'current')

    def test_an_unknown_update_command_is_refused(self):
        command = self.symbol('runtime_update_command')
        self.assertEqual(command(['--unknown'])['status'], 'error')
        self.assertEqual(command(['--check', '--now'])['status'], 'error')


if __name__ == '__main__':
    unittest.main()
