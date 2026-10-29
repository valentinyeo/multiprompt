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
    const samples = fs.readFileSync(path.join(dir, 'speed-trend.jsonl'), 'utf8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(samples.map(sample => sample.value), [51, 500, 5000, 5001]);
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
