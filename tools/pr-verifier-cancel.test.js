const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const verifier = require('./pr-verifier.cjs');

const head = 'a'.repeat(40);
const run = { id: 1, conclusion: 'cancelled' };
const pr = { number: 1076, state: 'open', draft: false, head: { sha: head } };
const retry = (cancelled = run, pull = pr, checks = [], runs = []) => {
  assert.equal(typeof verifier.cancelledRunNeedsRetry, 'function');
  return verifier.cancelledRunNeedsRetry(cancelled, pull, checks, runs);
};

test('a cancelled run queues the latest uncovered head once', () => {
  assert.equal(retry(), true);
  assert.equal(retry({ ...run, head_sha: 'b'.repeat(40) }), true);
  assert.equal(retry(run, pr, [{ name: 'pstack-verifier recovery', head_sha: head }]), false);
  assert.equal(retry(run, { ...pr, head: { sha: 'b'.repeat(40) } }, [{ name: 'pstack-verifier recovery', head_sha: head }]), true);
});

test('an active latest-head run or a current successful verdict prevents duplicate recovery', () => {
  for (const status of ['pending', 'queued', 'in_progress', 'waiting', 'requested']) {
    assert.equal(retry(run, pr, [], [{ id: 2, display_title: 'verify PR 1076', head_sha: head, status }]), false);
  }
  assert.equal(retry(run, pr, [], [{ id: 2, display_title: 'verify PR 1076', event: 'workflow_dispatch', status: 'queued' }]), false);
  assert.equal(retry(run, pr, [{ name: 'pstack-verifier', head_sha: head, conclusion: 'success' }]), false);
  assert.equal(retry(run, pr, [], [{ id: 2, display_title: 'verify PR 1076', head_sha: 'b'.repeat(40), event: 'pull_request', status: 'queued' }]), true);
  assert.equal(retry(run, pr, [], [{ id: 2, display_title: 'verify PR 999', head_sha: head, status: 'queued' }]), true);
});

test('recovery never restarts failures, successful runs, drafts, or closed PRs', () => {
  for (const conclusion of ['failure', 'success', 'timed_out']) assert.equal(retry({ ...run, conclusion }), false);
  assert.equal(retry(run, { ...pr, state: 'closed' }), false);
  assert.equal(retry(run, { ...pr, draft: true }), false);
});

test('superseded runs stop queued report jobs while the independent cancellation observer remains enabled', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier.yml'), 'utf8');
  for (const name of ['tests', 'verdict']) {
    const job = workflow.split(`\n  ${name}:\n`)[1].split(/\n  [\w-]+:\n/)[0];
    assert.match(job, /if: always\(\) && !cancelled\(\)/, name);
  }
  const recovery = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier-blocked.yml'), 'utf8');
  assert.match(recovery, /workflow_run:[\s\S]*workflows: \[PR verifier\][\s\S]*types: \[completed\]/);
  assert.match(recovery, /actions: write/);
  assert.match(recovery, /github.event.workflow_run.conclusion != 'success'/);
});

for (const failure of ['', 'marker', 'dispatch']) test(`the cancellation observer reserves one latest-head attempt before dispatch, even when ${failure || 'nothing'} fails`, { skip: process.platform === 'win32' }, () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-cancel-'));
  try {
    const requests = path.join(directory, 'requests');
    const marker = path.join(directory, 'marker');
    const event = path.join(directory, 'event.json');
    fs.writeFileSync(event, JSON.stringify({ repository: { default_branch: 'master' }, workflow_run: {
      ...run, status: 'completed', event: 'pull_request', head_repository: { full_name: 'owner/repo' },
      pull_requests: [{ number: pr.number, head: { sha: 'b'.repeat(40) } }],
    } }));
    fs.writeFileSync(path.join(directory, 'gh'), String.raw`#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.REQUESTS, JSON.stringify(args) + '\n');
const route = args.find(arg => arg.startsWith('repos/')) || '';
if (args.includes('graphql')) {
  const pr = JSON.parse(process.env.PULL);
  const recoveries = fs.existsSync(process.env.MARKER) ? [{ databaseId: 2, name: 'pstack-verifier recovery', status: 'COMPLETED', conclusion: 'NEUTRAL' }] : [];
  console.log(JSON.stringify({ data: { repository: { pullRequest: { number: pr.number, state: 'OPEN', isDraft: false, title: '', body: '', headRefOid: pr.head.sha, baseRefName: 'master', headRepository: { nameWithOwner: 'owner/repo' }, comments: { nodes: [] }, commits: { nodes: [{ commit: { checkSuites: { nodes: [{ status: 'COMPLETED', conclusion: 'SUCCESS', recoveries: { nodes: recoveries } }] } } }] } } } } }));
} else if (route.includes('/pulls/')) console.log(process.env.PULL);
else if (args.includes('name=pstack-verifier recovery')) {
  if (process.env.FAILURE === 'marker') process.exit(1);
  fs.writeFileSync(process.env.MARKER, 'reserved');
} else if (route.endsWith('/dispatches') && process.env.FAILURE === 'dispatch') process.exit(1);
else if (route.endsWith('/check-runs?filter=all&per_page=100') && fs.existsSync(process.env.MARKER)) console.log(JSON.stringify({ name: 'pstack-verifier recovery', head_sha: '${head}' }));
else if (route.endsWith('/runs?per_page=100')) console.log(JSON.stringify([{ id: 1, display_title: 'unrelated', status: 'completed', pad: 'x'.repeat(2 * 1024 * 1024) }]));
`, { mode: 0o755 });
    const env = { ...process.env, PATH: `${directory}${path.delimiter}${process.env.PATH}`, REQUESTS: requests, MARKER: marker,
      GITHUB_EVENT_PATH: event, REPO: 'owner/repo', FAILURE: failure, PULL: JSON.stringify({ ...pr, head: { sha: head, repo: { full_name: 'owner/repo' } } }) };
    for (let attempt = 0; attempt < 2; attempt++) {
      const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'recover'], { env, encoding: 'utf8' });
      const failed = failure === 'marker' || (failure === 'dispatch' && attempt === 0);
      assert.equal(result.status, failed ? 1 : 0, result.stderr);
    }
    const calls = fs.readFileSync(requests, 'utf8').trim().split('\n').map(line => JSON.parse(line));
    const queued = calls.filter(args => args.some(arg => arg.endsWith('/dispatches')));
    assert.equal(queued.length, failure === 'marker' ? 0 : 1);
    for (const args of queued) {
      assert.ok(args.includes('ref=master'));
      assert.ok(args.includes('inputs[pr]=1076'));
    }
    assert.ok(calls.some(args => args.includes(`head_sha=${head}`) && args.includes('name=pstack-verifier recovery')));
    assert.equal(calls.some(args => args.includes('conclusion=success')), false);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('the verifier records the same journeys on base and head with the head harness', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier.yml'), 'utf8');
  assert.match(workflow, /tests:\n    needs: \[resolve, select, head\]/);
  assert.match(workflow, /needs: \[tests, resolve, select, head, before\]/);
  assert.match(workflow, /head:\n    needs: \[resolve, select\]/);
  assert.doesNotMatch(workflow, /failed-head|base_features|base-journey-cache|base_cache/);
  assert.equal([...workflow.matchAll(/uses: \.\/\.github\/workflows\/verify\.yml/g)].length, 2);
  assert.match(workflow, /app_revision: \$\{\{ needs.resolve.outputs.base_tip_sha \}\}/);
  assert.match(workflow, /video_label: before/);
  assert.match(workflow, /video_label: after/);
});

const oldHead = 'a'.repeat(40);
const newHead = 'b'.repeat(40);

function cancelledRun(headSha) {
  return { id: 1, status: 'completed', conclusion: 'cancelled', event: 'pull_request', head_sha: headSha,
    head_repository: { full_name: 'owner/repo' }, display_title: 'verify PR 1076',
    html_url: 'https://github.com/owner/repo/actions/runs/1', pull_requests: [] };
}

function recoveryCalls(workflowRun, runs, pullHead) {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'verifier-stale-'));
  try {
    const requests = path.join(directory, 'requests');
    const event = path.join(directory, 'event.json');
    fs.writeFileSync(event, JSON.stringify({ repository: { default_branch: 'master' }, workflow_run: workflowRun }));
    fs.writeFileSync(path.join(directory, 'gh'), String.raw`#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.REQUESTS, JSON.stringify(args) + '\n');
const route = args.find(arg => arg.startsWith('repos/')) || '';
if (args.includes('graphql')) {
  const pull = JSON.parse(process.env.PULL);
  console.log(JSON.stringify({ data: { repository: { pullRequest: { number: pull.number, state: 'OPEN', isDraft: false, title: '', body: '', headRefOid: pull.head.sha, baseRefName: 'master', headRepository: { nameWithOwner: pull.head.repo.full_name }, comments: { nodes: [] }, commits: { nodes: [{ commit: { checkSuites: { nodes: [] } } }] } } } } }));
} else if (route.endsWith('/runs?per_page=100')) console.log(process.env.RUNS);
else console.log('{}');
`, { mode: 0o755 });
    const result = spawnSync(process.execPath, [path.join(__dirname, 'pr-verifier.cjs'), 'recover'], { encoding: 'utf8', env: {
      ...process.env, PATH: `${directory}${path.delimiter}${process.env.PATH}`, REQUESTS: requests, GITHUB_EVENT_PATH: event,
      REPO: 'owner/repo', RUNS: JSON.stringify(runs),
      PULL: JSON.stringify({ number: 1076, state: 'open', draft: false, head: { sha: pullHead, repo: { full_name: 'owner/repo' } } }),
    } });
    const calls = fs.existsSync(requests) ? fs.readFileSync(requests, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line)) : [];
    return { status: result.status, stderr: result.stderr, calls };
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

const stampsHead = calls => calls.filter(args => args.includes('name=pstack-verifier') || args.includes('name=pstack-verifier (BLOCKED)'));

test('a cancelled run never publishes a verdict for a head it did not verify', () => {
  assert.equal(typeof verifier.supersededCancellation, 'function');
  const pull = { number: 1076, head: { sha: newHead } };
  const queued = [{ id: 2, display_title: 'verify PR 1076', head_sha: newHead, status: 'queued' }];
  assert.equal(verifier.supersededCancellation(cancelledRun(oldHead), pull, []), true);
  assert.equal(verifier.supersededCancellation(cancelledRun(newHead), pull, queued), true);
  assert.equal(verifier.supersededCancellation(cancelledRun(newHead), pull, [{ id: 2, display_title: 'verify PR 1076', head_sha: newHead, status: 'completed' }]), false);
  assert.equal(verifier.supersededCancellation(cancelledRun(newHead), pull, [{ id: 2, display_title: 'verify PR 999', head_sha: newHead, status: 'queued' }]), false);
  assert.equal(verifier.supersededCancellation(cancelledRun(newHead), pull, []), false);
});

test('a push that cancelled the older head run leaves the new head pending, with no BLOCKED check', { skip: process.platform !== 'linux' }, () => {
  const { status, stderr, calls } = recoveryCalls(cancelledRun(oldHead),
    [{ id: 1, display_title: 'verify PR 1076', head_sha: oldHead, event: 'pull_request', status: 'completed' },
      { id: 2, display_title: 'verify PR 1076', head_sha: newHead, event: 'pull_request', status: 'queued' }], newHead);
  assert.equal(status, 0, stderr);
  assert.deepEqual(stampsHead(calls), []);
  assert.equal(calls.some(args => args[0] === 'pr' && args[1] === 'comment'), false);
});

test('a cancelled run for the current head with no newer run still reports BLOCKED', { skip: process.platform !== 'linux' }, () => {
  const { status, stderr, calls } = recoveryCalls(cancelledRun(newHead),
    [{ id: 1, display_title: 'verify PR 1076', head_sha: newHead, event: 'pull_request', status: 'completed' }], newHead);
  assert.equal(status, 0, stderr);
  const stamped = stampsHead(calls);
  assert.ok(stamped.length >= 1);
  for (const args of stamped) {
    assert.ok(args.includes(`head_sha=${newHead}`));
    assert.ok(args.includes(`output[title]=pstack-verifier: BLOCKED`));
    assert.ok(args.some(arg => arg.startsWith('output[summary]=') && arg.startsWith(`output[summary]=pstack-verifier: BLOCKED @ ${newHead}\n`)));
  }
  assert.equal(calls.some(args => args[0] === 'pr' && args[1] === 'comment'), true);
});
