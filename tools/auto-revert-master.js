const { execFileSync } = require('node:child_process');
const { quarantined } = require('./journey-policy.json');

const journeyKey = name => name.slice(8, -1).split(',')[0].trim();
const failedJourneys = jobs => [...new Set(jobs.filter(job => job.conclusion === 'failure' && /^verify \([^)]+\)$/.test(job.name)).map(job => journeyKey(job.name)).filter(key => !Object.hasOwn(quarantined, key)))];

function baselineFor(history, key) {
  for (const entry of history) {
    const results = entry.jobs.filter(job => /^verify \([^)]+\)$/.test(job.name) && journeyKey(job.name) === key && ['success', 'failure'].includes(job.conclusion));
    if (results.length) return { run: entry.run, conclusion: results.some(job => job.conclusion === 'failure') ? 'failure' : 'success' };
  }
  return null;
}

function decide({ run, repository, commits, jobs, history = [] }) {
  const refuse = reason => ({ action: 'refuse', reason });
  if (!Number.isSafeInteger(run.id) || run.id <= 0) return refuse('Invalid run id');
  if (run.path !== '.github/workflows/verify.yml') return refuse('Not the Verify desktop workflow');
  if (run.repository?.full_name !== repository || run.head_repository?.full_name !== repository) return refuse('Run belongs to another repository');
  if (run.status !== 'completed' || !['failure', 'cancelled'].includes(run.conclusion) || run.event !== 'push' || run.head_branch !== 'master') return refuse('Not a completed failing or cancelled push on master');
  if (!/^[a-f0-9]{40}$/.test(run.head_sha)) return refuse('Invalid run head');
  const failed = failedJourneys(jobs);
  if (!failed.length && jobs.some(job => job.conclusion === 'failure' && /^verify \([^)]+\)$/.test(job.name) && Object.hasOwn(quarantined, journeyKey(job.name)))) return { action: 'ignore', reason: 'Only quarantined journeys failed' };
  if (!failed.length && run.conclusion === 'cancelled') return { action: 'ignore', reason: 'Cancelled run has no failed journey' };
  const marker = `Auto-Revert-Run: ${run.id}`;
  const duplicate = commits.find(commit => commit.commit.message.split('\n').includes(marker));
  if (duplicate) return { action: 'skip', reason: `Run already reverted by ${duplicate.sha}`, duplicate: duplicate.commit.message };
  const target = commits.find(commit => commit.sha === run.head_sha);
  if (!target) return refuse('Run head is not on the first-parent history of master');
  const subject = target.commit.message.split('\n')[0];
  if (/^Revert\b|^Auto-Revert-Run: /m.test(target.commit.message)) return refuse('Run head is itself a revert; refusing to undo an earlier commit');
  if (commits.some(commit => commit.commit.message.split('\n').includes(`This reverts commit ${target.sha}.`) || commit.commit.message.split('\n').includes(`This reverts commit ${target.sha}, reversing`))) {
    return { action: 'skip', reason: `Commit ${target.sha} already has a revert on master` };
  }
  const ticket = subject.match(/\b(IGSH-\d+):(?:\s|$)/)?.[1];
  if (!ticket) return { action: 'ignore', reason: 'Run head subject has no IGSH ticket id' };
  if (!failed.length) return refuse('No failed verify journey found in the run');
  const baselines = new Map();
  for (const key of failed) {
    const baseline = baselineFor(history, key);
    if (!baseline) return refuse(`No earlier result for journey ${key}`);
    baselines.set(key, baseline);
  }
  const journeys = failed.filter(key => baselines.get(key).conclusion === 'success');
  if (!journeys.length) return { action: 'skip', reason: `Journeys already red before ${run.head_sha}: ${failed.join(', ')}` };
  if (!target.parents?.length) return refuse('Cannot revert a root commit');
  for (const key of journeys) {
    const baseline = baselines.get(key).run;
    if (baseline.head_sha !== target.parents[0].sha) return { action: 'skip', reason: `Cannot isolate ${target.sha}: journey ${key} last passed on ${baseline.head_sha} in run ${baseline.id}, not on its parent ${target.parents[0].sha}` };
  }
  return { action: 'revert', sha: target.sha, mainline: target.parents.length > 1 ? 1 : null, ticket, journeys, marker };
}

function main() {
  const runId = process.env.AUTO_REVERT_RUN_ID;
  if (!/^[1-9]\d*$/.test(runId || '')) throw new Error('Expected a numeric AUTO_REVERT_RUN_ID');
  const event = process.env.GITHUB_EVENT_NAME;
  if (!['workflow_dispatch', 'workflow_run'].includes(event) || process.env.GITHUB_REF !== 'refs/heads/master') throw new Error('Auto-revert must execute from master');
  const dryRun = event === 'workflow_dispatch';
  const repository = process.env.GITHUB_REPOSITORY;
  if (repository !== 'valentinyeo/multiprompt') throw new Error('Unexpected repository');
  const git = (...args) => execFileSync('git', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trimEnd();
  const gh = (...args) => {
    for (let attempt = 0; ; attempt++) {
      try {
        return execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
      } catch (error) {
        const message = error.stderr?.toString() || error.message;
        if (attempt >= 3 || !/API rate limit exceeded|secondary rate limit/i.test(message)) throw error;
        let delay = 60000 * (attempt + 1);
        if (/API rate limit exceeded/i.test(message)) {
          const limits = JSON.parse(execFileSync('gh', ['api', 'rate_limit'], { encoding: 'utf8' }));
          delay = Math.max(delay, limits.resources.core.reset * 1000 - Date.now() + 1000);
        }
        console.error(`::warning::GitHub rate limit; retrying in ${Math.ceil(delay / 1000)} seconds`);
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, delay);
      }
    }
  };
  const api = (path, ...args) => JSON.parse(gh('api', path, ...args));
  const run = api(`repos/${repository}/actions/runs/${runId}`);
  if (String(run.id) !== runId) throw new Error('Run id mismatch');
  const runJobs = candidate => api(`repos/${repository}/actions/runs/${candidate.id}/attempts/${candidate.run_attempt}/jobs?per_page=100`, '--paginate', '--slurp').flatMap(page => page.jobs);
  const jobs = runJobs(run);
  const failed = failedJourneys(jobs);
  const history = [];
  if (failed.length) {
    const earlierRuns = api(`repos/${repository}/actions/workflows/verify.yml/runs?branch=master&event=push&status=completed&per_page=50`).workflow_runs
      .filter(candidate => candidate.id !== run.id && candidate.created_at < run.created_at && ['success', 'failure', 'cancelled'].includes(candidate.conclusion));
    for (const candidate of earlierRuns) {
      if (history.length >= 20 || failed.every(key => baselineFor(history, key))) break;
      history.push({ run: candidate, jobs: runJobs(candidate) });
    }
  }
  git('fetch', 'origin', 'master');
  const tip = git('rev-parse', 'origin/master');
  const fields = git('log', '--first-parent', '-z', '--format=%H%x00%P%x00%B', 'origin/master').split('\0');
  const commits = [];
  for (let index = 0; index + 2 < fields.length; index += 3) {
    commits.push({ sha: fields[index], parents: fields[index + 1].split(' ').filter(Boolean).map(sha => ({ sha })), commit: { message: fields[index + 2] } });
  }
  const decision = decide({ run, repository, commits, jobs, history });
  console.log(JSON.stringify({ dryRun, runId, ...decision }, null, 2));
  if (decision.action === 'ignore') {
    if (process.env.GITHUB_STEP_SUMMARY) require('node:fs').appendFileSync(process.env.GITHUB_STEP_SUMMARY, `No commit reverted: ${decision.reason}\n\nRun: ${run.html_url}\n`);
    return;
  }
  if (dryRun) {
    if (decision.action === 'refuse') throw new Error(decision.reason);
    return;
  }
  const marker = `Auto-Revert-Run: ${runId}`;
  const failing = jobs.filter(job => job.conclusion === 'failure').map(job => job.name).join(', ') || 'Unknown failed job';
  const ticket = decision.ticket || commits.find(commit => commit.sha === run.head_sha)?.commit.message.split('\n')[0].match(/\bIGSH-\d+\b/)?.[0] || 'Unknown ticket';
  const notify = detail => {
    const title = `${ticket}: master verify failure (run ${runId})`;
    const body = `${marker}\n\n${detail}\n\nFailed journeys/jobs: ${failing}\n\nRun: ${run.html_url}\nHead: ${run.head_sha}\n\nThe board ticket was not reopened by this run. Manually reopen ${ticket} and post the failing journeys above.`;
    const existing = api(`repos/${repository}/issues?state=all&per_page=100`, '--paginate', '--slurp').flat().find(issue => !issue.pull_request && issue.body?.split('\n').includes(marker));
    if (!existing) api(`repos/${repository}/issues`, '-X', 'POST', '-f', `title=${title}`, '-f', `body=${body}`);
    console.error('::error::Board ticket not reopened; the GitHub issue records the cause and the required manual reopening.');
    process.exitCode = 1;
  };
  const reopenBoard = (key, journeys, context) => {
    try {
      execFileSync('node', ['tools/auto-revert-board.js', key, run.html_url, journeys], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 120000 });
    } catch (error) {
      notify(`${context}, but the board ticket was not reopened: ${error.stderr?.toString().trim() || error.message}`);
    }
  };
  if (decision.action === 'skip') {
    const key = decision.duplicate?.match(/\bIGSH-\d+\b/)?.[0];
    const journeys = decision.duplicate?.match(/^Failed journeys: (.+)$/m)?.[1];
    if (key && journeys) reopenBoard(key, journeys, decision.reason);
    return;
  }
  if (decision.action === 'refuse') {
    notify(`No commit reverted: ${decision.reason}`);
    return;
  }
  const branch = `auto-revert/${runId}`;
  const subject = commits.find(commit => commit.sha === decision.sha).commit.message.split('\n')[0];
  const journeyText = decision.journeys.join(', ');
  const enableMerge = pull => {
    for (const workflow of ['gitleaks.yml', 'no-comments.yml', 'test.yml']) {
      gh('workflow', 'run', workflow, '--repo', repository, '--ref', branch);
    }
    gh('workflow', 'run', 'verify.yml', '--repo', repository, '--ref', branch, '-f', 'feature=appearance');
    gh('pr', 'merge', pull, '--repo', repository, '--auto', '--squash');
  };
  const earlier = git('ls-remote', '--heads', 'origin', branch)
    ? JSON.parse(gh('pr', 'list', '--repo', repository, '--head', branch, '--state', 'all', '--json', 'url,state') || '[]')[0]
    : null;
  if (earlier) {
    if (earlier.state === 'CLOSED') {
      notify(`Revert pull request ${earlier.url} was closed without merging, so nothing was rolled back and the ticket was left alone.`);
      return;
    }
    try {
      if (earlier.state === 'OPEN') enableMerge(earlier.url);
    } catch (error) {
      notify(`Auto-revert could not enable squash auto-merge on ${earlier.url}: ${error.message}\n\nstdout:\n${error.stdout?.toString() || ''}\n\nstderr:\n${error.stderr?.toString() || ''}`);
      throw error;
    }
    reopenBoard(ticket, journeyText, `Revert pull request ${earlier.url} already exists`);
    return;
  }
  let pullRequest;
  try {
    if (git('rev-parse', 'HEAD') !== tip || git('status', '--porcelain')) throw new Error('Checkout is not a clean current master; refusing to revert');
    git('merge-base', '--is-ancestor', decision.sha, 'origin/master');
    git('config', 'user.name', 'github-actions[bot]');
    git('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com');
    git('checkout', '-b', branch, decision.sha);
    git('revert', '--no-commit', ...(decision.mainline ? ['-m', String(decision.mainline)] : []), decision.sha);
    git('commit', '-m', `Revert "${subject}"`, '-m', `This reverts commit ${decision.sha}.\n\n${decision.marker}\nFailed journeys: ${decision.journeys.join(', ')}\nVerify run: ${run.html_url}`);
    git('-c', 'credential.helper=', '-c', 'credential.helper=!gh auth git-credential', 'push', 'origin', `HEAD:refs/heads/${branch}`);
    pullRequest = gh('pr', 'create', '--repo', repository, '--base', 'master', '--head', branch, '--title', `Revert ${subject}`, '--body', `This reverts commit ${decision.sha}.\n\n${decision.marker}\nFailed journeys: ${decision.journeys.join(', ')}\nVerify run: ${run.html_url}`).trimEnd();
    enableMerge(pullRequest);
  } catch (error) {
    notify(`Auto-revert could not prepare or enable squash auto-merge for ${decision.sha}: ${error.message}\n\nstdout:\n${error.stdout?.toString() || ''}\n\nstderr:\n${error.stderr?.toString() || ''}`);
    throw error;
  }
  reopenBoard(ticket, journeyText, `Opened ${pullRequest} to revert only ${decision.sha} with squash auto-merge enabled`);
}

module.exports = { decide };
if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  }
}
