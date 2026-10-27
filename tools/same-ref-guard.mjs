import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const windowMs = 60 * 60 * 1000;

export function windowsHeld(jobs) {
  return jobs.some(job => (job.name === 'bench' || /^repeat \d+$/.test(job.name || '')) && job.conclusion !== 'skipped');
}

export function blockedRun({ runs, jobsFor, ref, now, currentId, span = windowMs }) {
  for (const run of runs) {
    if (run.id != null && String(run.id) === String(currentId)) continue;
    if (run.head_branch !== ref) continue;
    const created = Date.parse(run.created_at);
    if (!Number.isFinite(created) || created > now || now - created >= span) continue;
    if (windowsHeld(jobsFor(run))) return true;
  }
  return false;
}

export function assertSamples(value) {
  if (String(value) !== '7') throw new Error('samples must be 7');
}

export function repeatPlan(count, max, blocked) {
  if (!new RegExp(`^[1-${max}]$`).test(String(count))) throw new Error(`count must be an integer from 1 to ${max}`);
  return { run: blocked ? 'false' : 'true', runs: blocked ? [1] : Array.from({ length: Number(count) }, (_, index) => index + 1) };
}

function gh(api) {
  const result = spawnSync('gh', ['api', api], {
    encoding: 'utf8',
    env: { ...process.env, GH_TOKEN: process.env.GH_TOKEN || process.env.GITHUB_TOKEN || '' },
  });
  if (result.status !== 0) throw new Error(result.stderr || 'GitHub API failed');
  return JSON.parse(result.stdout);
}

function main() {
  if (process.env.GUARD_SAMPLES != null && process.env.GUARD_SAMPLES !== '') assertSamples(process.env.GUARD_SAMPLES);
  const max = Number(process.env.GUARD_COUNT_MAX || 3);
  let blocked = false;
  if (process.env.GUARD_WORKFLOW) {
    const ref = process.env.GUARD_REF;
    const repo = process.env.GITHUB_REPOSITORY;
    const listed = gh(`repos/${repo}/actions/workflows/${process.env.GUARD_WORKFLOW}/runs?branch=${encodeURIComponent(ref)}&per_page=100`);
    blocked = blockedRun({
      runs: listed.workflow_runs || [],
      jobsFor(run) {
        return gh(`repos/${repo}/actions/runs/${run.id}/jobs?per_page=100`).jobs || [];
      },
      ref,
      now: Date.now(),
      currentId: process.env.GITHUB_RUN_ID,
    });
  }
  const lines = [];
  if (process.env.GUARD_COUNT != null && process.env.GUARD_COUNT !== '') {
    const plan = repeatPlan(process.env.GUARD_COUNT, max, blocked);
    lines.push(`run=${plan.run}`, `runs=${JSON.stringify(plan.runs)}`);
  } else lines.push(`run=${blocked ? 'false' : 'true'}`);
  const text = `${lines.join('\n')}\n`;
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, text);
  else process.stdout.write(text);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) main();
