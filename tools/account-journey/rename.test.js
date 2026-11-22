const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '../..');

test('rename waits for fresh palette readiness and selection', () => {
  const result = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-File', 'tools/fixtures/HYCI-137/rename.ps1'], {
    cwd: root, encoding: 'utf8', timeout: 30000,
  });
  assert.equal(result.status, 0, `pwsh failed: ${result.error || ''}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`);
});
