import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

test('stable job snapshot handles churn and incomplete enumeration', () => {
  const result = spawnSync('pwsh', ['-NoProfile', '-File', fileURLToPath(new URL('./snapshot.test.ps1', import.meta.url))], { encoding: 'utf8' });
  assert.equal(result.status, 0, `${result.error ?? ''}\n${result.stdout}\n${result.stderr}`);
});
