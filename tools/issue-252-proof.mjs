import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const mode = process.argv[2];
const command = (program, args) => execFileSync(program, args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
const json = args => JSON.parse(command('gh', args));
const read = path => fs.readFileSync(path, 'utf8');

if (mode === 'public') {
  const base = command('git', ['show', 'daf2435:src/main.zig']);
  assert.equal(read('src/main.zig').match(/pub const APP_VERSION = "([^"]+)"/)[1], base.match(/pub const APP_VERSION = "([^"]+)"/)[1]);
  assert.equal(read('src/changelog.zig'), command('git', ['show', 'daf2435:src/changelog.zig']));
  assert.ok(read('changelog.d/IGSH-252-laptop-sync.md').trim().length > 0);
  assert.ok(read('src/shortcuts.zig').includes('Ctrl+K -> Sync between laptops'));
  assert.ok(read('openwiki/operations/keyboard-shortcuts.md').includes('Sync between laptops'));
  const paths = command('git', ['diff', '--name-only', 'daf2435']).trim().split('\n');
  for (const path of paths) {
    if (!fs.existsSync(path)) continue;
    assert.ok(!read(path).includes('/' + 'home/'), `Machine-specific path in ${path}`);
  }
  assert.match(command(process.execPath, ['tools/strip-comments.mjs', '--check']), /No code comments found/);
  console.log('ISSUE-252 public release rules verified');
} else {
  assert.ok(['protocol', 'regressions', 'pr'].includes(mode), 'Expected public, protocol, regressions or pr');
  const pr = json(['api', 'repos/valentinyeo/multiprompt/pulls/139']);
  const head = command('git', ['rev-parse', 'HEAD']).trim();
  assert.equal(pr.head.sha, head, 'PR must contain the current commit');
  assert.equal(pr.title, 'IGSH-252: hosts, workspaces and sessions sync between laptops (opt-in)');
  assert.equal(pr.head.ref, 'ceo/IGSH-252');
  assert.equal(pr.base.ref, 'master');
  assert.equal(pr.state, 'open');
  assert.equal(pr.merged, false);
  const testedHead = command('git', ['log', '-1', '--format=%H', '--', '.', ':(exclude)GATES.md']).trim();
  assert.equal(command('git', ['diff', '--name-only', testedHead, 'HEAD', '--', '.', ':(exclude)GATES.md']).trim(), '');
  if (mode === 'pr') {
    const checks = json(['pr', 'checks', '139', '--json', 'name,state,bucket,link']);
    const codeChecks = json(['api', `repos/valentinyeo/multiprompt/commits/${testedHead}/check-runs?per_page=100`]).check_runs;
    for (const name of ['build-x64', 'build-arm64', 'test', 'test-vps (1)', 'test-vps (2)', 'test-windows (1)', 'test-windows (2)', 'test-windows (3)', 'test-windows (4)', 'no-comments', 'secret-scan', 'extension-version']) {
      assert.ok(codeChecks.some(check => check.name === name && check.conclusion === 'success'), `Missing green check: ${name}`);
    }
    for (const check of checks) assert.ok(check.bucket === 'pass' || check.bucket === 'skipping' && ['release', 'test', 'test-vps', 'test-windows'].includes(check.name), `Check not green: ${check.name} ${check.state}`);
    console.log(`ISSUE-252 PR verified: #139 tested code ${testedHead}; current checks green`);
  } else {
    const runs = json(['api', 'repos/valentinyeo/multiprompt/actions/runs?branch=ceo%2FIGSH-252&per_page=30']).workflow_runs;
    const run = runs.find(run => run.name === 'Tests' && run.head_sha === testedHead);
    assert.ok(run, 'Tests run for current head must exist');
    assert.equal(run.conclusion, 'success', `Tests run ${run.id} must be green`);
    const jobs = json(['api', `repos/valentinyeo/multiprompt/actions/runs/${run.id}/jobs?per_page=100`]).jobs;
    const logs = name => {
      const job = jobs.find(job => job.name === name);
      assert.equal(job?.conclusion, 'success', name);
      return command('gh', ['api', `repos/valentinyeo/multiprompt/actions/jobs/${job.id}/logs`]);
    };
    const portable = logs('test-vps (2)');
    if (mode === 'protocol') {
      for (const title of ['production two-device protocol executes add edit delete conflict round trip offline and privacy cases', 'actual scheduler arms only one timer and off means no wakeups', 'actual SSH watcher blocks rearms before posting and releases its notification on stop or failure']) {
        assert.ok(new RegExp(`ok \\d+ - ISSUE-252 ${title}`).test(portable), title);
      }
      const service = logs('test-vps (1)');
      for (const title of ['authenticated devices round trip add edit delete and deterministic host conflicts', 'record service rejects credentials keys local paths geometry malformed ids and future clocks', 'records are account scoped and unauthorized or revoked devices cannot read or write']) assert.ok(new RegExp(`ok \\d+ - ISSUE-252 ${title}`).test(service), title);
      console.log(`ISSUE-252 protocol proven on GitHub run ${run.id}`);
    } else {
      assert.match(portable, /ok \d+ - ISSUE-252 conflict tombstone and readback mutations fail executable scenarios/);
      assert.match(portable, /ISSUE-252 original baseline rejected: host deletion and key privacy/);
      assert.match(portable, /ok \d+ - ISSUE-252 real original host deletion and key privacy regressions fail before this change/);
      console.log(`ISSUE-252 regression controls proven on GitHub run ${run.id}`);
    }
  }
}
