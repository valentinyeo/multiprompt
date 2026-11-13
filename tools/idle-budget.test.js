const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

let tools;
async function load() {
  if (!tools) tools = await import('./idle-budget.mjs');
  return tools;
}

function dump(tickMs, extra = {}) {
  return {
    tick_ms: tickMs,
    idle_ms: 120000,
    deep_idle: 0,
    server_fetch: 0,
    thread_spawn: 0,
    invalidate: 0,
    timer_fire: 0,
    log_line: 0,
    process_spawn: 0,
    timers: {},
    ...extra,
  };
}

async function run(before, after) {
  const { loadBudget, loadRegistry, evaluate } = await load();
  return evaluate({ budget: loadBudget(), registry: loadRegistry(), before, after });
}

test('a window with only registered periodic timers inside their caps passes', async () => {
  const before = dump(100000);
  const after = dump(400000, { timers: { 2: 2, 15: 2, 19: 300, 20: 150, 25: 0 } });
  const result = await run(before, after);
  assert.deepEqual(result.failures, []);
  assert.equal(result.ok, true);
});

test('master-like counters from the ticket fail on the named sources', async () => {
  const before = dump(100000);
  const after = dump(400000, { server_fetch: 960, thread_spawn: 960, invalidate: 9000, log_line: 1200, timer_fire: 120, timers: { 27: 120 } });
  const result = await run(before, after);
  assert.equal(result.ok, false);
  const sources = result.failures.map(f => f.source);
  for (const name of ['server_fetch', 'thread_spawn', 'invalidate', 'log_line']) assert.ok(sources.includes(name), name);
  const message = result.failures.find(f => f.source === 'server_fetch').message;
  assert.match(message, /^server_fetch is over budget: 960 in 300 s \(192\.0 per minute\), budget 0$/);
});

test('one fetch is already over a zero budget', async () => {
  const result = await run(dump(100000), dump(400000, { server_fetch: 1 }));
  assert.equal(result.ok, false);
  assert.equal(result.failures.length, 1);
  assert.match(result.failures[0].message, /server_fetch is over budget: 1 in 300 s/);
});

test('an event timer that wakes at idle fails by name', async () => {
  const result = await run(dump(100000), dump(400000, { timers: { 40: 3 } }));
  assert.equal(result.ok, false);
  assert.match(result.failures[0].message, /^timer 40 \(TIMER_CHAT_DRAFT\) is over budget: 3 wakes in 300 s, budget 0$/);
});

test('an unregistered timer slot fails as unregistered', async () => {
  const result = await run(dump(100000), dump(400000, { timers: { 61: 1 } }));
  assert.equal(result.ok, false);
  assert.match(result.failures[0].message, /timer 61 \(unregistered\)/);
});

test('a periodic timer gets its registered rate plus one wake of slack', async () => {
  const { loadRegistry, timerCaps } = await load();
  const caps = timerCaps(loadRegistry());
  assert.equal(caps.get(2).perMinute, 2);
  const within = await run(dump(100000), dump(400000, { timers: { 2: 11 } }));
  assert.equal(within.ok, true);
  const over = await run(dump(100000), dump(400000, { timers: { 2: 12 } }));
  assert.equal(over.ok, false);
  assert.match(over.failures[0].message, /timer 2 \(TIMER_NAME_POLL\) is over budget: 12 wakes in 300 s, budget 11/);
});

test('timers sharing a slot take the larger cap', async () => {
  const { loadRegistry, timerCaps } = await load();
  const caps = timerCaps(loadRegistry());
  assert.equal(caps.get(36).perMinute, 0);
  assert.equal(caps.get(36).names.length, 2);
});

test('a hook thread timer never reaches the counted slots', async () => {
  const { loadRegistry, timerCaps } = await load();
  const caps = timerCaps(loadRegistry());
  const names = [...caps.values()].flatMap(c => c.names);
  assert.ok(!names.includes('INPUT_HOOK_THREAD_TIMER_REQUEST_ID'));
});

test('a window shorter than the minimum is refused', async () => {
  const result = await run(dump(100000), dump(200000));
  assert.equal(result.ok, false);
  assert.match(result.failures[0].message, /idle window is 100 s; at least 280 s is required/);
});

test('dumps taken out of order are refused', async () => {
  const result = await run(dump(400000), dump(100000));
  assert.equal(result.ok, false);
  assert.equal(result.failures[0].source, 'window');
});

test('a null budget reports the source without failing it', async () => {
  const { loadBudget } = await load();
  assert.equal(loadBudget().sources.process_spawn, null);
  const result = await run(dump(100000), dump(400000, { process_spawn: 40 }));
  assert.equal(result.ok, true);
  const row = result.rows.find(r => r.source === 'process_spawn');
  assert.equal(row.observed, 40);
});

test('counters are compared as differences, not totals', async () => {
  const result = await run(dump(100000, { server_fetch: 50, invalidate: 700 }), dump(400000, { server_fetch: 50, invalidate: 700 }));
  assert.equal(result.ok, true);
});

test('the report names the verdict and every failure', async () => {
  const { render } = await load();
  const text = render(await run(dump(100000), dump(400000, { thread_spawn: 7 })));
  assert.match(text, /IDLE BUDGET FAILED/);
  assert.match(text, /thread_spawn is over budget: 7 in 300 s/);
  const ok = render(await run(dump(100000), dump(400000)));
  assert.match(ok, /IDLE BUDGET PASSED/);
});

test('the command line exits 1 on a failure and 0 on a pass', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'idle-budget-'));
  try {
    const a = path.join(dir, 'a.json');
    const b = path.join(dir, 'b.json');
    const report = path.join(dir, 'report.txt');
    const script = path.join(__dirname, 'idle-budget.mjs');
    fs.writeFileSync(a, JSON.stringify(dump(100000)));
    fs.writeFileSync(b, JSON.stringify(dump(400000, { server_fetch: 5 })));
    const failed = spawnSync(process.execPath, [script, a, b, report], { encoding: 'utf8' });
    assert.equal(failed.status, 1);
    assert.match(failed.stdout, /server_fetch is over budget/);
    assert.match(fs.readFileSync(report, 'utf8'), /IDLE BUDGET FAILED/);
    fs.writeFileSync(b, JSON.stringify(dump(400000)));
    assert.equal(spawnSync(process.execPath, [script, a, b], { encoding: 'utf8' }).status, 0);
    assert.equal(spawnSync(process.execPath, [script], { encoding: 'utf8' }).status, 2);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('the budget file matches the ticket', async () => {
  const { loadBudget } = await load();
  const budget = loadBudget();
  assert.equal(budget.window_seconds, 300);
  for (const name of ['server_fetch', 'thread_spawn', 'invalidate', 'log_line']) assert.equal(budget.sources[name], 0, name);
});
