import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const checker = path.resolve('tools/check-zig-syntax.mjs');
const fixtures = path.resolve('tools/fixtures/HYCI-150');

test('compiler preflight rejects the historical regression and checks generated sources', () => {
  assert.ok(fs.existsSync(checker), 'production Zig syntax preflight must exist');
  const run = (cwd, ...files) => spawnSync(process.execPath, [checker, ...files], { cwd, encoding: 'utf8' });
  const check = (result, status, label) => {
    const output = (result.stdout || '') + (result.stderr || '');
    console.log(`${label}: ${output.trim()}`);
    assert.equal(result.status, status, `${label}: ${output}`);
    assert.match(output, /Zig syntax (passed|failed): \d+ files in \d+ ms/);
    return output;
  };
  for (let i = 0; i < 5; i++) {
    const bad = check(run(process.cwd(), path.join(fixtures, 'bad.zig')), 1, `bad ${i + 1}`);
    assert.match(bad, /bad\.zig:\d+:\d+: error:/);
    check(run(process.cwd(), path.join(fixtures, 'fixed.zig')), 0, `fixed ${i + 1}`);
  }
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'zig-syntax-'));
  try {
    fs.mkdirSync(path.join(temp, 'src', 'nested'), { recursive: true });
    fs.writeFileSync(path.join(temp, 'build.zig'), 'pub fn main( ) void { }\n');
    fs.writeFileSync(path.join(temp, 'src', 'nested', 'valid.zig'), 'pub fn main( ) void { }\n');
    fs.copyFileSync(path.join(fixtures, 'bad.zig'), path.join(temp, 'src', 'changelog.zig'));
    assert.match(check(run(temp), 1, 'generated invalid changelog'), /changelog\.zig:\d+:\d+: error:/);
    fs.copyFileSync(path.join(fixtures, 'fixed.zig'), path.join(temp, 'src', 'changelog.zig'));
    check(run(temp), 0, 'generated fixed changelog and unformatted source');
    fs.copyFileSync(path.join(fixtures, 'bad.zig'), path.join(temp, 'src', 'nested', 'valid.zig'));
    assert.match(check(run(temp), 1, 'nested invalid source'), /valid\.zig:\d+:\d+: error:/);
    check(run(process.cwd(), 'src/changelog.zig'), 0, 'current changelog');
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
});
