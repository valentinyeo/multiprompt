const assert = require('node:assert/strict');
const { test } = require('node:test');
const verifier = require('./pr-verifier.cjs');

function finish(pr, masterFails = false, headStatus = 'passed', extra = {}) {
  const selection = verifier.validateSelection({ features: ['appearance'] }, ['appearance'], pr);
  const run = status => ({ status, artifact: 'verify-appearance', error: status === 'failed' ? 'wrong visible appearance' : '', screenshots: ['after.png'], ...extra });
  const summary = { head: { appearance: [run(headStatus)] } };
  if (masterFails) summary.masterFailures = ['appearance'];
  return verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: 'a'.repeat(40), summary, selection, runUrl: 'https://example.test/run' });
}

const fix = { title: 'fix(settings): preserve appearance', body: 'Repro journey: `appearance`' };

test('an emergency label uses the owned-journey repair rule', () => {
  const emergency = { title: 'MUBO-235: Restore chat reachability', labels: [{ name: 'emergency' }], body: 'Repro journey: `appearance`' };
  assert.equal(finish(emergency, true).final, 'PASS');
  const selection = verifier.validateSelection({ features: ['sessions'] }, ['appearance', 'sessions'], emergency);
  assert.deepEqual(selection.features, ['sessions']);
  assert.equal(selection.bugFix, true);
});

test('a repair PR passes on its touched journey without a named repro', () => {
  for (const pr of [fix, { title: 'Settings repair', labels: [{ name: 'bug' }], body: fix.body }]) {
    for (const masterFails of [false, true]) {
      assert.equal(finish(pr, masterFails).final, 'PASS', JSON.stringify(pr));
    }
  }
});

test('a declared repro line never changes the selection', () => {
  const declared = verifier.validateSelection({ features: ['sessions'] }, ['appearance', 'sessions'], fix);
  const undeclared = verifier.validateSelection({ features: ['sessions'] }, ['appearance', 'sessions'], { title: 'Bug fix: settings' });
  assert.deepEqual(declared.features, ['sessions']);
  assert.deepEqual(undeclared.features, ['sessions']);
  assert.equal(declared.bugFix, true);
  assert.equal(undeclared.bugFix, true);
});

test('a repair label adds no journey when the diff maps to none', () => {
  for (const pr of [
    ...['bug', 'bug-fix', 'bugfix', 'bug fix', 'defect', 'regression'].map(name => ({ labels: [{ name }] })),
    ...['fix: appearance', 'Fix appearance', 'Appearance bug fix', 'bugfix: appearance'].map(title => ({ title })),
  ]) {
    const selection = verifier.validateSelection({ features: [] }, ['appearance'], pr);
    assert.deepEqual(selection.features, [], JSON.stringify(pr));
    const result = verifier.finalize({ verdict: { verdict: 'PASS' }, selection, summary: { head: {} } });
    assert.notEqual(result.final, 'FAIL', JSON.stringify(pr));
  }
});

test('a PR that is not a repair passes on its touched journey', () => {
  assert.equal(finish({ title: 'Document appearance' }).final, 'PASS');
});

test('the CLI selects only touched sources and publishes a passing verdict without a repro', { skip: process.platform === 'win32' }, () => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-repro-'));
  try {
    fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
const args = process.argv.slice(2);
require('node:fs').appendFileSync(process.env.GH_REQUESTS, JSON.stringify(args) + '\\n');
if (args[0] === 'pr') console.log(process.env.PR_FIXTURE);
else if (args.some(arg => arg.endsWith('/jobs'))) console.log(JSON.stringify({ name: 'head / verify (appearance)', conclusion: 'success' }));
else console.log(args[1].includes('/commits/') ? 'b'.repeat(40) : 'c'.repeat(40));
`, { mode: 0o755 });
    const output = path.join(dir, 'outputs');
    const requests = path.join(dir, 'requests.jsonl');
    const env = { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, GITHUB_OUTPUT: output, GH_REQUESTS: requests,
      REPO: 'owner/repo', PR_NUMBER: '1', BASE_SHA: 'HEAD', PR_FIXTURE: JSON.stringify({ ...fix, number: 1, state: 'OPEN', headRefOid: 'a'.repeat(40), baseRefName: 'release', commits: [] }) };
    const run = (args, extra = {}) => {
      fs.writeFileSync(output, '');
      const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), ...args], { env: { ...env, ...extra }, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      return fs.readFileSync(output, 'utf8');
    };
    assert.match(run(['resolve']), new RegExp(`base_sha=${'b'.repeat(40)}`));
    const calls = fs.readFileSync(requests, 'utf8').trim().split('\n').map(line => JSON.parse(line));
    assert.ok(calls.some(args => args.includes('repos/owner/repo/commits/master')), 'repair baselines must be master even for a retargeted PR');
    assert.ok(calls.some(args => args.includes(`repos/owner/repo/statuses/${'a'.repeat(40)}`) && args.includes('state=pending') && args.includes('context=pstack-verifier')), 'a metadata rerun must invalidate a previous green status on the same head');
    run(['prepare', dir]);
    assert.equal(fs.existsSync(path.join(dir, 'mapped.json')), true, 'Preparation saves the touched-source selection');
    assert.equal(fs.existsSync(path.join(dir, 'diff.patch')), true, 'Preparation saves the actual diff for independent CI-only review');
    const selected = run(['select', dir], { SELECTION: JSON.stringify({ features: [] }) });
    assert.match(selected, /features=\[\]/);
    assert.doesNotMatch(selected, /repro_features|base_features/);
    const selectionFile = path.join(dir, 'selection.json');
    const summary = path.join(dir, 'summary.json');
    fs.writeFileSync(summary, JSON.stringify({ head: {} }));
    assert.match(run(['finalize', selectionFile, summary, dir], { VERDICT: '{"verdict":"PASS"}', RUN_ID: '', JOB_RESULTS: '{}' }), /result=PASS\+NOTES/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

const ciFix = { title: 'SOFT-2728: Fix master red checks' };
const ciSelection = (extra = {}) => ({ ...verifier.validateSelection({ features: [] }, ['appearance'], ciFix), ciWorkflows: ['ci-repair-receipt.yml'], unmapped: [], ...extra });
const ciReceipt = (extra = {}) => ({ head: {}, ciRepro: [{ workflow: 'ci-repair-receipt.yml', part: 'tools', base_exit_code: 1, head_exit_code: 0, ...extra }] });
const ciFinish = (selection, summary) => verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: 'a'.repeat(40), summary, selection, runUrl: 'https://example.test/run' });
const passing = { head: { appearance: [{ status: 'passed', screenshots: ['after.png'] }] } };

test('a repair whose files are all owned by a CI workflow passes when that receipt shows base red and head green', () => {
  const result = ciFinish(ciSelection(), ciReceipt());
  assert.notEqual(result.final, 'FAIL');
  assert.match(result.body, /Repro by CI workflow: ci-repair-receipt\.yml \(tools: base exit 1, head exit 0\)/);
});

test('a CI receipt is not a repro when base stayed green, head is red, or the receipt is missing', () => {
  for (const summary of [ciReceipt({ base_exit_code: 0 }), ciReceipt({ head_exit_code: 1 }), ciReceipt({ base_exit_code: null }), { head: {} }, { head: {}, ciRepro: [{ workflow: 'other.yml', part: 'tools', base_exit_code: 1, head_exit_code: 0 }] }]) {
    assert.equal(ciFinish(ciSelection(), summary).final, 'FAIL', JSON.stringify(summary));
  }
});

test('a repair PR with a touched journey is judged on that journey alone', () => {
  const result = ciFinish(ciSelection({ features: ['appearance'] }), passing);
  assert.equal(result.final, 'PASS');
  assert.doesNotMatch(result.body, /Repro journey/i);
});

test('a repair PR whose files no journey owns still needs a CI workflow receipt', () => {
  const result = ciFinish(ciSelection({ unmapped: ['src/main.zig'] }), { head: {}, base: {}, ciRepro: [] });
  assert.equal(result.final, 'FAIL');
  assert.match(result.body, /CI workflow receipt.*base.*failed.*head.*passed/i);
});

test('a leftover nearest field never turns a proven CI receipt into a missing journey', () => {
  const result = ciFinish(ciSelection({ nearest: [{ file: 'src/main.zig', feature: 'appearance' }] }), ciReceipt());
  assert.notEqual(result.final, 'FAIL');
  assert.doesNotMatch(result.body, /Nearest mapped feature/);
});

test('a PR that is not a repair never needs the CI receipt', () => {
  const selection = { ...ciSelection(), ...verifier.validateSelection({ features: [] }, ['appearance'], { title: 'Document appearance' }), ciWorkflows: ['ci-repair-receipt.yml'], unmapped: [] };
  assert.notEqual(ciFinish(selection, { head: {} }).final, 'FAIL');
});

test('summarize carries the repro of each selected CI workflow from its raw summary', () => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-ci-repro-'));
  try {
    fs.mkdirSync(path.join(dir, 'evidence/ci-repair-receipt'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'evidence/ci-repair-receipt/summary.json'), JSON.stringify({ repro: { part: 'tools', base_exit_code: 1, head_exit_code: 0 } }));
    fs.writeFileSync(path.join(dir, 'selection.json'), JSON.stringify({ features: [], ciWorkflows: ['ci-repair-receipt.yml'] }));
    fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: 'a'.repeat(40) }));
    fs.writeFileSync(path.join(dir, 'ci-workflows.json'), '[]');
    fs.mkdirSync(path.join(dir, 'evidence'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'evidence/ci-workflows.json'), JSON.stringify([{ workflow: 'ci-repair-receipt.yml', artifact: 'ci-repair-receipt', head_sha: 'a'.repeat(40), conclusion: 'success' }]));
    fs.writeFileSync(path.join(dir, 'ci.json'), JSON.stringify({ checks: [{ head_sha: 'a'.repeat(40) }] }));
    fs.writeFileSync(path.join(dir, 'diff.patch'), 'diff');
    const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'summarize', path.join(dir, 'evidence'), path.join(dir, 'selection.json'), dir], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(dir, 'summary.json'), 'utf8')).ciRepro, [{ workflow: 'ci-repair-receipt.yml', part: 'tools', base_exit_code: 1, head_exit_code: 0 }]);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
