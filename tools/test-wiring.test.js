const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const os = require('node:os');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const localOnly = new Set(['tools/chat-working-bar.test.mjs', 'tools/chat-permission-buttons.test.mjs']);
const testFile = /(\.test\.[a-z]+|-test\.py)$/;

function testFiles(dirs) {
  return dirs.flatMap((dir) => fs.readdirSync(path.join(root, dir)).filter((f) => testFile.test(f)).map((f) => `${dir}/${f}`));
}

function runners() {
  const workflows = path.join(root, '.github/workflows');
  const files = ['build.zig', ...fs.readdirSync(workflows).map((f) => `.github/workflows/${f}`)];
  return files.map((f) => fs.readFileSync(path.join(root, f), 'utf8')).join('\n');
}

function unwired(files, text) {
  return files.filter((f) => !new RegExp(`["\\s]${f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?=["\\s])`).test(text));
}

test('every tools/, extension/ and service/test/ test file runs in build.zig or a workflow', () => {
  const missing = unwired(testFiles(['tools', 'extension', 'service/test']).filter(file => !localOnly.has(file)), runners());
  assert.deepEqual(missing, [], `add these to a node --test step in build.zig (test-vps runs on every PR): ${missing.join(', ')}`);
});

test('the local Wine chat gates exist and are not wired into CI', () => {
  for (const file of localOnly) assert.ok(fs.existsSync(path.join(root, file)));
  assert.deepEqual(unwired([...localOnly], runners()), [...localOnly]);
});

test('the check catches a test file named nowhere', () => {
  const text = 'b.addSystemCommand(&.{ "node", "--test", "tools/a.test.json" });\n      - run: node --test tools/b.test.js\n';
  assert.deepEqual(unwired(['tools/a.test.js', 'tools/b.test.js', 'tools/c.test.js', 'tools/a.test.json'], text), ['tools/a.test.js', 'tools/c.test.js']);
});

test('the capped Wine runner runs desktop tests then test-vps without forwarding desktop arguments', () => {
  const script = fs.readFileSync(path.join(root, 'tools/test-windows-wine.sh'), 'utf8');
  assert.match(script, /^set -euo pipefail$/m);
  const builds = script.split('\n').filter(line => line.includes('"$zig" build'));
  assert.deepEqual(builds, [
    '"${runner[@]}" nice -n 15 "$zig" build test-desktop -Dtarget=x86_64-windows-gnu -fwine -j4 --summary all "$@"',
    '"${runner[@]}" nice -n 15 "$zig" build test-vps --summary all',
  ]);
  const docs = ['openwiki/operations/build-and-install.md'];
  if (fs.existsSync(path.join(root, 'tools/public-export'))) docs.push('CLAUDE.md', 'AGENTS.md', 'tools/public-export/overlay/openwiki/operations/build-and-install.md');
  for (const file of docs) {
    const text = fs.readFileSync(path.join(root, file), 'utf8');
    assert.match(text, /tools\/test-windows-wine\.sh[^\n]*(?:\n[^\n]*)?test-vps/, file);
  }
});

test('the Wine runner propagates the selected compiler to native child tests', { skip: process.platform === 'win32' }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wine-toolchain-'));
  try {
    const selected = path.join(dir, 'selected');
    const older = path.join(dir, 'older');
    fs.mkdirSync(selected);
    fs.mkdirSync(older);
    const zig = path.join(selected, 'zig');
    fs.writeFileSync(zig, '#!/bin/sh\nprintf \'{"selected":"%s","resolved":"%s","exe":"%s","step":"%s"}\\n\' "$ZIG" "$(command -v zig)" "${ZIG_EXE:-}" "$2"\n', { mode: 0o755 });
    fs.writeFileSync(path.join(older, 'zig'), '#!/bin/sh\nexit 99\n', { mode: 0o755 });
    const result = spawnSync('bash', ['tools/test-windows-wine.sh'], {
      cwd: root, encoding: 'utf8', timeout: 120000,
      env: { ...process.env, ZIG: zig, ZIG_EXE: '', PATH: older + path.delimiter + process.env.PATH, MP_WINE_LOCK: path.join(dir, 'lock') },
    });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const calls = result.stdout.trim().split('\n').map(line => JSON.parse(line));
    assert.deepEqual(calls.map(call => call.step), ['test-desktop', 'test-vps']);
    for (const call of calls) assert.deepEqual([call.selected, call.resolved, call.exe], [zig, zig, zig]);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
