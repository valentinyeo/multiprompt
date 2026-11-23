#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const modulePath = fileURLToPath(import.meta.url);

const MS_MIN = 60_000;

export function minutesBetween(start, end) {
  if (!start || !end) return null;
  const left = Date.parse(start);
  const right = Date.parse(end);
  if (!Number.isFinite(left) || !Number.isFinite(right) || right < left) return null;
  return (right - left) / MS_MIN;
}

export function bugFixPullRequest(pr) {
  const title = String(pr?.title || '');
  const labels = (pr?.labels || []).map(label => (typeof label === 'string' ? label : label?.name || ''));
  return /\bbug(?:[ -]?fix)?\b|^fix(?:\([^)]*\))?[!:]|\bfix(?:es|ed)?\b/i.test(title) ||
    labels.some(label => /^(?:bug|bug[ -]?fix|defect|regression)$/i.test(label));
}

export function pickReleaseRun(runs, mergeSha) {
  const released = (Array.isArray(runs) ? runs : [])
    .filter(run => run?.conclusion === 'success' && String(run.head_sha || '') === String(mergeSha || ''))
    .sort((left, right) => Date.parse(right.updated_at || right.created_at) - Date.parse(left.updated_at || left.created_at));
  return released[0] || null;
}

export function workflowRunMinutes(run) {
  if (!run?.created_at) return null;
  const end = run.updated_at || run.completed_at;
  return minutesBetween(run.created_at, end);
}

export function firstSuccessfulRun(runs, workflowName, headSha) {
  return (Array.isArray(runs) ? runs : [])
    .filter(run => run?.name === workflowName && run?.conclusion === 'success' && String(run.head_sha || '') === String(headSha || ''))
    .sort((left, right) => Date.parse(left.updated_at || left.created_at) - Date.parse(right.updated_at || right.created_at))[0] || null;
}

export function analyzePullRequest(pr, runs, releaseRuns) {
  if (!pr?.mergedAt) return null;
  const mergeSha = pr.mergeCommit?.oid || pr.headRefOid;
  const tests = firstSuccessfulRun(runs, 'Tests', mergeSha);
  const verifier = firstSuccessfulRun(runs, 'PR verifier', mergeSha);
  const release = pickReleaseRun(releaseRuns, mergeSha);
  const openedAt = pr.createdAt;
  const testsAt = tests?.updated_at || tests?.created_at;
  const verifierAt = verifier?.updated_at || verifier?.created_at;
  const mergeAt = pr.mergedAt;
  const releaseAt = release?.updated_at || release?.created_at;
  const stages = {
    tests: minutesBetween(openedAt, testsAt),
    verifier: minutesBetween(testsAt || openedAt, verifierAt),
    merge_wait: minutesBetween(verifierAt || testsAt || openedAt, mergeAt),
    release: minutesBetween(mergeAt, releaseAt),
  };
  const total = minutesBetween(openedAt, releaseAt);
  return { number: pr.number, openedAt, mergeAt, releaseAt, total, stages, mergeSha };
}

export function percentile(values, fraction) {
  const sorted = values.filter(value => Number.isFinite(value)).sort((left, right) => left - right);
  if (!sorted.length) return null;
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(fraction * sorted.length) - 1));
  return sorted[index];
}

export function summarizeSamples(samples) {
  const totals = samples.map(sample => sample.total).filter(Number.isFinite);
  return {
    count: samples.length,
    median_open_to_release_min: percentile(totals, 0.5),
    p90_open_to_release_min: percentile(totals, 0.9),
  };
}

export function defaultIo() {
  return {
    exec: (command, args) => spawnSync(command, args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }),
    write: text => process.stdout.write(text),
    error: text => process.stderr.write(text),
  };
}

function ghJson(io, repo, query, parameters = {}) {
  const args = ['api', 'graphql', '-f', `query=${query}`, '-f', `owner=${repo.split('/')[0]}`, '-f', `name=${repo.split('/')[1]}`];
  for (const [key, value] of Object.entries(parameters)) args.push(typeof value === 'number' ? '-F' : '-f', `${key}=${value}`);
  const result = io.exec('gh', args);
  if (result.status !== 0) throw new Error(String(result.stderr || result.stdout || 'gh api graphql failed').trim());
  return JSON.parse(result.stdout);
}

function ghRest(io, route) {
  const result = io.exec('gh', ['api', route, '--paginate']);
  if (result.status !== 0) throw new Error(String(result.stderr || result.stdout || `gh api ${route} failed`).trim());
  const text = result.stdout.trim();
  if (!text) return [];
  return text.split('\n').filter(Boolean).flatMap(line => {
    try {
      const parsed = JSON.parse(line);
      return Array.isArray(parsed) ? parsed : [parsed];
    } catch {
      return [];
    }
  });
}

export function loadFixTimings(io, repo, { days = 7, limit = 40 } = {}) {
  const since = new Date(Date.now() - days * 86_400_000).toISOString();
  const query = `query($owner:String!,$name:String!,$since:DateTime!,$limit:Int!) {
    repository(owner:$owner,name:$name) {
      pullRequests(states:MERGED,first:$limit,orderBy:{field:UPDATED_AT,direction:DESC}) {
        nodes {
          number title createdAt mergedAt headRefOid
          mergeCommit { oid }
          labels(first:20) { nodes { name } }
        }
      }
    }
  }`;
  const data = ghJson(io, repo, query, { since, limit });
  const pulls = (data.data?.repository?.pullRequests?.nodes || [])
    .map(node => ({
      number: node.number,
      title: node.title,
      createdAt: node.createdAt,
      mergedAt: node.mergedAt,
      headRefOid: node.headRefOid,
      mergeCommit: node.mergeCommit,
      labels: (node.labels?.nodes || []).map(label => label.name),
    }))
    .filter(pr => pr.mergedAt && Date.parse(pr.mergedAt) >= Date.parse(since) && bugFixPullRequest(pr));
  const verifierRuns = ghRest(io, `repos/${repo}/actions/workflows/pr-verifier.yml/runs?per_page=100&created=${since.slice(0, 10)}..`).map(run => ({
    name: 'PR verifier',
    conclusion: run.conclusion,
    head_sha: run.head_sha,
    created_at: run.created_at,
    updated_at: run.updated_at,
  }));
  const testRuns = ghRest(io, `repos/${repo}/actions/workflows/test.yml/runs?per_page=100&created=${since.slice(0, 10)}..`).map(run => ({
    name: 'Tests',
    conclusion: run.conclusion,
    head_sha: run.head_sha,
    created_at: run.created_at,
    updated_at: run.updated_at,
  }));
  const releaseRuns = ghRest(io, `repos/${repo}/actions/workflows/release.yml/runs?per_page=100&created=${since.slice(0, 10)}..`);
  const runs = [...verifierRuns, ...testRuns];
  return pulls.map(pr => analyzePullRequest(pr, runs, releaseRuns)).filter(Boolean);
}

export function formatLine(sample) {
  const stages = sample.stages;
  const total = sample.total == null ? 'n/a' : sample.total.toFixed(1);
  return [
    `PR ${sample.number}`,
    `open_to_release_min=${total}`,
    `tests=${formatStage(stages.tests)}`,
    `verifier=${formatStage(stages.verifier)}`,
    `merge_wait=${formatStage(stages.merge_wait)}`,
    `release=${formatStage(stages.release)}`,
  ].join(' ');
}

function formatStage(value) {
  return value == null ? 'n/a' : value.toFixed(1);
}

function main(argv, env, io = defaultIo()) {
  const summary = argv.includes('--summary');
  const days = Number(env.FIX_TIME_DAYS || argv.find(arg => /^\d+$/.test(arg)) || 7);
  const repo = env.REPO || env.GITHUB_REPOSITORY || 'valentinyeo/multiprompt';
  const samples = loadFixTimings(io, repo, { days });
  const rollup = summarizeSamples(samples);
  if (summary) {
    io.write(`Fix-to-release (${rollup.count} merged bug-fix PRs, ${days}d): median ${formatStage(rollup.median_open_to_release_min)} min, p90 ${formatStage(rollup.p90_open_to_release_min)} min\n`);
    return;
  }
  for (const sample of samples) io.write(`${formatLine(sample)}\n`);
  io.write(`Fix-to-release summary: median ${formatStage(rollup.median_open_to_release_min)} min, p90 ${formatStage(rollup.p90_open_to_release_min)} min (${rollup.count} PRs)\n`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === modulePath) {
  try {
    main(process.argv.slice(2), process.env);
  } catch (error) {
    defaultIo().error(`${error.message}\n`);
    process.exit(1);
  }
}