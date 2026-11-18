const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const test = require('node:test');
const verifier = require('./pr-verifier.cjs');

const base = 'b'.repeat(40);
const harness = 'c'.repeat(64);
const repo = 'owner/repo';
const row = { feature: 'appearance', 'app-revision': base, 'caption-dpi': 96, 'caption-browser-theme': 'light' };

function fixture(t, variant = row, status = 'failed') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'base-cache-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const evidence = path.join(dir, 'evidence');
  fs.mkdirSync(evidence);
  const write = (name, value) => fs.writeFileSync(path.join(evidence, name), JSON.stringify(value));
  write('result.json', { status, error: status === 'failed' ? 'wrong visible appearance' : '', cleanup: 'owned process tree stopped', checks: ['appearance'] });
  write('doctor.json', { alive: true });
  write('build.json', { revision: base, embeddedRevision: base, harnessRevision: 'a'.repeat(40), sha256: 'd'.repeat(64) });
  fs.writeFileSync(path.join(evidence, 'after.png'), 'png');
  const options = { variant, harness, repo, runId: '101' };
  return { dir, evidence, write, options };
}

test('workflow restores before the base matrix and publishes reusable bundles only for explicit base runs', async t => {
  const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/pr-verifier.yml'), 'utf8');
  const verify = fs.readFileSync(path.join(__dirname, '../.github/workflows/verify.yml'), 'utf8');
  assert.match(workflow, /base-journey-cache\.cjs restore/);
  assert.match(workflow, /features: \$\{\{ needs\.failed-head\.outputs\.features \}\}/);
  assert.match(workflow, /harness_version: \$\{\{ needs\.failed-head\.outputs\.harness_version \}\}/);
  assert.match(workflow, /name: pr-verifier-base-reuse/);
  assert.match(verify, /base-journey-cache\.cjs stamp/);
  assert.match(verify, /name: \$\{\{ steps\.base-cache\.outputs\.name \}\}/);
  assert.match(verify, /if: always\(\) && inputs\.base_cache/);
  const cache = require('./base-journey-cache.cjs');

  await t.test('the cache key separates journeys, commits, harness versions and display variants', () => {
    const key = cache.cacheName(row, harness);
    assert.notEqual(cache.cacheName({ ...row, feature: 'sessions' }, harness), key);
    assert.notEqual(cache.cacheName({ ...row, 'app-revision': 'a'.repeat(40) }, harness), key);
    assert.notEqual(cache.cacheName(row, 'd'.repeat(64)), key);
    assert.notEqual(cache.cacheName({ ...row, 'caption-dpi': 144 }, harness), key);
    assert.notEqual(cache.cacheName({ ...row, 'caption-browser-theme': 'dark' }, harness), key);
    assert.throws(() => cache.cacheName({ ...row, 'app-revision': 'master' }, harness));
  });

  await t.test('complete product failures remain reusable and still satisfy the real master repro gate', t => {
    const f = fixture(t);
    assert.equal(cache.stamp(f.evidence, f.options), true);
    assert.equal(cache.validEvidence(f.evidence, f.options), true);
    const output = path.join(f.dir, 'comparison');
    fs.mkdirSync(output);
    fs.cpSync(f.evidence, path.join(output, `verify-appearance-${base}`), { recursive: true });
    fs.cpSync(f.evidence, path.join(output, 'verify-appearance'), { recursive: true });
    fs.writeFileSync(path.join(output, 'verify-appearance/result.json'), JSON.stringify({ status: 'passed', cleanup: 'owned process tree stopped' }));
    const selection = verifier.validateSelection({ features: ['appearance'] }, ['appearance'], { title: 'fix: appearance', body: 'Repro journey: `appearance`' });
    const finish = () => verifier.finalize({ verdict: { verdict: 'PASS' }, selection, summary: verifier.summarize(output, ['appearance'], base) }).final;
    assert.equal(finish(), 'BLOCKED', 'a reused master failure cannot waive head break-it evidence');
    const breakIt = path.join(output, 'verify-appearance/break-it');
    const variations = ['resize', 'maximize', 'fast-switch', 'long-chat'].map(name => {
      const directory = path.join(breakIt, name);
      fs.mkdirSync(directory, { recursive: true });
      fs.writeFileSync(path.join(directory, 'after.png'), 'png');
      fs.writeFileSync(path.join(directory, 'journey.mp4'), 'video');
      fs.writeFileSync(path.join(directory, 'video.json'), JSON.stringify({ streams: [{ width: 1280, height: 720 }] }));
      return { name, status: 'passed', actions: 1, cleanup: 'complete' };
    });
    fs.writeFileSync(path.join(breakIt, 'result.json'), JSON.stringify({ feature: 'appearance', status: 'passed', variations }));
    assert.equal(finish(), 'PASS');
    fs.writeFileSync(path.join(output, `verify-appearance-${base}/result.json`), JSON.stringify({ status: 'passed', cleanup: 'owned process tree stopped' }));
    assert.equal(finish(), 'FAIL', 'a cached master pass cannot replace a real master failure');
  });

  for (const damage of ['result.json', 'doctor.json', 'after.png', 'build.json', 'cleanup', 'infrastructure', 'revision', 'embeddedRevision', 'manifest']) {
    await t.test(`incomplete or mismatched ${damage} evidence is a miss, never a reusable failure`, t => {
      const f = fixture(t);
      cache.stamp(f.evidence, f.options);
      if (damage.includes('.')) fs.rmSync(path.join(f.evidence, damage));
      else if (damage === 'cleanup') f.write('result.json', { status: 'failed', error: 'wrong appearance', cleanup: 'pending' });
      else if (damage === 'infrastructure') f.write('result.json', { status: 'failed', error: 'Workflow failed before launch', cleanup: 'stopped', failureKind: 'infrastructure' });
      else if (damage === 'manifest') f.write('base-cache.json', { ...f.options, harness: 'e'.repeat(64) });
      else f.write('build.json', { revision: base, embeddedRevision: base, [damage]: 'a'.repeat(40) });
      assert.equal(cache.validEvidence(f.evidence, f.options), false);
      assert.equal(cache.stamp(f.evidence, f.options), damage === 'manifest');
    });
  }

  await t.test('harness versions ignore application-only and test-only edits but change for runtime harness dependencies', t => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'harness-version-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const git = args => execFileSync('git', args, { cwd: dir, encoding: 'utf8' }).trim();
    git(['init', '-q']);
    const put = (name, value) => { const file = path.join(dir, name); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, value); };
    put('tools/driver.ps1', 'drive');
    put('src/chat_send.zig', 'app');
    put('src/app_state.zig', 'catalog');
    put('.github/workflows/verify.yml', 'workflow');
    const tree = () => { git(['add', '.']); return git(['write-tree']); };
    const version = () => cache.harnessVersion(tree(), dir);
    const initial = version();
    put('src/chat_send.zig', 'new app');
    put('tools/example.test.js', 'test');
    assert.equal(version(), initial);
    for (const name of ['tools/driver.ps1', 'src/app_state.zig', '.github/workflows/verify.yml', '.claude/skills/verify-multiprompt/control.ps1']) {
      const before = version();
      put(name, 'changed');
      assert.notEqual(version(), before, name);
    }
    git(['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'old PR without cache tools']);
    const actualWorkflow = path.join(dir, 'actual-workflow.yml');
    fs.writeFileSync(actualWorkflow, 'new workflow from the controller revision');
    const restored = spawnSync(process.execPath, [path.join(__dirname, 'base-journey-cache.cjs'), 'restore', path.join(dir, 'restored')], {
      env: { ...process.env, FEATURES: '[]', BASE_SHA: base, REPO: repo, RUN_ID: '102', HARNESS_VERSION: '', HARNESS_ROOT: dir, WORKFLOW_FILE: actualWorkflow,
        GITHUB_OUTPUT: path.join(dir, 'outputs'), GITHUB_STEP_SUMMARY: path.join(dir, 'summary') }, encoding: 'utf8',
    });
    assert.equal(restored.status, 0, restored.stderr);
    assert.match(restored.stdout, new RegExp(`harness_version=${cache.harnessVersion('HEAD', dir, actualWorkflow)}`));
    assert.notEqual(cache.harnessVersion('HEAD', dir, actualWorkflow), cache.harnessVersion('HEAD', dir));
  });

  await t.test('two PR runs on one base reuse complete evidence before scheduling; missing variants rerun the whole journey', { skip: process.platform !== 'linux' }, t => {
    const f = fixture(t);
    cache.stamp(f.evidence, f.options);
    const archive = path.join(f.dir, 'artifact.zip');
    execFileSync('zip', ['-qr', archive, '.'], { cwd: f.evidence });
    const bin = path.join(f.dir, 'bin');
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, 'gh'), `#!/usr/bin/env node
  const fs = require('node:fs');
  const endpoint = process.argv[3];
  fs.appendFileSync(process.env.REQUESTS, endpoint + '\\n');
  if (process.env.API_BAD === '1') { console.log('{}'); process.exit(0); }
  if (process.env.DOWNLOAD_BAD === '1' && endpoint.endsWith('/zip')) process.exit(1);
  if (endpoint.endsWith('/zip')) process.stdout.write(fs.readFileSync(process.env.ARCHIVE));
  else if (endpoint.includes('/artifacts?')) {
    const name = new URL('https://example.test/' + endpoint).searchParams.get('name');
    console.log(JSON.stringify({ artifacts: process.env.COLD === '1' || !name.includes('-appearance-') ? [] : [{ id: 1, name, expired: process.env.EXPIRED === '1', workflow_run: { id: 101 } }] }));
  } else console.log(JSON.stringify({ id: 101, path: '.github/workflows/pr-verifier.yml', event: 'pull_request', repository: { full_name: 'owner/repo' }, head_repository: { full_name: process.env.FOREIGN === '1' ? 'other/repo' : 'owner/repo' } }));
  `, { mode: 0o755 });
    const requests = path.join(f.dir, 'requests');
    const run = (runId, cold, extra = {}) => {
      const out = path.join(f.dir, runId);
      const result = spawnSync(process.execPath, [path.join(__dirname, 'base-journey-cache.cjs'), 'restore', out], {
        env: { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, REPO: repo, RUN_ID: runId, BASE_SHA: base, HARNESS_VERSION: harness,
          FEATURES: '["appearance","title-bar"]', COLD: cold, ARCHIVE: archive, REQUESTS: requests, GITHUB_OUTPUT: path.join(f.dir, `${runId}.output`), GITHUB_STEP_SUMMARY: path.join(f.dir, `${runId}.summary`), ...extra }, encoding: 'utf8',
      });
      assert.equal(result.status, 0, result.stderr);
      return JSON.parse(fs.readFileSync(path.join(out, 'reuse.json')));
    };
    assert.deepEqual(run('102', '1').features, ['appearance', 'title-bar']);
    const warm = run('103', '0');
    assert.deepEqual(warm.features, ['title-bar']);
    assert.deepEqual(warm.reused, ['appearance']);
    assert.equal(warm.beforeJobs, 7);
    assert.equal(warm.afterJobs, 6);
    assert.ok(fs.existsSync(path.join(f.dir, '103', `verify-appearance-${base}`, 'after.png')));
    assert.ok(!fs.existsSync(path.join(f.dir, '103', `verify-title-bar-${base}-96-light`)));
    for (const extra of [{ EXPIRED: '1' }, { FOREIGN: '1' }, { API_BAD: '1' }, { DOWNLOAD_BAD: '1' }, { RUN_ID: '101' }, { HARNESS_VERSION: 'e'.repeat(64) }, { BASE_SHA: 'a'.repeat(40) }]) {
      assert.deepEqual(run('105', '0', extra).features, ['appearance', 'title-bar']);
    }
    run('103', '1');
    assert.ok(!fs.existsSync(path.join(f.dir, '103', `verify-appearance-${base}`)), 'rerunning a restore cannot retain a stale hit');
    const partial = fixture(t, { ...row, feature: 'title-bar' });
    cache.stamp(partial.evidence, partial.options);
    const partialArchive = path.join(partial.dir, 'partial.zip');
    execFileSync('zip', ['-qr', partialArchive, '.'], { cwd: partial.evidence });
    const fake = fs.readFileSync(path.join(bin, 'gh'), 'utf8').replace("!name.includes('-appearance-')", "!name.endsWith('-96-light')");
    fs.writeFileSync(path.join(bin, 'gh'), fake);
    assert.deepEqual(run('106', '0', { FEATURES: '["title-bar"]', ARCHIVE: partialArchive }).features, ['title-bar']);
    assert.ok(!fs.existsSync(path.join(f.dir, '106', `verify-title-bar-${base}-96-light`)), 'partial display coverage must not leak into the verdict');
    fs.writeFileSync(path.join(bin, 'gh'), fake.replace("!name.endsWith('-96-light')", "!name.includes('-appearance-')"));
    fs.rmSync(path.join(f.evidence, 'doctor.json'));
    fs.rmSync(archive);
    execFileSync('zip', ['-qr', archive, '.'], { cwd: f.evidence });
    assert.deepEqual(run('104', '0').features, ['appearance', 'title-bar']);
  });

  await t.test('the hosted comparison counts queue-inclusive wall time and actual skipped jobs, and rejects invalid speed claims', () => {
    const { measure, compare } = require('./measure-base-reuse.cjs');
    const run = { id: 101, status: 'completed', conclusion: 'success', pull_requests: [{ number: 1 }], created_at: '2026-01-01T00:00:00Z' };
    const jobs = [
      { name: 'base / verify (appearance)', status: 'completed', conclusion: 'success', labels: ['windows-latest'], started_at: '2026-01-01T00:10:00Z', completed_at: '2026-01-01T00:15:00Z' },
      { name: 'pstack-verifier report', status: 'completed', conclusion: 'success', labels: ['ubuntu-latest'], started_at: '2026-01-01T00:15:00Z', completed_at: '2026-01-01T00:16:00Z' },
    ];
    const reuse = { base, harness, features: ['appearance'], reused: [], beforeJobs: 1, afterJobs: 1, sources: [] };
    const before = measure(run, jobs, reuse);
    assert.equal(before.wallSeconds, 960);
    assert.equal(before.initialQueueSeconds, 600);
    assert.equal(before.baseWindowsJobs, 1);
    const warm = { ...reuse, features: [], reused: ['appearance'], afterJobs: 0, sources: [{ runId: 101 }] };
    const after = measure({ ...run, id: 102, pull_requests: [{ number: 2 }] }, [{ ...jobs[1], conclusion: 'failure' }], warm);
    assert.equal(compare(before, after).after.scheduledJobs, 1);
    assert.equal(compare(before, after).after.failures.length, 1, 'failed runs must remain visible in timing reports');
    assert.throws(() => measure({ ...run, status: 'in_progress' }, jobs, reuse), /never waits/);
    assert.throws(() => compare(before, { ...after, pr: 1 }), /distinct PRs/);
    assert.throws(() => compare(before, { ...after, reuse: { ...warm, harness: 'wrong' } }), /same base, harness/);
    assert.throws(() => compare(before, { ...after, baseWindowsJobs: 1 }), /did not skip/);
    assert.throws(() => compare(before, { ...after, reuse: { ...warm, sources: [{ runId: 99 }] } }), /reused from that run/);
  });

  await t.test('tmux-binding remains a miss because its separate Linux semantic proof is not in the Windows artifact', t => {
    const f = fixture(t, { ...row, feature: 'tmux-binding' });
    assert.equal(cache.stamp(f.evidence, f.options), false);
  });
});
