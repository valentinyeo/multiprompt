import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const workflow = fs.readFileSync(new URL('../.github/workflows/test.yml', import.meta.url), 'utf8');
const names = ['test', 'test-update-source', 'test-windows-update', 'test-vps', 'test-worker', 'build-windows'];

function verifyRouting(text) {
  const jobs = Object.fromEntries([...text.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  assert.equal(jobs.changes, undefined);
  assert.doesNotMatch(text, /needs\.changes|needs:.*\bchanges\b/);
  for (const name of names) {
    const job = jobs[name];
    assert.ok(job, name);
    assert.doesNotMatch(job, /^    if:/m);
    if (name === 'test-windows-update') assert.match(job, /^    needs: \[build-windows\]$/m);
    else assert.doesNotMatch(job, /^    needs:/m);
    const steps = job.split(/(?=^      - )/m).filter(step => step.startsWith('      - '));
    const checkout = steps.findIndex(step => step.includes('uses: actions/checkout@'));
    assert.ok(checkout >= 0, name);
    assert.match(steps[checkout], /fetch-depth: 0/);
    const classify = steps[checkout + 1];
    assert.match(classify, /id: paths\n        shell: bash\n/);
    assert.match(classify, /EVENT: \$\{\{ github.event_name \}\}/);
    assert.match(classify, /BASE: \$\{\{ github.event.pull_request.base.sha \|\| github.event.before \}\}/);
    assert.match(classify, /HEAD: \$\{\{ github.event.pull_request.head.sha \|\| github.sha \}\}/);
    assert.match(classify, /run: bash -e -o pipefail tools\/classify-test-paths.sh/);
    for (const step of steps.slice(checkout + 2)) {
      if (name === 'test-update-source' && step.includes('node --test tools/startup-responsive.test.js')) {
        assert.doesNotMatch(step, /^        if:/m);
      } else {
        assert.match(step, /if: steps\.paths\.outputs\.heavy == 'true'(?: && .*)?\n/);
      }
    }
  }
  assert.equal((text.match(/node --test tools\/startup-responsive.test.js/g) || []).length, 1);
  assert.match(jobs['test-update-source'], /runs-on: ubuntu-latest/);
  assert.match(jobs.test, /run: zig build test[^\n]*\$\{\{ matrix\.group == 2 && '-j1' \|\| '' \}\}/, 'timed Windows shard must not compete with sibling builds and tests');
  assert.match(jobs['test-vps'], /run: zig build test-vps[^\n]*\$\{\{ matrix\.group == 1 && '-j1' \|\| '' \}\}/, 'timed VPS shard must not compete with sibling builds and tests');
}

test('each test job classifies after full-history checkout and gates all heavy steps', () => {
  verifyRouting(workflow);
});

test('routing checks reject the removed dependency, missing history, classifier and heavy guards', () => {
  for (const [before, after] of [
    ['jobs:\n', 'jobs:\n  changes:\n    runs-on: ubuntu-latest\n'],
    ['    runs-on: windows-latest', '    needs: changes\n    runs-on: windows-latest'],
    ['          fetch-depth: 0', '          fetch-depth: 1'],
    ['        id: paths', '        id: missing'],
    ["${{ matrix.group == 1 && '-j1' || '' }}", ''],
    ["${{ matrix.group == 2 && '-j1' || '' }}", ''],
    ["        if: steps.paths.outputs.heavy == 'true'", '        if: true'],
  ]) {
    assert.ok(workflow.includes(before));
    assert.throws(() => verifyRouting(workflow.replace(before, after)), assert.AssertionError);
  }
});

test('red regression job installs the Zig compiler before running changed suites', () => {
  const red = fs.readFileSync(new URL('../.github/workflows/check-red-run.yml', import.meta.url), 'utf8');
  const install = red.indexOf('      - name: Install Zig 0.16.0');
  const execute = red.indexOf('      - name: Require changed tests to fail on merge-base source');
  assert.ok(install >= 0 && execute > install);
  assert.match(red.slice(install, execute), /curl -fsSL https:\/\/ziglang\.org\/download\/0\.16\.0\/zig-x86_64-linux-0\.16\.0\.tar\.xz/);
  assert.match(red.slice(install, execute), /tar -xf/);
  assert.match(red.slice(install, execute), /zig-x86_64-linux-0\.16\.0.*GITHUB_PATH/);
});
