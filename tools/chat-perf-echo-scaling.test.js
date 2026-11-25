const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_perf_test.zig'), 'utf8');
const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');

const refBlocks = 6100;
const refBlockChars = 1200;

function workUnits(blocks, blockChars) {
  return blocks * (blockChars + refBlockChars);
}

const refWork = workUnits(refBlocks, refBlockChars);
const heaviestWork = workUnits(12_200, 600);
const smallWork = workUnits(2800, 600);
const slack = 1.2;
const floor = 20;
const tick = 15.625;
const minBatch = 100;

function refFromSmallBaseline(baselineMs) {
  return baselineMs * (refWork / smallWork);
}

function budgetMs(referenceMs, units) {
  return Math.max(floor, referenceMs * (units / refWork) * slack);
}

function legacyWorkUnits(blocks, blockChars) {
  return blocks * blockChars;
}

function legacyBudgetMs(referenceMs, units) {
  return Math.max(floor, referenceMs * (units / (refBlocks * refBlockChars)) * slack);
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
  assert.match(source, /heaviest_work_units: u64 = workUnits\(12200, 600\)/);
  assert.match(source, /return b \* \(c \+ @as\(u64, @intCast\(ref_block_chars\)\)\)/);
  assert.match(source, /IGSH-991 SOFT-3146 echo assign budget credits per-block scan alongside character volume/);
  assert.match(source, /slack_ratio: f64 = 1\.2/);
  assert.match(source, /absolute_floor_ms: i64 = 20/);
  assert.match(source, /CPU960 reference_per_call_ms=\{d:\.3\}/);
  assert.match(source, /CPU991 matching worst_ratio=\{d:\.3\}/);
  const refChars = 6100 * 1200;
  const heavyChars = 12_200 * 600;
  assert.equal(refChars, heavyChars, 'the reference history holds the same characters as the heaviest case');
  assert.ok(heaviestWork / refWork > 1.4 && heaviestWork / refWork < 1.6, 'block-heavy histories weigh more than character volume alone');
});

test('CPU991 pairs every scenario trial with an adjacent reference trial and runs the heaviest case first', () => {
  assert.match(source, /const block_counts = \[_\]usize\{ 12200, 2800, 1200 \}/);
  assert.match(source, /const block_chars = \[_\]usize\{ 600, 60 \}/);
  assert.match(source, /const scenario_first = trial % 2 == 0/);
  assert.match(source, /const pair = try Bench\.paired\(scenario, reference, scenario_first\)/);
  assert.match(source, /const scenario_budget_ms = Bench\.budgetMs\(pair\.reference_ms, units\)/);
  assert.match(source, /best_ratio = @min\(best_ratio, ratio\)/);
  assert.match(source, /reference_batch_ms=\{d\}/);
  assert.doesNotMatch(source, /late calibrate/);

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
  const ratios = recorded.cases.map(row => row.best / budgetMs(recorded.reference, workUnits(row.blocks, row.chars)));
  const heaviestRatio = ratios[ratios.length - 1];
  assert.ok(heaviestRatio <= 1, `${recorded.job} stays inside the block-aware budget at ratio ${heaviestRatio.toFixed(3)}`);
  assert.ok(
    ratios.slice(0, -1).every(ratio => ratio < 0.5),
    `every case before the last stayed inside its budget: ${ratios.slice(0, -1).map(r => r.toFixed(3)).join(' ')}`,
  );
  assert.ok(wouldPass(33, recorded.reference, heaviestWork), 'the same heavy case read 33 ms in the green run, so the shape is fine');
  const soft3146 = { reference: 32, best: 62, blocks: 12200, chars: 600 };
  const soft3146Units = workUnits(soft3146.blocks, soft3146.chars);
  const legacyLimit = legacyBudgetMs(soft3146.reference, legacyWorkUnits(soft3146.blocks, soft3146.chars));
  assert.ok(soft3146.best > legacyLimit, `legacy gate rejects ${soft3146.best} ms over ${legacyLimit.toFixed(3)} ms`);
  assert.ok(
    soft3146.best > budgetMs(soft3146.reference, soft3146Units),
    'SOFT-3146 compared its heavy case with a reference read in a different, faster window',
  );
  console.log('%s heavy_ratio=%s soft3146_budget=%s', recorded.job, heaviestRatio.toFixed(3), budgetMs(soft3146.reference, soft3146Units).toFixed(3));
});

test('SOFT-3146 a doubled heavy path still fails the block-aware gate', () => {
  const reference = refFromSmallBaseline(15);
  const budget = budgetMs(reference, heaviestWork);
  assert.equal(wouldPass(92, reference, heaviestWork), false, `regressed 92 ms must exceed ${budget.toFixed(3)} ms`);
  assert.ok(wouldPass(33, 32, heaviestWork), 'a heavy case read beside its own reference stays green');
});

test('IGSH-991 a reference from the same window keeps a slow shared runner inside the budget', () => {
  const job = 'run 45462960580 job 138690219653 test-vps (1)';
  const referenceFastWindow = 29;
  const heavySlowWindow = 61;
  const heavySameCaseFastWindow = 36;
  const swing = heavySlowWindow / heavySameCaseFastWindow;
  assert.ok(swing > 1.5, `the shared runner swung ${swing.toFixed(2)}x inside one run`);
  const pairedReference = referenceFastWindow * swing;
  const unpaired = heavySlowWindow / budgetMs(referenceFastWindow, heaviestWork);
  const paired = heavySlowWindow / budgetMs(pairedReference, heaviestWork);
  assert.ok(unpaired > 1, `${job} red at ${unpaired.toFixed(3)} of budget against a reference from another window`);
  assert.ok(paired <= 1, `${job} green at ${paired.toFixed(3)} of budget against a reference paired with it`);
  const doubled = heavySlowWindow * 2;
  assert.ok(doubled / budgetMs(pairedReference, heaviestWork) > 1, 'a doubled heavy path still reds next to its own reference');
  console.log('%s swing=%sx unpaired=%s paired=%s', job, swing.toFixed(2), unpaired.toFixed(3), paired.toFixed(3));
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

test('IGSH-991 paired references hold on every recorded shared runner and still red a doubled path', () => {
  const run = 'run 45480523538 test-vps (1) x20';
  const measured = [
    { reference: 22.8, heavy: 23.85 },
    { reference: 23.0, heavy: 23.85 },
    { reference: 23.0, heavy: 24.0 },
    { reference: 23.2, heavy: 23.85 },
    { reference: 23.4, heavy: 24.0 },
    { reference: 27.0, heavy: 25.697 },
    { reference: 28.75, heavy: 28.527 },
    { reference: 29.25, heavy: 28.253 },
    { reference: 29.25, heavy: 29.319 },
    { reference: 31.5, heavy: 32.149 },
    { reference: 32.4, heavy: 32.936 },
    { reference: 34.667, heavy: 35.872 },
    { reference: 35.0, heavy: 33.524 },
    { reference: 35.0, heavy: 35.721 },
    { reference: 36.333, heavy: 37.155 },
    { reference: 39.0, heavy: 37.908 },
    { reference: 41.0, heavy: 42.343 },
    { reference: 41.333, heavy: 42.185 },
    { reference: 50.5, heavy: 51.029 },
    { reference: 72.0, heavy: 75.524 },
  ];
  const shares = measured.map(row => row.heavy / budgetMs(row.reference, heaviestWork));
  assert.ok(
    shares.every(share => share <= 1),
    `${run} stayed green on every runner: ${shares.map(share => share.toFixed(3)).join(' ')}`,
  );
  assert.ok(Math.max(...shares) < 0.75, `the worst recorded runner used ${Math.max(...shares).toFixed(3)} of its budget`);
  assert.ok(
    measured.every(row => row.heavy * 2 > budgetMs(row.reference, heaviestWork)),
    'a doubled heavy path reds on every recorded runner',
  );
  assert.equal(wouldPass(92, refFromSmallBaseline(15), heaviestWork), false, 'a doubled heavy path still fails the small-history baseline');
  assert.ok(minBatch > 0);
  console.log('%s paired budget shares min=%s max=%s', run, Math.min(...shares).toFixed(3), Math.max(...shares).toFixed(3));
});
