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
    if (name === 'test-windows-update') {
      assert.match(job, /^    if: github.event_name != 'pull_request'$/m);
      assert.match(job, /^    needs: \[build-windows\]$/m);
    } else {
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
    assert.throws(() => verifyRouting(workflow.replaceAll(before, after)), assert.AssertionError);
  }
});

test('Windows group 3 has a bounded twenty-minute build and test budget', () => {
  const job = workflow.split('\n  test:\n')[1].split(/\n  [\w-]+:\n/)[0];
  const budget = job.match(/timeout-minutes: \$\{\{ (.+) \}\}/)[1];
  assert.deepEqual([1, 2, 3, 4, 5].map(group => vm.runInNewContext(budget, { matrix: { group } })), [15, 10, 20, 10, 10]);
});

test('Tests starts on every pull request and every master push so drift cannot hide', () => {
  const events = workflow.split('\non:\n')[1]?.split('\npermissions:')[0];
  assert.ok(events, 'workflow events are declared');
  assert.match(events, /^  pull_request:$/m);
  assert.match(events, /^  push:\n    branches: \[master\]$/m);
  assert.match(events, /^  workflow_dispatch:$/m);
  assert.match(events, /^  schedule:\n    - cron: /m);
  assert.doesNotMatch(events, /^  (?:workflow_run|repository_dispatch):/m);
});

test('red regression job installs the Zig compiler before running changed suites', () => {
  const red = fs.readFileSync(new URL('../.github/workflows/check-red-run.yml', import.meta.url), 'utf8');
  const install = red.indexOf('      - name: Install Zig 0.16.0');
  const execute = red.indexOf('      - name: Require changed tests to fail on merge-base source');
  assert.ok(install >= 0 && execute > install);
  assert.match(red.slice(install, execute), /uses: \.\/\.github\/actions\/setup-zig/);
  assert.match(red.slice(install, execute), /ZIG=\$RUNNER_TEMP\/zig-x86_64-linux-0\.16\.0\/zig/);
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
  assert.match(verify, /workflow_call:\n    inputs:\n[\s\S]*?      revision:\n        required: false\n        type: string/);
  verifyManualNightly(verify);
  const expression = verify.match(/CHAT_REACTIONS_PROOF: \$\{\{ (.+) \}\}/)?.[1];
  assert.ok(expression, 'reaction proof routing exists');
  for (const [requested, feature, expected] of [[true, 'chat-delivery', '1'], [false, 'chat-double-click', '1'], [false, 'chat-delivery', '']]) {
    assert.equal(vm.runInNewContext(expression, { inputs: { chat_reactions_proof: requested }, matrix: { feature } }), expected);
  }
  assert.match(verify, /drive\.ps1 -Feature \$env:FEATURE/);
});

test('manual and nightly verification execute native appearance', async () => {
  const verify = fs.readFileSync(new URL('../.github/workflows/verify.yml', import.meta.url), 'utf8');
  verifyManualNightly(verify);
  assert.match(verify, /feature:\n        description: Feature map file stem[^\n]*\n        required: true\n        default: appearance/);
  const { discoverFeatures } = await import('./verify-features.cjs');
  const features = discoverFeatures();
  assert.ok(features.full.includes('appearance'));
  assert.match(verify, /fromJSON\(needs.journeys.outputs.matrix\)/);
  const script = verify.split('      - id: matrix\n')[1].split("          node - <<'NODE' >> \"$GITHUB_OUTPUT\"\n")[1].split('          NODE')[0].replace(/^          /gm, '');
  const { execFileSync } = await import('node:child_process');
  const matrix = (event, feature, source = script) => {
    const output = execFileSync(process.execPath, ['-'], { cwd: new URL('..', import.meta.url), input: source, encoding: 'utf8', env: { ...process.env, EVENT: event, FEATURE: feature, FEATURES: '', APP_REVISION: '' }, stdio: ['pipe', 'pipe', 'pipe'] });
    return JSON.parse(output.split('\n').find(line => line.startsWith('selected=')).slice(9));
  };
  assert.deepEqual(matrix('schedule', ''), features.available);
  assert.deepEqual(matrix('workflow_dispatch', 'appearance'), ['appearance']);
  assert.ok(matrix('workflow_dispatch', 'all').includes('appearance'));
  const broken = script.replace(': available;', ': [];');
  assert.notEqual(broken, script);
  assert.throws(() => matrix('schedule', '', broken));
  assert.match(verify, /runs-on: windows-latest/);
  assert.match(verify, /FEATURE: \$\{\{ matrix.feature \}\}/);
  const driver = verify.split('      - name: Launch Doctor Drive Evidence Cleanup\n')[1]?.split(/\n      - /)[0];
  assert.ok(driver);
  assert.match(driver, /drive\.ps1 -Feature \$env:FEATURE/);
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

test('speed baseline walks back to the newest earlier commit that builds', () => {
  const step = workflow.split('      - name: Build baseline\n')[1]?.split(/\n      - name: /)[0];
  assert.ok(step, 'baseline build step exists');
  assert.match(step, /\$requested = \(git merge-base \$env:BASE HEAD\)\.Trim\(\)/);
  assert.match(step, /for \(\$attempt = 0; \$attempt -lt 12; \$attempt \+= 1\)/);
  assert.match(step, /git rev-parse "\$base\^"/);
  assert.match(step, /\$base = \$parent/);
  assert.match(step, /"SPEED_BASE=\$base"/);
  assert.match(step, /"SPEED_REQUESTED_BASE=\$requested"/);
  const record = workflow.split('      - name: Record baseline commit\n')[1]?.split(/\n      - name: /)[0];
  assert.ok(record, 'baseline record step exists');
  assert.match(record, /evidence\/base\/baseline\.txt/);
  assert.match(record, /walked back because/);
});

test('a master push publishes without a release journey gate and never cancels a running release', () => {
  const release = fs.readFileSync(new URL('../.github/workflows/release.yml', import.meta.url), 'utf8');
  const jobs = Object.fromEntries([...release.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  assert.equal(jobs.journeys, undefined, 'release.yml must not run candidate journeys');
  assert.equal(jobs['journey-gate'], undefined, 'release.yml must not gate publication on journeys');
  assert.doesNotMatch(release, /release-journeys\.mjs|release-journey-receipt|needs\.prepare\.outputs\.features/);
  assert.match(jobs.release, /^    needs: \[prepare, build, launch, gitleaks\]$/m);
  assert.match(release, /sha256sum -- \*\.exe \*\.zip release-notes\.json > SHA256SUMS\.txt/);
  const auto = fs.readFileSync(new URL('../.github/workflows/auto-release.yml', import.meta.url), 'utf8');
  assert.match(auto, /^concurrency:\n  group: auto-release-\$\{\{ github\.ref \}\}\n  cancel-in-progress: false$/m);
  assert.match(auto, /needs\.release\.result == 'success' \|\| needs\.release\.result == 'cancelled'/);
});
