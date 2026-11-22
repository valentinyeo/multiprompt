import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export function updateProof(run, jobs, sha) {
  if (!run || run.head_sha !== sha || !['push', 'workflow_dispatch'].includes(run.event)) throw new Error('Updater proof must match the exact release source');
  const required = ['test-windows-update (Lifecycle)', 'test-windows-update (Rollback)'];
  const checks = required.map(name => {
    const matches = jobs.filter(job => job.name === name);
    if (matches.length !== 1 || matches[0].status !== 'completed' || matches[0].conclusion !== 'success') throw new Error(`Missing successful updater proof: ${name}`);
    return { name, url: matches[0].html_url, conclusion: matches[0].conclusion };
  });
  return { sha, testsRun: run.html_url, checks };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const sha = process.argv[2];
  const repo = process.env.GITHUB_REPOSITORY;
  if (!/^[a-f0-9]{40}$/.test(sha) || !/^[\w.-]+\/[\w.-]+$/.test(repo)) throw new Error('Expected full source SHA and GITHUB_REPOSITORY');
  const api = route => JSON.parse(execFileSync('gh', ['api', '--paginate', '--slurp', route], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }));
  const runs = api(`repos/${repo}/actions/workflows/test.yml/runs?head_sha=${sha}&per_page=100`).flatMap(page => page.workflow_runs);
  const run = runs.filter(run => run.head_sha === sha && ['push', 'workflow_dispatch'].includes(run.event)).sort((a, b) => b.id - a.id)[0];
  if (!run) throw new Error('No updater test run for the exact release source');
  const jobs = api(`repos/${repo}/actions/runs/${run.id}/jobs?per_page=100`).flatMap(page => page.jobs);
  const receipt = updateProof(run, jobs, sha);
  fs.mkdirSync('release-proof', { recursive: true });
  fs.writeFileSync('release-proof/updater.json', JSON.stringify(receipt, null, 2));
  console.log('UPDATER_SOURCE_PROOF_OK', JSON.stringify(receipt));
}
