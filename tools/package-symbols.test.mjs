import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

test('packages the app symbols, not the bridge symbols, with their original names', () => {
  const root = mkdtempSync(join(tmpdir(), 'symbols-'));
  try {
    const input = join(root, 'bin');
    const output = join(root, 'dist');
    mkdirSync(input);
    writeFileSync(join(input, 'multiprompt.exe'), 'app exe');
    writeFileSync(join(input, 'multiprompt.pdb'), 'app symbols');
    writeFileSync(join(input, 'zigshell-bridge.pdb'), 'bridge symbols');
    const run = () => spawnSync('bash', ['tools/package-symbols.sh', input, output, 'x64'], { encoding: 'utf8' });
    assert.equal(run().status, 0);
    assert.equal(readFileSync(join(output, 'multiprompt-x64-symbols.pdb'), 'utf8'), 'app symbols');
    const archive = join(output, 'multiprompt-x64-symbols.zip');
    const extract = spawnSync('unzip', ['-p', archive, 'multiprompt.pdb'], { encoding: 'utf8' });
    assert.equal(extract.status, 0);
    assert.equal(extract.stdout, 'app symbols');
    rmSync(join(input, 'multiprompt.pdb'));
    assert.notEqual(run().status, 0);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
