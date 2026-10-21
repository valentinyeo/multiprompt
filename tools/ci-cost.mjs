import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const options = new Map();
for (let i = 2; i < process.argv.length; i += 2) options.set(process.argv[i], process.argv[i + 1]);
const repo = options.get('--repo') || 'valentinyeo/multiprompt';
const limit = Number(options.get('--limit') || 100);
if (!Number.isInteger(limit) || limit < 1) throw new Error('--limit must be a positive integer');
const api = endpoint => JSON.parse(execFileSync(process.env.GH_API_BIN || 'gh', ['api', endpoint], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }));
const pr = options.has('--pr') ? api(`repos/${repo}/pulls/${options.get('--pr')}`) : null;
const event = options.get('--event') || 'pull_request';
const query = new URLSearchParams({ event, per_page: '100' });
if (pr) query.set('branch', pr.head.ref);
if (options.has('--before')) query.set('created', `<${options.get('--before')}`);
if (options.has('--head')) query.set('head_sha', options.get('--head'));
const runs = [];
for (let page = 1; runs.length < limit; page++) {
  const batch = api(`repos/${repo}/actions/runs?${query}&page=${page}`).workflow_runs;
  for (const run of batch) {
    if (pr && !run.pull_requests.some(item => item.number === pr.number) && run.head_repository?.full_name !== pr.head.repo.full_name) continue;
    runs.push(run);
    if (runs.length === limit) break;
  }
  if (batch.length < 100) break;
}
for (const run of runs) {
  run.jobs = [];
  for (let page = 1; ; page++) {
    const batch = api(`repos/${repo}/actions/runs/${run.id}/jobs?per_page=100&page=${page}&filter=latest`).jobs;
    run.jobs.push(...batch);
    if (batch.length < 100) break;
  }
}
const seconds = (start, end) => Math.max(0, (Date.parse(end) - Date.parse(start)) / 1000);
const percentile = (values, p) => values.length ? [...values].sort((a, b) => a - b)[Math.ceil(values.length * p) - 1] : null;
const fmt = value => value === null ? '—' : value.toFixed(2);
const pushKey = run => `${run.head_repository?.full_name}:${run.head_branch}:${run.head_sha}`;
const pushes = new Set(runs.map(pushKey)).size;
const rows = new Map();
const samples = [];
for (const run of runs) {
  const workflow = run.path?.split('@')[0].split('/').pop() || run.name;
  for (const job of run.jobs) {
    if (job.conclusion === 'skipped' || !job.started_at || !job.completed_at || job.status !== 'completed') continue;
    const queue = seconds(job.created_at || run.created_at, job.started_at);
    const duration = seconds(job.started_at, job.completed_at);
    const testSteps = job.steps.filter(step => /^(Run tests|Run server tool tests|Run session restore fixtures|Sweep real zsb.exe command help|Build the account Worker|Run account Worker tests)$/.test(step.name));
    const test = testSteps.reduce((sum, step) => sum + (step.started_at && step.completed_at ? seconds(step.started_at, step.completed_at) : 0), 0);
    const sample = { run: run.id, workflow, job: job.name, push: pushKey(run), duration, queue, test, overhead: duration - test, conclusion: job.conclusion };
    samples.push(sample);
    for (const key of [`Workflow|${workflow}`, `Job|${workflow} / ${job.name}`]) {
      if (!rows.has(key)) rows.set(key, []);
      rows.get(key).push(sample);
    }
  }
}
console.log(`Sample: ${runs.length} ${event} workflow runs; ${pushes} distinct PR pushes; ${samples.length} completed, non-skipped jobs. Pending jobs excluded; cancelled job time included. Queue origin: job.created_at when available, otherwise run.created_at (includes dependency wait). Reruns use latest attempt only.`);
console.log('\n| Kind | Workflow / job | Job-min / push | Queue p50 (s) | Queue p90 (s) | Jobs |');
console.log('|---|---|---:|---:|---:|---:|');
for (const [key, values] of [...rows].sort(([a], [b]) => a.localeCompare(b))) {
  const [kind, name] = key.split('|');
  console.log(`| ${kind} | ${name.replaceAll('|', '\\|')} | ${fmt(values.reduce((sum, item) => sum + item.duration, 0) / 60 / pushes)} | ${fmt(percentile(values.map(item => item.queue), 0.5))} | ${fmt(percentile(values.map(item => item.queue), 0.9))} | ${values.length} |`);
}
console.log(`| Total | All jobs | ${fmt(samples.reduce((sum, item) => sum + item.duration, 0) / 60 / pushes)} | ${fmt(percentile(samples.map(item => item.queue), 0.5))} | ${fmt(percentile(samples.map(item => item.queue), 0.9))} | ${samples.length} |`);
console.log('\n| Test job | Runtime p50 / p90 (s) | Setup + teardown p50 / p90 (s) | Test steps p50 / p90 (s) |');
console.log('|---|---:|---:|---:|');
for (const [key, values] of [...rows].filter(([key]) => /^Job\|test.yml \/ test-(windows|vps)/.test(key)).sort(([a], [b]) => a.localeCompare(b))) {
  const pair = field => `${fmt(percentile(values.map(item => item[field]), 0.5))} / ${fmt(percentile(values.map(item => item[field]), 0.9))}`;
  console.log(`| ${key.slice(4)} | ${pair('duration')} | ${pair('overhead')} | ${pair('test')} |`);
}
const originalRuns = new Set(runs.filter(run => run.jobs.filter(job => /^test-windows \(\d+\)$/.test(job.name)).length === 8 && run.jobs.filter(job => /^test-vps \(\d+\)$/.test(job.name)).length === 3).map(run => run.id));
const successful = samples.filter(item => originalRuns.has(item.run) && item.conclusion === 'success' && item.test > 0);
const stats = (platform, group, field, p) => percentile(successful.filter(item => item.workflow === 'test.yml' && item.job === `test-${platform} (${group})`).map(item => item[field]), p);
const plans = [
  [8, 3, [[1], [2], [3], [4], [5], [6], [7], [8]], [[1], [2], [3]]],
  [4, 2, [[1, 5], [2, 3], [4, 6], [7, 8]], [[1, 2], [3]]],
  [3, 2, [[1, 5, 6], [2, 3, 8], [4, 7]], [[1, 2], [3]]],
  [3, 1, [[1, 5, 6], [2, 3, 8], [4, 7]], [[1, 2, 3]]],
  [2, 2, [[1, 2, 3, 4], [5, 6, 7, 8]], [[1, 2], [3]]],
  [2, 1, [[1, 2, 3, 4], [5, 6, 7, 8]], [[1, 2, 3]]],
];
if ([1, 2, 3, 4, 5, 6, 7, 8].every(group => stats('windows', group, 'test', 0.9) !== null) && [1, 2, 3].every(group => stats('vps', group, 'test', 0.9) !== null)) {
  const jobP90 = (workflow, name) => percentile(samples.filter(item => item.conclusion === 'success' && item.workflow === workflow && item.job === name).map(item => item.duration), 0.9) || 0;
  const routing = jobP90('test.yml', 'changes') + jobP90('test.yml', 'test');
  const arm64 = Math.max(jobP90('release.yml', 'build-arm64'), jobP90('test.yml', 'build-arm64'));
  console.log(`\nHistorical 8+3 shard model: successful non-STAMP samples from original 8-Windows/3-VPS runs only; sum test-step percentiles within each merged group plus maximum group setup/teardown percentile. Active Tests model adds ${routing}s routing/aggregate and the ${arm64}s arm64 critical path. Summed percentiles are conservative estimates, not a measured percentile of merged jobs. No queue prediction: fewer occupied slots are a proxy, not a causal queue estimate.`);
  console.log('\n| Windows + VPS | Shard job-min p50 | Slowest shard p90 model (s) | Tests active p90 model (s) | Slots / 20 | Groups (Windows; VPS) |');
  console.log('|---|---:|---:|---:|---:|---|');
  for (const [windows, vps, winGroups, vpsGroups] of plans) {
    const estimate = p => [['windows', winGroups], ['vps', vpsGroups]].flatMap(([platform, groups]) => groups.map(group => group.reduce((sum, id) => sum + stats(platform, id, 'test', p), 0) + Math.max(...group.map(id => stats(platform, id, 'overhead', p)))));
    console.log(`| ${windows} + ${vps} | ${fmt(estimate(0.5).reduce((sum, value) => sum + value, 0) / 60)} | ${fmt(Math.max(...estimate(0.9)))} | ${fmt(routing + Math.max(arm64, ...estimate(0.9)))} | ${windows + vps} / 20 | ${winGroups.map(group => group.join('+')).join(', ')}; ${vpsGroups.map(group => group.join('+')).join(', ')} |`);
  }
}
for (const run of runs.filter(run => run.path?.split('@')[0].endsWith('/test.yml') && run.status === 'completed' && run.conclusion === 'success')) {
  const jobs = run.jobs.filter(job => job.conclusion === 'success' && job.started_at && job.completed_at);
  const first = Math.min(...jobs.map(job => Date.parse(job.started_at)));
  const last = Math.max(...jobs.map(job => Date.parse(job.completed_at)));
  const changes = jobs.find(job => job.name === 'changes');
  const result = jobs.find(job => job.name === 'test');
  const heavy = jobs.filter(job => /^(test-windows|test-vps|build-arm64|service)/.test(job.name));
  const activePath = (changes ? seconds(changes.started_at, changes.completed_at) : 0) + Math.max(0, ...heavy.map(job => seconds(job.started_at, job.completed_at))) + (result ? seconds(result.started_at, result.completed_at) : 0);
  console.log(`\nTests run ${run.id}: queue-inclusive ${fmt(seconds(run.created_at, new Date(last).toISOString()))}s; first-job-to-last-job ${fmt((last - first) / 1000)}s; active critical-path estimate ${fmt(activePath)}s; ${heavy.length} heavy jobs.`);
}
if (options.has('--json')) fs.writeFileSync(options.get('--json'), JSON.stringify({ measuredAt: new Date().toISOString(), repo, options: Object.fromEntries(options), pushes, runs, samples }, null, 2) + '\n');
