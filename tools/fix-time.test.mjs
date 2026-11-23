import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  analyzePullRequest,
  bugFixPullRequest,
  minutesBetween,
  percentile,
  summarizeSamples,
} from './fix-time.mjs';

const opened = '2026-11-22T10:00:00Z';
const testsDone = '2026-11-22T11:30:00Z';
const verifyDone = '2026-11-22T12:00:00Z';
const merged = '2026-11-22T14:00:00Z';
const released = '2026-11-22T16:00:00Z';
const mergeSha = 'a'.repeat(40);

test('bugFixPullRequest matches repair titles and bug labels', () => {
  assert.equal(bugFixPullRequest({ title: 'MUBO-241: Fix verifier paperwork', labels: [] }), true);
  assert.equal(bugFixPullRequest({ title: 'Docs', labels: [{ name: 'bug' }] }), true);
  assert.equal(bugFixPullRequest({ title: 'Docs', labels: [] }), false);
});

test('minutesBetween returns fractional minutes', () => {
  assert.equal(minutesBetween(opened, testsDone), 90);
  assert.equal(minutesBetween(testsDone, verifyDone), 30);
  assert.equal(minutesBetween(opened, opened), 0);
  assert.equal(minutesBetween(verifyDone, opened), null);
});

test('analyzePullRequest splits open-to-release stages', () => {
  const runs = [
    { name: 'Tests', conclusion: 'success', head_sha: mergeSha, created_at: opened, updated_at: testsDone },
    { name: 'PR verifier', conclusion: 'success', head_sha: mergeSha, created_at: testsDone, updated_at: verifyDone },
  ];
  const releaseRuns = [{ conclusion: 'success', head_sha: mergeSha, created_at: merged, updated_at: released }];
  const sample = analyzePullRequest({
    number: 241,
    createdAt: opened,
    mergedAt: merged,
    mergeCommit: { oid: mergeSha },
    headRefOid: mergeSha,
  }, runs, releaseRuns);
  assert.equal(sample.total, 360);
  assert.deepEqual(sample.stages, { tests: 90, verifier: 30, merge_wait: 120, release: 120 });
});

test('weekly verification maintenance reports median and p90', () => {
  const workflow = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), '../.github/workflows/maintain-verification.yml'), 'utf8');
  assert.match(workflow, /node tools\/fix-time\.mjs --summary >> "\$GITHUB_STEP_SUMMARY"/);
});

test('summarizeSamples reports median and p90', () => {
  const summary = summarizeSamples([
    { total: 100 },
    { total: 200 },
    { total: 300 },
    { total: 400 },
  ]);
  assert.equal(summary.count, 4);
  assert.equal(summary.median_open_to_release_min, 200);
  assert.equal(summary.p90_open_to_release_min, 400);
  assert.equal(percentile([], 0.5), null);
});