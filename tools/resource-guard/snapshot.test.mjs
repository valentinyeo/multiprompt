import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

test('stable job snapshot handles churn and incomplete enumeration', () => {
  assert.ok(fs.existsSync(new URL('./snapshot.ps1', import.meta.url)), 'Stable job snapshot must ship');
  assert.ok(fs.existsSync(new URL('./snapshot.test.ps1', import.meta.url)), 'Stable job snapshot test must ship');
  const result = spawnSync('pwsh', ['-NoProfile', '-File', fileURLToPath(new URL('./snapshot.test.ps1', import.meta.url))], { encoding: 'utf8' });
  assert.equal(result.status, 0, `${result.error ?? ''}\n${result.stdout}\n${result.stderr}`);
});

test('resource staging preserves payloads and telemetry layout', () => {
  const result = spawnSync('pwsh', ['-NoProfile', '-File', fileURLToPath(new URL('./stage.test.ps1', import.meta.url))], { encoding: 'utf8' });
  assert.equal(result.status, 0, `${result.error ?? ''}\n${result.stdout}\n${result.stderr}`);
});

test('session schema and switched chat readiness', () => {
  const result = spawnSync('pwsh', ['-NoProfile', '-File', fileURLToPath(new URL('./session.test.ps1', import.meta.url))], { encoding: 'utf8' });
  assert.equal(result.status, 0, `${result.error ?? ''}\n${result.stdout}\n${result.stderr}`);
});
