import process from 'node:process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { hasEmergencyLabel } from './check-emergency-lane.mjs';

export function emergencyMergeFromPulls(pulls) {
  return (pulls || []).some(pr => hasEmergencyLabel((pr.labels || []).map(label => label.name || label)));
}

function gh(args, env) {
  return execFileSync('gh', args, { encoding: 'utf8', env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
}

export function emergencyMergeHead(env) {
  const repo = env.GITHUB_REPOSITORY;
  const sha = env.SHA;
  if (!repo || !/^[0-9a-f]{40}$/i.test(String(sha || ''))) return false;
  const pulls = JSON.parse(gh(['api', `repos/${repo}/commits/${sha}/pulls`], env));
  return emergencyMergeFromPulls(pulls);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.stdout.write(emergencyMergeHead(process.env) ? 'true' : 'false');
}