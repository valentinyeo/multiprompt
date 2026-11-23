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
