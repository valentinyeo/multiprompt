import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const checker = fileURLToPath(new URL('./check-file-size.mjs', import.meta.url));

function fixture(t, sources, baseline = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'file-size-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'src'));
  fs.mkdirSync(path.join(root, 'tools'));
  const write = (file, source) => {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), source);
  };
  for (const [file, source] of Object.entries(sources)) write(file, source);
  const baselinePath = path.join(root, 'tools/file-size-baseline.json');
  fs.writeFileSync(baselinePath, JSON.stringify(baseline) + '\n');
  const readBaseline = () => JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
  const run = (...args) => spawnSync(process.execPath, [checker, ...args], { cwd: root, encoding: 'utf8', timeout: 5000 });
  return { root, write, readBaseline, run };
}

test('the 6000-line cap includes blank lines and an unterminated last line', t => {
  const f = fixture(t, { 'src/new.zig': '\n'.repeat(6000) });
  assert.equal(f.run().status, 0);
  f.write('src/new.zig', '\n'.repeat(6000) + 'x');
  const result = f.run();
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /src\/new\.zig.*6001.*6000/);
  assert.match(result.stderr, /split/i);
  f.write('src/new.zig', 'x\r\n'.repeat(6000));
  assert.equal(f.run().status, 0);
});

test('each baselined file may stay the same or shrink but cannot grow', t => {
  const baseline = { 'src/large.zig': 7000, 'src/other.zig': 8000 };
  const f = fixture(t, { 'src/large.zig': 'x\n'.repeat(7000), 'src/other.zig': '' }, baseline);
  assert.equal(f.run().status, 0);
  f.write('src/large.zig', 'x\n'.repeat(6500));
  assert.equal(f.run().status, 0);
  assert.deepEqual(f.readBaseline(), baseline);
  f.write('src/large.zig', 'x\n'.repeat(7001));
  assert.equal(f.run().status, 1);
  assert.deepEqual(f.readBaseline(), baseline);
});

test('write lowers limits, removes deleted and under-cap entries, and never blesses growth', t => {
  const f = fixture(t, { 'src/large.zig': '\n'.repeat(6500), 'src/small.zig': '\n'.repeat(6000) },
    { 'src/large.zig': 7000, 'src/small.zig': 7000, 'src/deleted.zig': 7000 });
  assert.equal(f.run('--write').status, 0);
  assert.deepEqual(f.readBaseline(), { 'src/large.zig': 6500 });
  assert.equal(f.run('--write').status, 0);
  f.write('src/large.zig', '\n'.repeat(6501));
  assert.equal(f.run('--write').status, 1);
  assert.deepEqual(f.readBaseline(), { 'src/large.zig': 6500 });
  f.write('src/large.zig', '');
  f.write('src/new.zig', '\n'.repeat(6001));
  assert.equal(f.run('--write').status, 1);
  assert.deepEqual(f.readBaseline(), { 'src/large.zig': 6500 });
});

test('only Zig sources are checked, including nested sources', t => {
  const f = fixture(t, { 'src/empty.zig': '', 'src/ignored.txt': '\n'.repeat(7000), 'tools/ignored.zig': '\n'.repeat(7000) });
  assert.equal(f.run().status, 0);
  f.write('src/nested/new.zig', '\n'.repeat(6001));
  const result = f.run();
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /src\/nested\/new\.zig/);
});

test('invalid or missing baseline and unknown arguments fail closed', t => {
  for (const baseline of [null, [], { 'src/main.zig': 6000 }, { 'src/main.zig': 6001.5 }, { 'tools/other.zig': 7000 }]) {
    const f = fixture(t, {}, baseline);
    assert.equal(f.run().status, 1);
  }
  const f = fixture(t, {});
  assert.equal(f.run('--reset').status, 1);
  fs.unlinkSync(path.join(f.root, 'tools/file-size-baseline.json'));
  assert.equal(f.run().status, 1);
});
