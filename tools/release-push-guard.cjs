#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const statuses = ['requested', 'pending', 'waiting', 'queued', 'in_progress'];
const repository = 'valentinyeo/multiprompt';

function workflowDiff(old, next, cwd) {
  return execFileSync('git', ['diff', '--name-only', '-z', '--no-renames', old, next, '--', '.github/workflows/'], { cwd, stdio: ['ignore', 'pipe', 'ignore'] }).length > 0;
}

async function checkPush(input, remoteUrl, { git, token, request }) {
  let workflowChange = false;
  for (const line of input.split('\n').filter(Boolean)) {
    const fields = line.trim().split(/\s+/);
    if (fields.length !== 4) throw new Error('invalid push metadata');
    const [, local, ref, remote] = fields;
    if (ref !== 'refs/heads/master') continue;
    if (!/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/.test(local) || !/^(?:[0-9a-f]{40}|[0-9a-f]{64})$/.test(remote) || /^0+$/.test(local) || /^0+$/.test(remote)) {
      throw new Error('cannot compare master push');
    }
    if (git(remote, local)) workflowChange = true;
  }
  if (!workflowChange) return;
  if (!/^(?:git@github\.com:|https:\/\/github\.com\/|ssh:\/\/git@github\.com\/)valentinyeo\/multiprompt(?:\.git)?\/?$/i.test(remoteUrl)) {
    throw new Error('cannot confirm target repository');
  }
  const credential = token();
  if (!credential) throw new Error('cannot obtain App authentication');
  for (const status of statuses) {
    const url = `https://api.github.com/repos/${repository}/actions/workflows/auto-release.yml/runs?branch=master&status=${status}&per_page=1`;
    const result = await request(url, { headers: { Authorization: `Bearer ${credential}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'multiprompt-release-push-guard' }, redirect: 'error', signal: AbortSignal.timeout(20000) });
    if (!result.ok) throw new Error('GitHub request failed');
    const response = await result.json();
    if (!response || !Number.isSafeInteger(response.total_count) || response.total_count < 0 || !Array.isArray(response.workflow_runs) ||
        response.workflow_runs.length !== Math.min(response.total_count, 1) ||
        response.workflow_runs.some(run => !run || run.status !== status)) {
      throw new Error('invalid GitHub response');
    }
    if (response.total_count > 0) throw new Error(`auto-release is ${status}; wait for it to finish`);
  }
}

if (require.main === module) {
  (async () => {
    if (process.argv.length !== 4) throw new Error('invalid hook arguments');
    await checkPush(fs.readFileSync(0, 'utf8'), process.argv[3], {
      git: workflowDiff,
      token: () => execFileSync(path.join(require('node:os').homedir(), '.local/bin/gh-app-token-sf'), { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 120000 }).trim(),
      request: fetch,
    });
  })().catch(error => {
    const message = error.message.startsWith('auto-release is ') ? error.message : 'could not confirm auto-release is quiet';
    console.error(`BLOCKED: ${message}`);
    process.exitCode = 1;
  });
}

module.exports = { checkPush, workflowDiff };
