const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('a locked old backup does not stop the install prune', t => {
  if (process.platform !== 'win32') {
    t.skip('requires Windows file locking and powershell.exe');
    return;
  }

  const installer = fs.readFileSync(path.join(__dirname, 'install-laptop1.sh'), 'utf8');
  const lines = installer.split(/\r?\n/).filter(line => line.includes('multiprompt-stable-v*.exe'));
  assert.equal(lines.length, 1);
  const prune = lines[0].trim().replace(/\\([$"\\])/g, '$1');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'install-prune-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const names = Array.from({ length: 8 }, (_, i) => `multiprompt-stable-v0.28.80${i}-000000.exe`);
  for (const [i, name] of names.entries()) {
    const file = path.join(dir, name);
    fs.writeFileSync(file, 'backup');
    const time = new Date(Date.UTC(2024, 0, 1, 0, i));
    fs.utimesSync(file, time, time);
  }

  const locked = names[1];
  const script = path.join(dir, 'prune.ps1');
  fs.writeFileSync(script, `param([string]$b)
$ErrorActionPreference='Stop'
$handle = [System.IO.File]::Open((Join-Path $b '${locked}'), 'Open', 'Read', 'None')
try {
  ${prune}
  Write-Output 'PRUNE_FINISHED'
} finally {
  $handle.Dispose()
}
`);
  const result = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-File', script, dir], {
    encoding: 'utf8', timeout: 30000,
  });
  assert.ifError(result.error);
  const output = `${result.stdout}${result.stderr}`;
  assert.equal(result.status, 0, output);
  const outputLines = output.split(/\r?\n/);
  assert.ok(outputLines.includes('PRUNE_FINISHED'), output);
  assert.ok(fs.existsSync(path.join(dir, locked)), 'locked backup remains');
  for (const i of [0, 2]) {
    assert.equal(fs.existsSync(path.join(dir, names[i])), false, `${names[i]} was pruned`);
  }
  for (const name of names.slice(3)) {
    assert.ok(fs.existsSync(path.join(dir, name)), `${name} was kept`);
  }
  assert.deepEqual(outputLines.filter(line => line.startsWith('skipped locked backup ')), [
    `skipped locked backup ${locked}`,
  ], output);
});
