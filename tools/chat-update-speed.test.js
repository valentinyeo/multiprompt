const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const modulePath = path.join(__dirname, 'chat-update-speed.mjs');
async function reader() {
  assert.ok(fs.existsSync(modulePath), 'Paired speed evidence reader exists');
  return import(pathToFileURL(modulePath).href);
}
function fixture(cpu = [130, 125, 129], reconcile = false) {
  return `CPU707 parse rows=52430000 blocks=26736 messages=26736 parse_cpu_ms=600 parse_wall_ms=700
CPU707 suffix rows=1961 expected_rows=1961
CPU707 suffix rows=1961 expected_rows=1961
CPU707 suffix rows=1961 expected_rows=1961
CPU707 delta cpu_ms=${cpu.join('/')} wall_ms=140/135/139 best_cpu_ms=${Math.min(...cpu)} budget_ms=100 blocks=26737 changed_from=26735
${reconcile ? 'CPU707 reconcile picked=26736 expected_pick=26736 represented=26736 extra_picks=0 reconcile_cpu_ms=20 reconcile_wall_ms=25' : ''}`;
}

test('speed evidence retains failed baseline timings without treating them as candidate success', async () => {
  const { parseRun, compare } = await reader();
  const old = parseRun(fixture(), 1);
  const fixed = parseRun(fixture([30, 28, 29], true), 0);
  const result = compare(Array(5).fill(old), Array(5).fill(fixed));
  assert.equal(result.before.budgetFailures, 5);
  assert.equal(result.before.allCpuMs.median, 129);
  assert.equal(result.after.bestCpuMs.median, 28);
  assert.equal(result.passed, true);
  assert.equal(compare(Array(5).fill(old), Array(5).fill(old)).passed, false);
});

test('speed evidence rejects missing work and changed output', async () => {
  const { parseRun } = await reader();
  for (const log of [fixture().replace('rows=52430000', 'rows=100'), fixture().replace('blocks=26737', 'blocks=26736'), fixture().replace('changed_from=26735', 'changed_from=0'), fixture().replace('CPU707 suffix rows=1961 expected_rows=1961', '')]) {
    assert.throws(() => parseRun(log, 1));
  }
});

test('speed evidence requires successful reconciliation and explains every exit', async () => {
  const { parseRun } = await reader();
  assert.throws(() => parseRun(fixture([30, 28, 29]), 0), /Reconciliation/);
  assert.throws(() => parseRun(fixture([30, 28, 29], true).replace('extra_picks=0', 'extra_picks=1'), 0), /Reconciliation/);
  assert.throws(() => parseRun(fixture(), 137), /Unexplained/);
  assert.throws(() => parseRun(fixture([30, 28, 29], true), 1), /Unexplained/);
});

test('speed evidence keeps five repeats, identical histories and the original limit', async () => {
  const { parseRun, compare } = await reader();
  const good = parseRun(fixture([30, 28, 29], true), 0);
  assert.throws(() => compare([good], [good]), /Five complete/);
  assert.throws(() => compare(Array(5).fill(good), Array(5).fill({ ...good, rows: 52430001 })), /different histories/);
  assert.equal(compare(Array(5).fill(good), Array(5).fill({ ...good, best: 100 })).passed, false);
});
