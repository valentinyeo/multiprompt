import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const workflow = fs.readFileSync(new URL('../.github/workflows/test.yml', import.meta.url), 'utf8');
const names = ['test', 'test-update-source', 'test-windows-update', 'test-vps', 'test-worker', 'build-windows'];

function verifyManualNightly(text) {
  const events = text.split('\non:\n')[1]?.split('\npermissions:')[0];
  assert.ok(events, 'workflow events are declared');
  assert.match(events, /^  workflow_dispatch:/m);
  assert.match(events, /^  schedule:/m);
  assert.doesNotMatch(events, /^  (?:push|pull_request|workflow_run|repository_dispatch):/m);
}

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
    assert.match(classify, /BASE: \$\{\{ github.event_name == 'schedule' && github.sha \|\| github.event.pull_request.base.sha \|\| \(github.ref != 'refs\/heads\/master' && 'origin\/master'\) \|\| github.event.before \|\| format\('\{0\}\^', github.sha\) \}\}/);
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
    ["github.event_name == 'schedule' && github.sha || ", ''],
    [" || format('{0}^', github.sha)", ''],
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

test('manual and nightly reaction proof uses the shared journey', () => {
  const adapterFile = new URL('../.github/workflows/reaction-journey.yml', import.meta.url);
  assert.ok(fs.existsSync(adapterFile), 'reaction workflow adapter exists');
  const adapter = fs.readFileSync(adapterFile, 'utf8');
  verifyManualNightly(adapter);
  assert.match(adapter, /uses: \.\/\.github\/workflows\/verify\.yml/);
  assert.match(adapter, /feature: chat-delivery/);
  assert.match(adapter, /chat_reactions_proof: true/);
  const verify = fs.readFileSync(new URL('../.github/workflows/verify.yml', import.meta.url), 'utf8');
  assert.match(verify, /workflow_call:\n    inputs:\n(?:      [\s\S]*?)      chat_reactions_proof:/);
  assert.match(verify, /workflow_call:\n    inputs:\n      revision:\n        required: false\n        type: string/);
  verifyManualNightly(verify);
  assert.match(verify, /CHAT_REACTIONS_PROOF: \$\{\{ inputs.chat_reactions_proof && '1' \|\| '' \}\}/);
  assert.match(verify, /control\.ps1 -Feature \$env:FEATURE/);
});

test('manual and nightly verification execute native appearance', async () => {
  const verify = fs.readFileSync(new URL('../.github/workflows/verify.yml', import.meta.url), 'utf8');
  verifyManualNightly(verify);
  assert.match(verify, /feature:\n        description: Feature map file stem[^\n]*\n        required: true\n        default: appearance/);
  const { discoverFeatures } = await import('./verify-features.cjs');
  const features = discoverFeatures();
  assert.ok(features.full.includes('appearance'));
  const expression = verify.match(/^        feature: \$\{\{ (.+) \}\}$/m)?.[1];
  assert.ok(expression);
  const matrix = (event, feature, source = expression) => JSON.parse(JSON.stringify(vm.runInNewContext(source, {
    inputs: { feature }, github: { event_name: event, ref: 'refs/heads/master' },
    needs: { journeys: { outputs: { full: JSON.stringify(features.full), pr: JSON.stringify(features.pr) } } },
    fromJSON: JSON.parse, format: (pattern, value) => pattern.replace('{0}', value), startsWith: (value, prefix) => value.startsWith(prefix),
  })));
  assert.deepEqual(matrix('schedule', ''), ['appearance']);
  assert.deepEqual(matrix('workflow_dispatch', 'appearance'), ['appearance']);
  assert.ok(matrix('workflow_dispatch', 'all').includes('appearance'));
  const oldFallback = expression.replace("inputs.feature || 'appearance'", 'inputs.feature');
  assert.notEqual(oldFallback, expression);
  assert.notDeepEqual(matrix('schedule', '', oldFallback), ['appearance']);
  assert.match(verify, /runs-on: windows-latest/);
  assert.match(verify, /FEATURE: \$\{\{ matrix.feature \}\}/);
  const driver = verify.split('      - name: Launch Doctor Drive Evidence Cleanup\n')[1]?.split(/\n      - /)[0];
  assert.ok(driver);
  assert.match(driver, /control\.ps1 -Feature \$env:FEATURE/);
  assert.doesNotMatch(driver, /env\.FEATURE != 'appearance'|continue-on-error:/);
  const policy = JSON.parse(fs.readFileSync(new URL('./journey-policy.json', import.meta.url), 'utf8'));
  assert.equal(policy.quarantined.appearance, undefined);
});

test('report-only triggers reject automatic pushes and preserve legacy branch checker controls', async () => {
  const verify = fs.readFileSync(new URL('../.github/workflows/verify.yml', import.meta.url), 'utf8');
  verifyManualNightly(verify);
  for (const [before, after] of [
    ['  schedule:', '  removed_schedule:'],
    ['  workflow_dispatch:', '  removed_dispatch:'],
    ['  workflow_dispatch:', '  push:\n  workflow_dispatch:'],
    ['  workflow_dispatch:', '  pull_request:\n  workflow_dispatch:'],
  ]) {
    assert.ok(verify.includes(before));
    assert.throws(() => verifyManualNightly(verify.replace(before, after)), assert.AssertionError);
  }
  const { verifyPushBranches } = await import('./verify-workflow-branches.mjs');
  const legacy = 'on:\n  push:\n    branches: [master, ceo/IGSH-1012]\n';
  verifyPushBranches(legacy);
  verifyPushBranches(legacy.replace('branches: [master,', 'branches: [master, ceo/IGSH-9999,'));
  for (const replacement of ['', 'main, ', 'unrelated, ', "'ceo/OTHER-123', "]) {
    assert.throws(() => verifyPushBranches(legacy.replace('branches: [master, ', 'branches: [' + replacement)), assert.AssertionError);
  }
  assert.throws(() => verifyPushBranches(legacy.replace('branches: [master,', 'branches: [master, unrelated,')), assert.AssertionError);
});
