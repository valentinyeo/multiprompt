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

test('production publishes the build, startup proof and signature gates without a journey gate', () => {
  assert.equal(jobs.journeys, undefined, 'release.yml must not run candidate journeys');
  assert.equal(jobs['journey-gate'], undefined, 'release.yml must not gate publication on journeys');
  assert.doesNotMatch(workflow, /release-journeys\.mjs|release-journey-receipt/);
  assert.deepEqual(needsOf('build'), ['prepare']);
  assert.doesNotMatch(job('build'), /^    if:/m);
  assert.match(job('build'), /Executable embedded version does not match release tag/);
  assert.deepEqual(needsOf('launch'), ['prepare', 'build']);
  assert.match(job('launch'), /run: \.\/tools\/release-launch\.ps1 -Exe release-bin\/multiprompt-x64\.exe -Evidence release-proof/);
  assert.match(job('launch'), /name: release-launch-proof\n          path: release-proof\/\n          if-no-files-found: error/);
  assert.equal(jobs['resource-observation'], undefined, 'release.yml must not run resource-observation on the release path');
  assert.match(job('build'), /uses: actions\/cache@0057852bfaa89a56745cba8c7296529d2fc39830[\s\S]*zig-toolchain-0\.16\.0/);
  assert.match(job('build'), /uses: actions\/cache@0057852bfaa89a56745cba8c7296529d2fc39830[\s\S]*\.zig-cache[\s\S]*ZIG_GLOBAL_CACHE_DIR/);
  assert.match(job('build'), /python3 tools\/trim-zig-cache\.py --cap-mib 1600/);
  assert.doesNotMatch(job('launch'), /actions\/setup-node/);
  assert.match(job('gitleaks'), /release_scan: true/);
  assert.deepEqual(needsOf('release'), ['prepare', 'build', 'launch', 'gitleaks']);
  assert.doesNotMatch(job('release'), /^    if:/m);
  assert.match(job('release'), /run: node tools\/sign-release\.mjs/);
  assert.deepEqual(needsOf('queue-newer'), ['prepare', 'release']);
  const nightly = fs.readFileSync(new URL('../.github/workflows/resource-observation.yml', import.meta.url), 'utf8');
  assert.match(nightly, /^  schedule:\n    - cron: '[^']+'/m);
  assert.match(nightly, /node tools\/resource-warning-ticket\.mjs/);
});

test('symbol files build beside the release and attach after publication', () => {
  assert.deepEqual(needsOf('symbols'), ['prepare']);
  assert.deepEqual(needsOf('attach-symbols'), ['prepare', 'release', 'symbols']);
  assert.doesNotMatch(job('build'), /symbols/);
  assert.doesNotMatch(job('release'), /symbols/);
  assert.match(job('symbols'), /uses: actions\/cache\/restore@0057852bfaa89a56745cba8c7296529d2fc39830[\s\S]*\.zig-cache/);
  assert.match(job('symbols'), /name: multiprompt-\$\{\{ matrix.arch \}\}-symbols/);
  assert.match(job('attach-symbols'), /gh release upload "\$TAG" "\$\{files\[@\]\}"/);
});

test('a master push never cancels a release already running', () => {
  const auto = fs.readFileSync(new URL('../.github/workflows/auto-release.yml', import.meta.url), 'utf8');
  assert.match(auto, /^concurrency:\n  group: auto-release-\$\{\{ github\.ref \}\}\n  cancel-in-progress: false$/m);
  assert.match(auto, /needs\.release\.result == 'success' \|\| needs\.release\.result == 'cancelled'/);
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
