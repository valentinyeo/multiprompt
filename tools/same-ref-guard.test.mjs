import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { assertSamples, blockedRun, repeatPlan, windowMs, windowsHeld } from './same-ref-guard.mjs';

const now = Date.parse('2026-10-27T16:00:00Z');
const run = (id, minutes, ref = 'topic', extra = {}) => ({ id, head_branch: ref, created_at: new Date(now - minutes * 60 * 1000).toISOString(), ...extra });

test('the same-ref window is 60 minutes and only a real Windows bench or repeat holds it', () => {
  assert.equal(windowMs, 60 * 60 * 1000);
  assert.equal(windowsHeld([{ name: 'bench', conclusion: 'success' }]), true);
  assert.equal(windowsHeld([{ name: 'bench', conclusion: null }]), true);
  assert.equal(windowsHeld([{ name: 'bench', conclusion: 'skipped' }]), false);
  assert.equal(windowsHeld([{ name: 'repeat 3', conclusion: 'failure' }]), true);
  assert.equal(windowsHeld([{ name: 'repeat 3', conclusion: 'skipped' }]), false);
  assert.equal(windowsHeld([{ name: 'guard', conclusion: 'success' }, { name: 'plan', conclusion: null }]), false);
});

test('a skipped Windows job does not keep the next run off the runner', () => {
  const jobs = new Map([
    [1, [{ name: 'bench', conclusion: 'skipped' }]],
    [2, [{ name: 'bench', conclusion: 'success' }]],
  ]);
  const jobsFor = candidate => {
    assert.notEqual(candidate.id, 9);
    return jobs.get(candidate.id);
  };
  assert.equal(blockedRun({ runs: [run(9, 1), run(1, 5)], jobsFor, ref: 'topic', now, currentId: 9 }), false);
  assert.equal(blockedRun({ runs: [run(2, 59)], jobsFor, ref: 'topic', now, currentId: 3 }), true);
  assert.equal(blockedRun({ runs: [run(2, 60)], jobsFor, ref: 'topic', now, currentId: 3 }), false);
  assert.equal(blockedRun({ runs: [run(2, 5, 'other')], jobsFor, ref: 'topic', now, currentId: 3 }), false);
});

test('repeat input stays inside 1 to 3 and a blocked plan emits one unrun row', () => {
  assert.deepEqual(repeatPlan('1', 3, false), { run: 'true', runs: [1] });
  assert.deepEqual(repeatPlan('3', 3, false), { run: 'true', runs: [1, 2, 3] });
  assert.deepEqual(repeatPlan('3', 3, true), { run: 'false', runs: [1] });
  assert.throws(() => repeatPlan('4', 3, false), /1 to 3/);
  assert.throws(() => repeatPlan('10', 3, false), /1 to 3/);
  assert.doesNotThrow(() => assertSamples('7'));
  assert.throws(() => assertSamples('8'), /samples must be 7/);
});

test('the guard fails closed when the run lookup fails', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'same-ref-guard-'));
  try {
    fs.writeFileSync(path.join(dir, 'gh'), '#!/bin/sh\nexit 1\n', { mode: 0o755 });
    const result = spawnSync(process.execPath, [path.join(path.dirname(new URL(import.meta.url).pathname), 'same-ref-guard.mjs')], {
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: `${dir}${path.delimiter}${process.env.PATH}`,
        GUARD_WORKFLOW: 'chat-table-bench.yml',
        GUARD_REF: 'master',
        GUARD_SAMPLES: '7',
        GITHUB_REPOSITORY: 'owner/repo',
        GITHUB_RUN_ID: '1',
      },
    });
    assert.notEqual(result.status, 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
