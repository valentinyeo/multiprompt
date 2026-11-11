import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const folder = path.dirname(fileURLToPath(import.meta.url));
const runner = path.join(folder, 'run.mjs');
const checkScript = path.join(folder, 'check.ps1');
const setupScript = path.join(folder, 'setup.sh');
const requiredChecks = ['install', 'start', 'chats', 'computer-view', 'sync', 'memory', 'crashes'];

const run = (...args) => spawnSync(process.execPath, [runner, ...args], { encoding: 'utf8', timeout: 120000 });

test('the runner proves its own tag, ticket, verdict and comment rules', () => {
  const result = run('--self-test');
  assert.equal(result.status, 0, 'runner self-test');
  const report = JSON.parse(result.stdout);
  assert.equal(report.selfTest, 'pass');
  assert.equal(report.cases, 12);
});

test('the runner explains its flags without touching a laptop', () => {
  const result = run('--help');
  assert.equal(result.status, 0, 'runner usage');
  for (const flag of ['--host', '--tag', '--no-post', '--state-dir', '--self-test']) assert.match(result.stdout, new RegExp(flag));
});

test('the check script publishes exactly the required checks in order', () => {
  assert.ok(fs.existsSync(checkScript), 'check.ps1 is shipped');
  const source = fs.readFileSync(checkScript, 'utf8');
  assert.deepEqual([...source.matchAll(/Add-Check '([a-z-]+)'/g)].map(match => match[1]), requiredChecks);
});

test('the check script writes one result block and fails the run when a check fails', () => {
  assert.ok(fs.existsSync(checkScript), 'check.ps1 is shipped');
  const source = fs.readFileSync(checkScript, 'utf8');
  assert.equal((source.match(/LAPTOP_CHECK_JSON_BEGIN/g) || []).length, 1);
  assert.equal((source.match(/LAPTOP_CHECK_JSON_END/g) || []).length, 1);
  assert.match(source, /-not \$_\.ok \}\)\.Count -gt 0\) \{ exit 1 \}/);
  assert.doesNotMatch(source, /Remove-Item/);
});

test('the setup script installs a ten minute timer that runs the runner and can be stopped', () => {
  assert.ok(fs.existsSync(setupScript), 'setup.sh is shipped');
  const source = fs.readFileSync(setupScript, 'utf8');
  assert.match(source, /OnUnitActiveSec=10min/);
  assert.match(source, /systemctl --user enable --now/);
  assert.match(source, /tools\/laptop-check\/run\.mjs/);
  assert.doesNotMatch(source, /push|commit/);
});
