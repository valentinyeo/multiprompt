const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const verifier = require('./pr-verifier.cjs');

const root = path.join(__dirname, '..');
const head = 'a'.repeat(40);
const workflow = fs.readFileSync(path.join(root, '.github/workflows/pr-verifier.yml'), 'utf8');

function scratch(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-ci-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

test('the CI-only judge receives the actual patch and check results, not just PR claims', t => {
  const dir = scratch(t);
  fs.writeFileSync(path.join(dir, 'pr.md'), 'Untrusted claim: every check passed');
  fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: head }));
  fs.writeFileSync(path.join(dir, 'selection.json'), JSON.stringify({ features: [], reason: 'The picker suggested chat-still' }));
  fs.writeFileSync(path.join(dir, 'ci.json'), JSON.stringify({ checks: [{ name: 'test', head_sha: head, status: 'completed', conclusion: 'success', details_url: 'https://example.test/run/1' }] }));
  fs.writeFileSync(path.join(dir, 'diff.patch'), '- name: verify-chat-delivery\n+ name: verify-chat-working-live\n');
  const material = verifier.judgeInputs(dir, path.join(dir, 'evidence'));
  assert.match(material, /### ci\.json\n/);
  assert.match(material, new RegExp(head));
  assert.match(material, /### diff\.patch\n- name: verify-chat-delivery\n\+ name: verify-chat-working-live/);
  const prompt = verifier.judgeMessages(material)[0].content;
  assert.match(prompt, /selection\.features.*authoritative/);
  assert.match(prompt, /CI-only.*not missing journey evidence/);
  assert.match(prompt, /BLOCKED.*CI evidence/);
});

test('CI-owned checks supply exact-head raw findings to the judge and fail closed without them', t => {
  const dir = scratch(t);
  const evidence = path.join(dir, 'evidence');
  const artifact = path.join(evidence, 'chat-delivery-formal');
  fs.mkdirSync(artifact, { recursive: true });
  fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: head }));
  fs.writeFileSync(path.join(dir, 'selection.json'), JSON.stringify({ features: [], ciWorkflows: ['chat-delivery-formal.yml'] }));
  fs.writeFileSync(path.join(dir, 'ci.json'), JSON.stringify({ checks: [{ head_sha: head }] }));
  fs.writeFileSync(path.join(dir, 'diff.patch'), 'formal-check patch');
  assert.throws(() => verifier.judgeInputs(dir, evidence), /CI workflow evidence/);
  const receipt = { workflow: 'chat-delivery-formal.yml', head_sha: head, conclusion: 'success', id: 2, artifact: 'chat-delivery-formal' };
  fs.writeFileSync(path.join(evidence, 'ci-workflows.json'), JSON.stringify([receipt]));
  assert.throws(() => verifier.judgeInputs(dir, evidence), /CI workflow evidence/);
  fs.writeFileSync(path.join(artifact, 'summary.json'), JSON.stringify({ failures: ['NoFalseNotSent'], mutations_caught: ['NoFalseNotSent'], inherited_from: 'b'.repeat(40) }));
  const material = verifier.judgeInputs(dir, evidence);
  assert.match(material, /ci-workflows\.json/);
  assert.match(material, /chat-delivery-formal\/summary\.json/);
  assert.match(material, /NoFalseNotSent/);
  for (const change of [{ head_sha: 'b'.repeat(40) }, { conclusion: 'failure' }, { conclusion: null }, { artifact: 'different' }]) {
    fs.writeFileSync(path.join(evidence, 'ci-workflows.json'), JSON.stringify([{ ...receipt, ...change }]));
    assert.throws(() => verifier.judgeInputs(dir, evidence), /CI workflow evidence/);
  }
});

test('CI-only review fails closed without its CI snapshot or source patch', t => {
  const dir = scratch(t);
  fs.writeFileSync(path.join(dir, 'selection.json'), '{"features":[]}');
  assert.throws(() => verifier.judgeInputs(dir, dir), /CI-only.*evidence/);
  fs.writeFileSync(path.join(dir, 'ci.json'), '{"checks":[]}');
  assert.throws(() => verifier.judgeInputs(dir, dir), /CI-only.*evidence/);
  fs.writeFileSync(path.join(dir, 'diff.patch'), 'actual patch');
  assert.throws(() => verifier.judgeInputs(dir, dir), /CI-only.*evidence/);
  fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: head }));
  fs.writeFileSync(path.join(dir, 'ci.json'), JSON.stringify({ checks: [{ head_sha: 'b'.repeat(40) }] }));
  assert.throws(() => verifier.judgeInputs(dir, dir), /CI-only.*does not match the PR head/);
});

test('an intentional empty plan is distinguished from missing selected journey results', t => {
  const dir = scratch(t);
  fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: head }));
  fs.writeFileSync(path.join(dir, 'ci.json'), JSON.stringify({ checks: [{ name: 'test', head_sha: head, status: 'completed', conclusion: 'success' }] }));
  fs.writeFileSync(path.join(dir, 'diff.patch'), 'actual patch');
  assert.match(workflow, /Read verifier-out\/judge-inputs\.md/);
  for (const features of [[], ['appearance']]) {
    fs.writeFileSync(path.join(dir, 'selection.json'), JSON.stringify({ features, compareBase: false }));
    const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'summarize', path.join(dir, 'evidence'), path.join(dir, 'selection.json'), 'b'.repeat(40), dir], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    const evidence = fs.readFileSync(path.join(dir, 'evidence.md'), 'utf8');
    if (!features.length) {
      assert.match(evidence, /No desktop journeys were selected/);
      assert.match(evidence, /ci\.json/);
      const shared = fs.readFileSync(path.join(dir, 'judge-inputs.md'), 'utf8');
      assert.match(shared, /### ci\.json/);
      assert.match(shared, /### diff\.patch/);
    } else {
      assert.match(evidence, /appearance: head missing/);
      assert.doesNotMatch(evidence, /No desktop journeys were selected/);
    }
  }
  fs.writeFileSync(path.join(dir, 'selection.json'), '{"features":[]}');
  fs.writeFileSync(path.join(dir, 'ci.json'), JSON.stringify({ checks: [{ head_sha: 'b'.repeat(40) }] }));
  fs.rmSync(path.join(dir, 'judge-inputs.md'));
  const invalid = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'summarize', path.join(dir, 'evidence'), path.join(dir, 'selection.json'), 'b'.repeat(40), dir], { encoding: 'utf8' });
  assert.notEqual(invalid.status, 0);
  assert.equal(fs.existsSync(path.join(dir, 'judge-inputs.md')), false);
});

test('CI-only review never promotes FAIL, BLOCKED or failed Tests to a passing verdict', () => {
  for (const [verdict, jobs, expected] of [
    ['FAIL', {}, 'FAIL'],
    ['BLOCKED', {}, 'BLOCKED'],
    ['PASS+NOTES', { tests: { result: 'failure', outputs: { result: 'FAIL' } } }, 'FAIL'],
  ]) {
    const result = verifier.finalize({ verdict: { verdict }, headSha: head, summary: { head: {}, base: {} }, selection: { features: [], compareBase: false }, jobs });
    assert.equal(result.final, expected);
  }
});

test('the workflow collects all exact-head CI checks once and never reuses an old snapshot on API failure', { skip: process.platform === 'win32' }, t => {
  const dir = scratch(t);
  fs.mkdirSync(path.join(dir, 'verifier-out'));
  const step = workflow.split('      - name: Collect current-head CI evidence\n')[1]?.split(/\n      - /)[0];
  assert.ok(step, 'CI-only verdicts need current-head CI evidence');
  assert.match(step, /if: .*needs\.select\.outputs\.features == '\[\]'/);
  assert.match(step, /HEAD_SHA: \$\{\{ needs\.resolve\.outputs\.head_sha \}\}/);
  assert.match(step, /shell: bash/);
  const script = step.split('        run: |\n')[1].replace(/^          /gm, '');
  fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.REQUESTS, JSON.stringify(args) + '\\n');
if (args.includes('--slurp') && args.includes('--jq')) process.exit(2);
if (process.env.API_ERROR) process.exit(7);
for (const page of JSON.parse(process.env.PAGES)) console.log(JSON.stringify(page));
if (process.env.PARTIAL_API_ERROR) process.exit(7);
`, { mode: 0o755 });
  const env = { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, REQUESTS: path.join(dir, 'requests'), HEAD_SHA: head, REPO: 'owner/repo', PAGES: JSON.stringify([
    { check_runs: [{ name: 'test', head_sha: head, status: 'completed', conclusion: 'success', details_url: 'https://example.test/tests' }, { name: 'pstack-verifier', head_sha: head, conclusion: 'failure' }] },
    { check_runs: [{ name: 'counters', head_sha: head, status: 'completed', conclusion: 'success', details_url: 'https://example.test/counters' }] },
  ]) };
  const run = extra => spawnSync('bash', ['-e', '-o', 'pipefail', '-c', script], { cwd: dir, env: { ...env, ...extra }, encoding: 'utf8' });
  const result = run({});
  assert.equal(result.status, 0, result.stderr);
  const snapshot = JSON.parse(fs.readFileSync(path.join(dir, 'verifier-out/ci.json'), 'utf8'));
  assert.deepEqual(snapshot.checks.map(check => check.name), ['test', 'counters']);
  assert.ok(snapshot.checks.every(check => check.head_sha === head));
  const calls = fs.readFileSync(env.REQUESTS, 'utf8').trim().split('\n').map(JSON.parse);
  assert.equal(calls.length, 1);
  assert.ok(calls[0].includes(`repos/owner/repo/commits/${head}/check-runs?filter=latest&per_page=100`));
  assert.ok(calls[0].includes('--paginate'));
  assert.equal(calls[0].includes('--slurp'), false);
  assert.equal(calls[0].includes('--jq'), false);
  assert.notEqual(run({ API_ERROR: '1' }).status, 0);
  assert.equal(fs.readFileSync(path.join(dir, 'verifier-out/ci.json'), 'utf8'), '');
  assert.notEqual(run({ PAGES: '[{"check_runs":[]}]' }).status, 0);
  assert.equal(run({ PARTIAL_API_ERROR: '1' }).status, 7);
});
