const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const tableModule = import('./chat-perf-table.mjs');

const line = (parse, delta, reconcile) => `ok\nCPU707 benchmark bytes=52428800 messages=25000 parse_ms=${parse} delta_ms=${delta} reconcile_ms=${reconcile}\n`;

function evidence(dir, runs, identity = ['a'.repeat(40), 'IGSH-1: change']) {
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'identity.txt'), identity.join('\n') + '\n');
  runs.forEach((run, index) => {
    fs.writeFileSync(path.join(dir, `run-${index + 1}.log`), run.log);
    fs.writeFileSync(path.join(dir, `run-${index + 1}.exit`), `${run.exit}\n`);
  });
}

test('parseRun reads the benchmark line and flags a run without one', async () => {
  const { parseRun } = await tableModule;
  assert.deepEqual(parseRun(line(10, 2, 30), 0), { exit: 0, ok: true, bytes: 52428800, messages: 25000, parse: 10, delta: 2, reconcile: 30 });
  assert.deepEqual(parseRun('error: build failed', 1), { exit: 1, ok: false });
});

test('a row keeps every run and the summary reports median, min and max of the measured ones', async () => {
  const { buildRow, summarizeRow } = await tableModule;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'perf-row-'));
  evidence(dir, [{ log: line(100, 5, 40), exit: 0 }, { log: line(300, 7, 60), exit: 0 }, { log: line(200, 6, 50), exit: 0 }, { log: 'no line', exit: 1 }]);
  const summary = summarizeRow(buildRow(dir, 'v0.28.900'));
  assert.equal(summary.measured, 3);
  assert.equal(summary.total, 4);
  assert.deepEqual(summary.cells.parse, { median: 200, min: 100, max: 300 });
  assert.deepEqual(summary.cells.reconcile, { median: 50, min: 40, max: 60 });
});

test('markdown orders release tags by number and marks refs without a benchmark', async () => {
  const { buildRow, markdown } = await tableModule;
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'perf-table-'));
  const rows = [];
  for (const [ref, parse] of [['v0.28.917', 900], ['v0.28.900', 300]]) {
    const dir = path.join(root, ref);
    evidence(dir, [{ log: line(parse, 1, 2), exit: 0 }]);
    rows.push(buildRow(dir, ref));
  }
  const missing = path.join(root, 'abc1234');
  evidence(missing, [{ log: 'zig: no such step', exit: 1 }]);
  fs.writeFileSync(path.join(missing, 'unsupported.txt'), 'no test-chat-perf step\n');
  rows.push(buildRow(missing, 'abc1234'));
  const text = markdown(rows);
  assert.ok(text.indexOf('| v0.28.900 |') < text.indexOf('| v0.28.917 |'));
  assert.match(text, /\| abc1234 \| aaaaaaaa \| 0\/1 \(no benchmark step\) \| n\/a \| n\/a \| n\/a \|/);
  assert.match(text, /\| v0\.28\.917 \| aaaaaaaa \| 1\/1 \| 900 \[900, 900\] \| 1 \[1, 1\] \| 2 \[2, 2\] \|/);
});
