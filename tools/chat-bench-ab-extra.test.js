const { test } = require('node:test');
const assert = require('node:assert/strict');
const extraModule = import('./chat-bench/ab-extra.mjs');

function run(tag, index, metrics, failures = []) {
  return { label: tag === 'v0.28.900' ? 'A' : 'B', tag, index, result: { status: failures.length ? 'FAIL' : 'PASS', metrics, failures } };
}

test('per tag medians and ranges cover every CPU, memory and paint field', async () => {
  const { summarize, markdown } = await extraModule;
  const runs = [
    run('v0.28.900', 1, { idleAverageCpu: 1, thirtySecondPeakCpu: 50, peakRssMiB: 900, switchPaintP95Ms: 100 }),
    run('v0.28.900', 2, { idleAverageCpu: 3, thirtySecondPeakCpu: 70, peakRssMiB: 1100, switchPaintP95Ms: 140 }),
    run('v0.28.900', 3, { idleAverageCpu: 2, thirtySecondPeakCpu: 60, peakRssMiB: 1000, switchPaintP95Ms: 120 }),
    run('v0.28.917', 1, { idleAverageCpu: 9, thirtySecondPeakCpu: 190, peakRssMiB: 1500, switchPaintP95Ms: 400 }, ['thirty-second CPU']),
  ];
  const groups = summarize(runs);
  assert.equal(groups.length, 2);
  assert.deepEqual(groups[0].cells.idleAverageCpu, { median: 2, min: 1, max: 3, n: 3 });
  assert.deepEqual(groups[1].cells.thirtySecondPeakCpu, { median: 190, min: 190, max: 190, n: 1 });
  assert.equal(groups[1].failedChecks, 1);
  assert.equal(groups[0].cells.coldPaintP95Ms.n, 0);
  const text = markdown(groups);
  assert.match(text, /\| v0\.28\.900 \| 3 \| 2 \[1, 3\] \| n\/a \| n\/a \| 60 \[50, 70\] \| 1000 \[900, 1100\] \| 120 \[100, 140\] \| n\/a \| n\/a \| n\/a \| 0 \|/);
  assert.match(text, /\| v0\.28\.917 \| 1 \| 9 \[9, 9\] .* \| 1 \|/);
});

test('an empty run list fails closed', async () => {
  const { summarize } = await extraModule;
  assert.throws(() => summarize([]), /No benchmark/);
});
