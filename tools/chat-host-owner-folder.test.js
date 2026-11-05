const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

test('a missing folder in the host home resolves to the one other user that has it', () => {
  const program = String.raw`
import os, tempfile, types
from pathlib import Path

outer = {}
exec(compile(${JSON.stringify(source)}, 'reader', 'exec'), outer)
r = {}
exec(compile(outer['READER_SOURCE'], 'runtime', 'exec'), r)
with tempfile.TemporaryDirectory() as directory:
    homes = Path(directory) / 'home'
    me, other, third = homes / 'me', homes / 'other', homes / 'third'
    for folder in (me / 'projects' / 'own', other / 'projects' / 'shared', third / 'projects'):
        folder.mkdir(parents=True)
    r['HOME'] = me
    r['HOST_USER_HOMES'] = homes
    r['conversation_owner'] = lambda cwd, include_home=False: (Path(cwd).relative_to(homes).parts[0], homes / Path(cwd).relative_to(homes).parts[0])
    probes = []
    def run(argv, **kwargs):
        probes.append(argv)
        return types.SimpleNamespace(returncode=0 if os.path.isdir(argv[-1]) else 1)
    r['subprocess'].run = run
    own = str(me / 'projects' / 'own')
    assert r['host_folder'](own) == own
    assert probes == [], probes
    assert r['host_folder'](str(me / 'projects' / 'shared')) == str(other / 'projects' / 'shared')
    assert all(argv[:3] == ['sudo', '-n', '-u'] for argv in probes), probes
    missing = str(me / 'projects' / 'nowhere')
    assert r['host_folder'](missing) == missing
    (third / 'projects' / 'shared').mkdir()
    ambiguous = str(me / 'projects' / 'shared')
    assert r['host_folder'](ambiguous) == ambiguous
    r['host_write'](r['host_paths']('claude', 'synthetic-earlier')['config'], dict(enabled=True, cwd=str(third / 'projects' / 'shared')))
    assert r['host_folder'](ambiguous) == str(third / 'projects' / 'shared')
    outside = str(Path(directory) / 'elsewhere')
    assert r['host_folder'](outside) == outside
print('owner folder resolved')
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /owner folder resolved/);
});
