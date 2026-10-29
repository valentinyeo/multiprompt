import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const policy = JSON.parse(fs.readFileSync(new URL('./release-gates.json', import.meta.url), 'utf8'));

export function summarize(runs) {
  const checks = new Map();
  for (const run of runs) {
    for (const check of run.checks) {
      if (!checks.has(check.name)) checks.set(check.name, []);
      checks.get(check.name).push({ ...check, sha: run.sha, url: run.url });
    }
  }
  return [...checks].map(([name, samples]) => {
    const failures = samples.filter(sample => sample.failed);
    const unchanged = failures.filter(sample => samples.some(other => other.sha === sample.sha && !other.failed));
    const kind = samples.every(sample => sample.kind === 'speed') ? 'speed' : 'stability';
    return { name, kind, runs: samples.length, failures: failures.length, unchangedFailures: unchanged.length, quarantined: kind === 'speed' && unchanged.length / samples.length > policy.quarantineFailureRate, evidence: failures.map(sample => sample.url) };
  }).sort((a, b) => b.failures - a.failures || a.name.localeCompare(b.name));
}

function api(route) {
  return JSON.parse(execFileSync('gh', ['api', route], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }));
}

export function collect(repo, output) {
  if (!/^[\w.-]+\/[\w.-]+$/.test(repo)) throw new Error('Expected owner/repository');
  const runs = api(`repos/${repo}/actions/workflows/release.yml/runs?status=completed&per_page=${policy.historyRuns}`).workflow_runs;
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'release-history-'));
  const history = [];
  const regressions = [];
  try {
    for (const run of runs) {
      const checks = [];
      let page = 1;
      for (;;) {
        const jobs = api(`repos/${repo}/actions/runs/${run.id}/jobs?per_page=100&page=${page++}`).jobs;
        for (const job of jobs) {
          for (const step of job.steps ?? []) {
            if (!['success', 'failure', 'timed_out'].includes(step.conclusion)) continue;
            checks.push({ name: `${job.name} / ${step.name}`, kind: policy.defaultKind, failed: step.conclusion !== 'success' });
          }
        }
        if (jobs.length < 100) break;
      }
      const artifacts = api(`repos/${repo}/actions/runs/${run.id}/artifacts?per_page=100`).artifacts;
      const speed = artifacts.filter(artifact => artifact.name.startsWith('speed-trend-') && !artifact.expired);
      const samples = new Map();
      if (speed.length) {
        const destination = path.join(scratch, String(run.id));
        execFileSync('gh', ['run', 'download', String(run.id), '--repo', repo, '--pattern', 'speed-trend-*', '--dir', destination], { stdio: 'pipe' });
        const visit = directory => {
          for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
            const file = path.join(directory, entry.name);
            if (entry.isDirectory()) visit(file);
            else if (entry.isFile() && entry.name === 'speed-trend.jsonl') {
              for (const line of fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').trim().split('\n').filter(Boolean)) {
                const sample = JSON.parse(line);
                const gate = policy.checks[sample.name];
                if (!gate || !Number.isFinite(sample.value) || sample.value < 0) throw new Error('Invalid speed trend artifact');
                const previous = samples.get(sample.name);
                if (!previous || previous.value < sample.value) samples.set(sample.name, sample);
              }
            }
          }
        };
        visit(destination);
      }
      for (const [name, sample] of samples) {
        const gate = policy.checks[name];
        checks.push({ name, kind: gate.kind, failed: sample.value > gate.limit, maximumMs: sample.value });
        if (gate.kind === 'speed' && sample.value > gate.largeRegression) regressions.push({ name, value: sample.value, target: gate.limit, run: run.html_url, sha: run.head_sha });
      }
      history.push({ id: run.id, sha: run.head_sha, url: run.html_url, branch: run.head_branch, conclusion: run.conclusion, attempt: run.run_attempt, checks });
    }
  } finally { fs.rmSync(scratch, { recursive: true, force: true }); }
  const report = { policy, runs: history, checks: summarize(history), regressions };
  fs.mkdirSync(output, { recursive: true });
  fs.writeFileSync(path.join(output, 'release-history.json'), JSON.stringify(report, null, 2));
  const markdown = ['## Stability-first release checks', '', `Last ${history.length} completed release runs. Unclassified failures remain blocking stability checks. Only speed checks with mixed results on identical source may be quarantined.`, '', '| Check | Kind | Failures / runs | Unchanged-code failures | Quarantine |', '| --- | --- | ---: | ---: | --- |', ...report.checks.map(row => `| ${row.name.replaceAll('|', '/').replaceAll('\n', ' ')} | ${row.kind} | ${row.failures} / ${row.runs} | ${row.unchangedFailures} | ${row.quarantined ? 'speed only' : 'no'} |`), '', ...history.map(run => `- ${run.url} (${run.sha}, attempt ${run.attempt})`)].join('\n');
  fs.writeFileSync(path.join(output, 'release-history.md'), markdown);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown + '\n');
  return report;
}

export function fileRegressions(repo, report) {
  const regressions = report.regressions.filter(row => !process.env.RELEASE_RUN_ID || row.run.endsWith('/' + process.env.RELEASE_RUN_ID));
  if (!regressions.length) return;
  const existing = api(`repos/${repo}/issues?state=open&per_page=100`);
  const names = new Set();
  for (const regression of regressions) {
    if (names.has(regression.name)) continue;
    names.add(regression.name);
    const title = `Speed regression: ${regression.name}`;
    if (existing.some(issue => issue.title === title)) continue;
    const body = `Speed warning; release remains unblocked.\n\nMeasured: ${regression.value} ms. Target: ${regression.target} ms.\n\nRun: ${regression.run}\n\nCommit: ${regression.sha}`;
    execFileSync('gh', ['issue', 'create', '--repo', repo, '--title', title, '--body', body], { stdio: 'inherit' });
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [repo, output, flag] = process.argv.slice(2);
  if (!repo || !output || (flag && flag !== '--file-regressions')) throw new Error('usage: release-gates-history.mjs OWNER/REPO OUTPUT [--file-regressions]');
  const report = collect(repo, output);
  if (flag) fileRegressions(repo, report);
  console.log('RELEASE_HISTORY_RECORDED');
}
