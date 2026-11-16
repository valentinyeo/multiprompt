import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const checker = fileURLToPath(new URL('./check-timer-ratchet.mjs', import.meta.url));

function fixture(t, sources, baseline) {
  assert.ok(fs.existsSync(checker), 'The timer ratchet CLI must exist to block new wait-based quick fixes.');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'timer-ratchet-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'src'), { recursive: true });
  fs.mkdirSync(path.join(root, 'tools'));
  const write = (file, source) => {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), source);
  };
  for (const [file, source] of Object.entries(sources)) write(file, source);
  const baselinePath = path.join(root, 'tools/timer-ratchet-baseline.json');
  fs.writeFileSync(baselinePath, JSON.stringify(baseline, null, 2) + '\n');
  const readBaseline = () => JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
  const run = (...args) => spawnSync(process.execPath, [checker, ...args], { cwd: root, encoding: 'utf8' });
  return { root, write, readBaseline, run };
}

test('adding one Sleep fails and removing one passes without rewriting the baseline', t => {
  const f = fixture(t, { 'src/main.zig': 'Sleep(1);\n' }, { 'src/main.zig': 1 });
  assert.equal(f.run().status, 0);
  f.write('src/main.zig', 'Sleep(1);\nSleep(10);\n');
  const added = f.run();
  assert.equal(added.status, 1, added.stderr);
  assert.match(added.stderr, /src\/main\.zig.*2.*1/);
  assert.match(added.stderr, /root cause.*event.*message/i);
  f.write('src/main.zig', '');
  assert.equal(f.run().status, 0);
  assert.deepEqual(f.readBaseline(), { 'src/main.zig': 1 });
});

test('write only lowers limits, including deleted files, and cannot bless additions', t => {
  const f = fixture(t, { 'src/main.zig': 'Sleep(1);\n' }, { 'src/main.zig': 2, 'src/deleted.zig': 1 });
  assert.equal(f.run('--write').status, 0);
  assert.deepEqual(f.readBaseline(), { 'src/main.zig': 1 });
  assert.equal(f.run('--write').status, 0);
  assert.deepEqual(f.readBaseline(), { 'src/main.zig': 1 });
  f.write('src/main.zig', 'Sleep(1);\nSleep(2);\n');
  assert.equal(f.run('--write').status, 1);
  assert.deepEqual(f.readBaseline(), { 'src/main.zig': 1 });
});

test('new files have zero allowance and reductions elsewhere cannot offset growth', t => {
  const f = fixture(t, { 'src/nested/new.zig': 'SetTimer(hwnd, 1, 100, null);\n' }, { 'src/old.zig': 3 });
  const result = f.run('--write');
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /src\/nested\/new\.zig.*1.*0/);
  assert.deepEqual(f.readBaseline(), { 'src/old.zig': 3 });
});

test('all three patterns count, including qualified and whitespace-separated calls', t => {
  const f = fixture(t, { 'src/main.zig': 'win.Sleep (1);\nstd.Thread.sleep(10);\nwin.SetTimer\n(hwnd, 1, 20, null);\n' }, { 'src/main.zig': 3 });
  assert.equal(f.run().status, 0);
  for (const source of ['Sleep(1);', 'std.Thread.sleep(10);', 'SetTimer(hwnd, 1, 20, null);']) {
    f.write('src/main.zig', source.repeat(4));
    assert.equal(f.run().status, 1);
  }
});

test('only Zig files under src are counted', t => {
  const f = fixture(t, { 'src/ok.zig': '', 'src/ignored.txt': 'Sleep(1);', 'tools/ignored.zig': 'Sleep(1);' }, {});
  assert.equal(f.run().status, 0);
});

test('missing baseline and unknown arguments fail closed', t => {
  const f = fixture(t, { 'src/main.zig': 'Sleep(1);' }, {});
  assert.notEqual(f.run('--reset').status, 0);
  fs.unlinkSync(path.join(f.root, 'tools/timer-ratchet-baseline.json'));
  assert.notEqual(f.run('--write').status, 0);
});
