import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const workflow = fs.readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8');
const jobs = Object.fromEntries([...workflow.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));

test('production skips duplicate journeys but keeps build, startup, updater and signature gates', () => {
  assert.match(jobs.journeys, /if: inputs.proof/);
  assert.match(jobs.build, /needs: \[prepare, journeys\]/);
  assert.match(jobs.build, /needs.journeys.result == 'skipped'/);
  const condition = jobs.build.match(/^    if: (.+)$/m)[1];
  const allowed = new Function('needs', 'always', 'cancelled', `return (${condition});`);
  for (const prepare of ['success', 'failure', 'cancelled', 'skipped']) {
    for (const journeys of ['success', 'failure', 'cancelled', 'skipped']) {
      assert.equal(allowed({ prepare: { result: prepare }, journeys: { result: journeys } }, () => true, () => false), prepare === 'success' && ['success', 'skipped'].includes(journeys));
    }
  }
  assert.equal(allowed({ prepare: { result: 'success' }, journeys: { result: 'skipped' } }, () => true, () => true), false);
  assert.match(jobs['update-test'], /needs: \[prepare, build\]/);
  assert.match(jobs['update-test'], /node tools\/release-update-gate.mjs/);
  assert.match(jobs['update-test'], /WaitOne\(15000\)/);
  assert.match(jobs['update-test'], /\$process.HasExited/);
  assert.match(jobs['update-test'], /\$job.Stop\(\)/);
  assert.match(jobs.release, /needs: \[prepare, build, update-test\]/);
  assert.match(jobs.release, /run: node tools\/sign-release.mjs/);
  assert.match(jobs.build, /Executable embedded version does not match release tag/);
  assert.match(jobs['runner-sessions'], /needs: \[prepare, release\]/);
});

test('updater receipts require both successful scenarios on the exact source', async () => {
  assert.ok(fs.existsSync(new URL('./release-update-gate.mjs', import.meta.url)), 'Exact-source updater receipt must ship');
  const { updateProof } = await import('./release-update-gate.mjs');
  const sha = 'a'.repeat(40);
  const run = { head_sha: sha, event: 'push', html_url: 'https://example.org/run' };
  const checks = ['Lifecycle', 'Rollback'].map(name => ({ name: `test-windows-update (${name})`, status: 'completed', conclusion: 'success', html_url: `https://example.org/${name}` }));
  assert.equal(updateProof(run, checks, sha).checks.length, 2);
  for (const conclusion of ['failure', 'cancelled', 'skipped', null]) {
    assert.throws(() => updateProof(run, [checks[0], { ...checks[1], conclusion }], sha), /Missing successful updater proof/);
  }
  assert.throws(() => updateProof(run, checks.slice(0, 1), sha), /Missing successful updater proof/);
  assert.throws(() => updateProof(run, [...checks, checks[1]], sha), /Missing successful updater proof/);
  assert.throws(() => updateProof({ ...run, head_sha: 'b'.repeat(40) }, checks, sha), /exact release source/);
  assert.throws(() => updateProof({ ...run, event: 'pull_request' }, checks, sha), /exact release source/);
  assert.equal(updateProof({ ...run, conclusion: 'failure' }, checks, sha).sha, sha);
});


test('Windows parses the actual release startup command before shipping', { skip: process.platform !== 'win32' }, () => {
  const block = jobs['update-test'].match(/        run: \|\n((?:          [^\n]*\n|\n)+)/);
  assert.ok(block, 'Startup command must be present');
  const source = block[1].split('\n').map(line => line.slice(10)).join('\n');
  const parser = "$source = [Console]::In.ReadToEnd(); $tokens = $null; $problems = $null; $null = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$problems); if ($problems.Count -gt 0) { throw ($problems | Out-String) }; 'STARTUP_COMMAND_PARSED'";
  const result = spawnSync('powershell.exe', ['-NoProfile', '-Command', parser], { input: source, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /STARTUP_COMMAND_PARSED/);
});
