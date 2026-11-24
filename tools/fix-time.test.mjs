import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  analyzePullRequest,
  bugFixPullRequest,
  loadFixTimings,
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

test('PR checks use the head SHA while the release uses the squash SHA', () => {
  const headSha = 'b'.repeat(40);
  const sample = analyzePullRequest({
    number: 241, createdAt: opened, mergedAt: merged,
    mergeCommit: { oid: mergeSha }, headRefOid: headSha,
  }, [
    { name: 'Tests', conclusion: 'success', head_sha: headSha, updated_at: testsDone },
    { name: 'PR verifier', conclusion: 'success', head_sha: headSha, updated_at: verifyDone },
    { name: 'Tests', conclusion: 'success', head_sha: mergeSha, updated_at: released },
  ], [{ conclusion: 'success', head_sha: mergeSha, updated_at: released }]);
  assert.equal(sample.total, 360);
  assert.deepEqual(sample.stages, { tests: 90, verifier: 30, merge_wait: 120, release: 120 });
});

test('loadFixTimings reads paginated workflow objects and declares only used GraphQL variables', () => {
  const now = Date.now();
  const at = minutes => new Date(now - minutes * 60_000).toISOString();
  const headSha = 'b'.repeat(40);
  const io = { exec(command, args) {
    assert.equal(command, 'gh');
    if (args.includes('graphql')) {
      const query = args.find(arg => arg.startsWith('query='));
      assert.doesNotMatch(query, /\$since/);
      assert.equal(args.some(arg => arg.startsWith('since=')), false);
      return { status: 0, stdout: JSON.stringify({ data: { repository: { pullRequests: { nodes: [{
        number: 241, title: 'Fix verifier', labels: { nodes: [] },
        createdAt: at(360), mergedAt: at(120), headRefOid: headSha,
        mergeCommit: { oid: mergeSha },
      }] } } } }) };
    }
    assert.ok(args.includes('--paginate'));
    assert.ok(args.includes('--slurp'));
    const route = args[1];
    const isTests = route.includes('/test.yml/');
    const isVerifier = route.includes('/pr-verifier.yml/');
    const run = { conclusion: 'success', head_sha: isTests || isVerifier ? headSha : mergeSha,
      updated_at: at(isTests ? 270 : isVerifier ? 240 : 0) };
    return { status: 0, stdout: JSON.stringify([{ workflow_runs: [] }, { workflow_runs: [run] }], null, 2) };
  } };
  const samples = loadFixTimings(io, 'owner/repo');
  assert.equal(samples.length, 1);
  assert.equal(samples[0].total, 360);
  assert.deepEqual(samples[0].stages, { tests: 90, verifier: 30, merge_wait: 120, release: 120 });
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