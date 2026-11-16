const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const verifier = require('./pr-verifier.cjs');

const root = path.resolve(__dirname, '..');
const recovery = require('./fixtures/SOFT-2498/recovery.json');
const artifacts = require('./fixtures/SOFT-2498/artifacts.json');

for (const verdict of ['PASS', 'PASS+NOTES']) {
  test(`${verdict} is recognized with GitHub's rewritten check URL`, () => {
    const check = structuredClone(recovery.checks[1]);
    check.output.summary = check.output.summary.replace('PASS+NOTES', verdict);
    assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [check]), false);
  });

  test(`a later ${verdict} wins over an older recovery BLOCKED`, () => {
    const check = structuredClone(recovery.checks[1]);
    check.output.summary = check.output.summary.replace('PASS+NOTES', verdict).replace(String(recovery.run.id), String(recovery.run.id + 1));
    assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [recovery.checks[0], check]), false);
  });

  test(`a later posted ${verdict} supersedes an earlier FAIL and recovery BLOCKED`, () => {
    const comment = result => ({ user: { login: 'github-actions[bot]' }, body: recovery.checks[1].output.summary.replace('PASS+NOTES', result) });
    assert.equal(verifier.recoveryReport(recovery.run, recovery.headSha, [comment('FAIL'), comment('BLOCKED'), comment(verdict), comment('BLOCKED')]).result, verdict);
  });
}

test('an older verdict or a different head cannot suppress genuine recovery', () => {
  const check = structuredClone(recovery.checks[1]);
  check.output.summary = check.output.summary.replace(String(recovery.run.id), String(recovery.run.id - 1));
  assert.equal(verifier.recoveryNeeded(recovery.run, recovery.headSha, [check]), true);
  assert.equal(verifier.recoveryNeeded(recovery.run, 'a'.repeat(40), recovery.checks), true);
});

test('retry collection selects one newest artifact ID per journey and revision', () => {
  assert.equal(typeof verifier.latestArtifacts, 'function');
  const selected = verifier.latestArtifacts(artifacts.artifacts, artifacts.selection, artifacts.baseSha);
  assert.deepEqual(selected.map(item => item.id).sort(), [...artifacts.expectedIds].sort());
  assert.equal(new Set(selected.map(item => item.name)).size, selected.length);
  assert.deepEqual(verifier.latestArtifacts([...artifacts.artifacts].reverse(), artifacts.selection, artifacts.baseSha), selected);
  const headOnly = verifier.latestArtifacts(artifacts.artifacts, { ...artifacts.selection, compareBase: false }, artifacts.baseSha);
  assert.deepEqual(headOnly.map(item => item.name).sort(), ['verify-chat-focus', 'verify-command-palette']);
});

test('retry collection downloads exact IDs and replaces evidence without duplicate extraction', { skip: process.platform !== 'linux' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-retry-'));
  try {
    const bin = path.join(dir, 'bin');
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.GH_REQUESTS, JSON.stringify(args) + '\\n');
if (args[0] === 'run') {
  console.error('duplicate artifact extraction: action.focus.json: file exists');
  process.exit(1);
}
if (args.some(arg => /\\/artifacts\\/\\d+\\/zip$/.test(arg))) {
  process.stdout.write(Buffer.from(process.env.GH_ARCHIVE, 'base64'));
} else {
  const artifacts = JSON.parse(fs.readFileSync(process.env.GH_ARTIFACTS, 'utf8')).artifacts;
  process.stdout.write(artifacts.map(item => args.includes('.artifacts[].name') ? item.name : JSON.stringify(item)).join('\\n') + '\\n');
}
`, { mode: 0o755 });
    const selection = path.join(dir, 'selection.json');
    fs.writeFileSync(selection, JSON.stringify(artifacts.selection));
    const evidence = path.join(dir, 'evidence');
    const requests = path.join(dir, 'requests.jsonl');
    const env = {
      ...process.env,
      PATH: `${bin}${path.delimiter}${process.env.PATH}`,
      REPO: 'valentinyeo/multiprompt',
      RUN_ID: artifacts.runId,
      GH_ARTIFACTS: path.join(__dirname, 'fixtures/SOFT-2498/artifacts.json'),
      GH_REQUESTS: requests,
      GH_ARCHIVE: 'UEsDBBQAAAAAAAAAIVw/cY1iJQAAACUAAAALAAAAcmVzdWx0Lmpzb257InN0YXR1cyI6InBhc3NlZCIsInZlcnNpb24iOiJyZXRyeSJ9UEsDBBQAAAAAAAAAIVys7j7LFAAAABQAAAARAAAAYWN0aW9uLmZvY3VzLmpzb257ImNhcHR1cmUiOiJsYXRlc3QifVBLAQIUAxQAAAAAAAAAIVw/cY1iJQAAACUAAAALAAAAAAAAAAAAAACAAQAAAAByZXN1bHQuanNvblBLAQIUAxQAAAAAAAAAIVys7j7LFAAAABQAAAARAAAAAAAAAAAAAACAAU4AAABhY3Rpb24uZm9jdXMuanNvblBLBQYAAAAAAgACAHgAAACRAAAAAAA=',
    };
    for (let attempt = 0; attempt < 2; attempt++) {
      const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'download', selection, evidence, artifacts.baseSha], { env, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      for (const name of ['verify-chat-focus', `verify-chat-focus-${artifacts.baseSha}`, 'verify-command-palette', `verify-command-palette-${artifacts.baseSha}`]) {
        const proof = path.join(evidence, name, 'action.focus.json');
        assert.ok(fs.existsSync(proof), `${name} retained its evidence`);
        assert.equal(JSON.parse(fs.readFileSync(proof, 'utf8')).capture, 'latest');
      }
    }
    const calls = fs.readFileSync(requests, 'utf8').trim().split('\n').map(line => JSON.parse(line));
    const downloaded = calls.flatMap(args => args.filter(arg => /\/artifacts\/\d+\/zip$/.test(arg)).map(arg => Number(arg.match(/\/artifacts\/(\d+)\/zip$/)[1])));
    assert.deepEqual(downloaded.sort(), [...artifacts.expectedIds, ...artifacts.expectedIds].sort());
    assert.ok(calls.every(args => args[0] !== 'run'));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
