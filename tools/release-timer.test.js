const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const { decide, execute, collect } = require('./release-timer.js');

const fixturePath = path.join(__dirname, 'fixtures/SOFT-1944/snapshot.json');
const fixture = () => JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
const plan = input => decide(input, Date.parse(input.now));

test('only the trusted scheduled/manual workflow can mutate, and only its broken output calls the ladder', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/release-timer.yml'), 'utf8');
  assert.match(workflow, /cron: '\*\/30 \* \* \* \*'/);
  assert.doesNotMatch(workflow, /^  pull_request:/m);
  assert.match(workflow, /if: github.repository == 'valentinyeo\/multiprompt' && github.ref == 'refs\/heads\/master'/);
  assert.match(workflow, /cancel-in-progress: false/);
  assert.match(workflow, /runs-on: ubuntu-latest/);
  assert.doesNotMatch(workflow, /self-hosted/);
  assert.equal([...workflow.matchAll(/uses: valentinyeo\/token-ladder\/\.github\/actions\/ladder-call@main/g)].length, 1);
  assert.match(workflow, /if: \$\{\{ !cancelled\(\) && steps.timer.outputs.broken == 'true' \}\}/);
  assert.match(workflow, /default: true/);
});

test('healthy published master needs no model; approved idle PR is a merge candidate', () => {
  const result = plan(fixture());
  assert.deepEqual(result.broken, []);
  assert.deepEqual(result.merge.map(pr => pr.number), [42]);
  assert.deepEqual(result.close, []);
});

test('unreleased newest master is broken only once 45 minutes have elapsed since its push', () => {
  const input = fixture();
  input.release.sha = 'cccccccccccccccccccccccccccccccccccccccc';
  input.master.pushedAt = '2026-11-20T11:15:01Z';
  assert.deepEqual(plan(input).broken, []);
  input.master.pushedAt = '2026-11-20T11:15:00Z';
  assert.match(plan(input).broken[0], /45 minutes/);
  input.release = null;
  assert.equal(plan(input).broken.length, 1);
});

test('a failed release wakes the model before 45 minutes but old recovered failures do not', () => {
  const input = fixture();
  input.releaseRuns[0].conclusion = 'failure';
  assert.deepEqual(plan(input).broken, []);
  input.releaseRuns[0].created_at = '2026-11-20T11:59:00Z';
  input.releaseRuns[0].head_sha = 'dddddddddddddddddddddddddddddddddddddddd';
  assert.match(plan(input).broken[0], /Release workflow failed/);
  input.releaseRuns.push({ ...input.releaseRuns[0], id: 501, conclusion: null });
  assert.deepEqual(plan(input).broken, []);
  input.releaseRuns[1].conclusion = 'timed_out';
  assert.equal(plan(input).broken.length, 1);
});

test('merges wait one hour after PR and check activity', () => {
  const input = fixture();
  input.pulls[0].updatedAt = '2026-11-20T11:00:01Z';
  assert.deepEqual(plan(input).merge, []);
  input.pulls[0].updatedAt = '2026-11-20T11:00:00Z';
  assert.equal(plan(input).merge.length, 1);
  input.pulls[0].statusCheckRollup[0].completedAt = '2026-11-20T11:00:01Z';
  assert.deepEqual(plan(input).merge, []);
});

for (const [field, value] of [['reviewDecision', 'REVIEW_REQUIRED'], ['reviewDecision', 'CHANGES_REQUESTED'], ['mergeable', 'CONFLICTING'], ['mergeable', 'UNKNOWN'], ['isDraft', true], ['isCrossRepository', true], ['baseRefName', 'other'], ['state', 'CLOSED'], ['labels', [{ name: 'hold' }]]]) {
  test(`does not merge ${field}=${JSON.stringify(value)}`, () => {
    const input = fixture();
    input.pulls[0][field] = value;
    assert.deepEqual(plan(input).merge, []);
  });
}

for (const check of [null, { status: 'IN_PROGRESS', conclusion: null }, { status: 'COMPLETED', conclusion: 'FAILURE' }, { status: 'COMPLETED', conclusion: 'NEUTRAL' }, { state: 'PENDING', __typename: 'StatusContext' }]) {
  test(`missing or non-green checks cannot merge: ${JSON.stringify(check)}`, () => {
    const input = fixture();
    input.pulls[0].statusCheckRollup = check ? [check] : [];
    assert.deepEqual(plan(input).merge, []);
  });
}

test('failed PR closes only after two idle days and returns only the SOFT title prefix', () => {
  const input = fixture();
  const pr = input.pulls[0];
  pr.statusCheckRollup = [{ name: 'test', status: 'COMPLETED', conclusion: 'FAILURE', completedAt: '2026-11-18T12:00:00Z' }];
  pr.updatedAt = '2026-11-18T12:00:01Z';
  assert.deepEqual(plan(input).close, []);
  pr.updatedAt = '2026-11-18T12:00:00Z';
  let result = plan(input);
  assert.deepEqual(result.close.map(pr => pr.ticket), ['SOFT-1945']);
  assert.match(result.close[0].reason, /test/);
  assert.deepEqual(result.merge, []);
  pr.title = 'Unrelated SOFT-1945: title';
  assert.equal(plan(input).close[0].ticket, null);
  pr.statusCheckRollup[0].conclusion = 'SUCCESS';
  assert.deepEqual(plan(input).close, []);
  pr.statusCheckRollup[0].conclusion = 'FAILURE';
  pr.statusCheckRollup.push({ name: 'new run', status: 'IN_PROGRESS', startedAt: input.now });
  assert.deepEqual(plan(input).close, []);
});

test('dry run with fixtures performs no external actions and never requests a model', async () => {
  const input = fixture();
  input.release = null;
  const calls = [];
  const result = await execute(input, { dryRun: true, now: Date.parse(input.now), command: (...args) => calls.push(args) });
  assert.deepEqual(calls, []);
  assert.equal(result.wake, false);
  assert.equal(result.plan.broken.length, 1);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-timer-'));
  try {
    const output = path.join(dir, 'output');
    const summary = path.join(dir, 'summary');
    const run = spawnSync(process.execPath, [path.join(__dirname, 'release-timer.js'), '--dry-run', '--fixture', fixturePath], {
      encoding: 'utf8', env: { ...process.env, GITHUB_OUTPUT: output, GITHUB_STEP_SUMMARY: summary }, timeout: 10000,
    });
    assert.equal(run.status, 0, run.stderr);
    assert.match(fs.readFileSync(output, 'utf8'), /broken=false/);
    assert.match(fs.readFileSync(summary, 'utf8'), /Dry run/);
    assert.match(run.stdout, /42/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('execution reuses squash admission and dispatches release only after confirmed merge', async () => {
  const input = fixture();
  const calls = [];
  const result = await execute(input, { now: Date.parse(input.now), command: (file, args, options) => {
    calls.push([file, args]);
    if (file === process.execPath) {
      const event = JSON.parse(fs.readFileSync(options.env.GITHUB_EVENT_PATH, 'utf8'));
      assert.equal(path.basename(args[0]), 'automerge-admit-run.js');
      assert.equal(event.inputs.expected_head, input.pulls[0].headRefOid);
      assert.equal(event.inputs.idle_before, '2026-11-20T11:00:00.000Z');
      return '';
    }
    if (args[0] === 'pr' && args[1] === 'view') return JSON.stringify({ ...input.pulls[0], state: 'MERGED' });
    return '';
  } });
  assert.equal(result.wake, false);
  assert.ok(calls.some(([file, args]) => file === 'gh' && args.join(' ').includes('workflow run auto-release.yml')));
});

test('closing rechecks the PR and prints its ticket without a board token', async () => {
  const input = fixture();
  input.pulls[0].updatedAt = '2026-11-18T12:00:00Z';
  input.pulls[0].statusCheckRollup = [{ name: 'test', status: 'COMPLETED', conclusion: 'FAILURE' }];
  const calls = [];
  const result = await execute(input, { now: Date.parse(input.now), boardToken: '', command: (file, args) => {
    calls.push([file, args]);
    if (args[0] === 'pr' && args[1] === 'view') return JSON.stringify(input.pulls[0]);
    return '';
  } });
  assert.deepEqual(result.tickets, ['SOFT-1945']);
  assert.ok(calls.some(([file, args]) => file === 'gh' && args[1] === 'close' && args.includes('--comment')));
  assert.ok(calls.every(([file]) => file !== 'hypertask'));
  calls.length = 0;
  await execute(input, { now: Date.parse(input.now), boardToken: '', command: (file, args) => {
    calls.push([file, args]);
    return JSON.stringify({ ...input.pulls[0], updatedAt: input.now });
  } });
  assert.ok(calls.every(([, args]) => !args.includes('close')));
});

test('only broken releases wake a model, not failed PRs or maintenance errors', async () => {
  const input = fixture();
  input.pulls = [];
  assert.equal((await execute(input)).wake, false);
  input.release = null;
  assert.equal((await execute(input, { now: Date.parse(input.now) })).wake, true);
  input.release = fixture().release;
  input.pulls = fixture().pulls;
  const result = await execute(input, { now: Date.parse(input.now), command: () => { throw new Error('fixture failure'); } });
  assert.equal(result.wake, false);
  assert.equal(result.errors.length, 1);
});

for (const tokenMerge of [false, true]) test(`collect resolves the release tag and push time, including GitHub-token merges: ${tokenMerge}`, () => {
  const github = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-1944/github.json'), 'utf8'));
  if (tokenMerge) {
    github.pushRuns = [{ workflow_runs: [] }];
    github.graphql.data.repository.ref.target.associatedPullRequests = { nodes: [{ mergeCommit: { oid: fixture().master.sha }, mergedAt: fixture().master.pushedAt }] };
  }
  const calls = [];
  const result = collect((file, args) => {
    assert.equal(file, 'gh');
    calls.push(args);
    const endpoint = args[1];
    let value;
    if (args[0] === 'pr') value = github.pull;
    else if (endpoint === 'graphql') value = github.graphql;
    else if (endpoint.includes('/actions/workflows/')) value = { workflow_runs: github.releaseRuns };
    else if (endpoint.includes('/actions/runs?')) value = github.pushRuns;
    else if (endpoint.includes('/releases?')) value = github.releases;
    else if (endpoint.includes('/compare/')) {
      assert.ok(endpoint.includes('v0.28.1800...aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'));
      value = github.comparison;
    } else if (endpoint.includes('/pulls?')) value = github.pulls;
    else assert.fail(`Unexpected read ${endpoint}`);
    return JSON.stringify(value);
  });
  assert.deepEqual(result.master, fixture().master);
  assert.deepEqual(result.release, fixture().release);
  assert.deepEqual(result.pulls, fixture().pulls);
  assert.ok(calls.filter(args => /\/releases\?|\/pulls\?|\/actions\/runs\?/.test(args[1])).every(args => args.includes('--paginate')));
});

for (const [name, change, allowed] of [
  ['approved and idle', () => {}, true],
  ['head changed', pr => { pr.headRefOid = 'e'.repeat(40); }, false],
  ['approval removed', pr => { pr.reviewDecision = 'REVIEW_REQUIRED'; }, false],
  ['new PR activity', pr => { pr.updatedAt = '2026-11-20T11:01:00Z'; }, false],
  ['new check activity', pr => { pr.commits.nodes[0].commit.statusCheckRollup.contexts.nodes[0].completedAt = '2026-11-20T11:01:00Z'; }, false],
  ['protected release machinery', pr => { pr.files.nodes[0].path = 'tools/release-timer.js'; }, false],
  ['untrusted author', pr => { pr.author.login = 'other'; }, false],
]) {
  test(`real squash helper rechecks timer admission: ${name}`, t => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-timer-admission-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-1944/admission.json'), 'utf8'));
    change(data.data.repository.pullRequest);
    fs.writeFileSync(path.join(dir, 'response.json'), JSON.stringify(data));
    fs.writeFileSync(path.join(dir, 'event.json'), JSON.stringify({ inputs: {
      pull_request: '42', dry_run: 'true', expected_head: fixture().pulls[0].headRefOid, idle_before: '2026-11-20T11:00:00Z',
    } }));
    fs.writeFileSync(path.join(dir, 'gh'), `#!${process.execPath}\nconst fs = require('node:fs');\nfs.appendFileSync(process.env.CALL_LOG, JSON.stringify(process.argv.slice(2)) + '\\n');\nprocess.stdout.write(fs.readFileSync(process.env.RESPONSE_PATH));\n`, { mode: 0o755 });
    const result = spawnSync(process.execPath, [path.join(__dirname, 'automerge-admit-run.js')], { encoding: 'utf8', timeout: 10000,
      env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`, GITHUB_REPOSITORY: 'valentinyeo/multiprompt',
        GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_EVENT_PATH: path.join(dir, 'event.json'),
        RESPONSE_PATH: path.join(dir, 'response.json'), CALL_LOG: path.join(dir, 'calls') },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout.includes('#42: merge'), allowed, result.stdout);
    assert.equal(fs.readFileSync(path.join(dir, 'calls'), 'utf8').trim().split('\n').length, 1);
  });
}

test('an existing board token uses only the official CLI to move closed tickets to Todo unassigned', async () => {
  const input = fixture();
  input.pulls[0].updatedAt = '2026-11-18T12:00:00Z';
  input.pulls[0].statusCheckRollup = [{ name: 'test', status: 'COMPLETED', conclusion: 'FAILURE' }];
  const calls = [];
  await execute(input, { now: Date.parse(input.now), boardToken: 'fixture-token', command: (file, args, options) => {
    calls.push([file, args]);
    if (file === 'hypertask') assert.equal(options.env.HYPERTASKS_JWT_TOKEN, 'fixture-token');
    return args[1] === 'view' ? JSON.stringify(input.pulls[0]) : '';
  } });
  assert.deepEqual(calls.filter(([file]) => file === 'hypertask').map(([, args]) => args), [
    ['task', 'move', 'SOFT-1945', '--section', 'Todo'],
    ['task', 'update', 'SOFT-1945', '--clear-assignees'],
  ]);
});
