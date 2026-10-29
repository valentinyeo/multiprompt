import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = file => fs.readFileSync(new URL(file, root), 'utf8');
const exists = file => fs.existsSync(new URL(file, root));

test('release policy is explicit and speed warnings cannot mask missing content', async () => {
  assert.ok(exists('tools/release-gates.json'), 'Release policy must separate speed from stability');
  const policy = JSON.parse(read('tools/release-gates.json'));
  assert.equal(policy.checks['ui-hang'].kind, 'stability');
  assert.equal(policy.checks['ui-hang'].limit, 5000);
  assert.equal(policy.checks['browser-switch-gap'].kind, 'speed');
  assert.equal(policy.checks['browser-switch-gap'].limit, 50);
  const script = read('.claude/skills/verify-multiprompt/control-feature-chat-switch-speed.ps1');
  assert.match(script, /Assert-ReleaseTiming 'chat-switch'/);
  assert.match(script, /Assert-ReleaseTiming 'ui-hang'/);
  assert.match(script, /if \(\$timings\[\$mode\]\.missing -gt 0 -or \$timings\[\$mode\]\.first_frame_wrong_width -gt 0 -or \$timings\[\$mode\]\.moved_after_first_frame -gt 0\) \{ throw \$gapCase.detail \}/);
  const browser = read('.claude/skills/verify-multiprompt/control-feature-browser-switch-speed.ps1');
  assert.match(browser, /Assert-ReleaseTiming 'browser-switch-gap'/);
  assert.doesNotMatch(browser, /if \(\$pair.gap_ms -gt 50\) \{ throw/);
});

test('the actual timing boundary warns, retains samples, rejects hangs and fails closed', { skip: !process.env.GITHUB_ACTIONS }, () => {
  assert.ok(exists('tools/release-gates.ps1'), 'Timing policy must run at the measured boundary');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-gates-'));
  const shell = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
  try {
    const probe = path.join(dir, 'probe.ps1');
    fs.writeFileSync(probe, `param([string]$Name, [double]$Value, [string]$Evidence)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. './tools/release-gates.ps1'
Assert-ReleaseTiming $Name $Value 'test sample'
`);
    const run = (name, value) => spawnSync(shell, ['-NoProfile', '-File', probe, name, String(value), dir], { encoding: 'utf8' });
    assert.equal(run('browser-switch-gap', 51).status, 0);
    assert.equal(run('browser-switch-gap', 500).status, 0);
    assert.equal(run('ui-hang', 5000).status, 0);
    assert.notEqual(run('ui-hang', 5001).status, 0);
    assert.notEqual(run('unclassified-check', 1).status, 0);
    assert.notEqual(run('browser-switch-gap', -1).status, 0);
    assert.notEqual(run('browser-switch-gap', 5001).status, 0);
    const samples = fs.readFileSync(path.join(dir, 'speed-trend.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(samples.map(sample => sample.value), [51, 500, 5000, 5001, 5001, 5001]);
    assert.equal(samples[0].status, 'warning');
    assert.equal(samples[1].largeRegression, true);
    assert.equal(samples[2].status, 'passed');
    assert.equal(samples[3].status, 'failed');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('publication and proof cancellation use separate concurrency lanes', () => {
  const workflow = read('.github/workflows/release.yml');
  assert.match(workflow, /group: release-\$\{\{.*inputs.proof.*github.ref.*\}\}/);
  assert.match(workflow, /cancel-in-progress: \$\{\{ inputs.proof \|\| inputs.publication_proof \}\}/);
  assert.match(workflow, /needs: \[prepare, journeys\]/);
  assert.match(workflow, /group: release-publication\s+cancel-in-progress: false/);
  const history = read('.github/workflows/release-gates.yml');
  assert.match(history, /workflows: \[Release, auto-release\]/);
  assert.ok(history.includes('group: release-gates-${{ github.event_name }}-${{ github.event.workflow_run.id || github.ref }}'));
  assert.match(history, /startsWith\(github.event.workflow_run.head_branch, 'v'\)/);
});

test('history separates unchanged-code flakes from deterministic failures', async () => {
  assert.ok(exists('tools/release-gates-history.mjs'), 'Failure history must be reported');
  const { summarize } = await import('./release-gates-history.mjs');
  const runs = Array.from({ length: 20 }, (_, index) => ({ id: index, sha: index < 4 ? 'same-sha' : `sha-${index}`, url: `https://example.org/${index}`, checks: [{ name: 'browser-switch-gap', kind: 'speed', failed: index < 3 }] }));
  const [row] = summarize(runs);
  assert.equal(row.failures, 3);
  assert.equal(row.runs, 20);
  assert.equal(row.unchangedFailures, 3);
  assert.equal(row.quarantined, true);
  assert.equal(summarize(runs.map(run => ({ ...run, sha: 'same-sha', checks: [{ name: 'browser-switch-gap', kind: 'speed', failed: true }] })))[0].quarantined, false);
  assert.equal(summarize(runs.map(run => ({ ...run, checks: [{ ...run.checks[0], kind: 'stability' }] })))[0].quarantined, false);
});

test('speed-only warnings retain the complete repeated workload and invalid samples still block', async () => {
  assert.match(read('tools/switch-performance.mjs'), /speedWarnings = false/);
  const { assessRepeated } = await import('./switch-performance.mjs');
  const workload = () => ({ sha256: 'a'.repeat(64), observerPollMs: 750, observerIdleCpuMs: 0, appIdleCpuMs: 0, idleWallMs: 1000, idleStatusReads: 50, sessionCount: 10, transcriptBytes: 250 * 1024 * 1024, idleShell: 1, switches: Array.from({ length: 50 }, (_, index) => ({ shell: index % 10, us: 300000, blocks: 2 })), idleUs: Array(50).fill(10000) });
  const pairs = Array.from({ length: 5 }, () => ({ base: workload(), head: workload() }));
  assert.throws(() => assessRepeated(pairs), /exceeded unchanged/);
  const rows = assessRepeated(pairs, { speedWarnings: true });
  assert.equal(rows.length, 5);
  assert.equal(rows[0].candidate.pass, false);
  assert.equal(rows[0].candidate.p95Ms, 300);
  pairs[0].head.switches.pop();
  assert.throws(() => assessRepeated(pairs, { speedWarnings: true }), /exactly 50/);
  assert.match(read('.github/workflows/test.yml'), /report evidence\/base\/samples.json evidence\/head\/samples.json --release-policy/);
  assert.match(read('.github/workflows/test.yml'), /Assert-ReleaseTiming 'ui-hang' \$rows\[1\].maxMs/);
});

test('large warnings file one tracking issue, not old warnings or duplicates', { skip: process.platform === 'win32' }, async () => {
  assert.ok(exists('tools/release-gates-history.mjs'), 'Large regressions need a tracked outcome');
  const { fileRegressions } = await import('./release-gates-history.mjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-issues-'));
  const previous = { PATH: process.env.PATH, RELEASE_RUN_ID: process.env.RELEASE_RUN_ID, RELEASE_ISSUE_LOG: process.env.RELEASE_ISSUE_LOG };
  try {
    const log = path.join(dir, 'calls.jsonl');
    fs.writeFileSync(path.join(dir, 'gh'), `#!${process.execPath}
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.RELEASE_ISSUE_LOG, JSON.stringify(args) + '\\n');
if (args[0] === 'api') console.log(JSON.stringify([{ title: 'Speed regression: already-tracked' }]));
`, { mode: 0o755 });
    process.env.PATH = dir + path.delimiter + previous.PATH;
    process.env.RELEASE_RUN_ID = '123';
    process.env.RELEASE_ISSUE_LOG = log;
    const sample = { value: 500, target: 50, run: 'https://example.org/123', sha: 'measured-commit' };
    fileRegressions('fixture/repo', { regressions: [{ ...sample, name: 'fresh' }, { ...sample, name: 'fresh' }, { ...sample, name: 'already-tracked' }, { ...sample, name: 'old', run: 'https://example.org/122' }] });
    const calls = fs.readFileSync(log, 'utf8').trim().split('\n').map(JSON.parse);
    const created = calls.filter(args => args[0] === 'issue');
    assert.equal(created.length, 1);
    assert.equal(created[0][created[0].indexOf('--title') + 1], 'Speed regression: fresh');
    assert.match(created[0][created[0].indexOf('--body') + 1], /500 ms[\s\S]*https:\/\/example.org\/123[\s\S]*measured-commit/);
  } finally {
    for (const [name, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('missing baseline timing warns without hiding invalid candidate evidence', () => {
  assert.match(read('.github/workflows/test.yml'), /name: Measure baseline session speed\s+continue-on-error: true/);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'baseline-policy-'));
  try {
    const baseline = path.join(dir, 'baseline.json');
    const candidate = path.join(dir, 'candidate.json');
    const data = { revision: 'candidate', sessionCount: 10, transcriptBytes: 250 * 1024 * 1024, idleShell: 1, switches: Array.from({ length: 50 }, (_, index) => ({ shell: index % 10, us: 300000, blocks: 2 })), idleUs: Array(50).fill(10000) };
    fs.writeFileSync(candidate, JSON.stringify(data));
    const args = [new URL('tools/switch-performance.mjs', root).pathname, 'report', baseline, candidate, '--release-policy'];
    if (process.platform === 'win32') args[0] = decodeURIComponent(args[0].replace(/^\//, ''));
    const warned = spawnSync(process.execPath, args, { encoding: 'utf8' });
    assert.equal(warned.status, 0, warned.stdout + warned.stderr);
    assert.match(warned.stdout, /Baseline unavailable/);
    const verdict = JSON.parse(fs.readFileSync(path.join(dir, 'verdict.json'), 'utf8'));
    assert.equal(verdict[0].unavailable, true);
    assert.equal(verdict[1].pass, false);
    assert.equal(verdict[1].p95Ms, 300);
    data.switches.pop();
    fs.writeFileSync(candidate, JSON.stringify(data));
    const invalid = spawnSync(process.execPath, args, { encoding: 'utf8' });
    assert.notEqual(invalid.status, 0);
    assert.match(invalid.stderr, /Expected exactly 50 switches/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('live cache evidence preserves the shipped replacement-sharing fix', () => {
  const drive = read('tools/verify-chat-delivery/drive.ps1');
  const helper = drive.slice(drive.indexOf('function Read-Shared('), drive.indexOf('function Step('));
  assert.match(helper, /\[IO.FileShare\]::ReadWrite -bor \[IO.FileShare\]::Delete/);
  if (process.platform !== 'win32') return;
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'shared-cache-read-'));
  try {
    const file = path.join(directory, 'cache.jsonl');
    fs.writeFileSync(file, 'complete cache record');
    const script = `$ErrorActionPreference = 'Stop'
${helper}
$writer = [IO.FileStream]::new($env:CACHE_READ_FIXTURE, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete), 4096, [IO.FileOptions]::DeleteOnClose)
try {
  if ((Read-Shared $env:CACHE_READ_FIXTURE) -cne 'complete cache record') { throw 'Cache evidence differs from actual bytes' }
  Write-Output 'CACHE_REPLACEMENT_READ_OK'
} finally { $writer.Dispose() }
`;
    const observed = spawnSync('powershell.exe', ['-NoProfile', '-Command', script], { encoding: 'utf8', env: { ...process.env, CACHE_READ_FIXTURE: file } });
    assert.equal(observed.status, 0, observed.stdout + observed.stderr);
    assert.match(observed.stdout, /CACHE_REPLACEMENT_READ_OK/);
  } finally { fs.rmSync(directory, { recursive: true, force: true }); }
});
