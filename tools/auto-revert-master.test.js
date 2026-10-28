const test = require('node:test');

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

function featureMatrix(source) {
  assert.match(source, /fromJSON\(needs\.journeys\.outputs\.full\)/);
  return require('./verify-features.cjs').discoverFeatures();
}
const { decide } = require('./auto-revert-master.js');

const repository = 'valentinyeo/multiprompt';
const sha = 'a'.repeat(40);
const parent = 'b'.repeat(40);
const newer = 'c'.repeat(40);
const reverted = 'd'.repeat(40);
const commit = (hash, message, parents = [parent]) => ({ sha: hash, parents: parents.map(sha => ({ sha })), commit: { message } });
const fixture = () => ({
  repository,
  run: {
    id: 40195971037,
    name: 'verify full master',
    path: '.github/workflows/verify.yml',
    run_attempt: 1,
    created_at: '2026-10-24T12:00:00Z',
    event: 'push',
    status: 'completed',
    conclusion: 'failure',
    head_branch: 'master',
    head_sha: sha,
    repository: { full_name: repository },
    head_repository: { full_name: repository },
    html_url: `https://github.com/${repository}/actions/runs/40195971037`,
  },
  history: [{
    run: { id: 40195971036, run_attempt: 2, created_at: '2026-10-24T11:00:00Z', conclusion: 'success', head_sha: parent },
    jobs: [
      { name: 'verify (session-restore)', conclusion: 'success' },
      { name: 'verify (chat-focus)', conclusion: 'success' },
    ],
  }],
  commits: [commit(sha, 'IGSH-812: restore appearance (#350)', [parent, 'f'.repeat(40)]), commit(parent, 'IGSH-811: prior change', ['e'.repeat(40)])],
  jobs: [
    { id: 123, name: 'verify (appearance)', conclusion: 'success' },
    { id: 124, name: 'verify (session-restore)', conclusion: 'failure' },
    { id: 125, name: 'verify (chat-focus)', conclusion: 'failure' },
  ],
});

function runtime(input, event = 'workflow_dispatch', failure = null, rateLimits = []) {
  const calls = [];
  const output = [];
  const waits = [];
  const summaries = [];
  const process = { env: { AUTO_REVERT_RUN_ID: String(input.run.id), GITHUB_EVENT_NAME: event, GITHUB_REF: 'refs/heads/master', GITHUB_REPOSITORY: repository, GITHUB_STEP_SUMMARY: '/summary' }, exitCode: 0 };
  const module = { exports: {} };
  const require = name => {
    if (name === 'node:fs') return { appendFileSync(file, text) { assert.equal(file, '/summary'); summaries.push(text); } };
    assert.equal(name, 'node:child_process');
    return { execFileSync(command, args) {
      calls.push([command, ...args]);
      if (failure && args.includes(failure)) throw Object.assign(new Error(`Command failed: ${command} ${args.join(' ')}`), {
        stdout: Buffer.from(`partial ${failure} output\n\n`),
        stderr: Buffer.from(`GH013: ${failure} rejected\nexact command output\n`),
      });
      if (command === 'gh') {
        if (args[0] === 'api' && args[1] === 'rate_limit') return JSON.stringify({ resources: { core: { reset: Math.floor(Date.now() / 1000) + 120 } } });
        if (args[0] === 'api' && args[1].endsWith(`/actions/runs/${input.run.id}`) && rateLimits.length) {
          throw Object.assign(new Error('Command failed'), { stderr: Buffer.from(rateLimits.shift()) });
        }
        if (args[0] === 'pr' && args[1] === 'create') return `https://github.com/${repository}/pull/351\n`;
        if (args[0] === 'pr' && args[1] === 'merge') return '';
        if (args[0] === 'pr' && args[1] === 'list') return JSON.stringify(input.existingPull ? [{ url: input.existingPull, state: input.existingState || 'OPEN' }] : []);
        if (args[0] === 'workflow' && args[1] === 'run') return '';
        assert.equal(args[0], 'api');
        if (args.includes('POST')) return JSON.stringify({ number: 1 });
        if (args[1] === `repos/${repository}/actions/workflows/verify.yml/runs?branch=master&event=push&status=completed&per_page=50`) {
          return JSON.stringify({ workflow_runs: input.earlierRuns || [input.run, ...input.history.map(entry => entry.run)] });
        }
        if (args[1].includes('/jobs?')) {
          assert.equal(args.slice(2).join(' '), '--paginate --slurp');
          if (args[1] === `repos/${repository}/actions/runs/${input.run.id}/attempts/${input.run.run_attempt}/jobs?per_page=100`) return JSON.stringify([{ jobs: input.jobs }]);
          const entry = input.history.find(candidate => args[1] === `repos/${repository}/actions/runs/${candidate.run.id}/attempts/${candidate.run.run_attempt}/jobs?per_page=100`);
          assert.ok(entry, `unexpected jobs call ${args[1]}`);
          return JSON.stringify(entry.jobs.map(job => ({ jobs: [job] })));
        }
        if (args[1].includes('/issues?')) return JSON.stringify([[]]);
        return JSON.stringify(input.run);
      }
      if (command === 'node') return '';
      assert.equal(command, 'git');
      if (args[0] === 'log') return input.commits.map(commit => `${commit.sha}\0${commit.parents.map(parent => parent.sha).join(' ')}\0${commit.commit.message}\n\0`).join('');
      if (args[0] === 'rev-parse') return input.commits[0].sha;
      if (args[0] === 'ls-remote') return input.existingPull ? 'abc\trefs/heads/x' : '';
      return '';
    } };
  };
  require.main = module;
  vm.runInNewContext(fs.readFileSync(`${__dirname}/auto-revert-master.js`, 'utf8'), { require, module, process, Atomics: { wait: (...args) => waits.push(args[3]) }, console: { log: value => output.push(value), error: value => output.push(value) } });
  return { calls, output: output.join('\n'), process, waits, summaries };
}

test('real master run-name verify full master is accepted', () => {
  const input = fixture();
  input.run.name = 'verify full master';
  assert.equal(decide(input).action, 'revert');
});

test('failing master merge chooses its exact head, first parent and failing journey names', () => {
  assert.deepEqual(decide(fixture()), {
    action: 'revert', sha, mainline: 1, ticket: 'IGSH-812',
    journeys: ['session-restore', 'chat-focus'], marker: 'Auto-Revert-Run: 40195971037',
  });
});

const jobCalls = result => result.calls.filter(call => call[0] === 'gh' && call[1] === 'api' && call[2].includes('/jobs?'));
const listCalls = result => result.calls.filter(call => call[0] === 'gh' && call[1] === 'api' && call[2].includes('/workflows/verify.yml/runs?'));
const older = 'e'.repeat(40);

test('cancelled run with a failed journey whose baseline passed on the parent reverts', () => {
  const input = fixture();
  input.run.conclusion = 'cancelled';
  input.jobs[2].conclusion = 'cancelled';
  assert.deepEqual(decide(input), {
    action: 'revert', sha, mainline: 1, ticket: 'IGSH-812',
    journeys: ['session-restore'], marker: 'Auto-Revert-Run: 40195971037',
  });
  const result = runtime(input, 'workflow_run');
  assert.deepEqual(result.calls.filter(call => call[0] === 'git' && call[1] === 'revert'), [['git', 'revert', '--no-commit', '-m', '1', sha]]);
  const create = result.calls.find(call => call[1] === 'pr' && call[2] === 'create');
  assert.ok(create.includes(`This reverts commit ${sha}.\n\nAuto-Revert-Run: ${input.run.id}\nFailed journeys: session-restore\nVerify run: ${input.run.html_url}`));
});

test('cancelled run with no failed journey is ignored without an issue, git push or history lookup', () => {
  const input = fixture();
  input.run.conclusion = 'cancelled';
  input.jobs = input.jobs.map(job => ({ ...job, conclusion: job.conclusion === 'failure' ? 'cancelled' : job.conclusion }));
  assert.deepEqual(decide(input), { action: 'ignore', reason: 'Cancelled run has no failed journey' });
  input.commits[0].commit.message = 'Release version stamp';
  assert.equal(decide(input).action, 'ignore');
  const result = runtime(input, 'workflow_run');
  assert.equal(result.process.exitCode, 0);
  assert.equal(JSON.parse(result.output).action, 'ignore');
  assert.ok(result.calls.every(call => !call.includes('POST') && !call.includes('push') && !call.includes('revert')));
  assert.equal(listCalls(result).length, 0);
  assert.equal(jobCalls(result).length, 1);
});

test('baseline skips history entries where the journey job was cancelled', () => {
  const input = fixture();
  input.history = [
    { run: { id: 40195971036, run_attempt: 1, created_at: '2026-10-24T11:30:00Z', conclusion: 'cancelled', head_sha: parent }, jobs: [
      { name: 'verify (session-restore)', conclusion: 'cancelled' },
      { name: 'verify (chat-focus)', conclusion: 'success' },
    ] },
    { run: { id: 40195971035, run_attempt: 2, created_at: '2026-10-24T11:00:00Z', conclusion: 'cancelled', head_sha: parent }, jobs: [
      { name: 'verify (session-restore)', conclusion: 'success' },
      { name: 'verify (chat-focus)', conclusion: 'cancelled' },
    ] },
    { run: { id: 40195971034, run_attempt: 1, created_at: '2026-10-24T10:00:00Z', conclusion: 'failure', head_sha: older }, jobs: [
      { name: 'verify (session-restore)', conclusion: 'failure' },
    ] },
  ];
  assert.deepEqual(decide(input).journeys, ['session-restore', 'chat-focus']);
  const result = runtime(input);
  assert.equal(result.process.exitCode, 0);
  assert.equal(JSON.parse(result.output).action, 'revert');
  assert.deepEqual(jobCalls(result).map(call => call[2]), [
    `repos/${repository}/actions/runs/${input.run.id}/attempts/1/jobs?per_page=100`,
    `repos/${repository}/actions/runs/40195971036/attempts/1/jobs?per_page=100`,
    `repos/${repository}/actions/runs/40195971035/attempts/2/jobs?per_page=100`,
  ]);
  assert.equal(listCalls(result).length, 1);
});

test('journeys already red at their baseline skip green without opening an incident', () => {
  const input = fixture();
  input.history[0].run.conclusion = 'failure';
  input.history[0].jobs = input.jobs;
  assert.deepEqual(decide(input), {
    action: 'skip',
    reason: `Journeys already red before ${sha}: session-restore, chat-focus`,
  });
  const result = runtime(input, 'workflow_run');
  assert.match(result.output, /already red/);
  assert.ok(result.calls.every(call => !call.includes('revert') && !call.includes('push')));
  assert.ok(result.calls.every(call => !call.includes('POST')));
  assert.equal(result.process.exitCode, 0);
});

test('only newly failing journeys are blamed when master was already red', () => {
  const input = fixture();
  input.history[0].run.conclusion = 'failure';
  input.history[0].jobs[1].conclusion = 'failure';
  assert.deepEqual(decide(input), {
    action: 'revert', sha, mainline: 1, ticket: 'IGSH-812',
    journeys: ['session-restore'], marker: 'Auto-Revert-Run: 40195971037',
  });
  const result = runtime(input, 'workflow_run');
  const create = result.calls.find(call => call[1] === 'pr' && call[2] === 'create');
  assert.ok(create.includes(`This reverts commit ${sha}.\n\nAuto-Revert-Run: ${input.run.id}\nFailed journeys: session-restore\nVerify run: ${input.run.html_url}`));
  assert.deepEqual(result.calls.find(call => call[0] === 'node'), ['node', 'tools/auto-revert-board.js', 'IGSH-812', input.run.html_url, 'session-restore']);
});

test('a journey that last passed on an older commit than the parent is not blamed on the head', () => {
  const input = fixture();
  input.history.unshift({ run: { id: 40195971036, run_attempt: 1, created_at: '2026-10-24T11:30:00Z', conclusion: 'cancelled', head_sha: parent }, jobs: [
    { name: 'verify (session-restore)', conclusion: 'cancelled' },
    { name: 'verify (chat-focus)', conclusion: 'success' },
  ] });
  input.history[1].run = { ...input.history[1].run, id: 40195971035, head_sha: older };
  assert.deepEqual(decide(input), {
    action: 'skip',
    reason: `Cannot isolate ${sha}: journey session-restore last passed on ${older} in run 40195971035, not on its parent ${parent}`,
  });
  const result = runtime(input, 'workflow_run');
  assert.ok(result.calls.every(call => !call.includes('revert') && !call.includes('push')));
  assert.ok(result.calls.every(call => !call.includes('POST')));
  assert.equal(result.process.exitCode, 0);
});

test('matrix job names in history count as their plain journey', () => {
  const input = fixture();
  input.history[0].run.conclusion = 'failure';
  input.history[0].jobs = [
    { name: 'session-restore', conclusion: 'failure' },
    { name: 'verify (session-restore)', conclusion: 'success' },
    { name: 'verify (chat-focus, 96, light)', conclusion: 'failure' },
    { name: 'verify (chat-focus, 120, dark)', conclusion: 'cancelled' },
  ];
  assert.deepEqual(decide(input).journeys, ['session-restore']);
  input.jobs = [{ name: 'verify (chat-focus, 120, dark)', conclusion: 'failure' }, { name: 'verify (chat-focus)', conclusion: 'failure' }];
  assert.deepEqual(decide(input), { action: 'skip', reason: `Journeys already red before ${sha}: chat-focus` });
});

test('a failed journey with no earlier result refuses a revert', () => {
  const input = fixture();
  input.history[0].jobs = [{ name: 'verify (session-restore)', conclusion: 'success' }, { name: 'verify (chat-focus)', conclusion: 'cancelled' }];
  assert.deepEqual(decide(input), { action: 'refuse', reason: 'No earlier result for journey chat-focus' });
  input.history = [];
  assert.deepEqual(decide(input), { action: 'refuse', reason: 'No earlier result for journey session-restore' });
  const result = runtime(input);
  assert.equal(result.process.exitCode, 1);
  assert.match(result.output, /No earlier result for journey session-restore/);
  assert.equal(jobCalls(result).length, 1);
});

test('history ignores current, newer, same-time and skipped runs and stops once every journey has a baseline', () => {
  const input = fixture();
  input.history[0].run.conclusion = 'failure';
  input.history[0].jobs[1].conclusion = 'failure';
  const base = input.history[0].run;
  input.earlierRuns = [
    { ...base, id: input.run.id },
    { ...base, id: 40195971039, created_at: '2026-10-24T13:00:00Z' },
    { ...base, id: 40195971038, created_at: input.run.created_at },
    { ...base, id: 40195971033, created_at: '2026-10-24T11:40:00Z', conclusion: 'skipped' },
    base,
    { ...base, id: 40195971034, created_at: '2026-10-24T10:00:00Z' },
  ];
  const result = runtime(input);
  assert.equal(result.process.exitCode, 0);
  const decision = JSON.parse(result.output);
  assert.equal(decision.action, 'revert');
  assert.deepEqual(decision.journeys, ['session-restore']);
  assert.deepEqual(jobCalls(result).map(call => call[2]), [
    `repos/${repository}/actions/runs/${input.run.id}/attempts/1/jobs?per_page=100`,
    `repos/${repository}/actions/runs/${base.id}/attempts/2/jobs?per_page=100`,
  ]);
});

test('history lookup stops after 20 earlier runs', () => {
  const input = fixture();
  input.history = Array.from({ length: 25 }, (_, index) => ({
    run: { id: 40195971000 + index, run_attempt: 1, created_at: `2026-10-24T11:${String(59 - index).padStart(2, '0')}:00Z`, conclusion: 'cancelled', head_sha: parent },
    jobs: [{ name: 'verify (session-restore)', conclusion: 'cancelled' }],
  }));
  const result = runtime(input);
  assert.equal(result.process.exitCode, 1);
  assert.match(result.output, /No earlier result for journey session-restore/);
  assert.equal(jobCalls(result).length, 21);
});

test('squash merge is reverted without a mainline flag', () => {
  const input = fixture();
  input.commits[0].parents = [{ sha: parent }];
  assert.equal(decide(input).mainline, null);
});

test('a delayed failure chooses the failing head rather than a newer master commit', () => {
  const input = fixture();
  input.commits.unshift(commit(newer, 'IGSH-999: later unrelated change'));
  assert.equal(decide(input).sha, sha);
});

test('already-reverted run id skips the second run', () => {
  const input = fixture();
  input.commits.unshift(commit(reverted, `Revert "IGSH-812: restore appearance"\n\nThis reverts commit ${sha}.\n\nAuto-Revert-Run: ${input.run.id}\n`));
  assert.equal(decide(input).action, 'skip');
});

test('a marker for a different run is not a duplicate', () => {
  const input = fixture();
  input.commits.unshift(commit(reverted, `IGSH-999: another change\n\nAuto-Revert-Run: ${input.run.id}0`));
  assert.equal(decide(input).action, 'revert');
});

test('ticket-less head is ignored instead of selecting an older ticket commit', () => {
  const input = fixture();
  input.commits[0].commit.message = 'Release version stamp';
  assert.match(decide(input).reason, /no IGSH ticket/);
  assert.equal(decide(input).action, 'ignore');
});

test('head outside master first-parent history is refused', () => {
  const input = fixture();
  input.run.head_sha = 'e'.repeat(40);
  assert.match(decide(input).reason, /not on the first-parent history/);
});

test('a failed revert never causes an earlier unrelated commit to be reverted', () => {
  const input = fixture();
  input.commits[0].commit.message = 'Revert "IGSH-812: restore appearance"';
  assert.match(decide(input).reason, /itself a revert/);
});

test('a manual revert of the same target also skips a new run', () => {
  const input = fixture();
  input.commits.unshift(commit(reverted, `Revert "IGSH-812: restore appearance"\n\nThis reverts commit ${sha}.`));
  assert.equal(decide(input).action, 'skip');
});

for (const [name, patch] of [
  ['pull request', { event: 'pull_request' }],
  ['release tag', { head_branch: 'v0.28.866' }],
  ['successful run', { conclusion: 'success' }],
  ['skipped run', { conclusion: 'skipped' }],
  ['incomplete run', { status: 'in_progress' }],
  ['another workflow', { path: '.github/workflows/test.yml' }],
  ['foreign repository', { head_repository: { full_name: 'someone/fork' } }],
]) test(`${name} cannot trigger a revert`, () => {
  const input = fixture();
  Object.assign(input.run, patch);
  assert.equal(decide(input).action, 'refuse');
});

test('failure without a failed journey is refused', () => {
  const input = fixture();
  input.jobs = [{ name: 'chat-sync-audit', conclusion: 'failure' }];
  assert.match(decide(input).reason, /No failed verify journey/);
});

test('dry dispatch prints the commit without creating a branch, reverting, pushing, opening a PR or issue, or enabling auto-merge', () => {
  const result = runtime(fixture());
  assert.equal(result.process.exitCode, 0);
  assert.match(result.output, new RegExp(sha));
  assert.match(result.output, /"dryRun": true/);
  assert.ok(result.calls.every(call => call[0] === 'git'
    ? ['fetch', 'rev-parse', 'log'].includes(call[1])
    : call[1] === 'api' && !call.includes('POST')));
});

test('red workflow path reverts exactly one merge on the run-id branch, opens a subject-titled PR, enables squash auto-merge and reports the missing board token', () => {
  const input = fixture();
  const result = runtime(input, 'workflow_run');
  const branch = `auto-revert/${input.run.id}`;
  const checkout = result.calls.findIndex(call => call[1] === 'checkout');
  assert.deepEqual(result.calls[checkout], ['git', 'checkout', '-b', branch, sha]);
  const reverts = result.calls.filter(call => call[0] === 'git' && call[1] === 'revert');
  assert.deepEqual(reverts, [['git', 'revert', '--no-commit', '-m', '1', sha]]);
  const revert = result.calls.findIndex(call => call[1] === 'revert');
  const commit = result.calls.findIndex(call => call[0] === 'git' && call[1] === 'commit');
  assert.ok(result.calls[commit].some(arg => arg.includes('Auto-Revert-Run: 40195971037')));
  const push = result.calls.findIndex(call => call.includes('push'));
  assert.deepEqual(result.calls[push], ['git', '-c', 'credential.helper=', '-c', 'credential.helper=!gh auth git-credential', 'push', 'origin', `HEAD:refs/heads/${branch}`]);
  assert.equal(result.calls.filter(call => call.includes('push')).length, 1);
  const create = result.calls.findIndex(call => call[1] === 'pr' && call[2] === 'create');
  const body = `This reverts commit ${sha}.\n\nAuto-Revert-Run: ${input.run.id}\nFailed journeys: session-restore, chat-focus\nVerify run: ${input.run.html_url}`;
  assert.deepEqual(result.calls[create], ['gh', 'pr', 'create', '--repo', repository, '--base', 'master', '--head', branch, '--title', `Revert ${input.commits[0].commit.message}`, '--body', body]);
  const merge = result.calls.findIndex(call => call[1] === 'pr' && call[2] === 'merge');
  assert.deepEqual(result.calls[merge], ['gh', 'pr', 'merge', `https://github.com/${repository}/pull/351`, '--repo', repository, '--auto', '--squash']);
  const board = result.calls.findIndex(call => call[0] === 'node');
  assert.ok(checkout >= 0 && checkout < revert && revert < commit && commit < push && push < create && create < merge && merge < board);
  assert.deepEqual(result.calls[board], ['node', 'tools/auto-revert-board.js', 'IGSH-812', input.run.html_url, 'session-restore, chat-focus']);
  assert.equal(result.calls.filter(call => call.includes('POST')).length, 0);
  assert.equal(result.process.exitCode, 0);
});

test('a failed board reopen after the revert pull request opens an issue naming the ticket and fails the job', () => {
  const input = fixture();
  const result = runtime(input, 'workflow_run', 'tools/auto-revert-board.js');
  const issue = result.calls.find(call => call.includes('POST'));
  assert.ok(issue.some(arg => arg.includes('Manually reopen IGSH-812')));
  assert.ok(issue.some(arg => arg.includes('the board ticket was not reopened')));
  assert.equal(result.process.exitCode, 1);
});

test('a dry run never touches the board', () => {
  const result = runtime(fixture(), 'workflow_dispatch');
  assert.ok(result.calls.every(call => call[0] !== 'node'));
});

test('revert PR dispatches exactly the required workflows on its branch after creation and before auto-merge', () => {
  const input = fixture();
  const result = runtime(input, 'workflow_run');
  const branch = `auto-revert/${input.run.id}`;
  const dispatches = result.calls.filter(call => call[0] === 'gh' && call[1] === 'workflow' && call[2] === 'run');
  assert.deepEqual(dispatches, [
    ['gh', 'workflow', 'run', 'gitleaks.yml', '--repo', repository, '--ref', branch],
    ['gh', 'workflow', 'run', 'no-comments.yml', '--repo', repository, '--ref', branch],
    ['gh', 'workflow', 'run', 'test.yml', '--repo', repository, '--ref', branch],
    ['gh', 'workflow', 'run', 'verify.yml', '--repo', repository, '--ref', branch, '-f', 'feature=appearance'],
  ]);
  const create = result.calls.findIndex(call => call[1] === 'pr' && call[2] === 'create');
  const merge = result.calls.findIndex(call => call[1] === 'pr' && call[2] === 'merge');
  assert.ok(create >= 0 && merge > create);
  for (const dispatch of dispatches) {
    const index = result.calls.indexOf(dispatch);
    assert.ok(index > create && index < merge);
  }
  const required = fs.readFileSync(`${__dirname}/../.github/required-checks.txt`, 'utf8').trim().split(/\r?\n/).sort();
  assert.deepEqual(required, ['no-comments', 'secret-scan', 'test', 'verify (appearance)']);
  const workflow = fs.readFileSync(`${__dirname}/../.github/workflows/auto-revert-master.yml`, 'utf8');
  assert.match(workflow, /\n  actions: write\n/);
});

test('a delayed red workflow creates its revert branch from the failing head, not newer master', () => {
  const input = fixture();
  input.commits.unshift(commit(newer, 'IGSH-999: later unrelated change'));
  const result = runtime(input, 'workflow_run');
  assert.deepEqual(result.calls.find(call => call[1] === 'checkout'), ['git', 'checkout', '-b', `auto-revert/${input.run.id}`, sha]);
  const create = result.calls.find(call => call[1] === 'pr' && call[2] === 'create');
  assert.equal(create[create.indexOf('--title') + 1], 'Revert IGSH-812: restore appearance (#350)');
});

test('red workflow path reverts a squash without a mainline flag', () => {
  const input = fixture();
  input.commits[0].parents = [{ sha: parent }];
  const result = runtime(input, 'workflow_run');
  assert.deepEqual(result.calls.find(call => call[1] === 'revert'), ['git', 'revert', '--no-commit', sha]);
  assert.ok(result.calls.some(call => call[1] === 'pr' && call[2] === 'merge'));
});

test('duplicate red workflow path never pushes a second revert', () => {
  const input = fixture();
  input.commits.unshift(commit(reverted, `Revert "IGSH-812: restore appearance"\n\nAuto-Revert-Run: ${input.run.id}`));
  const result = runtime(input, 'workflow_run');
  assert.ok(result.calls.every(call => !call.includes('revert') && !call.includes('push')));
  assert.match(result.output, /already reverted/);
  assert.ok(result.calls.every(call => call[0] !== 'node'));
  assert.ok(result.calls.every(call => !call.includes('POST')));
  assert.equal(result.process.exitCode, 0);
});

test('a re-run after the revert merged still reopens the board ticket once more through the idempotent step', () => {
  const input = fixture();
  input.commits.unshift(commit(reverted, `Revert "IGSH-812: restore appearance"\n\nThis reverts commit ${sha}.\n\nAuto-Revert-Run: ${input.run.id}\nFailed journeys: session-restore\nVerify run: ${input.run.html_url}`));
  const result = runtime(input, 'workflow_run');
  assert.ok(result.calls.every(call => !call.includes('revert') && !call.includes('push')));
  assert.deepEqual(result.calls.find(call => call[0] === 'node'), ['node', 'tools/auto-revert-board.js', 'IGSH-812', input.run.html_url, 'session-restore']);
  assert.equal(result.calls.filter(call => call.includes('POST')).length, 0);
  assert.equal(result.process.exitCode, 0);
});

test('a re-run while the revert pull request is open redoes the check dispatches and auto-merge, then reaches the board without pushing again', () => {
  const input = fixture();
  input.existingPull = `https://github.com/${repository}/pull/351`;
  const result = runtime(input, 'workflow_run');
  assert.ok(result.calls.every(call => !call.includes('push') && !(call[0] === 'git' && call[1] === 'revert') && !(call[1] === 'pr' && call[2] === 'create')));
  const dispatched = result.calls.filter(call => call[1] === 'workflow' && call[2] === 'run').map(call => call[3]);
  assert.deepEqual(dispatched, ['gitleaks.yml', 'no-comments.yml', 'test.yml', 'verify.yml']);
  const merge = result.calls.findIndex(call => call[1] === 'pr' && call[2] === 'merge');
  const board = result.calls.findIndex(call => call[0] === 'node');
  assert.deepEqual(result.calls[merge], ['gh', 'pr', 'merge', input.existingPull, '--repo', repository, '--auto', '--squash']);
  assert.deepEqual(result.calls[board], ['node', 'tools/auto-revert-board.js', 'IGSH-812', input.run.html_url, 'session-restore, chat-focus']);
  assert.ok(merge >= 0 && merge < board);
  assert.equal(result.process.exitCode, 0);
});

test('a re-run whose auto-merge enabling fails opens an issue and leaves the ticket alone', () => {
  const input = fixture();
  input.existingPull = `https://github.com/${repository}/pull/351`;
  const result = runtime(input, 'workflow_run', 'merge');
  assert.ok(result.calls.every(call => call[0] !== 'node'));
  assert.ok(result.calls.some(call => call.includes('POST')));
  assert.equal(result.process.exitCode, 1);
});

test('a revert pull request closed without merging neither reopens the ticket nor pushes again', () => {
  const input = fixture();
  input.existingPull = `https://github.com/${repository}/pull/351`;
  input.existingState = 'CLOSED';
  const result = runtime(input, 'workflow_run');
  assert.ok(result.calls.every(call => call[0] !== 'node' && !call.includes('push') && !(call[1] === 'pr' && (call[2] === 'create' || call[2] === 'merge'))));
  const issue = result.calls.find(call => call.includes('POST'));
  assert.ok(issue.some(arg => arg.includes('closed without merging')));
  assert.equal(result.process.exitCode, 1);
});

test('a merged revert pull request that a re-run still sees reaches the board without touching the pull request', () => {
  const input = fixture();
  input.existingPull = `https://github.com/${repository}/pull/351`;
  input.existingState = 'MERGED';
  const result = runtime(input, 'workflow_run');
  assert.ok(result.calls.every(call => !call.includes('push') && !(call[1] === 'pr' && (call[2] === 'create' || call[2] === 'merge')) && !(call[1] === 'workflow')));
  assert.ok(result.calls.some(call => call[0] === 'node'));
  assert.equal(result.process.exitCode, 0);
});

for (const event of ['workflow_run', 'workflow_dispatch']) test(`ticket-less ${event} is neutral with an explanation and no mutations`, () => {
  const input = fixture();
  input.commits[0].commit.message = 'Release version stamp';
  const result = runtime(input, event);
  assert.equal(result.process.exitCode, 0, result.output);
  assert.equal(JSON.parse(result.output).action, 'ignore');
  assert.ok(result.calls.every(call => call[0] === 'git'
    ? ['fetch', 'rev-parse', 'log'].includes(call[1])
    : call[0] === 'gh' && call[1] === 'api' && !call.includes('POST')));
  assert.equal(result.summaries.length, 1);
  assert.match(result.summaries[0], /No commit reverted: Run head subject has no IGSH ticket id/);
  assert.ok(result.summaries[0].includes(input.run.html_url));
});

for (const [name, failure, blocked] of [
  ['revert branch creation failure', 'checkout', ['revert', 'commit', 'push', 'create', 'merge']],
  ['ruleset-rejected branch push', 'push', ['create', 'merge']],
  ['PR creation failure', 'create', ['run', 'merge']],
  ['secret scan dispatch failure', 'gitleaks.yml', ['no-comments.yml', 'test.yml', 'verify.yml', 'merge']],
  ['no-comments dispatch failure', 'no-comments.yml', ['test.yml', 'verify.yml', 'merge']],
  ['test dispatch failure', 'test.yml', ['verify.yml', 'merge']],
  ['appearance dispatch failure', 'verify.yml', ['merge']],
  ['squash auto-merge enabling failure', 'merge', []],
]) test(`${name} opens an issue with exact command output and fails closed without retrying`, () => {
  const result = runtime(fixture(), 'workflow_run', failure);
  const failed = result.calls.filter(call => call.includes(failure));
  assert.equal(failed.length, 1);
  assert.ok(result.calls.every(call => blocked.every(command => !call.includes(command))));
  const issue = result.calls.find(call => call.includes('POST'));
  assert.ok(issue.includes(`repos/${repository}/issues`));
  const body = issue.find(arg => arg.startsWith('body='));
  assert.ok(body.includes(`Command failed: ${failed[0].join(' ')}`));
  assert.ok(body.includes(`stdout:\npartial ${failure} output\n\n`));
  assert.ok(body.includes(`stderr:\nGH013: ${failure} rejected\nexact command output\n`));
  assert.equal(result.process.exitCode, 1);
});

test('auto-revert workflow runs for failed or cancelled master pushes and manual dispatch', () => {
  const workflow = fs.readFileSync(`${__dirname}/../.github/workflows/auto-revert-master.yml`, 'utf8');
  assert.match(workflow, /\n    if: github\.event_name == 'workflow_dispatch' \|\| \(\(github\.event\.workflow_run\.conclusion == 'failure' \|\| github\.event\.workflow_run\.conclusion == 'cancelled'\) && github\.event\.workflow_run\.event == 'push' && github\.event\.workflow_run\.head_branch == 'master'\)\n/);
});

test('auto-revert workflow grants contents and pull-request writes with the existing token', () => {
  const workflow = fs.readFileSync(`${__dirname}/../.github/workflows/auto-revert-master.yml`, 'utf8');
  assert.match(workflow, /\n  contents: write\n/);
  assert.match(workflow, /\n  pull-requests: write\n/);
  assert.match(workflow, /GH_TOKEN: \$\{\{ github.token \}\}/);
});

test('PR smoke and full master matrix stay wired without duplicate release-tag journeys', async () => {
  const verify = fs.readFileSync(`${__dirname}/../.github/workflows/verify.yml`, 'utf8');
  const release = fs.readFileSync(`${__dirname}/../.github/workflows/release.yml`, 'utf8');
  assert.ok(featureMatrix(verify).pr.includes('appearance'));
  assert.match(verify, /github.event_name == 'push' \|\| inputs.feature == 'all'/);
  const matrices = [featureMatrix(verify).pr, featureMatrix(verify).full];
  assert.ok(matrices[1].length >= 21);
  assert.ok(matrices[1].includes('settings-panel'));
  assert.ok(matrices[1].includes('chat-dictation'));
  assert.ok(matrices[1].includes('tmux-binding'));
  assert.ok(matrices[1].includes('chat-send-latency'));
  assert.ok(matrices[1].includes('remind-me'));
  assert.ok(matrices[1].includes('chat-first-paint'));
  const { verifyPushBranches } = await import('./verify-workflow-branches.mjs');
  verifyPushBranches(verify);
  const expression = verify.match(/^        feature: \$\{\{ (.+) \}\}$/m)[1];
  const targeted = vm.runInNewContext(expression, {
    needs: { journeys: { outputs: { pr: JSON.stringify(matrices[0]), full: JSON.stringify(matrices[1]) } } },
    github: { event_name: 'push', ref: 'refs/heads/ceo/IGSH-1055-hax2' }, inputs: {},
    fromJSON: JSON.parse, format: (pattern, value) => pattern.replace('{0}', value),
    startsWith: (value, prefix) => value.startsWith(prefix),
  });
  assert.deepEqual(JSON.parse(JSON.stringify(targeted)), ['browser-pane-stuck', 'chat-messages-only']);
  assert.doesNotMatch(release, /gh workflow run verify\.yml/);
});

test('verify journey jobs keep the plain name the ruleset and revert parser read', () => {
  const verify = fs.readFileSync(`${__dirname}/../.github/workflows/verify.yml`, 'utf8');
  assert.match(verify, /^  verify:\n    needs: journeys\n    if: inputs\.feature != 'chat-sync-audit'\n    runs-on: windows-latest\n    name: \$\{\{ inputs\.feature == 'title-bar' && format\('verify \(\{0\}, \{1\}, \{2\}\)', matrix\.feature, matrix\.caption-dpi, matrix\.caption-browser-theme\) \|\| inputs\.feature == 'window-controls' && format\('verify \(\{0\}, \{1\}\)', matrix\.feature, matrix\.caption-dpi\) \|\| format\('verify \(\{0\}\)', matrix\.feature\) \}\}\n/m);
});

test('controlled red proof requires the marker on appearance master pushes and excludes reverts', () => {
  const verify = fs.readFileSync(`${__dirname}/../.github/workflows/verify.yml`, 'utf8');
  const guard = "          if ($env:FEATURE -eq 'appearance' -and $env:GITHUB_EVENT_NAME -eq 'push' -and $env:GITHUB_REF -eq 'refs/heads/master' -and $env:HEAD_COMMIT_MESSAGE.Split([char]10)[0].Contains('IGSH-837 red proof') -and -not $env:HEAD_COMMIT_MESSAGE.StartsWith('Revert')) { throw 'IGSH-837 deliberate red master proof' }";
  const contract = source => {
    assert.doesNotMatch(source, /^(?:<{7}|={7}|>{7})(?:\s|$)/m);
    assert.deepEqual(source.split('\n').filter(line => line.includes('IGSH-837 deliberate red master proof')), [guard]);
    assert.match(source, /      - name: Validate journey and syntax\n        shell: powershell\n        env:\n          HEAD_COMMIT_MESSAGE: \$\{\{ github\.event\.head_commit\.message \}\}\n        run: \|/);
    assert.equal(source.split('${{ github.event.head_commit.message }}').length, 2);
  };
  contract(verify);
  for (const broken of [
    verify + '\n>>>>>>> conflict\n',
    verify.replace(" -and $env:GITHUB_REF -eq 'refs/heads/master'", ''),
    verify.replace("$env:GITHUB_EVENT_NAME -eq 'push'", "$env:GITHUB_EVENT_NAME -eq 'pull_request'"),
    verify.replace("$env:FEATURE -eq 'appearance' -and ", ''),
    verify.replace(" -and $env:HEAD_COMMIT_MESSAGE.Split([char]10)[0].Contains('IGSH-837 red proof')", ''),
    verify.replace(" -and -not $env:HEAD_COMMIT_MESSAGE.StartsWith('Revert')", ''),
    verify.replace('          HEAD_COMMIT_MESSAGE: ${{ github.event.head_commit.message }}\n', ''),
    verify.replace("$env:HEAD_COMMIT_MESSAGE.Split([char]10)[0].Contains('IGSH-837 red proof')", "'${{ github.event.head_commit.message }}'.Contains('IGSH-837 red proof')"),
    verify.replace(guard, guard + '\n' + guard),
  ]) assert.throws(() => contract(broken), assert.AssertionError);
});

test('one-shot proof rejects its subject only, never an innocent commit mentioning proof in its body', { skip: process.platform !== 'win32' }, () => {
  const { spawnSync } = require('node:child_process');
  const workflow = fs.readFileSync(`${__dirname}/../.github/workflows/verify.yml`, 'utf8');
  const guard = workflow.split('\n').find(line => line.includes("throw 'IGSH-837 deliberate red master proof'"));
  assert.ok(guard);
  for (const [message, expected] of [
    ['IGSH-859: separate reruns\n\nPreserve IGSH-837 red proof.', 0],
    ['IGSH-837: IGSH-837 red proof\n\nControlled failure.', 1],
    ['Revert IGSH-837: IGSH-837 red proof', 0],
  ]) {
    const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', guard], {
      env: { ...process.env, FEATURE: 'appearance', GITHUB_EVENT_NAME: 'push', GITHUB_REF: 'refs/heads/master', HEAD_COMMIT_MESSAGE: message }, encoding: 'utf8',
    });
    assert.equal(result.status, expected, `${message}\n${result.stdout}\n${result.stderr}`);
  }
});

for (const [name, errors] of [
  ['primary rate limit', ['gh: API rate limit exceeded (HTTP 403)']],
  ['secondary rate limit', ['gh: You have exceeded a secondary rate limit (HTTP 403)']],
  ['repeated rate limits', ['gh: API rate limit exceeded (HTTP 403)', 'gh: API rate limit exceeded (HTTP 403)']],
]) test(`${name} waits then retries without changing the revert decision`, () => {
  const count = errors.length;
  const result = runtime(fixture(), 'workflow_dispatch', null, [...errors]);
  assert.equal(result.process.exitCode, 0, result.output);
  assert.equal(JSON.parse(result.output.slice(result.output.indexOf('{'))).action, 'revert');
  assert.equal(result.waits.length, count);
  assert.ok(result.waits.every(ms => ms >= 60000 && ms <= 121000));
  assert.equal(result.calls.filter(call => call[0] === 'gh' && call[2] === `repos/${repository}/actions/runs/40195971037`).length, count + 1);
});

test('permission errors fail immediately without retrying or touching master', () => {
  const result = runtime(fixture(), 'workflow_run', null, ['gh: Resource not accessible by integration (HTTP 403)']);
  assert.equal(result.process.exitCode, 1);
  assert.equal(result.waits.length, 0);
  assert.ok(result.calls.every(call => !call.includes('push') && !call.includes('POST')));
});

test('auto-revert PRs pass the changelog and red-run admission rules that a revert cannot satisfy', t => {
  const os = require('node:os');
  const path = require('node:path');
  const { execFileSync, spawnSync } = require('node:child_process');
  assert.match(fs.readFileSync(`${__dirname}/auto-revert-master.js`, 'utf8'), /const branch = `auto-revert\/\$\{runId\}`;/);
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'auto-revert-admission-'));
  t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-q', '-b', 'master');
  git('config', 'user.email', 'test@example.invalid');
  git('config', 'user.name', 'Test');
  git('config', 'commit.gpgsign', 'false');
  fs.mkdirSync(path.join(repo, 'src'));
  fs.mkdirSync(path.join(repo, 'changelog.d'));
  fs.mkdirSync(path.join(repo, 'tools'));
  fs.writeFileSync(path.join(repo, 'src/feature.txt'), 'on');
  fs.writeFileSync(path.join(repo, 'changelog.d/DEMO-1-feature.md'), 'A feature works.\n');
  fs.writeFileSync(path.join(repo, 'tools/feature.test.cjs'), "require('node:test')('on', () => {});\n");
  git('add', '.');
  git('commit', '-qm', 'feature');
  const base = git('rev-parse', 'HEAD');
  git('revert', '--no-edit', 'HEAD');
  const head = git('rev-parse', 'HEAD');
  const env = { ...process.env };
  delete env.GITHUB_HEAD_REF;
  delete env.GITHUB_REF_NAME;
  delete env.GITHUB_OUTPUT;
  delete env.NODE_TEST_CONTEXT;
  const admit = (tool, args, branch) => spawnSync(process.execPath, [path.join(__dirname, tool), ...args], { cwd: repo, encoding: 'utf8', env: { ...env, GITHUB_HEAD_REF: branch } });
  for (const [tool, args] of [['version-stamp.mjs', ['check', base, head]], ['check-red-run.mjs', [base, head]]]) {
    const revert = admit(tool, args, 'auto-revert/40533455263');
    assert.equal(revert.status, 0, `${tool}: ${revert.stdout}${revert.stderr}`);
    const normal = admit(tool, args, 'ceo/DEMO-1');
    assert.equal(normal.status, 1, `${tool}: ${normal.stdout}${normal.stderr}`);
  }
});
