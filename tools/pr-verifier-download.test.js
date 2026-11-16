const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

test('verifier retries download only the newest evidence for each artifact name', { skip: process.platform === 'win32' }, t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-download-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const base = 'b'.repeat(40);
  const artifacts = [
    { id: 3, name: 'verify-chat-view' },
    { id: 1, name: 'verify-chat-view' },
    { id: 4, name: `verify-chat-view-${base}` },
    { id: 2, name: `verify-chat-view-${base}` },
    { id: 5, name: `verify-chat-view-${'c'.repeat(40)}` },
  ];
  fs.writeFileSync(path.join(dir, 'artifacts.json'), JSON.stringify(artifacts));
  execFileSync('python3', ['-c', `
import json, pathlib, sys, zipfile
root = pathlib.Path(sys.argv[1])
for artifact in json.loads((root / 'artifacts.json').read_text()):
    with zipfile.ZipFile(root / (str(artifact['id']) + '.zip'), 'w') as archive:
        archive.writestr('result.json', json.dumps({'id': artifact['id']}))
        if artifact['id'] < 3:
            archive.writestr('obsolete.png', 'old evidence')
`, dir]);
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const args = process.argv.slice(2);
const root = process.env.ARTIFACT_FIXTURE;
const artifacts = JSON.parse(fs.readFileSync(path.join(root, 'artifacts.json')));
if (args[0] === 'api' && args.some(arg => arg.endsWith('/artifacts'))) {
  for (const artifact of artifacts) console.log(args.includes('.artifacts[].name') ? artifact.name : JSON.stringify(artifact));
} else if (args[0] === 'api' && args.some(arg => /\\/artifacts\\/\\d+\\/zip$/.test(arg))) {
  const id = args.find(arg => /\\/artifacts\\/\\d+\\/zip$/.test(arg)).split('/').at(-2);
  process.stdout.write(fs.readFileSync(path.join(root, id + '.zip')));
} else if (args[0] === 'run' && args[1] === 'download') {
  const name = args[args.indexOf('--name') + 1];
  const dest = args[args.indexOf('--dir') + 1];
  for (const artifact of artifacts.filter(artifact => artifact.name === name)) {
    execFileSync('unzip', ['-q', path.join(root, artifact.id + '.zip'), '-d', dest], { stdio: ['ignore', 'pipe', 'pipe'] });
  }
} else {
  throw new Error('Unexpected gh arguments: ' + JSON.stringify(args));
}
`, { mode: 0o755 });
  const selection = path.join(dir, 'selection.json');
  fs.writeFileSync(selection, JSON.stringify({ features: ['chat-view'], compareBase: true }));
  const evidence = path.join(dir, 'evidence');
  const run = spawnSync(process.execPath, [path.join(root, 'tools/pr-verifier.cjs'), 'download', selection, evidence, base], {
    env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH, ARTIFACT_FIXTURE: dir, REPO: 'example/repo', RUN_ID: '7' },
    encoding: 'utf8',
  });
  assert.equal(run.status, 0, run.stderr);
  assert.deepEqual(fs.readdirSync(evidence).sort(), ['verify-chat-view', `verify-chat-view-${base}`].sort());
  for (const [name, id] of [['verify-chat-view', 3], [`verify-chat-view-${base}`, 4]]) {
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(evidence, name, 'result.json'))), { id });
    assert.equal(fs.existsSync(path.join(evidence, name, 'obsolete.png')), false);
  }
});
