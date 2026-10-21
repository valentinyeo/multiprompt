const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const summaryModule = import('./chat-bench/ab-summary.mjs');

function runs(a = [30, 10, 20], b = [70, 50, 60], failedA = [3, 1, 2], failedB = [0, 0, 0]) {
  return a.flatMap((paint, index) => [
    { label: 'A', tag: 'v0.28.783', result: { status: 'FAIL', metrics: { switchPaintP95Ms: paint }, failures: Array(failedA[index]).fill('check') } },
    { label: 'B', tag: 'v0.28.786', result: { status: 'PASS', metrics: { switchPaintP95Ms: b[index] }, failures: Array(failedB[index]).fill('check') } },
  ]);
}

test('odd medians, extrema, failed checks and signed differences use real result fields', async () => {
  const { summarize, markdown } = await summaryModule;
  const summary = summarize(runs());
  assert.deepEqual(summary.groups[0].switchPaintP95Ms, { median: 20, min: 10, max: 30, spread: 20 });
  assert.deepEqual(summary.groups[1].switchPaintP95Ms, { median: 60, min: 50, max: 70, spread: 20 });
  assert.deepEqual(summary.groups[0].failedChecks, { median: 2, min: 1, max: 3, spread: 2 });
  assert.deepEqual(summary.groups[1].failedChecks, { median: 0, min: 0, max: 0, spread: 0 });
  assert.deepEqual(summary.difference.switchPaintP95Ms, { medianBMinusA: 40, withinTagSpread: 20, exceedsWithinTagSpread: true });
  assert.deepEqual(summary.difference.failedChecks, { medianBMinusA: -2, withinTagSpread: 2, exceedsWithinTagSpread: false });
  const text = markdown(summary);
  assert.match(text, /v0\.28\.783 \| 3 \| 20 \[10, 30\] \| 2 \[1, 3\]/);
  assert.match(text, /switchPaintP95Ms \| 40 \| 20 \| yes/);
  assert.match(text, /failedChecks \| -2 \| 2 \| no/);
  assert.match(text, /Linux\/Wine on a GitHub-hosted Ubuntu 24\.04 runner; not native Windows acceptance/);
});

test('runner tooling and production reader require LF checkout on every OS', t => {
  const files = ['tools/chat-bench/run.mjs', 'tools/chat-bench/lib.mjs', 'tools/chat-bench/reader-service.py', 'tools/chat-bench/browser-fixture.c', 'tools/chat-bench/ssh-fixture.c', 'tools/chat-bench/config.json', 'src/chat_history_reader.py'];
  const cwd = path.join(__dirname, '..');
  const result = spawnSync('git', ['check-attr', 'text', 'eol', '--', ...files], { cwd, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-bench-checkout-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const checkout = spawnSync('git', ['-c', 'core.autocrlf=true', 'checkout-index', `--prefix=${dir}/`, '--', ...files], { cwd, encoding: 'utf8' });
  assert.equal(checkout.status, 0, checkout.stderr);
  for (const file of files) {
    assert.ok(result.stdout.includes(`${file}: text: set\n`), file);
    assert.ok(result.stdout.includes(`${file}: eol: lf\n`), file);
    const bytes = fs.readFileSync(path.join(dir, file));
    assert.equal(bytes.includes(13), false, file);
    assert.deepEqual(bytes, fs.readFileSync(path.join(cwd, file)), file);
  }
});

test('even and single-run medians, equal tags and zero spread are valid', async () => {
  const { summarize } = await summaryModule;
  const even = summarize(runs([10, 20], [12, 14], [0, 0], [0, 0]));
  assert.equal(even.groups[0].switchPaintP95Ms.median, 15);
  assert.equal(even.groups[1].switchPaintP95Ms.median, 13);
  assert.equal(even.difference.switchPaintP95Ms.exceedsWithinTagSpread, false);
  const single = runs([0], [1], [0], [0]);
  single[1].tag = single[0].tag;
  const result = summarize(single);
  assert.deepEqual(result.groups[0].switchPaintP95Ms, { median: 0, min: 0, max: 0, spread: 0 });
  assert.equal(result.difference.switchPaintP95Ms.exceedsWithinTagSpread, true);
  assert.equal(result.difference.failedChecks.exceedsWithinTagSpread, false);
});

test('negative gaps use magnitude and must exceed the larger within-tag spread', async () => {
  const { summarize } = await summaryModule;
  const summary = summarize(runs([90, 100, 110], [10, 20, 50]));
  assert.deepEqual(summary.difference.switchPaintP95Ms, { medianBMinusA: -80, withinTagSpread: 40, exceedsWithinTagSpread: true });
});

test('missing, invalid, infrastructure and unbalanced results fail closed', async () => {
  const { summarize } = await summaryModule;
  assert.throws(() => summarize([]), /No benchmark/);
  for (const mutate of [
    rows => rows.splice(1, 1),
    rows => { rows[0].label = 'C'; },
    rows => { rows[0].tag = 'v0.0.1'; },
    rows => { rows[0].tag = 'not-a-tag'; },
    rows => { delete rows[0].result; },
    rows => { rows[0].result.status = 'INFRA'; },
    rows => { delete rows[0].result.metrics.switchPaintP95Ms; },
    rows => { rows[0].result.metrics.switchPaintP95Ms = null; },
    rows => { rows[0].result.metrics.switchPaintP95Ms = NaN; },
    rows => { rows[0].result.metrics.switchPaintP95Ms = Infinity; },
    rows => { rows[0].result.metrics.switchPaintP95Ms = -1; },
    rows => { rows[0].result.metrics.switchPaintP95Ms = '10'; },
    rows => { delete rows[0].result.failures; },
    rows => { rows[0].result.failures = [null]; },
    rows => { rows[0].result.status = 'PASS'; },
  ]) {
    const rows = runs();
    mutate(rows);
    assert.throws(() => summarize(rows));
  }
  assert.throws(() => summarize(runs().filter(row => row.label === 'A')), /Missing B/);
});

test('CLI reads per-run results relative to manifest and writes JSON, markdown and job summary', async t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-bench-ab-test-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const manifest = runs().map((row, index) => {
    const folder = `${row.label}-${row.tag}-${Math.floor(index / 2) + 1}`;
    fs.mkdirSync(path.join(dir, folder));
    fs.writeFileSync(path.join(dir, folder, 'results.json'), JSON.stringify(row.result));
    return { label: row.label, tag: row.tag, index: Math.floor(index / 2) + 1, path: `${folder}/results.json` };
  });
  const manifestFile = path.join(dir, 'manifest.json');
  fs.writeFileSync(manifestFile, JSON.stringify(manifest));
  const output = path.join(dir, 'summary');
  const jobSummary = path.join(dir, 'job.md');
  const result = spawnSync(process.execPath, [path.join(__dirname, 'chat-bench/ab-summary.mjs'), manifestFile, output], {
    cwd: os.tmpdir(), env: { ...process.env, GITHUB_STEP_SUMMARY: jobSummary }, encoding: 'utf8', timeout: 5000,
  });
  assert.equal(result.status, 0, result.stderr);
  const summary = JSON.parse(fs.readFileSync(path.join(output, 'summary.json'), 'utf8'));
  const { summarize, markdown } = await summaryModule;
  assert.deepEqual(summary, { ...summarize(runs()), runs: manifest });
  assert.equal(fs.readFileSync(jobSummary, 'utf8'), markdown(summary));
  assert.equal(fs.readFileSync(path.join(output, 'summary.md'), 'utf8'), markdown(summary));
  fs.unlinkSync(path.join(dir, manifest[0].path));
  const missing = spawnSync(process.execPath, [path.join(__dirname, 'chat-bench/ab-summary.mjs'), manifestFile, output], { encoding: 'utf8', timeout: 5000 });
  assert.notEqual(missing.status, 0);
});
