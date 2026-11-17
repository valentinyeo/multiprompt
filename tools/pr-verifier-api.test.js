const nodeTest = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const verifier = require('./pr-verifier.cjs');
const head = 'a'.repeat(40);

function test(name, fn) {
  nodeTest(name, { skip: process.platform === 'win32' }, t => {
    assert.equal(typeof verifier.githubState, 'function');
    return fn(t);
  });
}

function fixture(t, responses) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-api-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.writeFileSync(path.join(dir, 'responses'), JSON.stringify(responses));
  fs.writeFileSync(path.join(dir, 'gh'), String.raw`#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.REQUESTS, JSON.stringify(args) + '\n');
if (args.some(arg => arg.includes('/test.yml/runs'))) { console.log(process.env.WORKFLOW_RUNS || '[{"id":1,"status":"completed","conclusion":"success"}]'); process.exit(0); }
if (!args.includes('graphql')) process.exit(2);
const responses = JSON.parse(fs.readFileSync(process.env.RESPONSES, 'utf8'));
console.log(JSON.stringify(responses.shift()));
fs.writeFileSync(process.env.RESPONSES, JSON.stringify(responses));
`, { mode: 0o755 });
  return { dir, env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, REQUESTS: path.join(dir, 'requests'), RESPONSES: path.join(dir, 'responses'), GITHUB_OUTPUT: path.join(dir, 'output'), REPO: 'owner/repo', HEAD_SHA: head },
    requests: () => fs.readFileSync(path.join(dir, 'requests'), 'utf8').trim().split('\n').map(line => JSON.parse(line)) };
}

const suite = (id, status, conclusion, name = 'Tests') => ({ status, conclusion, workflowRun: { databaseId: id, workflow: { name } } });
const state = suites => ({ data: { repository: { object: { checkSuites: { nodes: suites } } } } });
const modulePath = path.join(__dirname, 'pr-verifier.cjs');

test('one GraphQL query returns current-head Tests state without per-job REST calls', t => {
  const f = fixture(t, [state([suite(1, 'COMPLETED', 'SUCCESS'), suite(2, 'IN_PROGRESS', null), suite(3, 'COMPLETED', 'SUCCESS', 'Other workflow')])]);
  const result = spawnSync(process.execPath, ['-e', `const v=require(${JSON.stringify(modulePath)}); console.log(JSON.stringify(v.githubState(process.env,{headSha:process.env.HEAD_SHA})));`], { env: f.env, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const snapshot = JSON.parse(result.stdout);
  assert.equal(verifier.testsGate(snapshot.tests).action, 'wait');
  assert.equal(snapshot.tests.length, 2);
  assert.equal(f.requests().length, 1);
  assert.ok(f.requests()[0].includes(`head=${head}`));
});

test('recovery batches PR, verdict, comments, bot identity, and Tests into one snapshot', t => {
  const f = fixture(t, [{ data: { repository: { pullRequest: { number: 1076, state: 'OPEN', isDraft: false, headRefOid: head, baseRefName: 'master', title: 'CI speed', body: '', headRepository: { nameWithOwner: 'owner/repo' },
    comments: { nodes: [{ body: 'proof', author: { __typename: 'Bot', login: 'github-actions' } }] },
    commits: { nodes: [{ commit: { checkSuites: { nodes: [{ ...suite(1, 'COMPLETED', 'SUCCESS'), verdicts: { nodes: [{ databaseId: 4, name: 'pstack-verifier', status: 'COMPLETED', conclusion: 'SUCCESS', summary: 'proof' }] } }] } } }] } } } } }]);
  const result = spawnSync(process.execPath, ['-e', `const v=require(${JSON.stringify(modulePath)}); console.log(JSON.stringify(v.githubState(process.env,{number:1076})));`], { env: f.env, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const snapshot = JSON.parse(result.stdout);
  assert.equal(snapshot.pr.head.sha, head);
  assert.equal(snapshot.checks[0].head_sha, head);
  assert.equal(snapshot.comments[0].user.login, 'github-actions[bot]');
  assert.equal(verifier.testsGate(snapshot.tests).action, 'pass');
  assert.equal(f.requests().length, 1);
});

test('Tests waiting backs off from one minute to five minutes instead of polling every thirty seconds', t => {
  const f = fixture(t, [...Array(5).fill(state([suite(1, 'IN_PROGRESS', null)])), state([suite(1, 'COMPLETED', 'SUCCESS')])]);
  const delays = path.join(f.dir, 'delays');
  const script = `const fs=require('node:fs'); global.setTimeout=(fn,delay)=>{fs.appendFileSync(${JSON.stringify(delays)},delay+'\\n');fn();}; const v=require(${JSON.stringify(modulePath)});v.waitForTests(process.env).catch(error=>{console.error(error);process.exitCode=1;});`;
  const result = spawnSync(process.execPath, ['-e', script], { env: f.env, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(fs.readFileSync(delays, 'utf8').trim().split('\n').map(Number), [60000, 120000, 240000, 300000, 300000]);
  assert.match(fs.readFileSync(f.env.GITHUB_OUTPUT, 'utf8'), /result=PASS/);
  assert.equal(f.requests().filter(args => args.includes('graphql')).length, 6);
  assert.equal(f.requests().filter(args => args.some(arg => arg.includes('/test.yml/runs'))).length, 1);
});

test('query failures and missing head state cannot produce a successful Tests result', t => {
  for (const response of [{ errors: [{ message: 'rate limited' }] }, { data: { repository: { object: null } } }]) {
    const f = fixture(t, [response]);
    const result = spawnSync(process.execPath, [modulePath, 'wait-for-tests'], { env: f.env, encoding: 'utf8' });
    assert.notEqual(result.status, 0);
    assert.doesNotMatch(result.stdout, /result=PASS/);
    assert.match(fs.readFileSync(f.env.GITHUB_OUTPUT, 'utf8'), /result=BLOCKED/);
    assert.equal(f.requests().length, 1);
  }
});


test('the Tests waiter can read GraphQL check suites with its scoped workflow token', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier.yml'), 'utf8');
  const waiter = workflow.split('  tests:\n')[1].split('  resolve:\n')[0];
  assert.match(waiter, /permissions:[\s\S]*checks: read/);
});


test('terminal suite state is confirmed against the actual workflow, not verifier-created checks', t => {
  for (const [suiteResult, workflowResult, expected] of [['FAILURE', 'success', 'PASS'], ['SUCCESS', 'failure', 'FAIL']]) {
    const f = fixture(t, [state([suite(1, 'COMPLETED', suiteResult)])]);
    const result = spawnSync(process.execPath, [modulePath, 'wait-for-tests'], { env: { ...f.env, WORKFLOW_RUNS: JSON.stringify([{ id: 1, status: 'completed', conclusion: workflowResult }]) }, encoding: 'utf8' });
    assert.equal(result.status, expected === 'PASS' ? 0 : 1, result.stderr);
    const output = fs.readFileSync(f.env.GITHUB_OUTPUT, 'utf8');
    assert.match(output, new RegExp(`result=${expected}`));
    assert.equal(f.requests().length, 2);
    assert.ok(f.requests().some(args => args.some(arg => arg.includes(`head_sha=${head}`))));
  }
});
