const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_perf_test.zig'), 'utf8');

const calibWork = 2800 * 600;
const slack = 1.35;
const floor = 50;
const gate = 3;

function budgetMs(baselineMedianMs) {
  if (baselineMedianMs < gate) return floor;
  const scaled = baselineMedianMs * (12_200 * 600 / calibWork) * slack;
  return Math.max(floor, Math.ceil(scaled));
}

function wouldPass(slowestMedianMs, baselineMedianMs) {
  return slowestMedianMs <= budgetMs(baselineMedianMs);
}

test('CPU991 measures a same-run baseline before enforcing scaled budgets', () => {
  assert.match(source, /CPU960 calibrate/);
  assert.match(source, /baseline_median_ms/);
  assert.match(source, /calib_blocks: usize = 2800/);
  assert.match(source, /slack_ratio: f64 = 1.35/);
  assert.match(source, /CPU960 baseline_median_ms=/);
  assert.match(source, /CPU991 matching slowest_median_ms=\{d\} baseline_median_ms=\{d\} budget_ms=\{d\}/);
});

test('scaled budgets accept slow shared runners but keep the previous fast-runner ceiling', () => {
  const masterVpsRuns = [
    { id: '44816468510', slowest: 74, baseline: 16, oldPass: false },
    { id: '44821414996', slowest: 34, baseline: 8, oldPass: true },
    { id: '44815030127', slowest: 50, baseline: 8, oldPass: true },
    { id: '44808619663', slowest: 17, baseline: 6, oldPass: true },
    { id: '44803544730', slowest: 32, baseline: 6, oldPass: true },
  ];
  for (const row of masterVpsRuns) {
    const budget = budgetMs(row.baseline);
    const newPass = wouldPass(row.slowest, row.baseline);
    assert.ok(newPass, `${row.id} slowest=${row.slowest} baseline=${row.baseline} budget=${budget}`);
    if (row.id === '44816468510') {
      assert.equal(row.oldPass, false);
      assert.ok(row.slowest > floor, 'fixture must exceed the old absolute budget');
    }
  }
  assert.equal(wouldPass(46, 15), true, 'Windows-class 46 ms at baseline 15 ms');
  assert.equal(wouldPass(92, 15), false, 'a doubled heavy path should still fail');
  console.log('SOFT-2992 master replay ok samples=%d', masterVpsRuns.length);
});