import { test } from 'node:test';
import assert from 'node:assert/strict';
import { evaluateResources, evaluateLatency } from './evaluate.mjs';
const limits = { workload: 'fixture', sessionCount: 30, resources: { memoryToleranceBytes: 16, cardinalityGrowth: 0 }, latency: { sendPaintMs: 300, typingMs: 50 } };
const normal = { workload: 'fixture', sessionCount: 30, readySessions: 30, cleaned: true, appAlive: true, processes: 2, jobActiveProcesses: 2, rawProcesses: [{}, {}], syntheticSshProcesses: 1, syntheticSshReaders: 1, jobConsoleProcesses: 0, workingSetBytes: 100, idleCpuPercent: 1 };
test('comparison fails closed and blocks regressions', () => {
  assert.deepEqual(evaluateResources(limits, normal, normal), []);
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
