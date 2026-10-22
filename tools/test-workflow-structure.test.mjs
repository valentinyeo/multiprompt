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
    assert.doesNotMatch(job, /^    needs:/m);
    if (name === 'test-windows-update') {
      assert.match(job, /permissions:\n      contents: read\n      actions: read/);
      assert.ok(job.indexOf('name: Wait for x64 update verifier') < job.indexOf('uses: actions/download-artifact@'));
      assert.match(job, /if \(\$artifacts\.artifacts \| Where-Object \{ \$_\.name -eq \$env:ARTIFACT -and -not \$_\.expired \}\) \{ break \}/);
      assert.match(job, /Timed out waiting for x64 update verifier/);
      assert.ok(job.indexOf('name: Prepare unsigned update fixtures') < job.indexOf('name: Wait for x64 update verifier'));
      assert.match(job, /update-release-fixtures\.ps1[^\n]+-PrepareOnly/);
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
}

test('each test job classifies after full-history checkout and gates all heavy steps', () => {
  verifyRouting(workflow);
  const build = fs.readFileSync(new URL('../build.zig', import.meta.url), 'utf8');
  assert.match(build, /run\.has_side_effects = true;\s*run\.expectExitCode\(0\);/);
  assert.match(build, /b\.dupe\("--test-reporter=tap"\)/);
  assert.match(build, /b\.dupe\("--test-reporter-destination=stderr"\)/);
  const parallel = build.slice(build.indexOf('for ([_]*std.Build.Step.Run{'), build.indexOf('const test_groups'));
  assert.match(build, /if \(b\.graph\.host\.result\.os\.tag == \.windows\) \{\s*for \(\[_\]\*std\.Build\.Step\.Run/);
  assert.match(parallel, /--test-concurrency=1/);
  assert.doesNotMatch(parallel, /chat_view_gaps_tests/);
  for (const file of ['chat-cpu', 'ssh-reconnect', 'ssh-clock-standby']) {
    assert.match(fs.readFileSync(new URL(`./${file}.test.js`, import.meta.url), 'utf8'), /\['test', '-j1',/);
  }
  assert.match(build, /dependency == &run_sync_protocol_tests\.step or dependency == &frequent_integration_tests\.step/);
});

test('routing checks reject the removed dependency, missing history, classifier and heavy guards', () => {
  for (const [before, after] of [
    ['jobs:\n', 'jobs:\n  changes:\n    runs-on: ubuntu-latest\n'],
    ['    runs-on: windows-latest', '    needs: changes\n    runs-on: windows-latest'],
    ['      actions: read', '      actions: none'],
    ["throw 'Timed out waiting for x64 update verifier'", "Write-Host 'continue'"],
    ['-not $_.expired', '$true'],
    ['          fetch-depth: 0', '          fetch-depth: 1'],
    ['        id: paths', '        id: missing'],
    ["        if: steps.paths.outputs.heavy == 'true'", '        if: true'],
  ]) {
    assert.ok(workflow.includes(before));
    assert.throws(() => verifyRouting(workflow.replace(before, after)), assert.AssertionError);
  }
});
