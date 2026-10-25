const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
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
    name: 'Verify desktop',
    path: '.github/workflows/verify.yml',
    run_attempt: 1,
    event: 'push',
    status: 'completed',
    conclusion: 'failure',
    head_branch: 'master',
    head_sha: sha,
    repository: { full_name: repository },
    head_repository: { full_name: repository },
    html_url: `https://github.com/${repository}/actions/runs/40195971037`,
  },
  commits: [commit(sha, 'IGSH-812: restore appearance (#350)', [parent, 'f'.repeat(40)]), commit(parent, 'IGSH-811: prior change', ['e'.repeat(40)])],
  jobs: [
    { id: 123, name: 'verify (appearance)', conclusion: 'success' },
    { id: 124, name: 'verify (session-restore)', conclusion: 'failure' },
    { id: 125, name: 'verify (chat-focus)', conclusion: 'failure' },
  ],
});

function runtime(input, event = 'workflow_dispatch', failure = null) {
  const calls = [];
  const output = [];
  const process = { env: { AUTO_REVERT_RUN_ID: String(input.run.id), GITHUB_EVENT_NAME: event, GITHUB_REF: 'refs/heads/master', GITHUB_REPOSITORY: repository }, exitCode: 0 };
  const module = { exports: {} };
  const require = name => {
    assert.equal(name, 'node:child_process');
    return { execFileSync(command, args) {
      calls.push([command, ...args]);
      if (failure && args.includes(failure)) throw Object.assign(new Error(`Command failed: ${command} ${args.join(' ')}`), {
        stdout: Buffer.from(`partial ${failure} output\n\n`),
        stderr: Buffer.from(`GH013: ${failure} rejected\nexact command output\n`),
      });
      if (command === 'gh') {
        if (args[0] === 'pr' && args[1] === 'create') return `https://github.com/${repository}/pull/351\n`;
        if (args[0] === 'pr' && args[1] === 'merge') return '';
        if (args[0] === 'workflow' && args[1] === 'run') return '';
        assert.equal(args[0], 'api');
        if (args.includes('POST')) return JSON.stringify({ number: 1 });
        if (args[1].includes('/jobs?')) return JSON.stringify([{ jobs: input.jobs }]);
        if (args[1].includes('/issues?')) return JSON.stringify([[]]);
        return JSON.stringify(input.run);
      }
      assert.equal(command, 'git');
      if (args[0] === 'log') return input.commits.map(commit => `${commit.sha}\0${commit.parents.map(parent => parent.sha).join(' ')}\0${commit.commit.message}\n\0`).join('');
      if (args[0] === 'rev-parse') return input.commits[0].sha;
      return '';
    } };
  };
  require.main = module;
  vm.runInNewContext(fs.readFileSync(`${__dirname}/auto-revert-master.js`, 'utf8'), { require, module, process, console: { log: value => output.push(value), error: value => output.push(value) } });
  return { calls, output: output.join('\n'), process };
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

test('ticket-less head is refused instead of selecting an older ticket commit', () => {
  const input = fixture();
  input.commits[0].commit.message = 'Release version stamp';
  assert.match(decide(input).reason, /no IGSH ticket/);
  assert.equal(decide(input).action, 'refuse');
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
  const issue = result.calls.findIndex(call => call.includes('POST'));
  assert.ok(checkout >= 0 && checkout < revert && revert < commit && commit < push && push < create && create < merge && merge < issue);
  assert.ok(result.calls[issue].some(arg => arg.includes('Manually reopen IGSH-812')));
  assert.ok(result.calls[issue].some(arg => arg.includes('verify (session-restore)')));
  assert.ok(result.calls[issue].some(arg => arg.includes('squash auto-merge enabled')));
  assert.equal(result.process.exitCode, 1);
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
});

test('ticket-less red workflow opens an issue but never reverts or pushes', () => {
  const input = fixture();
  input.commits[0].commit.message = 'Release version stamp';
  const result = runtime(input, 'workflow_run');
  assert.ok(result.calls.every(call => !call.includes('revert') && !call.includes('push')));
  assert.ok(result.calls.some(call => call.includes('POST')));
  assert.equal(result.process.exitCode, 1);
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

test('auto-revert workflow grants contents and pull-request writes with the existing token', () => {
  const workflow = fs.readFileSync(`${__dirname}/../.github/workflows/auto-revert-master.yml`, 'utf8');
  assert.match(workflow, /\n  contents: write\n/);
  assert.match(workflow, /\n  pull-requests: write\n/);
  assert.match(workflow, /GH_TOKEN: \$\{\{ github.token \}\}/);
});

test('PR smoke, full master matrix and the release tag trigger stay wired', () => {
  const verify = fs.readFileSync(`${__dirname}/../.github/workflows/verify.yml`, 'utf8');
  const release = fs.readFileSync(`${__dirname}/../.github/workflows/release.yml`, 'utf8');
  assert.match(verify, /pull_request' && fromJSON\('\["appearance"\]'\)/);
  assert.match(verify, /github.event_name == 'push' \|\| inputs.feature == 'all'/);
  const matrices = [...verify.matchAll(/fromJSON\('(\[[^'\n]+\])'\)/g)].map(match => JSON.parse(match[1]));
  assert.equal(matrices[1].length, 17);
  assert.ok(matrices[1].includes('chat-dictation'));
  assert.ok(matrices[1].includes('remind-me'));
  assert.match(verify, /^  push:\n    branches: \[master\]\n    tags: \['v\*'\]/m);
  assert.doesNotMatch(release, /gh workflow run verify\.yml/);
});

test('verify journey jobs keep the plain name the ruleset and revert parser read', () => {
  const verify = fs.readFileSync(`${__dirname}/../.github/workflows/verify.yml`, 'utf8');
  assert.match(verify, /^  verify:\n    if: inputs\.feature != 'chat-sync-audit'\n    runs-on: windows-latest\n    name: \$\{\{ inputs\.feature == 'title-bar' && format\('verify \(\{0\}, \{1\}, \{2\}\)', matrix\.feature, matrix\.caption-dpi, matrix\.caption-browser-theme\) \|\| format\('verify \(\{0\}\)', matrix\.feature\) \}\}\n/m);
});

test('controlled red proof is valid source and fails only chat-view on master pushes', () => {
  const verify = fs.readFileSync(`${__dirname}/../.github/workflows/verify.yml`, 'utf8');
  const guard = "          if ($env:FEATURE -eq 'chat-view' -and $env:GITHUB_EVENT_NAME -eq 'push' -and $env:GITHUB_REF -eq 'refs/heads/master') { throw 'IGSH-837 deliberate red master proof' }";
  const contract = source => {
    assert.doesNotMatch(source, /^(?:<{7}|={7}|>{7})(?:\s|$)/m);
    assert.deepEqual(source.split('\n').filter(line => line.includes('IGSH-837 deliberate red master proof')), [guard]);
  };
  contract(verify);
  for (const broken of [
    verify + '\n>>>>>>> conflict\n',
    verify.replace(" -and $env:GITHUB_REF -eq 'refs/heads/master'", ''),
    verify.replace("$env:GITHUB_EVENT_NAME -eq 'push'", "$env:GITHUB_EVENT_NAME -eq 'pull_request'"),
    verify.replace("$env:FEATURE -eq 'chat-view' -and ", ''),
    verify.replace(guard, guard + '\n' + guard),
  ]) assert.throws(() => contract(broken), assert.AssertionError);
});
