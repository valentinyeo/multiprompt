import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { emergencyMergeFromPulls } from './emergency-merge-head.mjs';

const release = fs.readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8');
const buildInstall = fs.readFileSync(new URL('../openwiki/operations/build-and-install.md', import.meta.url), 'utf8');

function timeoutMinutes(jobBlock) {
  const match = jobBlock.match(/timeout-minutes: (\d+)/);
  return match ? Number(match[1]) : 0;
}

const jobs = Object.fromEntries([...release.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));

test('a master push still publishes through auto-release', () => {
  const auto = fs.readFileSync(new URL('../.github/workflows/auto-release.yml', import.meta.url), 'utf8');
  assert.match(auto, /push:\n    branches: \[master\]/);
  assert.match(auto, /uses: \.\/\.github\/workflows\/release\.yml/);
});

test('measured release timeouts keep emergency publication under one hour before the updater poll', () => {
  const prepare = 5;
  const build = timeoutMinutes(jobs.build);
  const launch = timeoutMinutes(jobs.launch);
  const releaseJob = timeoutMinutes(jobs.release);
  const resource = timeoutMinutes(jobs['resource-observation']);
  const normalWorst = prepare + build + Math.max(launch, resource) + releaseJob;
  const emergencyWorst = prepare + build + launch + releaseJob;
  const updaterPollMinutes = 5;
  assert.ok(buildInstall.includes('every five minutes'));
  assert.ok(normalWorst > emergencyWorst);
  assert.ok(emergencyWorst + updaterPollMinutes < 60, `emergency worst-case minutes ${emergencyWorst} plus updater poll must stay under 60`);
  assert.match(jobs['resource-observation'], /if: needs\.prepare\.outputs\.emergency != 'true'/);
  assert.match(jobs.release, /needs\.resource-observation\.result == 'skipped'/);
});

test('emergency merge detection follows the merged pull request labels', () => {
  assert.equal(emergencyMergeFromPulls([{ labels: [{ name: 'docs' }] }]), false);
  assert.equal(emergencyMergeFromPulls([{ labels: [{ name: 'emergency' }] }]), true);
});