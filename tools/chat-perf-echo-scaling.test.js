const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_perf_test.zig'), 'utf8');
const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');

const refWork = 6100 * 1200;
const heaviestWork = 12_200 * 600;
const smallWork = 2800 * 600;
const slack = 1.35;
const floor = 50;
const tick = 15.625;
const minBatch = 100;

function refFromSmallBaseline(baselineMs) {
  return baselineMs * (refWork / smallWork);
}

function budgetMs(referenceMs, units) {
  return Math.max(floor, referenceMs * (units / refWork) * slack);
}

function wouldPass(bestMs, referenceMs, units) {
  return bestMs <= budgetMs(referenceMs, units);
}

test('IGSH-991 echo budgets run only under stable optimize', () => {
  const start = build.indexOf('const chat_perf_tests = b.addTest');
  const end = build.indexOf('const run_chat_perf_tests =', start);
  assert.ok(start >= 0 && end > start);
  assert.match(build.slice(start, end), /\.filters = &\.\{ "CPU707", "ISSUE-421" \}/);
  const echoStart = build.indexOf('const chat_echo_budget_tests = b.addTest');
  const echoEnd = build.indexOf('const run_chat_echo_budget_tests =', echoStart);
  assert.match(build.slice(echoStart, echoEnd), /\.filters = &\.{"IGSH-991"}/);
});

test('CPU991 measures a same-volume reference before enforcing scaled budgets', () => {
  assert.match(source, /CPU960 calibrate/);
  assert.match(source, /reference_per_call_ms/);
  assert.match(source, /ref_blocks: usize = 6100/);
  assert.match(source, /ref_block_chars: usize = 1200/);
  assert.match(source, /heaviest_work_units: u64 = 12200 \* 600/);
  assert.match(source, /slack_ratio: f64 = 1\.35/);
  assert.match(source, /absolute_floor_ms: i64 = 50/);
  assert.match(source, /CPU960 reference_per_call_ms=\{d:\.3\}/);
  assert.match(source, /CPU991 matching worst_ratio=\{d:\.3\}/);
  const refWorkUnits = 6100 * 1200;
  const heaviest = 12_200 * 600;
  assert.equal(refWork, refWorkUnits, 'the reference history holds the same characters as the heaviest case');
  assert.ok(heaviest / refWork > 0.99 && heaviest / refWork < 1.01, 'reference and heaviest case share one working set');
});

test('CPU991 calibrates in the window it judges and runs the heaviest case first', () => {
  assert.match(source, /const block_counts = \[_\]usize\{ 12200, 2800, 1200 \}/);
  assert.match(source, /const block_chars = \[_\]usize\{ 600, 60 \}/);
  assert.match(source, /CPU960 late calibrate/);
  assert.match(source, /@max\(early_reference_per_call_ms, late_reference_per_call_ms\)/);
  assert.match(source, /CPU960 window_reference_per_call_ms=\{d:\.3\}/);

  const recorded = {
    job: 'run 45108637392 job 137475644260 test-vps (1)',
    reference: 33,
    cases: [
      { blocks: 1200, chars: 60, best: 0.392 },
      { blocks: 1200, chars: 600, best: 3.226 },
      { blocks: 2800, chars: 60, best: 0.917 },
      { blocks: 2800, chars: 600, best: 7.571 },
      { blocks: 12200, chars: 60, best: 4 },
      { blocks: 12200, chars: 600, best: 58.5 },
    ],
  };
  const ratios = recorded.cases.map(row => row.best / budgetMs(recorded.reference, row.blocks * row.chars));
  const heaviestRatio = ratios[ratios.length - 1];
  assert.ok(heaviestRatio > 1, `${recorded.job} ended over budget at ratio ${heaviestRatio.toFixed(3)}`);
  assert.ok(
    ratios.slice(0, -1).every(ratio => ratio < 0.2),
    `every case before the last stayed far inside its budget: ${ratios.slice(0, -1).map(r => r.toFixed(3)).join(' ')}`,
  );
  assert.ok(wouldPass(33, recorded.reference, heaviestWork), 'the same heavy case read 33 ms in the green run, so the shape is fine');
  assert.ok(wouldPass(58.5, 45, heaviestWork), 'a calibration that shares the drift lifts the heavy case over its own reading');
  console.log('%s heavy_ratio=%s green_ratio=%s', recorded.job, heaviestRatio.toFixed(3), (33 / 50).toFixed(3));
});

test('every trial reads a batch of calls that spans many CPU clock ticks', () => {
  assert.match(source, /tick_ms: f64 = 15\.625/);
  assert.match(source, /min_batch_ms: i64 = 100/);
  assert.match(source, /for \(0\.\.reps\) \|_\| \{/);
  assert.match(source, /echo\.assign\(&pending, users\[0 \.\. users\.len - 1 \+ @intFromBool\(present\)\], false, &\.\{\}, &picked\)/);
  assert.match(source, /batch_ms = ms\(start\)/);
  assert.match(source, /per_call_ms = @as\(f64, @floatFromInt\(batch_ms\)\) \/ @as\(f64, @floatFromInt\(@max\(reps, 1\)\)\)/);
  assert.ok(minBatch / tick >= 6, `a batch spans at least six ticks: ${minBatch / tick}`);
  const worstTickShare = tick / (minBatch / slack);
  assert.ok(worstTickShare < 0.35, `one tick must stay under the slack: ${worstTickShare}`);
});

test('scaled budgets accept slow shared runners but keep the previous fast-runner ceiling', () => {
  const masterVpsRuns = [
    { id: '44816468510', slowest: 74, baseline: 16, oldPass: false },
    { id: '44821414996', slowest: 34, baseline: 8, oldPass: true },
    { id: '44815030127', slowest: 50, baseline: 10, oldPass: true },
    { id: '44808619663', slowest: 17, baseline: 6, oldPass: true },
    { id: '44803544730', slowest: 32, baseline: 6, oldPass: true },
  ];
  for (const row of masterVpsRuns) {
    const reference = refFromSmallBaseline(row.baseline);
    const budget = budgetMs(reference, heaviestWork);
    const newPass = wouldPass(row.slowest, reference, heaviestWork);
    assert.ok(newPass, `${row.id} slowest=${row.slowest} baseline=${row.baseline} budget=${budget}`);
    if (row.id === '44816468510') {
      assert.equal(row.oldPass, false);
      assert.ok(row.slowest > floor, 'fixture must exceed the old absolute budget');
    }
  }
  assert.equal(wouldPass(92, refFromSmallBaseline(15), heaviestWork), false, 'a doubled heavy path still fails');
  assert.ok(minBatch > 0);
  console.log('SOFT-3052 same-volume reference replay ok samples=%d', masterVpsRuns.length);
});
