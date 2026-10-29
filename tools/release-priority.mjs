import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export function priorityPlan(runs, repository, current, preempt = false) {
  const active = runs.filter(run => run.status !== 'completed');
  const production = active.filter(run => (preempt || run.id !== current) && run.head_repository?.full_name === repository &&
    (run.head_branch === 'master' || /^v\d+\.\d+\.\d+$/.test(run.head_branch)) &&
    (run.name === 'Release' || (run.name === 'auto-release' && run.jobs?.some(job => job.name.startsWith('release / ') && job.conclusion !== 'skipped'))));
  const cancel = preempt ? active.filter(run => run.id !== current && run.head_branch && run.head_branch !== 'master' &&
    !/^v\d+\.\d+\.\d+$/.test(run.head_branch)).map(run => run.id) : [];
  return { admitted: production.length === 0, production: production.map(run => run.id), cancel };
}

function api(route) {
  return JSON.parse(execFileSync('gh', ['api', '--paginate', '--slurp', route], { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const mode = process.argv[2];
  const repository = process.env.GITHUB_REPOSITORY;
  if (!['admit', 'preempt', 'inspect'].includes(mode) || !/^[\w.-]+\/[\w.-]+$/.test(repository)) throw new Error('Expected admit|preempt|inspect and GITHUB_REPOSITORY');
  const runs = new Map();
  for (const status of ['queued', 'in_progress', 'pending', 'waiting', 'requested']) {
    for (const page of api(`repos/${repository}/actions/runs?status=${status}&per_page=100`)) {
      if (!Array.isArray(page.workflow_runs)) throw new Error('Invalid workflow run list');
      for (const run of page.workflow_runs) {
        if (!Number.isSafeInteger(run.id) || typeof run.status !== 'string' || typeof run.name !== 'string') throw new Error('Invalid workflow identity');
        runs.set(run.id, run);
      }
    }
  }
  for (const run of runs.values()) {
    if (run.name === 'auto-release' && run.head_branch === 'master') {
      run.jobs = api(`repos/${repository}/actions/runs/${run.id}/jobs?per_page=100`).flatMap(page => page.jobs);
    }
  }
  const plan = priorityPlan([...runs.values()], repository, Number(process.env.GITHUB_RUN_ID), mode === 'preempt' || mode === 'inspect');
  console.log(JSON.stringify(plan));
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `## Master release priority\n\n${JSON.stringify(plan)}\n`);
  if (mode === 'preempt') {
    for (const id of plan.cancel) {
      try {
        execFileSync('gh', ['api', '--method', 'POST', `repos/${repository}/actions/runs/${id}/cancel`], { stdio: 'pipe' });
      } catch (error) {
        if (api(`repos/${repository}/actions/runs/${id}`)[0].status !== 'completed') throw error;
      }
    }
    console.log('MASTER_RELEASE_PREEMPTION_OK');
  } else if (mode === 'admit' && !plan.admitted) {
    console.error('MASTER_RELEASE_FIRST: rerun branch proof after publication');
    process.exitCode = 1;
  } else console.log(mode === 'inspect' ? 'PRIORITY_INSPECTION_OK' : 'BRANCH_ADMITTED');
}
