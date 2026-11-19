const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

function measure(run, jobs, reuse) {
  if (run.status !== 'completed' || jobs.some(job => job.status !== 'completed')) throw new Error('Measurement needs completed runs; this command never waits');
  const end = Math.max(...jobs.map(job => Date.parse(job.completed_at)).filter(Number.isFinite));
  const start = Math.min(...jobs.map(job => Date.parse(job.started_at)).filter(Number.isFinite));
  const created = Date.parse(run.created_at);
  if (![end, start, created].every(Number.isFinite) || end < start || start < created) throw new Error('Incomplete workflow timing');
  const scheduled = jobs.filter(job => job.conclusion !== 'skipped');
  return {
    runId: run.id, pr: (run.pull_requests || [])[0]?.number || Number(run.display_title?.match(/^verify PR (\d+)$/)?.[1]),
    url: run.html_url, conclusion: run.conclusion, totalJobs: jobs.length, scheduledJobs: scheduled.length,
    baseWindowsJobs: scheduled.filter(job => job.name.startsWith('base / ') && job.labels?.some(label => /windows/i.test(label))).length,
    failures: scheduled.filter(job => !['success', 'neutral'].includes(job.conclusion)).map(job => ({ name: job.name, conclusion: job.conclusion })),
    wallSeconds: (end - created) / 1000, initialQueueSeconds: (start - created) / 1000, reuse,
  };
}

function compare(before, after) {
  const wanted = item => [...item.reuse.features, ...item.reuse.reused].sort().join(',');
  if (!before.pr || !after.pr || before.pr === after.pr || before.runId === after.runId) throw new Error('Use two distinct PRs');
  if (before.reuse.base !== after.reuse.base || before.reuse.harness !== after.reuse.harness || wanted(before) !== wanted(after)) throw new Error('The PRs need the same base, harness and requested journeys');
  if (before.reuse.reused.length || !after.reuse.reused.length || !after.reuse.sources.some(source => String(source.runId) === String(before.runId))) throw new Error('Need a cold run followed by evidence reused from that run');
  if (after.reuse.afterJobs >= before.reuse.afterJobs || after.baseWindowsJobs >= before.baseWindowsJobs) throw new Error('The second run did not skip baseline Windows jobs');
  return { before, after, note: 'Wall time includes runner queues. Failures are listed; a quicker failed run does not establish the 20-minute goal.' };
}

function collect(repo, id, directory) {
  if (!/^\d+$/.test(id)) throw new Error('Expected a workflow run ID');
  const api = endpoint => JSON.parse(execFileSync('gh', ['api', endpoint], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }));
  const run = api(`repos/${repo}/actions/runs/${id}`);
  if (run.status !== 'completed') throw new Error(`Run ${id} is not complete; this command never waits`);
  const pages = JSON.parse(execFileSync('gh', ['api', '--paginate', '--slurp', `repos/${repo}/actions/runs/${id}/jobs?per_page=100`], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }));
  execFileSync('gh', ['run', 'download', id, '--repo', repo, '--name', 'pr-verifier-base-reuse', '--dir', directory], { stdio: 'inherit' });
  return measure(run, pages.flatMap(page => page.jobs), JSON.parse(fs.readFileSync(path.join(directory, 'reuse.json'), 'utf8')));
}

module.exports = { measure, compare };
if (require.main === module) {
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'measure-base-reuse-'));
  try {
    const [repo, before, after] = process.argv.slice(2);
    if (!repo || !before || !after) throw new Error('Usage: node tools/measure-base-reuse.cjs <owner/repo> <cold-run-id> <warm-run-id>');
    console.log(JSON.stringify(compare(collect(repo, before, path.join(scratch, 'before')), collect(repo, after, path.join(scratch, 'after'))), null, 2));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
  finally { fs.rmSync(scratch, { recursive: true, force: true }); }
}
