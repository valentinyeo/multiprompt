import process from 'node:process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

export const EMERGENCY_LABEL = 'emergency';

export function hasEmergencyLabel(labels = []) {
  return labels.some(label => String(label || '').trim().toLowerCase() === EMERGENCY_LABEL);
}

export function checkEmergencyLane(openPulls, current = {}) {
  const open = openPulls.filter(pr => String(pr.state || 'OPEN').toUpperCase() === 'OPEN' && !pr.draft);
  const emergencyActive = open.some(pr => hasEmergencyLabel(pr.labels));
  if (!emergencyActive) return { ok: true, reason: 'no open emergency pull request' };
  const state = String(current.state || 'OPEN').toUpperCase();
  if (state !== 'OPEN') return { ok: true, reason: 'pull request is not open' };
  if (current.draft) return { ok: true, reason: 'draft pull requests stay out of the merge queue' };
  if (hasEmergencyLabel(current.labels)) return { ok: true, reason: 'emergency pull request' };
  return {
    ok: false,
    reason: 'an open pull request carries the emergency label; merge that fix first or wait until it closes. After the emergency pull request closes or loses the label, rerun the emergency-lane check on paused pull requests',
  };
}

export function shouldRefreshSiblingChecks(action, labels, openPulls) {
  if (!['closed', 'labeled', 'unlabeled'].includes(action)) return false;
  const laneActive = openPulls.some(pr => String(pr.state || 'OPEN').toUpperCase() === 'OPEN' && !pr.draft && hasEmergencyLabel(pr.labels));
  if (laneActive) return false;
  return true;
}

function gh(args, env) {
  return execFileSync('gh', args, { encoding: 'utf8', env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
}

function listOpenPulls(repo, env) {
  const lines = gh(['pr', 'list', '--repo', repo, '--state', 'open', '--limit', '200', '--json', 'number,title,state,isDraft,labels,headRefName'], env).trim();
  if (!lines) return [];
  return JSON.parse(lines).map(pr => ({
    number: pr.number,
    title: pr.title,
    state: pr.state,
    draft: pr.isDraft,
    labels: (pr.labels || []).map(label => label.name),
    headRefName: pr.headRefName,
  }));
}

function rerunEmergencyLane(repo, branch, env) {
  const runs = JSON.parse(gh(['run', 'list', '--repo', repo, '--workflow', 'emergency-lane.yml', '--branch', branch, '--limit', '20', '--json', 'databaseId,event,status,conclusion'], env));
  const latest = runs.find(run => run.event === 'pull_request');
  if (!latest?.databaseId) return false;
  if (latest.status === 'in_progress' || latest.status === 'queued') return true;
  gh(['run', 'rerun', String(latest.databaseId), '--repo', repo], env);
  return true;
}

function runCheck(env) {
  const repo = env.REPO;
  const labels = JSON.parse(env.PR_LABELS || '[]');
  const openPulls = listOpenPulls(repo, env);
  const result = checkEmergencyLane(openPulls, {
    number: Number(env.PR_NUMBER),
    labels,
    draft: env.PR_DRAFT === 'true',
    state: env.PR_STATE || 'OPEN',
  });
  if (result.ok) {
    console.log(result.reason);
    return;
  }
  throw new Error(result.reason);
}

function runRefresh(env) {
  const repo = env.REPO;
  const labels = JSON.parse(env.PR_LABELS || '[]');
  const openPulls = listOpenPulls(repo, env);
  if (!shouldRefreshSiblingChecks(env.EVENT_ACTION, labels, openPulls)) {
    console.log('Emergency lane state unchanged for other pull requests');
    return;
  }
  if (openPulls.some(pr => !pr.draft && hasEmergencyLabel(pr.labels))) {
    console.log('Emergency lane still active');
    return;
  }
  let refreshed = 0;
  for (const pr of openPulls) {
    if (pr.draft) continue;
    if (rerunEmergencyLane(repo, pr.headRefName, env)) refreshed += 1;
  }
  console.log(`Requested emergency-lane reruns for ${refreshed} open pull requests`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const command = process.argv[2];
  try {
    if (command === 'check') runCheck(process.env);
    else if (command === 'refresh') runRefresh(process.env);
    else throw new Error('Usage: node tools/check-emergency-lane.mjs check|refresh');
  } catch (error) {
    console.error(error.message || error);
    process.exitCode = 1;
  }
}