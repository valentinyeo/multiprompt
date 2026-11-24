import { test } from 'node:test';
import assert from 'node:assert/strict';
import { copyFileSync, mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('.', import.meta.url));
let run;
try {
  ({ run } = await import('./mb.mjs'));
} catch (error) {
  if (error?.code !== 'ERR_MODULE_NOT_FOUND') throw error;
}

function home() {
  const dir = mkdtempSync(join(tmpdir(), 'mb-permission-'));
  for (const name of ['auto-open-request', 'auto-answered-request', 'auto-blocked']) {
    const project = join(dir, '.claude', 'projects', '-home-example-' + name);
    mkdirSync(project, { recursive: true });
    copyFileSync(join(here, 'fixtures', 'MUBO-282', name + '.jsonl'), join(project, name + '.jsonl'));
  }
  return dir;
}

test('MUBO-282 mb permission-requests lists the open request once and reads the same twice', async () => {
  const dir = home();
  try {
    const out = [];
    const env = { HOME: dir, PATH: '/usr/bin:/bin' };
    assert.equal(await run(['permission-requests'], { env, out: line => out.push(line), err: () => {} }), 0);
    assert.equal(out.length, 1, out.join('\n'));
    assert.match(out[0], /app wants to run a command\. It is waiting for your yes/);
    assert.match(out[0], /auto mode safety check/);
    const again = [];
    assert.equal(await run(['permission-requests'], { env, out: line => again.push(line), err: () => {} }), 0);
    assert.deepEqual(again, out);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('MUBO-282 mb permission-requests says so when nothing is open', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'mb-permission-empty-'));
  try {
    const out = [];
    assert.equal(await run(['permission-requests', '--dir', dir], { env: { HOME: dir, PATH: '/usr/bin:/bin' }, out: line => out.push(line), err: () => {} }), 0);
    assert.deepEqual(out, ['no open permission requests']);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
