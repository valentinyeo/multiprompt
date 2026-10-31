const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const workflow = fs.readFileSync(path.join(root, process.env.AUTOMERGE_RED_CONTROL === '1'
  ? 'tools/fixtures/IGSH-1042/automerge-before.yml' : '.github/workflows/automerge.yml'), 'utf8');
const sha = 'a'.repeat(40);
const master = 'b'.repeat(40);
const page = nodes => ({ nodes, pageInfo: { hasNextPage: false, endCursor: null } });
const checkNames = ['test', 'no-comments', 'extension-version', 'secret-scan', 'ledger-guard'];
const checks = checkNames.map(name => ({ __typename: 'CheckRun', name, status: 'COMPLETED', conclusion: 'SUCCESS' }));
const snapshot = () => ({ data: { repository: { deleteBranchOnMerge: true, pullRequest: {
  id: 'PR_fixture', number: 42, state: 'OPEN', headRefOid: sha, baseRefOid: master,
  baseRef: { target: { oid: master } },
  headRefName: 'feature', baseRefName: 'master', author: { login: 'owner' },
  isCrossRepository: false, isDraft: false, mergeable: 'MERGEABLE', changedFiles: 1,
  labels: page([]), files: { ...page([{ path: 'README.md', changeType: 'MODIFIED' }]), totalCount: 1 },
  headRef: { compare: { aheadBy: 0, baseTarget: { oid: sha }, headTarget: { oid: master } } },
  commits: { nodes: [{ commit: { oid: sha, statusCheckRollup: { id: 'ROLL_fixture', contexts: page(checks.map(check => ({ ...check }))) } } }] },
} } } });
const event = () => ({ repository: { full_name: 'owner/repo' }, workflow_run: {
  id: 99, event: 'pull_request', conclusion: 'success', head_sha: sha, head_branch: 'feature',
  head_repository: { full_name: 'owner/repo' }, pull_requests: [{ number: 42 }],
} });

function fixture(t, response = snapshot(), payload = event(), env = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'automerge-event-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const log = path.join(dir, 'calls');
  fs.writeFileSync(log, '');
  fs.writeFileSync(path.join(dir, 'response.json'), JSON.stringify(response));
  fs.writeFileSync(path.join(dir, 'event.json'), JSON.stringify(payload));
  fs.writeFileSync(path.join(dir, 'gh'), `#!${process.execPath}
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.CALL_LOG, JSON.stringify(args) + '\\n');
if (args[0] === 'api' && args[1] === 'graphql') {
  const query = args.find(a => a.startsWith('query=')).slice(6);
  if (query.startsWith('mutation')) {
    if (!process.env.MERGE_RESPONSE) process.exit(2);
    console.log(process.env.MERGE_RESPONSE);
  } else if (query.includes('after: $cursor')) console.log(process.env.PAGE_RESPONSE || '{}');
  else process.stdout.write(fs.readFileSync(process.env.RESPONSE_PATH));
} else if (args[0] === 'workflow' && args[1] === 'run' && process.env.MERGE_RESPONSE) process.exit(0);
else if (args[0] === 'api' && args[1] === '--method' && args[2] === 'DELETE' && process.env.MERGE_RESPONSE) process.exit(0);
else if (args[0] === 'api' && args[1].includes('/files') && process.env.REST_RESPONSE) console.log(process.env.REST_RESPONSE);
else if (args[0] === 'pr' && args[1] === 'list') console.log(JSON.stringify([{number:42,headRefOid:'${sha}'}]));
else if (args[0] === 'pr' && args[1] === 'view') console.log(JSON.stringify({headRefOid: '${sha}', changedFiles: 1, statusCheckRollup: []}));
else if (args[0] === 'api' && args[1].includes('/compare/')) console.log('0');
else if (args[0] === 'api' && args[1].includes('/files')) console.log(JSON.stringify([[{filename: 'README.md'}]]));
else if (args[0] === 'api' && args[1].includes('/commits/')) console.log('${master}');
else if (args[0] === 'run' && args[1] === 'list') console.log('1');
else { console.error('Unexpected gh command: ' + JSON.stringify(args)); process.exit(2); }
`, { mode: 0o755 });
  const run = () => {
    const step = workflow.match(/        run: \|\n((?:          [^\n]*\n|\n)+)/);
    assert(step, 'workflow entry point');
    return spawnSync('bash', ['-euo', 'pipefail', '-c', step[1].split('\n').map(line => line.slice(10)).join('\n')], {
      cwd: root, encoding: 'utf8', env: { ...process.env, PATH: `${dir}${path.delimiter}${process.env.PATH}`,
        CALL_LOG: log, RESPONSE_PATH: path.join(dir, 'response.json'), RUNNER_TEMP: dir,
        GITHUB_EVENT_PATH: path.join(dir, 'event.json'), GITHUB_EVENT_NAME: 'workflow_run',
        GITHUB_REPOSITORY: 'owner/repo', REPO: 'owner/repo', REPO_OWNER: 'owner', DRY_RUN: 'true',
        EVENT_NAME: 'workflow_run', RUN_CONCLUSION: 'success', RUN_EVENT: 'pull_request', HEAD_BRANCH: 'feature', HEAD_SHA: sha, ...env },
    });
  };
  return { run, calls: () => fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) };
}

test('one completed PR check reads only its PR, with one snapshot and no writes', t => {
  const f = fixture(t);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(f.calls().length, 1, JSON.stringify(f.calls()));
  assert.deepEqual(f.calls()[0].slice(0, 2), ['api', 'graphql']);
  assert.match(result.stdout, /#42: merge/);
  assert.match(result.stdout, /dry.run/);
});

test('no timer or shared cancellation queue remains', () => {
  assert.doesNotMatch(workflow, /schedule:|cron:|concurrency:/);
  assert.match(workflow, /branches-ignore: \[master\]/);
});

for (const [name, change] of [
  ['master', run => { run.head_branch = 'master'; }],
  ['non-PR source', run => { run.event = 'push'; }],
  ['failed source', run => { run.conclusion = 'failure'; }],
  ['fork', run => { run.head_repository.full_name = 'fork/repo'; }],
  ['missing PR', run => { run.pull_requests = []; }],
  ['ambiguous PRs', run => { run.pull_requests.push({ number: 43 }); }],
]) test(`${name} event makes no API calls`, t => {
  const payload = event();
  change(payload.workflow_run);
  const f = fixture(t, snapshot(), payload);
  assert.equal(f.run().status, 0);
  assert.deepEqual(f.calls(), []);
});

test('stale check never admits a newer PR head', t => {
  const payload = event();
  payload.workflow_run.head_sha = 'c'.repeat(40);
  const f = fixture(t, snapshot(), payload);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /stale completed check/);
  assert.equal(f.calls().length, 1);
});

test('manual start selects exactly the requested PR and defaults to dry-run', t => {
  const f = fixture(t, snapshot(), { inputs: { pull_request: '42' } }, { GITHUB_EVENT_NAME: 'workflow_dispatch', DRY_RUN: '' });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /dry-run/);
  assert.equal(f.calls().length, 1);
});

test('manual start rejects invalid or missing numbers before a read', t => {
  for (const number of ['', 'abc', '-1', '0', '1.2', 'Infinity']) {
    const f = fixture(t, snapshot(), { inputs: { pull_request: number } }, { GITHUB_EVENT_NAME: 'workflow_dispatch' });
    assert.equal(f.run().status, 1, number);
    assert.deepEqual(f.calls(), []);
  }
});

for (const [name, change, verdict] of [
  ['draft', pr => { pr.isDraft = true; }, 'draft'],
  ['hold', pr => { pr.labels = page([{ name: 'hold' }]); }, 'hold label'],
  ['owner', pr => { pr.author.login = 'other'; }, 'not a same-repo PR'],
  ['fork', pr => { pr.isCrossRepository = true; }, 'not a same-repo PR'],
  ['base', pr => { pr.baseRefName = 'other'; }, 'base is not master'],
  ['behind', pr => { pr.headRef.compare.aheadBy = 2; }, 'behind master by 2'],
  ['protected', pr => { pr.files.nodes[0].path = '.github/workflows/test.yml'; }, 'needs manual review'],
  ['missing check', pr => { pr.commits.nodes[0].commit.statusCheckRollup.contexts = page(checks.slice(1)); }, 'not green: test'],
  ['extra failure', pr => { pr.commits.nodes[0].commit.statusCheckRollup.contexts.nodes.push({ __typename: 'StatusContext', context: 'extra', state: 'FAILURE' }); }, 'not green: extra'],
  ['visible source', pr => { pr.files.nodes[0].path = 'src/chat.zig'; }, 'verify (appearance)'],
]) test(`${name} policy still blocks merging`, t => {
  const response = snapshot();
  change(response.data.repository.pullRequest);
  const f = fixture(t, response);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.ok(result.stdout.includes(verdict), result.stdout);
  assert.equal(f.calls().length, 1);
});

for (const [name, change] of [
  ['file count', pr => { pr.changedFiles = 2; }],
  ['missing files', pr => { pr.files = null; }],
  ['check head', pr => { pr.commits.nodes[0].commit.oid = master; }],
  ['comparison head', pr => { pr.headRef.compare.baseTarget.oid = master; }],
  ['comparison master', pr => { pr.headRef.compare.headTarget.oid = sha; }],
  ['base target missing', pr => { pr.baseRef = null; }],
  ['base target invalid', pr => { pr.baseRef.target.oid = 'invalid'; }],
  ['comparison missing', pr => { pr.headRef.compare = null; }],
]) test(`incomplete ${name} fails closed`, t => {
  const response = snapshot();
  change(response.data.repository.pullRequest);
  const f = fixture(t, response);
  const result = f.run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /failed closed/);
  assert.equal(f.calls().length, 1);
});

for (const previous of ['.github/workflows/test.yml', 'src/chat.zig', 'README-old.md']) {
  test(`rename from ${previous} retains old-path policy`, t => {
    const response = snapshot();
    response.data.repository.pullRequest.files.nodes[0].changeType = 'RENAMED';
    const f = fixture(t, response, event(), { REST_RESPONSE: JSON.stringify([[{ filename: 'README.md', previous_filename: previous, status: 'renamed' }]]) });
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    assert.equal(f.calls().length, 3);
    assert.ok(result.stdout.includes(previous.startsWith('.github') ? 'needs manual review' : previous.startsWith('src') ? 'verify (appearance)' : '#42: merge'), result.stdout);
  });
}

test('file overflow reads all REST pages, including protected paths beyond 100', t => {
  const response = snapshot();
  const pr = response.data.repository.pullRequest;
  pr.changedFiles = 101;
  pr.files.pageInfo = { hasNextPage: true, endCursor: 'files-100' };
  const rest = [Array.from({ length: 100 }, (_, n) => ({ filename: `doc-${n}.md` })), [{ filename: 'tools/automerge-admit.sh' }]];
  const f = fixture(t, response, event(), { REST_RESPONSE: JSON.stringify(rest) });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /needs manual review/);
  assert.equal(f.calls().length, 3);
});

for (const [field, type, extra, verdict] of [
  ['labels', 'PullRequest', { name: 'hold' }, 'hold label'],
  ['contexts', 'StatusCheckRollup', { __typename: 'StatusContext', context: 'late-failure', state: 'FAILURE' }, 'not green: late-failure'],
]) test(`${field} pagination retains late blocking data`, t => {
  const response = snapshot();
  const pr = response.data.repository.pullRequest;
  const connection = field === 'labels' ? pr.labels : pr.commits.nodes[0].commit.statusCheckRollup.contexts;
  connection.pageInfo = { hasNextPage: true, endCursor: 'page-100' };
  const f = fixture(t, response, event(), { PAGE_RESPONSE: JSON.stringify({ data: { node: { [field]: page([extra]) } } }) });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.ok(result.stdout.includes(verdict), result.stdout);
  assert.equal(f.calls().length, 3);
  assert.ok(f.calls()[1].some(arg => arg.includes(`... on ${type}`)));
});

test('an atomic head-bound merge alone starts three master checks', t => {
  const merged = { data: { mergePullRequest: { pullRequest: { number: 42, merged: true, mergeCommit: { oid: master } } } } };
  const f = fixture(t, snapshot(), event(), { DRY_RUN: 'false', MERGE_RESPONSE: JSON.stringify(merged) });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  const calls = f.calls();
  assert.equal(calls.length, 5);
  assert.ok(calls[1].some(arg => arg.includes('expectedHeadOid: $head')));
  assert.ok(calls[1].includes(`head=${sha}`));
  assert.deepEqual(calls.slice(2).map(args => args.slice(0, 3)), [
    ['workflow', 'run', 'test.yml'], ['workflow', 'run', 'no-comments.yml'], ['workflow', 'run', 'gitleaks.yml'],
  ]);
});

test('a rejected merge race never dispatches master checks', t => {
  const f = fixture(t, snapshot(), event(), { DRY_RUN: 'false', MERGE_RESPONSE: JSON.stringify({ errors: [{ message: 'Pull Request is not mergeable' }] }) });
  const result = f.run();
  assert.equal(result.status, 1);
  assert.equal(f.calls().length, 2);
  assert.match(result.stderr, /failed closed/);
});

test('completed merged PR never merges or dispatches again', t => {
  const response = snapshot();
  response.data.repository.pullRequest.state = 'MERGED';
  const f = fixture(t, response, event(), { DRY_RUN: 'false' });
  assert.equal(f.run().status, 0);
  assert.equal(f.calls().length, 1);
});

test('dispatch checks the selected branch, while events check trusted default code', () => {
  assert.match(workflow, /ref: \$\{\{ github.event_name == 'workflow_dispatch' && github.ref \|\| github.event.repository.default_branch \}\}/);
  assert.match(workflow, /GH_TOKEN: \$\{\{ github.token \}\}/);
  assert.match(workflow, /github.event.workflow_run.event == 'pull_request'/);
  assert.match(workflow, /pull_requests\[1\] == null/);
});

test('old workflow is a failing API-budget control', () => {
  const result = spawnSync(process.execPath, ['--test', '--test-name-pattern=^one completed PR check', __filename], {
    cwd: root, encoding: 'utf8', env: { ...process.env, NODE_TEST_CONTEXT: undefined, AUTOMERGE_RED_CONTROL: '1' },
  });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stdout, /\d+ !== 1/);
});

for (const rest of [[], [[{ filename: 'README.md', status: 'renamed' }]]]) {
  test('incomplete rename-origin response cannot merge', t => {
    const response = snapshot();
    response.data.repository.pullRequest.files.nodes[0].changeType = 'RENAMED';
    const f = fixture(t, response, event(), { REST_RESPONSE: JSON.stringify(rest) });
    const result = f.run();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /incomplete REST files/);
    assert.equal(f.calls().length, 2);
  });
}

test('GraphQL errors never merge or dispatch', t => {
  const f = fixture(t, { errors: [{ message: 'Unavailable' }] });
  const result = f.run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /incomplete GraphQL response/);
  assert.equal(f.calls().length, 1);
});

test('successful merge retains branch cleanup when repository auto-deletion is off', t => {
  const response = snapshot();
  response.data.repository.deleteBranchOnMerge = false;
  response.data.repository.pullRequest.headRefName = 'ceo/IGSH-42';
  const merged = { data: { mergePullRequest: { pullRequest: { number: 42, merged: true, mergeCommit: { oid: master } } } } };
  const f = fixture(t, response, event(), { DRY_RUN: 'false', MERGE_RESPONSE: JSON.stringify(merged) });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(f.calls().length, 6);
  assert.deepEqual(f.calls()[5], ['api', '--method', 'DELETE', 'repos/owner/repo/git/refs/heads/ceo%2FIGSH-42']);
});

for (const [login, verdict] of [['software-factory-runners', 'merge'], ['other-app', 'not a same-repo PR']]) {
  test(`GraphQL bot ${login} retains CLI author policy`, t => {
    const response = snapshot();
    response.data.repository.pullRequest.author = { login, __typename: 'Bot' };
    const f = fixture(t, response);
    const result = f.run();
    assert.equal(result.status, 0, result.stderr);
    assert.ok(result.stdout.includes(verdict), result.stdout);
  });
}

test('manual emergency inspection on master does not require a new source diff', () => {
  assert.match(workflow, /name: Prove regression on merge-base source\n        if: github.event_name == 'workflow_dispatch' && github.ref_name != github.event.repository.default_branch/);
});

test('cached PR base does not replace the current master target', t => {
  const response = snapshot();
  const pr = response.data.repository.pullRequest;
  pr.baseRefOid = 'c'.repeat(40);
  pr.headRef.compare.aheadBy = 1;
  const f = fixture(t, response);
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /behind master by 1/);
  assert.equal(f.calls().length, 1);
});
