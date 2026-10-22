import assert from 'node:assert/strict';
import { spawnSync, execFileSync } from 'node:child_process';
const command = (program, args) => execFileSync(program, args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
if (process.argv[2] === 'regressions') {
  const result = spawnSync(process.execPath, ['--test', 'tools/issue-252-review.test.js'], { encoding: 'utf8', env: { ...process.env, ISSUE_252_BEFORE: '278a12b84bdef461ff4281eb402532c6b456eccb' } });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  for (const item of ['A', 'B', 'C', 'D', 'E', 'N']) assert.match(result.stdout, new RegExp(`not ok \\d+ - ISSUE-252 ${item} `));
  assert.match(result.stdout, /# fail 6/);
  console.log('ISSUE-252 review negative controls verified');
} else if (process.argv[2] === 'pr') {
  const head = command('git', ['rev-parse', 'HEAD']).trim();
  const pr = JSON.parse(command('gh', ['api', 'repos/valentinyeo/multiprompt/pulls/139']));
  assert.equal(pr.head.sha, head);
  assert.equal(pr.state, 'open');
  assert.equal(pr.merged, false);
  const checks = JSON.parse(command('gh', ['api', `repos/valentinyeo/multiprompt/commits/${head}/check-runs?per_page=100`])).check_runs;
  const nonrelease = checks.filter(check => !['build-x64', 'build-arm64', 'release'].includes(check.name));
  for (const name of ['test', 'test-vps (1)', 'test-vps (2)', 'test-windows (1)', 'test-windows (2)', 'test-windows (3)', 'test-windows (4)', 'no-comments', 'secret-scan', 'extension-version']) assert.ok(nonrelease.some(check => check.name === name && check.conclusion === 'success'), name);
  for (const check of nonrelease) assert.equal(check.conclusion, 'success', check.name);
  assert.equal(command('git', ['diff', '--name-only', 'HEAD', '--', '.', ':(exclude)GATES.md']).trim(), '');
  console.log(`ISSUE-252 review PR verified: ${nonrelease.length} non-release checks passed at ${head}`);
} else {
  throw new Error('Expected regressions or pr');
}
