import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
reference = '9ee03f97b05f50238aaac77154ebf11be3cc30b7'
expected = Path(__file__).with_name('recovery-android-corpus.sha256').read_text(encoding='utf-8')
actual = []
for line in expected.splitlines():
    digest, name = line.split('  ', 1)
    content = subprocess.check_output(['git', 'show', reference + ':' + name], cwd=root)
    actual.append(hashlib.sha256(content).hexdigest() + '  ' + name)
manifest = '\n'.join(actual) + '\n'
if manifest != expected:
    raise ValueError('published application source corpus differs from Android published corpus')
harness = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
Path(sys.argv[1]).write_text(manifest, encoding='utf-8')
Path(sys.argv[2]).write_text(json.dumps(dict(application_source=reference, harness_source=harness,
    android_fixture_source='3ae3ba89ce907fb45fc30c514e447fb1a9cc8d40',
    corpus_sha256=hashlib.sha256(manifest.encode()).hexdigest()), indent=2), encoding='utf-8')
