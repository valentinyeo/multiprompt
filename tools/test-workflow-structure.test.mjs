import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const workflow = fs.readFileSync(new URL('../.github/workflows/test.yml', import.meta.url), 'utf8');
const names = ['test', 'test-update-source', 'test-windows-update', 'test-vps', 'test-worker', 'build-windows'];

function verifyRouting(text) {
  const jobs = Object.fromEntries([...text.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  assert.equal(jobs.changes, undefined);
  assert.doesNotMatch(text, /needs\.changes|needs:.*\bchanges\b/);
  const paths = jobs.paths;
  assert.match(paths, /runs-on: ubuntu-latest/);
  assert.match(paths, /timeout-minutes: 2/);
  assert.doesNotMatch(paths, /^    needs:/m);
  assert.match(paths, /heavy: \$\{\{ steps\.paths\.outputs\.heavy \}\}/);
  const pathSteps = paths.split(/(?=^      - )/m).filter(step => step.startsWith('      - '));
  const pathCheckout = pathSteps.findIndex(step => step.includes('uses: actions/checkout@'));
  assert.match(pathSteps[pathCheckout], /fetch-depth: 0/);
  assert.match(pathSteps[pathCheckout + 1], /id: paths\n        shell: bash\n/);
  assert.match(jobs.test, /^    needs: paths\n    if: needs\.paths\.outputs\.heavy == 'true'\n/m);
  assert.match(jobs['test-windows-update'], /^    needs: \[paths, build-windows\]\n    if: needs\.paths\.outputs\.full == 'true' && needs\.paths\.outputs\.heavy == 'true' && needs\.build-windows\.result == 'success'\n/m);
  const result = jobs['test-result'];
  assert.match(result, /name: test\n/);
  assert.match(result, /if: always\(\)/);
  assert.match(result, /HEAVY: \$\{\{ needs\.paths\.outputs\.heavy \}\}/);
  assert.match(result, /accept windows "\$WINDOWS"/);
  assert.match(result, /accept update "\$UPDATE"/);
  assert.match(jobs.test, /group: \$\{\{ fromJSON\(needs\.paths\.outputs\.groups\) \}\}/);
  assert.match(result, /accept always "\$PATHS"/);
  for (const name of names) {
    const job = jobs[name];
    assert.ok(job, name);
    if (name === 'test' || name === 'test-windows-update') assert.match(job, /^    if:/m);
    else {
      assert.doesNotMatch(job, /^    if:/m);
      assert.doesNotMatch(job, /^    needs:/m);
    }
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
    ["    needs: paths\n    if: needs.paths.outputs.heavy == 'true'\n", ''],
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

test('branch reaction proof uses the shared journey without changing production triggers', () => {
  const adapterFile = new URL('../.github/workflows/reaction-journey.yml', import.meta.url);
  assert.ok(fs.existsSync(adapterFile), 'reaction workflow adapter exists');
  const adapter = fs.readFileSync(adapterFile, 'utf8');
  assert.match(adapter, /branches: \[ceo\/IGSH-1012\]/);
  assert.match(adapter, /uses: \.\/\.github\/workflows\/verify\.yml/);
  assert.match(adapter, /feature: chat-delivery/);
  assert.match(adapter, /chat_reactions_proof: true/);
  const verify = fs.readFileSync(new URL('../.github/workflows/verify.yml', import.meta.url), 'utf8');
  assert.match(verify, /workflow_call:\n    inputs:\n      chat_reactions_proof:/);
  assert.match(verify, /branches: \[master\]/);
});
