import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

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

test('measured release timeouts keep publication under one hour before the updater poll', () => {
  const prepare = 5;
  const build = timeoutMinutes(jobs.build);
  const launch = timeoutMinutes(jobs.launch);
  const releaseJob = timeoutMinutes(jobs.release);
  const worst = prepare + build + launch + releaseJob;
  const updaterPollMinutes = 5;
  assert.ok(buildInstall.includes('every five minutes'));
  assert.equal(jobs['resource-observation'], undefined, 'the release path never waits on resource observation');
  assert.ok(worst + updaterPollMinutes < 60, `release worst-case minutes ${worst} plus updater poll must stay under 60`);
});
