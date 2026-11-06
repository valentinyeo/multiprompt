import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
assert.ok(fs.existsSync(new URL('./evaluate.mjs', import.meta.url)), 'Resource evaluator must ship');
const { evaluateResources, evaluateLatency } = await import('./evaluate.mjs');
const limits = { workload: 'fixture', sessionCount: 30, resources: { memoryToleranceBytes: 16, cardinalityGrowth: 0 }, latency: { sendPaintMs: 300, typingMs: 50 } };
const file = { inputPath: 'input', stagedPath: 'staged', inputSha256: 'a'.repeat(64), stagedSha256: 'a'.repeat(64) };
const staging = { exe: file, bridge: file, config: file, helper: file };
const normal = { staging, workload: 'fixture', sessionCount: 30, readySessions: 30, cleaned: true, appAlive: true, processes: 2, jobActiveProcesses: 2, rawProcesses: [{}, {}], syntheticSshProcesses: 1, syntheticSshReaders: 1, jobConsoleProcesses: 0, workingSetBytes: 100, idleCpuPercent: 1 };
test('resource workflows pass versions safely to PowerShell', () => {
  const pr = fs.readFileSync(new URL('../../.github/workflows/resource-observation.yml', import.meta.url), 'utf8');
  const release = fs.readFileSync(new URL('../../.github/workflows/release.yml', import.meta.url), 'utf8');
  assert.match(pr, /\$tag = node tools\/release-version\.mjs\s+if \(\$LASTEXITCODE -ne 0\) \{ exit \$LASTEXITCODE \}\s+"CANDIDATE_VERSION=\$\(\$tag\.Substring\(1\)\)" \| Out-File -FilePath \$env:GITHUB_ENV -Encoding utf8 -Append/);
  assert.match(pr, /zig build -Dtarget=x86_64-windows-gnu -Drelease=true "-Dversion=\$env:CANDIDATE_VERSION"/);
  assert.match(pr, /-Feature chat-send-latency -Exe \$exe -ExpectedVersion \$env:CANDIDATE_VERSION -ExpectedHash \$hash/);
  assert.match(release, /-Feature chat-send-latency -Exe \$exe -ExpectedVersion \$version -ExpectedHash \$hash/);
});
test('comparison fails closed and blocks regressions', () => {
  assert.deepEqual(evaluateResources(limits, normal, normal), []);
  const otherConfig = { ...file, inputSha256: 'b'.repeat(64), stagedSha256: 'b'.repeat(64) };
  assert.match(evaluateResources(limits, normal, { ...normal, staging: { ...staging, config: otherConfig } }).join(), /telemetry config differs/);
  assert.match(evaluateResources(limits, normal, { ...normal, staging: {} }).join(), /invalid exe staging/);
  assert.match(evaluateResources(limits, normal, { ...normal, processes: 3, jobActiveProcesses: 3, rawProcesses: [{}, {}, {}] }).join(), /processes: 3 exceeds baseline/);
  assert.match(evaluateResources(limits, normal, { ...normal, syntheticSshProcesses: 2 }).join(), /syntheticSshProcesses/);
  assert.match(evaluateResources(limits, normal, { ...normal, syntheticSshReaders: 2 }).join(), /syntheticSshReaders/);
  assert.match(evaluateResources(limits, normal, { ...normal, workingSetBytes: 117 }).join(), /workingSetBytes/);
  assert.match(evaluateResources(limits, normal, { ...normal, readySessions: 29 }).join(), /incomplete workload/);
  assert.match(evaluateResources(limits, null, normal).join(), /missing/);
  assert.match(evaluateResources(limits, normal, { ...normal, jobActiveProcesses: 3 }).join(), /incomplete/);
});
test('latency warns and missing samples remain unmeasured', () => {
  const samples = ms => ({ samples: Array.from({ length: 20 }, () => ({ paintedMs: ms })) });
  assert.equal(evaluateLatency(limits, samples(300)).status, 'pass');
  assert.equal(evaluateLatency(limits, samples(301)).status, 'warning');
  assert.equal(evaluateLatency(limits, samples(NaN)).status, 'unmeasured');
});
