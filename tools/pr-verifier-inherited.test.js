const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const verifier = require('./pr-verifier.cjs');

const head = 'a'.repeat(40);
const selection = { features: ['appearance'], reason: '', uncovered: '', doneWhen: [] };

function evidence(t, result) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pr-verifier-inherited-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(dir, 'verify-appearance'));
  fs.writeFileSync(path.join(dir, 'verify-appearance', 'result.json'), JSON.stringify(result));
  fs.writeFileSync(path.join(dir, 'verify-appearance', 'after.png'), 'png');
  fs.writeFileSync(path.join(dir, 'verify-appearance', 'journey.mp4'), 'mp4');
  return dir;
}

function verdict(t, result, masterFailures = []) {
  const summary = verifier.summarize(evidence(t, result), ['appearance']);
  summary.masterFailures = masterFailures;
  return { summary, ...verifier.finalize({ verdict: { verdict: 'PASS', evidence: [] }, headSha: head, summary, selection, runUrl: 'https://example.test/run/1' }) };
}

test('a head journey the latest master nightly also fails is inherited and capped at PASS+NOTES', t => {
  const { final, body } = verdict(t, { status: 'failed', error: 'no ring' }, ['appearance']);
  assert.equal(final, 'PASS+NOTES');
  assert.match(body, /- Already failing in master's latest nightly verify run, so not caused by this change: appearance\./);
  assert.match(body, /- appearance: head failed \(inherited\)/);
});

test('the judge input marks an inherited journey before it reads the result', t => {
  const summary = verifier.summarize(evidence(t, { status: 'failed', error: 'no ring' }), ['appearance']);
  summary.masterFailures = ['appearance'];
  assert.match(verifier.evidenceMarkdown(summary, selection), /## appearance: head failed, inherited from master nightly/);
});

test('a head journey master does not fail is a FAIL', t => {
  const { final, body } = verdict(t, { status: 'failed', error: 'no ring' });
  assert.equal(final, 'FAIL');
  assert.doesNotMatch(body, /Already failing/);
});

test('another journey failing on master does not inherit this one', t => {
  const { final } = verdict(t, { status: 'failed', error: 'no ring' }, ['chat-view']);
  assert.equal(final, 'FAIL');
});

test('a passing head journey is PASS even when master fails the same journey', t => {
  const { final } = verdict(t, { status: 'passed' }, ['appearance']);
  assert.equal(final, 'PASS');
});

test('lost screenshots still block an inherited journey', t => {
  const dir = evidence(t, { status: 'failed', error: 'no ring' });
  fs.unlinkSync(path.join(dir, 'verify-appearance', 'after.png'));
  const summary = verifier.summarize(dir, ['appearance']);
  summary.masterFailures = ['appearance'];
  assert.equal(verifier.finalize({ verdict: { verdict: 'PASS+NOTES' }, summary, selection }).final, 'BLOCKED');
});

function fakeGh(t, master) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-nightly-gh-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
const args = process.argv.slice(2);
const endpoint = args.find(arg => arg.startsWith('repos/')) || '';
if (endpoint.includes('/workflows/verify.yml/runs')) process.stdout.write(JSON.stringify([{ id: 7, html_url: 'https://example.test/run/7' }]));
else if (endpoint.includes('/workflows/test.yml/runs')) process.stdout.write(JSON.stringify([{ id: 4, html_url: 'https://example.test/run/4' }]));
else if (endpoint.endsWith('/jobs?per_page=100')) {
  const run = Number(endpoint.match(/\\/runs\\/(\\d+)\\/jobs/)[1]);
  const master = run !== 7;
  const jobs = master
    ? [{ name: 'test-vps (3)', conclusion: ${JSON.stringify(master)} }, { name: 'reader-tests', conclusion: 'success' }]
    : [{ name: 'build-app', conclusion: 'failure' }, { name: 'verify (appearance)', conclusion: 'failure' }, { name: 'verify (chat-view)', conclusion: 'success' }, { name: 'verify (title-bar, 96, dark)', conclusion: 'failure' }];
  process.stdout.write(JSON.stringify([{ jobs }]));
} else process.exit(2);
`, { mode: 0o755 });
  const saved = { PATH: process.env.PATH, REPO: process.env.REPO };
  process.env.PATH = `${dir}${path.delimiter}${process.env.PATH}`;
  process.env.REPO = 'owner/repo';
  t.after(() => { process.env.PATH = saved.PATH; process.env.REPO = saved.REPO; });
  return process.env;
}

test('the latest scheduled master verify run names every failed journey job', t => {
  assert.equal(typeof verifier.masterJourneyFailures, 'function');
  const env = fakeGh(t, 'failure');
  assert.deepEqual(verifier.masterJourneyFailures(env), ['appearance', 'title-bar']);
});

test('an unreadable master run means no journey is inherited', t => {
  const saved = { PATH: process.env.PATH, REPO: process.env.REPO };
  t.after(() => { process.env.PATH = saved.PATH; process.env.REPO = saved.REPO; });
  process.env.PATH = `${fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-no-gh-'))}${path.delimiter}${process.env.PATH}`;
  process.env.REPO = 'owner/repo';
  assert.deepEqual(verifier.masterJourneyFailures(process.env), []);
});

test('a Tests failure the same job also has on master is inherited, not a PR failure', t => {
  assert.equal(typeof verifier.testsInherited, 'function');
  const env = fakeGh(t, 'failure');
  const note = verifier.testsInherited(env, [{ id: 5, status: 'completed', conclusion: 'failure' }]);
  assert.match(note, /Tests failed on test-vps \(3\)/);
  assert.match(note, /the same job failed in master's latest completed run \(https:\/\/example\.test\/run\/4\)/);
});

test('a Tests failure master does not have stays a PR failure', t => {
  const env = fakeGh(t, 'success');
  assert.equal(verifier.testsInherited(env, [{ id: 5, status: 'completed', conclusion: 'failure' }]), '');
});

test('the verdict notes an inherited Tests failure and never turns it into FAIL', () => {
  const { final, body } = verifier.finalize({
    verdict: { verdict: 'PASS', evidence: [] }, headSha: head, runUrl: 'u',
    selection: { features: [] },
    summary: { head: {} },
    jobs: { tests: { result: 'success', outputs: { result: 'INHERITED', note: "Tests failed on test-vps (3), the same job failed in master's latest completed run, so this is not a PR failure." } } },
  });
  assert.equal(final, 'PASS+NOTES');
  assert.match(body, /- Tests failed on test-vps \(3\)/);
});

test('a plain Tests failure still forces FAIL', () => {
  const result = verifier.finalize({ verdict: { verdict: 'PASS' }, headSha: head, selection: { features: [] }, summary: { head: {} }, jobs: { tests: { result: 'success', outputs: { result: 'FAIL' } } } });
  assert.equal(result.final, 'FAIL');
  assert.match(result.body, /- Tests failed for this head\./);
});

function waitGh(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-wait-gh-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.writeFileSync(path.join(dir, 'gh'), `#!/usr/bin/env node
const args = process.argv.slice(2);
const endpoint = args.find(arg => arg.startsWith('repos/')) || '';
const job = conclusion => JSON.stringify([{ jobs: [{ name: 'test-vps (3)', conclusion }, { name: 'reader-tests', conclusion: 'success' }] }]);
const tests = [{ status: 'COMPLETED', conclusion: 'FAILURE', workflowRun: { databaseId: 5, workflow: { name: 'Tests' } } }];
if (args.includes('graphql')) process.stdout.write(JSON.stringify({ data: { repository: { object: { checkSuites: { nodes: tests } } } } }));
else if (endpoint.includes('/workflows/test.yml/runs?head_sha=')) process.stdout.write(JSON.stringify([{ id: 5, status: 'completed', conclusion: 'failure' }]));
else if (endpoint.includes('/workflows/test.yml/runs?branch=master')) process.stdout.write(JSON.stringify([{ id: 4, html_url: 'https://example.test/run/4' }]));
else if (endpoint.endsWith('/actions/runs/5/jobs?per_page=100')) process.stdout.write(job('failure'));
else if (endpoint.endsWith('/actions/runs/4/jobs?per_page=100')) process.stdout.write(job(process.env.GH_MASTER_TESTS));
else process.exit(2);
`, { mode: 0o755 });
  return dir;
}

for (const [master, expected] of [['failure', 'INHERITED'], ['success', 'FAIL']]) {
  test(`the Tests wait reports ${expected} when master's same job is ${master}`, t => {
    const dir = waitGh(t);
    const out = path.join(dir, 'output');
    const result = require('node:child_process').spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'wait-for-tests'], {
      encoding: 'utf8',
      env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, REPO: 'owner/repo', HEAD_SHA: head, CI_WORKFLOWS: '[]', GITHUB_OUTPUT: out, POLL_MS: '10', MAX_POLL_MS: '10', GH_MASTER_TESTS: master },
    });
    const output = fs.readFileSync(out, 'utf8');
    assert.match(output, new RegExp(`result=${expected}`));
    assert.equal(result.status, expected === 'INHERITED' ? 0 : 1, result.stderr);
    if (expected === 'INHERITED') assert.match(output, /note=.*test-vps \(3\).*same job failed in master's latest completed run/);
  });
}
