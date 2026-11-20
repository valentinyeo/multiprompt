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

test('CI artifact download uses the successful exact-head workflow, not a desktop artifact', { skip: process.platform === 'win32' }, t => {
  const dir = scratch(t);
  const evidence = path.join(dir, 'evidence');
  fs.writeFileSync(path.join(dir, 'selection.json'), JSON.stringify({ features: [], ciWorkflows: ['chat-delivery-formal.yml'] }));
  fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: head }));
  const archive = path.join(dir, 'formal.zip');
  const zip = spawnSync('python3', ['-c', 'import sys, zipfile; z=zipfile.ZipFile(sys.argv[1], "w"); z.writestr("summary.json", "{\\"failures\\":[\\"NoFalseNotSent\\"]}"); z.close()', archive], { encoding: 'utf8' });
  assert.equal(zip.status, 0, zip.stderr);
  fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.REQUESTS, JSON.stringify(args) + '\\n');
const url = args[1];
if (url.includes('/actions/runs/999/artifacts')) process.exit(0);
if (url.includes('/chat-delivery-formal.yml/runs?')) console.log(JSON.stringify([{id: 7, head_sha: process.env.HEAD_SHA, status: 'completed', conclusion: 'success'}]));
else if (url.includes('/actions/runs/7/artifacts')) console.log(JSON.stringify([{id: 77, name: 'chat-delivery-formal', expired: false}]));
else if (url.endsWith('/actions/artifacts/77/zip')) process.stdout.write(fs.readFileSync(process.env.ARCHIVE));
else process.exit(3);
`, { mode: 0o755 });
  const requests = path.join(dir, 'requests');
  const result = spawnSync(process.execPath, [path.join(root, 'tools/pr-verifier.cjs'), 'download', path.join(dir, 'selection.json'), evidence], {
    encoding: 'utf8', env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, REQUESTS: requests, ARCHIVE: archive, HEAD_SHA: head, RUN_ID: '999', REPO: 'owner/repo' },
  });
  assert.equal(result.status, 0, result.stderr);
  const summary = path.join(evidence, 'chat-delivery-formal/summary.json');
  assert.ok(fs.existsSync(summary), 'The selected CI workflow must supply its raw formal findings');
  assert.deepEqual(JSON.parse(fs.readFileSync(summary, 'utf8')).failures, ['NoFalseNotSent']);
  const [receipt] = JSON.parse(fs.readFileSync(path.join(evidence, 'ci-workflows.json'), 'utf8'));
  assert.equal(receipt.head_sha, head);
  assert.equal(receipt.id, 7);
  assert.equal(receipt.artifact_id, 77);
  assert.match(fs.readFileSync(requests, 'utf8'), /event=pull_request/);
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
  assert.match(workflow, /write-judge-request verifier-out/);
  for (const features of [[], ['appearance']]) {
    fs.writeFileSync(path.join(dir, 'selection.json'), JSON.stringify({ features }));
    const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'summarize', path.join(dir, 'evidence'), path.join(dir, 'selection.json'), dir], { encoding: 'utf8' });
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
  const invalid = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'summarize', path.join(dir, 'evidence'), path.join(dir, 'selection.json'), dir], { encoding: 'utf8' });
  assert.notEqual(invalid.status, 0);
  assert.equal(fs.existsSync(path.join(dir, 'judge-inputs.md')), false);
});

test('CI-only review never promotes FAIL, BLOCKED or failed Tests to a passing verdict', () => {
  for (const [verdict, jobs, expected] of [
    ['FAIL', {}, 'FAIL'],
    ['BLOCKED', {}, 'BLOCKED'],
    ['PASS+NOTES', { tests: { result: 'failure', outputs: { result: 'FAIL' } } }, 'FAIL'],
  ]) {
    const result = verifier.finalize({ verdict: { verdict }, headSha: head, summary: { head: {} }, selection: { features: [] }, jobs });
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

test('the CI receipt summary merges parts, records the base proof and fails on a red head', t => {
  const dir = scratch(t);
  const run = (...args) => spawnSync(process.execPath, [path.join(__dirname, 'ci-receipt-summary.mjs'), ...args], { encoding: 'utf8', env: { ...process.env, HEAD_SHA: head } });
  fs.writeFileSync(path.join(dir, 'head.log'), 'ok 1 - the cancellation observer\n# pass 1\n# fail 0\n');
  fs.writeFileSync(path.join(dir, 'base.log'), 'not ok 1 - the cancellation observer\n  spawnSync gh ENOBUFS\n# pass 0\n# fail 1\n');
  fs.writeFileSync(path.join(dir, 'win.log'), 'CPU961 trial\nCPU991 matching slowest_median_ms=31\n');
  const pattern = 'ENOBUFS|^(ok|not ok) [0-9]+ - the cancellation observer|^# (pass|fail) ';
  assert.equal(run(path.join(dir, 'out'), 'tools', path.join(dir, 'head.log'), '0', pattern, path.join(dir, 'base.log'), '1').status, 0);
  assert.equal(run(path.join(dir, 'out'), 'echo-budget', path.join(dir, 'win.log'), '0', '^CPU(961|991) ').status, 0);
  const summary = JSON.parse(fs.readFileSync(path.join(dir, 'out/summary.json'), 'utf8'));
  assert.deepEqual(summary.repro, { part: 'tools', base_exit_code: 1, head_exit_code: 0 });
  assert.deepEqual(Object.keys(summary.parts), ['tools', 'echo-budget']);
  assert.ok(summary.parts.tools.base_lines.some(line => line.includes('ENOBUFS')));
  assert.equal(summary.head_sha, head);
  assert.equal(summary.exit_code, 0);
  assert.equal(run(path.join(dir, 'out2'), 'tools', path.join(dir, 'head.log'), '1', pattern).status, 1);
  assert.equal(JSON.parse(fs.readFileSync(path.join(dir, 'out2/summary.json'), 'utf8')).exit_code, 1);
  assert.equal(run(path.join(dir, 'out3'), 'tools', path.join(dir, 'head.log'), '0', pattern, path.join(dir, 'base.log')).status, 2);
});
