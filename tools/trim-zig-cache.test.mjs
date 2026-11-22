import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const tool = process.env.TRIM_ZIG_CACHE_SCRIPT || fileURLToPath(new URL('./trim-zig-cache.py', import.meta.url));

function snapshot(dir) {
  return fs.readdirSync(dir, { recursive: true }).sort().map(name => {
    const file = path.join(dir, name);
    const stat = fs.statSync(file);
    return [name, stat.mode, stat.mtimeMs, stat.isFile() ? fs.readFileSync(file) : null];
  });
}

for (const [name, cap, globalKiB, dropped, warning] of [
  ['under cap', 3, 128, false, false],
  ['exactly at cap', 2, 128, false, false],
  ['over cap', 1, 128, true, false],
  ['global alone exceeds cap', 1, 2048, true, true],
]) {
  test(`cache stays consistent ${name}`, t => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'trim-zig-cache-test-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const local = path.join(dir, '.zig-cache');
    const globalCache = path.join(dir, 'global-cache');
    const files = {
      '.zig-cache/h/manifest': Buffer.alloc(384 * 1024, 'h'),
      '.zig-cache/o/11111111111111111111111111111111/build': Buffer.alloc(512 * 1024, 'a'),
      '.zig-cache/o/22222222222222222222222222222222/test': Buffer.alloc(512 * 1024, 'b'),
      '.zig-cache/o/33333333333333333333333333333333/test': Buffer.alloc(512 * 1024, 'c'),
      'global-cache/o/shared': Buffer.alloc(globalKiB * 1024, 'g'),
    };
    for (const [name, content] of Object.entries(files)) {
      const file = path.join(dir, name);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, content);
    }
    const localBefore = snapshot(local);
    const globalBefore = snapshot(globalCache);
    const result = spawnSync('python3', ['-I', tool, '--cap-mib', String(cap)], {
      cwd: dir, encoding: 'utf8', timeout: 10000, env: { ...process.env, ZIG_GLOBAL_CACHE_DIR: globalCache },
    });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(snapshot(globalCache), globalBefore, 'global cache must remain untouched');
    if (dropped) assert.equal(fs.existsSync(local), false, 'local cache must be fully gone above cap');
    else assert.deepEqual(snapshot(local), localBefore, 'local cache must remain fully intact at or below cap');
    const beforeMiB = (1920 + globalKiB) / 1024;
    const afterMiB = dropped ? globalKiB / 1024 : beforeMiB;
    const lines = result.stdout.split('\n');
    assert.ok(lines.includes(`Zig caches before: ${beforeMiB.toFixed(1)} MiB; cap: ${cap} MiB`));
    assert.ok(lines.includes(`Local Zig cache dropped: ${dropped ? 'yes' : 'no'}`));
    assert.ok(lines.includes(`Zig caches after: ${afterMiB.toFixed(1)} MiB`));
    assert.equal(result.stdout.includes('::warning::'), warning);
    if (warning) assert.ok(result.stdout.includes(`::warning::Zig caches still ${afterMiB.toFixed(1)} MiB after trimming, above the ${cap} MiB cap`));
  });
}
