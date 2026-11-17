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
if (args[0] === 'pr') console.log(process.env.PR_FIXTURE);
else if (args.some(arg => arg.endsWith('/jobs'))) console.log(JSON.stringify({ name: 'head appearance / verify (appearance)', conclusion: 'success' }));
else console.log(args[1].includes('/commits/') ? 'b'.repeat(40) : 'c'.repeat(40));
`, { mode: 0o755 });
    const output = path.join(dir, 'outputs');
    const env = { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, GITHUB_OUTPUT: output,
      REPO: 'owner/repo', PR_NUMBER: '1', PR_FIXTURE: JSON.stringify({ ...fix, number: 1, state: 'OPEN', headRefOid: 'a'.repeat(40), baseRefName: 'master', commits: [] }) };
    const run = (args, extra = {}) => {
      fs.writeFileSync(output, '');
      const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), ...args], { env: { ...env, ...extra }, encoding: 'utf8' });
      assert.equal(result.status, 0, result.stderr);
      return fs.readFileSync(output, 'utf8');
    };
    assert.match(run(['resolve']), new RegExp(`base_sha=${'b'.repeat(40)}`));
    run(['prepare', dir]);
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
