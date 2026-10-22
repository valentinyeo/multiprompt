const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('benchmark comparison leaves revision build files intact and uses repeated relative samples', () => {
  const workflow = read('.github/workflows/chat-table-bench.yml');
  assert.doesNotMatch(workflow, /Substring\(|Copy-Item after\/build\.zig/);
  assert.match(workflow, /prepare\.js/);
  assert.match(workflow, /1\.\.7/);
  const summary = read('tools/chat-table-bench/summary.js');
  assert.doesNotMatch(summary, /<= 0\.35/);
  assert.match(summary, /1\.1/);
});

test('standalone samples amortize runner noise with longer warmup and measurement', () => {
  const main = read('tools/chat-table-bench/main.zig');
  assert.match(main, /const warmup_builds: usize = 500;/);
  assert.match(main, /const measured_builds: usize = 20_000;/);
  assert.match(main, /for \(0\.\.warmup_builds \+ measured_builds\)/);
  assert.match(main, /if \(index >= warmup_builds\) total_ticks \+= end - start;/);
  assert.match(main, /CHAT_TABLE_SAMPLE builds=\{d\}[\s\S]*\.\{ measured_builds, total_ticks, frequency \}/);
});

test('normal test graph contains a small cache test but no timing benchmark', () => {
  const render = read('src/chat_render.zig');
  assert.doesNotMatch(render, /test "IGSH-436 table build benchmark"|0\.\.2000|CHAT_TABLE_BENCH/);
  assert.match(render, /test "IGSH-436 production table layout reuses its cached build"/);
  assert.doesNotMatch(read('build.zig'), /bench-chat-tables|const table_bench/);
});

test('table changes do not add a shard-wide bridge installation dependency', () => {
  assert.doesNotMatch(read('build.zig'), /test_groups\[3\]\.dependOn\(&bridge_install\.step\)/);
});

const { summarize } = require('./summary');
const samples = (before, after) => Object.fromEntries([['before', before], ['after', after]].map(([name, ticks]) => [name, ticks.map((value, index) => ({ sample: index + 1, builds: 20000, ticks: value, frequency: 1000000 }))]));

test('regression guard accepts faster paired samples on slow shared runners', () => {
  assert.equal(summarize(samples(Array(7).fill(10000000), Array(7).fill(7000000))).ratio, 0.7);
});

test('regression guard accepts equal paired samples', () => {
  assert.equal(summarize(samples(Array(7).fill(100), Array(7).fill(100))).ratio, 1);
});

test('regression guard accepts slightly slower paired samples within noise', () => {
  assert.equal(summarize(samples(Array(7).fill(100), Array(7).fill(105))).ratio, 1.05);
  assert.ok(Math.abs(summarize(samples(Array(7).fill(100), Array(7).fill(110))).ratio - 1.1) <= Number.EPSILON);
});

test('regression guard rejects clearly slower median or inconsistent paired samples', () => {
  assert.throws(() => summarize(samples(Array(7).fill(100), Array(7).fill(120))), /median regression/);
  assert.throws(() => summarize(samples(Array(7).fill(100), [100, 100, 100, 100, 100, 120, 120])), /six of seven/);
  assert.doesNotThrow(() => summarize(samples(Array(7).fill(100), [100, 100, 100, 100, 100, 100, 120])));
});

test('regression guard rejects malformed samples', () => {
  assert.throws(() => summarize(samples(Array(7).fill(100), Array(6).fill(60))), /sample count/);
  const invalid = samples(Array(7).fill(100), Array(7).fill(60));
  invalid.after[0].sample = 2;
  assert.throws(() => summarize(invalid), /sequence/);
  invalid.after[0].sample = 1;
  invalid.after[0].builds = 2000;
  assert.throws(() => summarize(invalid), /build count/);
  invalid.after[0].builds = 20000;
  invalid.after[0].ticks = NaN;
  assert.throws(() => summarize(invalid), /ticks/);
});

test('standalone preparation preserves future render declarations and revision build definitions', () => {
  const os = require('node:os');
  const { prepare } = require('./prepare');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'table-bench-controls-'));
  try {
    fs.mkdirSync(path.join(dir, 'src'));
    const source = 'fn chatTableLayout() void {}\ntest "future test" {}\nconst future = 42;\n';
    fs.writeFileSync(path.join(dir, 'src/chat_render.zig'), source);
    fs.writeFileSync(path.join(dir, 'build.zig'), 'future revision build graph');
    prepare(dir);
    assert.equal(fs.readFileSync(path.join(dir, 'src/chat_render.zig'), 'utf8'), `${source}\npub const benchTableLayout = chatTableLayout;\n`);
    assert.equal(fs.readFileSync(path.join(dir, 'build.zig'), 'utf8'), 'future revision build graph');
    assert.equal(fs.readFileSync(path.join(dir, 'src/chat_table_bench.zig'), 'utf8'), read('tools/chat-table-bench/main.zig'));
    assert.throws(() => prepare(dir), /already prepared/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
