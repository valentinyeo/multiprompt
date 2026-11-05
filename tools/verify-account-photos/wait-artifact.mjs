import { spawnSync } from 'node:child_process';

const [name, destination] = process.argv.slice(2);
if (!['session-picture-endpoint', 'session-picture-phone'].includes(name) || !/^\d+$/.test(process.env.GITHUB_RUN_ID || '') || !/^[\w.-]+\/[\w.-]+$/.test(process.env.GITHUB_REPOSITORY || '')) throw new Error('Invalid artifact request');
const run = (args, timeout = 60000) => spawnSync('gh', args, { encoding: 'utf8', timeout });
const deadline = Date.now() + 1200000;
let found = false;
while (Date.now() < deadline) {
  const result = run(['api', `repos/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}/artifacts?per_page=100`], Math.min(60000, deadline - Date.now()));
  if (result.status !== 0) throw new Error('Artifact lookup failed');
  const artifacts = JSON.parse(result.stdout).artifacts;
  if (artifacts.some(item => item.name === name && !item.expired)) { found = true; break; }
  const remaining = deadline - Date.now();
  if (remaining <= 0) break;
  await new Promise(resolve => setTimeout(resolve, Math.min(300000, remaining)));
}
if (!found) throw new Error(`Timed out waiting for ${name}`);
if (destination) {
  const result = run(['run', 'download', process.env.GITHUB_RUN_ID, '--repo', process.env.GITHUB_REPOSITORY, '--name', name, '--dir', destination]);
  if (result.status !== 0) throw new Error('Artifact download failed');
}
console.log(`${name} available`);
