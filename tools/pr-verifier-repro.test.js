const assert = require('node:assert/strict');
const { test } = require('node:test');
const verifier = require('./pr-verifier.cjs');

function finish(pr, baseStatus, headStatus = 'passed', extra = {}) {
  const selection = verifier.validateSelection({ features: ['appearance'], compare_base: false }, ['appearance'], pr);
  const run = status => ({ status, artifact: 'verify-appearance', error: status === 'failed' ? 'wrong visible appearance' : '', screenshots: ['after.png'], ...extra });
  return verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: 'a'.repeat(40),
    summary: { head: { appearance: [run(headStatus)] }, base: { appearance: baseStatus ? [run(baseStatus)] : [] } }, selection, runUrl: 'https://example.test/run' });
}

const fix = { title: 'fix(settings): preserve appearance', body: 'Repro journey: `appearance`' };

test('a fix PR without a failing-on-master repro fails even when the judge says PASS', () => {
  for (const pr of [fix, { title: 'Settings repair', labels: [{ name: 'bug' }], body: fix.body }]) {
    for (const baseStatus of [undefined, 'passed']) {
      const result = finish(pr, baseStatus);
      assert.equal(result.final, 'FAIL');
      assert.match(result.body, /Repro journey.*master.*failed.*head.*passed/i);
    }
  }
});

test('a fix PR must name its repro journey', () => {
  assert.equal(finish({ title: 'Bug fix: settings' }, 'failed').final, 'FAIL');
  assert.equal(finish({ title: 'Settings', labels: [{ name: 'bug-fix' }] }, 'failed').final, 'FAIL');
});

test('the named repro must fail on master and pass on head', () => {
  assert.equal(finish(fix, 'failed').final, 'PASS');
  assert.equal(finish(fix, 'failed', 'failed').final, 'FAIL');
  assert.equal(finish(fix, 'failed', 'passed', { failureKind: 'infrastructure' }).final, 'FAIL');
});

test('an unrelated failing journey cannot substitute for the named repro', () => {
  assert.equal(finish({ ...fix, body: 'Repro journey: `sessions`' }, 'failed').final, 'FAIL');
});

test('unknown, duplicate and slow repro declarations cannot pass', () => {
  for (const body of ['Repro journey: `unknown`', 'Repro journey: `pane-layout`', `${fix.body}\n${fix.body}`]) {
    assert.equal(finish({ ...fix, body }, 'failed').final, 'FAIL');
  }
});

test('repair labels and titles require evidence even without any picked journeys', () => {
  for (const pr of [
    ...['bug', 'bug-fix', 'bugfix', 'bug fix', 'defect', 'regression'].map(name => ({ labels: [{ name }] })),
    ...['fix: appearance', 'Fix appearance', 'Appearance bug fix', 'bugfix: appearance'].map(title => ({ title })),
  ]) {
    const selection = verifier.validateSelection({ features: [] }, ['appearance'], pr);
    const result = verifier.finalize({ verdict: { verdict: 'PASS' }, selection, summary: { head: {}, base: {} } });
    assert.equal(result.final, 'FAIL', JSON.stringify(pr));
  }
});

test('non-fix PRs keep the existing optional baseline behaviour', () => {
  assert.equal(finish({ title: 'Document appearance' }, undefined).final, 'PASS');
});

test('the declared repro takes priority over the picker and forces a master comparison', () => {
  const selected = verifier.validateSelection({ features: ['sessions', 'chat-view', 'title-bar'], compare_base: false }, ['appearance', 'sessions', 'chat-view', 'title-bar'], fix);
  assert.deepEqual(selected.features, ['appearance', 'sessions', 'chat-view']);
  assert.equal(selected.compareBase, true);
  assert.equal(selected.reproJourney, 'appearance');
});

test('the CLI carries real PR metadata into selection, schedules a passing repro on master, and rechecks it at publication', { skip: process.platform === 'win32' }, () => {
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
    assert.equal(fs.existsSync(path.join(dir, 'mapped.json')), true, 'Preparation retains the touched-source selection alongside the required repro');
    assert.equal(fs.existsSync(path.join(dir, 'diff.patch')), true, 'Preparation saves the actual diff for independent CI-only review');
    const selected = run(['select', dir], { SELECTION: JSON.stringify({ features: [], compare_base: false }) });
    assert.match(selected, /repro_features=\["appearance"\]/);
    assert.match(selected, /features=\["appearance"\]/);
    assert.match(run(['failed-head'], { FEATURES: '["appearance"]', REPRO_FEATURES: '["appearance"]', RUN_ID: '1' }), /features=\["appearance"\]/);
    const selectionFile = path.join(dir, 'selection.json');
    const selection = JSON.parse(fs.readFileSync(selectionFile, 'utf8'));
    fs.writeFileSync(selectionFile, JSON.stringify({ ...selection, bugFix: false }));
    const summary = path.join(dir, 'summary.json');
    fs.writeFileSync(summary, JSON.stringify({ head: { appearance: [{ status: 'passed', screenshots: ['after.png'] }] }, base: {} }));
    assert.match(run(['finalize', selectionFile, summary, dir], { VERDICT: '{"verdict":"PASS"}', RUN_ID: '', JOB_RESULTS: '{}' }), /result=FAIL/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

const ciFix = { title: 'SOFT-2728: Fix master red checks' };
const ciSelection = (extra = {}) => ({ ...verifier.validateSelection({ features: [] }, ['appearance'], ciFix), ciWorkflows: ['ci-repair-receipt.yml'], unmapped: [], ...extra });
const ciReceipt = (extra = {}) => ({ head: {}, base: {}, ciRepro: [{ workflow: 'ci-repair-receipt.yml', part: 'tools', base_exit_code: 1, head_exit_code: 0, ...extra }] });
const ciFinish = (selection, summary) => verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: 'a'.repeat(40), summary, selection, runUrl: 'https://example.test/run' });

test('a fix whose files are all owned by a CI workflow passes when that receipt shows base red and head green', () => {
  const result = ciFinish(ciSelection(), ciReceipt());
  assert.notEqual(result.final, 'FAIL');
  assert.match(result.body, /Repro by CI workflow: ci-repair-receipt\.yml \(tools: base exit 1, head exit 0\)/);
});

test('a CI receipt is not a repro when base stayed green, head is red, or the receipt is missing', () => {
  for (const summary of [ciReceipt({ base_exit_code: 0 }), ciReceipt({ head_exit_code: 1 }), ciReceipt({ base_exit_code: null }), { head: {}, base: {} }, { head: {}, base: {}, ciRepro: [{ workflow: 'other.yml', part: 'tools', base_exit_code: 1, head_exit_code: 0 }] }]) {
    assert.equal(ciFinish(ciSelection(), summary).final, 'FAIL', JSON.stringify(summary));
  }
});

test('a product fix or an unmapped file still needs a repro journey despite a CI receipt', () => {
  for (const extra of [{ features: ['appearance'] }, { unmapped: ['src/main.zig'] }, { ciWorkflows: [] }]) {
    const result = ciFinish(ciSelection(extra), ciReceipt());
    assert.equal(result.final, 'FAIL', JSON.stringify(extra));
    assert.match(result.body, /Repro journey.*master.*failed.*head.*passed/i);
  }
});

test('a leftover nearest field never turns a proven CI repro into a missing journey', () => {
  const result = ciFinish(ciSelection({ nearest: [{ file: 'src/main.zig', feature: 'appearance' }] }), ciReceipt());
  assert.notEqual(result.final, 'FAIL');
  assert.doesNotMatch(result.body, /Nearest mapped feature/);
});

test('a PR that is not a fix never needs the CI repro', () => {
  const selection = { ...ciSelection(), ...verifier.validateSelection({ features: [] }, ['appearance'], { title: 'Document appearance' }), ciWorkflows: ['ci-repair-receipt.yml'], unmapped: [] };
  assert.notEqual(ciFinish(selection, { head: {}, base: {} }).final, 'FAIL');
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
    fs.writeFileSync(path.join(dir, 'selection.json'), JSON.stringify({ features: [], ciWorkflows: ['ci-repair-receipt.yml'], compareBase: false }));
    fs.writeFileSync(path.join(dir, 'pr.json'), JSON.stringify({ headRefOid: 'a'.repeat(40) }));
    fs.writeFileSync(path.join(dir, 'ci-workflows.json'), '[]');
    fs.mkdirSync(path.join(dir, 'evidence'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'evidence/ci-workflows.json'), JSON.stringify([{ workflow: 'ci-repair-receipt.yml', artifact: 'ci-repair-receipt', head_sha: 'a'.repeat(40), conclusion: 'success' }]));
    fs.writeFileSync(path.join(dir, 'ci.json'), JSON.stringify({ checks: [{ head_sha: 'a'.repeat(40) }] }));
    fs.writeFileSync(path.join(dir, 'diff.patch'), 'diff');
    const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'summarize', path.join(dir, 'evidence'), path.join(dir, 'selection.json'), 'b'.repeat(40), dir], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(fs.readFileSync(path.join(dir, 'summary.json'), 'utf8')).ciRepro, [{ workflow: 'ci-repair-receipt.yml', part: 'tools', base_exit_code: 1, head_exit_code: 0 }]);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
