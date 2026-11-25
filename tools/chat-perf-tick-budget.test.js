const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_perf_test.zig'), 'utf8');

function number(name, pattern) {
  const found = source.match(pattern);
  assert.ok(found, `${name} missing from src/chat_perf_test.zig`);
  return Number(found[1]);
}

const tick = number('tick_ms', /tick_ms: f64 = ([\d.]+)/);
const minBatch = number('min_batch_ms', /min_batch_ms: i64 = (\d+)/);
const slack = number('slack_ratio', /slack_ratio: f64 = ([\d.]+)/);
const floor = number('absolute_floor_ms', /absolute_floor_ms: i64 = (\d+)/);
const refBlockChars = 1200;

function workUnits(blocks, blockChars) {
  return blocks * (blockChars + refBlockChars);
}

const refWork = workUnits(6100, refBlockChars);
const heaviestWork = workUnits(12_200, 600);
const smallWork = workUnits(2800, 600);

function quantize(ms) {
  return Math.floor(ms / tick + 1e-9) * tick;
}

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

function oldBudget(calibrateReadingMs) {
  return Math.max(50, Math.ceil(calibrateReadingMs * (heaviestWork / smallWork) * 1.35));
}

function newBudget(referencePerCallMs) {
  return Math.max(floor, referencePerCallMs * (heaviestWork / refWork) * slack);
}

function batchedPerCall(truePerCallMs) {
  const reps = Math.max(1, Math.ceil(minBatch / truePerCallMs));
  const batch = quantize(reps * truePerCallMs);
  return { reps, perCall: batch / reps, error: truePerCallMs - batch / reps };
}

test('SOFT-3052 recorded 0 and 15 ms calibrate readings flake the old gate', () => {
  const recorded = {
    job: 'run 45006022668 job 137157781639 test-windows (2)',
    calibrate: [0, 15, 15, 0, 15, 0, 15],
    calibrateWall: [8, 8, 8, 8, 9, 20, 20],
    reconcile: [93, 78, 93, 78, 93],
    reconcileWall: [83, 84, 84, 85, 84],
  };
  assert.ok(recorded.calibrate.every(reading => reading % 15 === 0), 'recorded calibrate readings sit on the tick grid');
  const oldRead = median(recorded.reconcile);
  const oldLimit = oldBudget(median(recorded.calibrate));
  const trueCalibrate = median(recorded.calibrateWall);
  const trueHeavy = median(recorded.reconcileWall);
  assert.equal(oldLimit, 89);
  assert.ok(oldRead > oldLimit, `old gate reds on a reading of ${oldRead} ms over ${oldLimit} ms`);
  assert.ok(trueHeavy < oldLimit, `the measured path used ${trueHeavy} ms of real CPU, inside its ${oldLimit} ms budget`);
  assert.ok(trueCalibrate < tick, 'the calibrate call costs less than one tick, so its reading is 0 or 15');

  const reference = batchedPerCall(trueHeavy);
  const heavy = batchedPerCall(trueHeavy);
  const newLimit = newBudget(reference.perCall);
  assert.ok(heavy.perCall <= newLimit, `batched reading ${heavy.perCall} ms stays inside ${newLimit} ms`);
  assert.ok(heavy.error <= tick / heavy.reps, `batched error ${heavy.error} ms stays inside one tick over ${heavy.reps} reps`);
  assert.ok(reference.reps > 1 && heavy.reps > 1, 'both sides read a multi-call batch');
  console.log('%s old_reading=%d old_budget=%d true_cpu_ms=%d new_per_call_ms=%d new_budget_ms=%d reps=%d', recorded.job, oldRead, oldLimit, trueHeavy, heavy.perCall, newLimit, heavy.reps);
});

test('SOFT-3052 a batched trial keeps one tick inside a fraction of the budget', () => {
  for (const truePerCallMs of [0.3, 1, 4, 8, 18, 84, 117, 250]) {
    const measured = batchedPerCall(truePerCallMs);
    assert.ok(measured.reps >= 1);
    assert.ok(measured.error >= 0, 'the CPU tick clock can only read low');
    assert.ok(measured.error <= tick / measured.reps + 1e-9, `${truePerCallMs} ms under-reads by ${measured.error}`);
    const worstRatio = truePerCallMs / measured.perCall;
    assert.ok(worstRatio <= slack, `${truePerCallMs} ms reads ${measured.perCall} ms, ratio ${worstRatio}`);
  }
  console.log('SOFT-3052 batched tick guard ok min_batch_ms=%d tick_ms=%s', minBatch, tick);
});

test('SOFT-3052 a doubled heavy path still fails the batched gate', () => {
  const reference = batchedPerCall(84);
  const regressed = batchedPerCall(84 * 2 + tick);
  const limit = newBudget(reference.perCall);
  assert.ok(regressed.perCall > limit, `regressed reading ${regressed.perCall} ms must exceed ${limit} ms`);
  const noisyReference = batchedPerCall(84 + tick);
  assert.ok(84 <= newBudget(noisyReference.perCall), 'a one tick slower reference keeps the good path green');
  console.log('SOFT-3052 regression guard ok limit_ms=%d regressed_ms=%d', limit, regressed.perCall);
});
