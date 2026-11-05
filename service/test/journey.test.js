import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';

test('supplied fixture refresh tokens authenticate both devices', { timeout: 60000 }, async () => {
  const dir = await mkdtemp(join(tmpdir(), 'journey-test-'));
  const socket = createServer();
  await new Promise(resolve => socket.listen(0, '127.0.0.1', resolve));
  const port = socket.address().port;
  await new Promise(resolve => socket.close(resolve));
  const fixture = {
    account_id: 'journey@example.com',
    desktop_device_id: 'journey-device',
    android_device_id: 'journey-device-b',
    desktop_refresh_token: randomBytes(32).toString('base64url'),
    android_refresh_token: randomBytes(32).toString('base64url')
  };
  const config = join(dir, 'config.json');
  await writeFile(config, JSON.stringify(fixture));
  const child = spawn(process.execPath, [fileURLToPath(new URL('../journey/server.mjs', import.meta.url)), `--port=${port}`, '--bind=127.0.0.1', `--config=${config}`], { stdio: ['ignore', 'pipe', 'pipe'] });
  try {
    await Promise.race([
      new Promise((resolve, reject) => {
        let output = '';
        child.stdout.on('data', chunk => { output += chunk; if (output.includes('journey service ready')) resolve(); });
        child.once('exit', code => reject(new Error(`Fixture exited: ${code}`)));
      }),
      new Promise((_, reject) => setTimeout(() => reject(new Error('Fixture startup timed out')), 30000).unref())
    ]);
    for (const [token, device] of [[fixture.desktop_refresh_token, fixture.desktop_device_id], [fixture.android_refresh_token, fixture.android_device_id]]) {
      const response = await fetch(`http://127.0.0.1:${port}/oauth/token`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ grant_type: 'refresh_token', refresh_token: token }) });
      assert.equal(response.status, 200);
      const body = await response.json();
      assert.equal(body.device_id, device);
      assert.ok(body.access_token);
    }
    const oversized = await fetch(`http://127.0.0.1:${port}/oauth/token`, { method: 'POST', body: 'x'.repeat(1024 * 1024 + 1) });
    assert.equal(oversized.status, 413);
  } finally {
    if (child.exitCode === null && child.signalCode === null) { child.kill(); await once(child, 'exit'); }
    await rm(dir, { recursive: true, force: true });
  }
});
