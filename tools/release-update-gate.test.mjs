import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { spawnSync } from 'node:child_process';

const workflow = fs.readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8');
const jobs = Object.fromEntries([...workflow.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));

function job(name) {
  assert.ok(jobs[name], `release.yml must keep the ${name} job`);
  return jobs[name];
}

function needsOf(name) {
  const line = job(name).match(/^    needs: (\[[^\]]*\]|\S+)$/m);
  assert.ok(line, `${name} must declare its needs`);
  return line[1].replace(/[[\]]/g, '').split(',').map(entry => entry.trim()).filter(Boolean);
}

test('production skips duplicate journeys but keeps build, startup, journey receipt and signature gates', () => {
  assert.deepEqual(needsOf('journeys'), ['prepare', 'build']);
  assert.match(job('journeys'), /^    if: needs\.prepare\.outputs\.features != '\[\]'$/m);
  assert.doesNotMatch(job('journeys'), /inputs\.proof/);
  assert.match(job('journeys'), /uses: \.\/\.github\/workflows\/verify\.yml/);
  assert.deepEqual(needsOf('build'), ['prepare']);
  assert.doesNotMatch(job('build'), /^    if:/m);
  assert.match(job('build'), /Executable embedded version does not match release tag/);
  assert.deepEqual(needsOf('journey-gate'), ['prepare', 'build', 'journeys']);
  const gate = job('journey-gate').match(/^    if: (.+)$/m)[1];
  const allowed = new Function('needs', 'always', 'cancelled', `return (${gate});`);
  for (const prepare of ['success', 'failure', 'cancelled']) {
    for (const build of ['success', 'failure', 'cancelled']) {
      for (const journeys of ['success', 'failure', 'cancelled', 'skipped']) {
        assert.equal(allowed({ prepare: { result: prepare }, build: { result: build }, journeys: { result: journeys } }, () => true, () => false), prepare === 'success' && build === 'success');
      }
    }
  }
  assert.equal(allowed({ prepare: { result: 'success' }, build: { result: 'success' }, journeys: { result: 'skipped' } }, () => true, () => true), false);
  assert.match(job('journey-gate'), /node tools\/release-journeys\.mjs check/);
  assert.match(job('journey-gate'), /name: release-journey-receipt/);
  assert.deepEqual(needsOf('launch'), ['prepare', 'build']);
  assert.match(job('launch'), /run: \.\/tools\/release-launch\.ps1 -Exe release-bin\/multiprompt-x64\.exe -Evidence release-proof/);
  assert.match(job('launch'), /name: release-launch-proof\n          path: release-proof\/\n          if-no-files-found: error/);
  assert.match(job('gitleaks'), /release_scan: true/);
  assert.deepEqual(needsOf('release'), ['prepare', 'build', 'launch', 'gitleaks', 'resource-observation', 'journey-gate']);
  assert.doesNotMatch(job('release'), /^    if:/m);
  assert.match(job('release'), /name: release-journey-receipt/);
  assert.match(job('release'), /cp release-journeys\.json dist\/release-journeys\.json/);
  assert.match(job('release'), /run: node tools\/sign-release\.mjs/);
  assert.deepEqual(needsOf('queue-newer'), ['prepare', 'release']);
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
  const source = fs.readFileSync(new URL('./release-launch.ps1', import.meta.url), 'utf8');
  const parser = "$source = [Console]::In.ReadToEnd(); $tokens = $null; $problems = $null; $null = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$problems); if ($problems.Count -gt 0) { throw ($problems | Out-String) }; 'STARTUP_COMMAND_PARSED'";
  const result = spawnSync('powershell.exe', ['-NoProfile', '-Command', parser], { input: source, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /STARTUP_COMMAND_PARSED/);
});
