import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { releaseVersion, nextReleaseTag } from './release-version.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const workflow = fs.readFileSync(path.join(root, '.github/workflows/release.yml'), 'utf8');
const tag = 'v1.2.3';
const changelog = '.{ .ver = "1.2.3" },\n.{ .ver = "1.2.2" },\n';
const script = (name, source = workflow) => {
  const block = source.match(new RegExp(`      - name: ${name}\\n[\\s\\S]*?        run: \\|\\n((?:          [^\\n]*\\n|\\n)+)`));
  assert(block, `Missing workflow script: ${name}`);
  return block[1].split('\n').map(line => line.slice(10)).join('\n');
};

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-version-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'Release Test');
  git('config', 'user.email', 'release@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  git('config', 'core.autocrlf', 'false');
  fs.mkdirSync(path.join(dir, 'src'));
  fs.mkdirSync(path.join(dir, 'tools'));
  fs.writeFileSync(path.join(dir, 'src/changelog.zig'), changelog);
  for (const file of ['release-version.mjs', 'version-stamp.mjs', 'strip-comments.mjs', 'auto-release-admit.sh']) fs.copyFileSync(path.join(root, 'tools', file), path.join(dir, 'tools', file));
  fs.writeFileSync(path.join(dir, 'src/main.zig'), 'pub const APP_VERSION = build_config.app_version orelse "1.2.3";\n');
  git('add', '.');
  git('commit', '-m', 'fixture');
  git('tag', 'v1.2.2');
  git('commit', '--allow-empty', '-m', 'release candidate');
  const sha = git('rev-parse', 'HEAD');
  const remote = path.join(dir, 'remote.git');
  git('clone', '--bare', dir, remote);
  git('remote', 'add', 'origin', remote);
  const log = path.join(dir, 'gh-log');
  fs.writeFileSync(log, '');
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}
const fs = require('node:fs');
const { execFileSync } = require('node:child_process');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.GH_LOG, JSON.stringify(args) + '\\n');
if (args[0] === 'run' && args[1] === 'view') {
  console.log(JSON.stringify({ jobs: [{ name: 'verify (relaunch-saved-sessions)', conclusion: process.env.VERIFY_CONCLUSION || 'success' }] }));
  process.exit(0);
}
if (args[0] === 'run' && args.includes('release-gate.yml')) {
  console.log('[]');
  process.exit(0);
}
if (args[0] === 'run' && args.includes('verify.yml')) {
  const sha = args[args.indexOf('--commit') + 1];
  console.log(JSON.stringify(sha === process.env.TESTED_SHA ? [{ databaseId: 700, event: 'push', status: 'completed', conclusion: 'success' }] : []));
  process.exit(0);
}
if (args[0] === 'run') {
  const sha = args[args.indexOf('--commit') + 1];
  console.log(JSON.stringify(sha === process.env.TESTED_SHA ? [{ databaseId: 1, event: 'push', status: 'completed', conclusion: process.env.TEST_CONCLUSION || 'success' }] : []));
  process.exit(0);
}
if (args[0] === 'api' && args[1].endsWith('/releases/latest')) {
  if (process.env.LATEST_READ_FAIL === '1') process.exit(1);
  console.log(process.env.GH_STATE && fs.existsSync(process.env.GH_STATE) ? JSON.parse(fs.readFileSync(process.env.GH_STATE)).latest : process.env.PUBLISHED_TAG || 'v1.2.8');
  process.exit(0);
}
if (args[0] === 'api') {
  const field = name => args.find(a => a.startsWith(name + '=')).slice(name.length + 1);
  execFileSync('git', ['--git-dir', process.env.TEST_REMOTE, 'update-ref', field('ref'), field('sha'), ''], { stdio: 'ignore' });
  process.exit(0);
}
if (args[1] === 'view') {
  const state = process.env.GH_STATE && fs.existsSync(process.env.GH_STATE) ? JSON.parse(fs.readFileSync(process.env.GH_STATE)) : { releases: [] };
  process.exit(process.env.RELEASE_EXISTS === '1' || state.releases.includes(args[2]) ? 0 : 1);
}
if (args[1] !== 'create') process.exit(2);
if (process.env.GH_CREATE_FAIL === '1') process.exit(1);
if (process.env.GH_STATE) {
  const state = fs.existsSync(process.env.GH_STATE) ? JSON.parse(fs.readFileSync(process.env.GH_STATE)) : { latest: process.env.PUBLISHED_TAG, releases: [] };
  state.releases.push(args[2]);
  if (args.includes('--latest') || args.includes('--latest=true')) state.latest = args[2];
  fs.writeFileSync(process.env.GH_STATE, JSON.stringify(state));
}
const existing = require('node:child_process').spawnSync('git', ['--git-dir', process.env.TEST_REMOTE, 'show-ref', '--verify', '--quiet', 'refs/tags/' + args[2]]);
if (existing.status === 1) execFileSync('git', ['--git-dir', process.env.TEST_REMOTE, 'update-ref', 'refs/tags/' + args[2], process.env.BUILT_SHA]);
else if (existing.status !== 0) process.exit(existing.status || 1);
`, { mode: 0o755 });
  return { dir, git, sha, remote, log,
    run: (name, env = {}, source = workflow) => spawnSync('bash', ['-euo', 'pipefail', '-c', script(name, source)], { cwd: dir, encoding: 'utf8',
      env: { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, GITHUB_EVENT_NAME: 'push', GITHUB_REF: 'refs/heads/master', GITHUB_REPOSITORY: 'example/multiprompt',
        TAG: tag, BUILT_SHA: sha, PUBLISHED_TAG: 'v1.2.2', GH_STATE: path.join(dir, 'release-state.json'), REQUESTED_TAG: '', RUNNER_TEMP: dir, GITHUB_OUTPUT: path.join(dir, 'output'), GH_LOG: log, TEST_REMOTE: remote, ...env } }),
    admit: (env = {}) => spawnSync('bash', ['tools/auto-release-admit.sh'], { cwd: dir, encoding: 'utf8',
      env: { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, GITHUB_REPOSITORY: 'example/multiprompt',
        GH_LOG: log, TEST_REMOTE: remote, TESTED_SHA: git('rev-parse', 'HEAD'), ...env } }),
    calls: () => fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line)),
  };
}

test('reads the first changelog version, including flexible whitespace', () => {
  assert.equal(releaseVersion(changelog), tag);
  assert.equal(releaseVersion('.ver\n = "2.30.400"'), 'v2.30.400');
  assert.equal(releaseVersion(changelog, tag), tag);
});

test('rejects missing versions and mismatching or unsafe tags', () => {
  for (const text of ['', '.version = "1.2.3"', '.ver = "1.2"', '.ver = "1.2.3-beta"']) assert.throws(() => releaseVersion(text), /No release version/);
  for (const requested of ['v1.2.2', '1.2.3', 'v1.2.3\nother', 'v1.2.3;bad']) assert.throws(() => releaseVersion(changelog, requested), /does not match/);
});

test('CLI reads files and fails closed', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-cli-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const file = path.join(dir, 'changelog.zig');
  fs.writeFileSync(file, changelog);
  const run = (...args) => spawnSync(process.execPath, [path.join(root, 'tools/release-version.mjs'), ...args], { encoding: 'utf8' });
  assert.equal(run(file).stdout.trim(), tag);
  assert.equal(run(file, tag).status, 0);
  assert.equal(run(file, 'v9.9.9').status, 1);
  assert.equal(run(`${file}-missing`).status, 1);
});

test('master release builds both architectures, launches, scans and publishes the exact source', () => {
  const auto = fs.readFileSync(path.join(root, '.github/workflows/auto-release.yml'), 'utf8');
  assert.match(auto, /push:\n    branches: \[master\]/);
  assert.match(auto, /workflow_dispatch:/);
  assert.match(auto, /if: github.ref == 'refs\/heads\/master'/);
  assert.match(auto, /uses: \.\/\.github\/workflows\/release.yml/);
  assert.doesNotMatch(auto, /workflow_run:|schedule:|auto-release-admit/);
  assert.match(workflow, /workflow_dispatch:[\s\S]*tag:[\s\S]*required: false/);
  assert.match(workflow, /workflow_call:/);
  assert.doesNotMatch(workflow, /^  (?:push|pull_request):/m);
  assert.match(workflow, /permissions:\n  contents: write/);
  assert.doesNotMatch(workflow, /--draft/);
  assert.deepEqual([...workflow.matchAll(/secrets\.(\w+)/g)].map(match => match[1]), ['MULTIPROMPT_RELEASE_SIGNING_KEY']);
  assert.match(workflow, /run: node tools\/sign-release\.mjs/);
  assert.match(workflow, /arch: x64\n            target: x86_64-windows-gnu/);
  assert.match(workflow, /arch: arm64\n            target: aarch64-windows-gnu/);
  assert.equal((workflow.match(/ref: \$\{\{ needs.prepare.outputs.sha \}\}/g) || []).length, 3);
  assert.match(workflow, /launch:\n    needs: \[prepare, build\]/);
  assert.match(workflow, /run: \.\/tools\/release-launch\.ps1 -Exe release-bin\/multiprompt-x64.exe/);
  assert.match(workflow, /gitleaks:\n    uses: \.\/\.github\/workflows\/gitleaks.yml/);
  assert.match(workflow, /release:\n    needs: \[prepare, build, launch, gitleaks\]/);
  assert.match(workflow, /concurrency:\n      group: release-publication\n      cancel-in-progress: false/);
  assert.match(workflow, /GH_TOKEN: \$\{\{ github.token \}\}/);
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /"tools\/version-stamp.test.mjs", "tools\/release-version.test.mjs"/);
  for (const step of ['test_step', 'vps_test_step']) assert(build.includes(`${step}.dependOn(&version_stamp_tests.step);`));
  assert(fs.readFileSync(path.join(root, 'tools/public_audit.py'), 'utf8').includes('tools/release-version.test.mjs'));
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.equal((tests.match(/node --test tools\/release-version.test.mjs/g) || []).length, 2);
});

test('release downloads exclude verification evidence from published update assets', t => {
  const f = fixture(t);
  const artifacts = new Map([
    ['multiprompt-x64', ['multiprompt-x64.exe', 'zigshell-bridge-x64.exe']],
    ['multiprompt-arm64', ['multiprompt-arm64.exe', 'zigshell-bridge-arm64.exe']],
    ['verify-tmux-binding', ['binding-name-reused-stderr.log', 'result.json']],
    ['verify-browser', ['journey.json', 'screenshot.png']],
  ]);
  const release = workflow.split('\n  release:\n')[1].split('\n  runner-sessions:\n')[0];
  const downloads = [...release.matchAll(/      - uses: actions\/download-artifact@[^\n]+\n        with:\n((?:          [^\n]+\n)+)/g)];
  assert.ok(downloads.length > 0, 'Release must download build artifacts');
  for (const [, inputs] of downloads) {
    const name = inputs.match(/^          name: (.+)$/m)?.[1];
    const destination = inputs.match(/^          path: (.+)$/m)?.[1];
    assert.equal(destination, 'dist');
    for (const [artifact, files] of artifacts) {
      if (name && artifact !== name) continue;
      const directory = path.join(f.dir, destination, !name && !inputs.includes('merge-multiple: true') ? artifact : '');
      fs.mkdirSync(directory, { recursive: true });
      for (const file of files) fs.writeFileSync(path.join(directory, file), '');
    }
  }
  const generated = ['multiprompt-extension.zip', 'release-notes.json', 'SHA256SUMS.txt', 'SHA256SUMS.txt.sig'];
  for (const file of generated) fs.writeFileSync(path.join(f.dir, 'dist', file), '');
  const result = f.run('Publish release');
  assert.equal(result.status, 0, result.stderr);
  const published = f.calls().find(args => args[0] === 'release' && args[1] === 'create');
  assert.ok(published, 'Release must publish');
  const assets = published.filter(arg => arg.startsWith('dist/')).map(arg => path.basename(arg));
  assert.deepEqual(assets.sort(), [...artifacts.get('multiprompt-x64'), ...artifacts.get('multiprompt-arm64'), ...generated].sort());
});

test('release builds both architectures independently of the report-only Tests workflow', () => {
  const jobs = Object.fromEntries([...workflow.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  assert.equal(jobs['pr-build'], undefined);
  assert.match(jobs.build, /needs: prepare/);
  assert.match(jobs.release, /needs: \[prepare, build, launch, gitleaks\]/);
  assert.doesNotMatch(jobs.release, /journeys|update-test|test-result/);
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(tests, /name: build-windows \(\$\{\{ matrix.arch \}\}\)\n    runs-on: ubuntu-latest\n/);
  assert.match(tests, /run: zig build -Dtarget=aarch64-windows-gnu/);
  assert.match(tests, /needs: \[test, test-vps, build-windows, test-windows-update, test-worker, test-update-source, check-red-run, switch-performance\]/);
  assert.match(tests, /BUILD: \$\{\{ needs\.build-windows\.result \}\}/);
});

test('aggregate routing requires every test job and rejects every unsuccessful dependency', () => {
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const aggregate = tests.split('\n  test-result:\n')[1];
  assert.match(aggregate, /needs: \[test, test-vps, build-windows, test-windows-update, test-worker, test-update-source, check-red-run, switch-performance\]/);
  for (const [variable, job] of Object.entries({ WINDOWS: 'test', VPS: 'test-vps', BUILD: 'build-windows', UPDATE: 'test-windows-update', WORKER: 'test-worker', UPDATE_SOURCE: 'test-update-source', RED_RUN: 'check-red-run', SPEED: 'switch-performance' })) {
    assert.ok(aggregate.includes(`${variable}: $` + `{{ needs.${job}.result }}`));
  }
  assert.match(aggregate, /for result in "\$@"; do\n              \[ "\$result" = success \] \|\| return 1/);
  assert.match(aggregate, /for result in failure cancelled skipped; do/);
  assert.match(aggregate, /require_jobs "\$WINDOWS" "\$VPS" "\$BUILD" "\$UPDATE" "\$WORKER" "\$UPDATE_SOURCE" "\$RED_RUN"/);
  assert.doesNotMatch(aggregate, /CHANGES|HEAVY|needs\.changes/);
  const script = aggregate.split('        run: |\n')[1].split('\n').map(line => line.slice(10)).join('\n');
  const success = { WINDOWS: 'success', VPS: 'success', BUILD: 'success', UPDATE: 'success', WORKER: 'success', UPDATE_SOURCE: 'success', RED_RUN: 'success', SPEED: 'success' };
  const run = env => spawnSync('bash', ['-e', '-c', script], { encoding: 'utf8', env: { ...process.env, ...success, ...env } });
  const result = run({});
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Aggregate routing controls passed/);
  for (const job of Object.keys(success)) {
    for (const status of ['failure', 'cancelled', 'skipped', 'invalid', '']) assert.equal(run({ [job]: status }).status, 1, `${job}: ${status}`);
  }
});

test('five Windows and three VPS jobs retain the upstream test graph with independent Worker checks', () => {
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  const matrices = [...tests.matchAll(/^        group: \[([^\]]+)\]$/gm)].map(match => match[1].split(',').map(value => Number(value.trim())));
  assert.deepEqual(matrices, [[1, 2, 3, 4, 5], [1, 2, 3]]);
  assert.deepEqual([...build.matchAll(/b.step\("test-group-(\d+)"/g)].map(match => Number(match[1])), matrices[0]);
  assert.deepEqual([...build.matchAll(/b.step\("test-vps-group-(\d+)"/g)].map(match => Number(match[1])), matrices[1]);
  for (const [option, count, array] of [['test-group', 5, 'test_groups'], ['test-vps-group', 3, 'vps_groups']]) {
    assert.ok(build.includes(`"Run one ${array === 'test_groups' ? 'desktop' : 'server'} test group (1-${count})"`));
    assert.ok(build.includes(`if (group < 1 or group > ${array}.len) @panic("${option} must be between 1 and ${count}")`));
    assert.ok(build.includes(`for (${array}) |group| ${array === 'test_groups' ? 'test_step' : 'vps_test_step'}.dependOn(group)`));
  }
  assert.match(tests, /run: zig build test --summary all -Dtest-group=\$\{\{ matrix.group \}\}/);
  assert.match(tests, /run: zig build test-vps --summary all -Dtest-vps-group=\$\{\{ matrix.group \}\}/);
  const vps = tests.split('\n  test-vps:\n')[1].split(/\n  [\w-]+:\n/)[0];
  const worker = tests.split('\n  test-worker:\n')[1].split(/\n  [\w-]+:\n/)[0];
  assert.doesNotMatch(vps, /Build the account Worker|Run account Worker tests|cache: npm/);
  assert.match(worker, /runs-on: ubuntu-latest\n    timeout-minutes: 10/);
  assert.match(worker, /actions\/checkout@[a-f0-9]{40}\n        with:\n          fetch-depth: 0/);
  assert.match(worker, /actions\/setup-node@[a-f0-9]{40}\n        if: steps\.paths\.outputs\.heavy == 'true'\n        with:\n          node-version: 22\n          cache: npm\n          cache-dependency-path: service\/package-lock.json/);
  assert.match(worker, /name: Build the account Worker\n        if: steps\.paths\.outputs\.heavy == 'true' && steps\.rule\.outputs\.kind != 'STAMP'\n        working-directory: service\n        timeout-minutes: 2\n        run: npm ci --no-audit --no-fund --prefer-offline && npx wrangler deploy --dry-run --outdir .build/);
  assert.match(worker, /name: Run account Worker tests\n        if: steps\.paths\.outputs\.heavy == 'true' && steps\.rule\.outputs\.kind != 'STAMP'\n        run: node --test service\/test\/infra.test.js service\/test\/worker.test.js/);
  for (const name of ['Restore Zig toolchain (PR)', 'Cache Zig toolchain', 'Install Zig 0.16.0']) {
    const step = vps.split(/(?=^      - )/m).find(step => step.startsWith(`      - name: ${name}\n`));
    assert.ok(step);
    assert.ok(worker.includes(step));
  }
  assert.ok(worker.indexOf('name: Install Zig') < worker.indexOf('name: Run account Worker tests'));
  assert.doesNotMatch(worker, /zig build|ZIG_GLOBAL_CACHE_DIR|\.zig-cache|matrix:/);
  assert.match(build, /const zsb_help_tests = b.addSystemCommand\(&\.\{ "node", "--test", "tools\/zsb-help.test.js" \}\)/);
  assert.match(build, /zsb_help_tests.step.dependOn\(&bridge_install.step\)/);
  assert.match(build, /test_step.dependOn\(&zsb_help_tests.step\)/);
});

test('gitleaks scans every push while other checks run manually or nightly', () => {
  const scan = fs.readFileSync(path.join(root, '.github/workflows/gitleaks.yml'), 'utf8');
  assert.match(scan, /^  push:\n  pull_request:/m);
  assert.match(scan, /^  schedule:/m);
  assert.match(scan, /^  workflow_dispatch:/m);
  assert.match(scan, /^  workflow_call:/m);
  for (const file of ['no-comments', 'docs-site', 'verify']) {
    const text = fs.readFileSync(path.join(root, `.github/workflows/${file}.yml`), 'utf8');
    const events = text.split('\non:\n')[1].split(/\n(?:permissions|concurrency|jobs):/)[0];
    assert.match(events, /^  workflow_dispatch:/m, file);
    assert.match(events, /^  schedule:/m, file);
    assert.doesNotMatch(events, /^  (?:push|pull_request|workflow_run):/m, file);
  }
});

test('one lightweight workflow preserves both check names and checker suites', () => {
  const checks = fs.readFileSync(path.join(root, '.github/workflows/no-comments.yml'), 'utf8');
  assert.match(checks, /^  workflow_dispatch:/m);
  assert.match(checks, /^  schedule:/m);
  for (const name of ['no-comments', 'extension-version']) assert.match(checks, new RegExp(`^    name: ${name}$`, 'm'));
  for (const command of [
    'node --test tools/strip-comments.test.js',
    'node tools/strip-comments.mjs --check',
    'node --test tools/check-extension-version.test.js',
    'node tools/check-extension-version.mjs origin/${{ github.base_ref }}',
  ]) assert(checks.includes(command), command);
  assert(!fs.existsSync(path.join(root, '.github/workflows/extension-version.yml')));
});

for (const event of ['push', 'workflow_dispatch']) {
  test(`workflow resolves ${event} version from the built commit`, { skip: process.platform === 'win32' }, t => {
    const f = fixture(t);
    const result = f.run('Resolve release version and commit', { GITHUB_EVENT_NAME: event, REQUESTED_TAG: event === 'workflow_dispatch' ? tag : '' });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), `tag=${tag}\nsha=${f.sha}\n`);
  });
}

test('dispatch of an existing tag builds its commit rather than the dispatch branch', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  f.git('tag', tag);
  fs.writeFileSync(path.join(f.dir, 'src/changelog.zig'), '.ver = "1.2.4"\n');
  f.git('commit', '-am', 'new version');
  const result = f.run('Resolve release version and commit', { GITHUB_EVENT_NAME: 'workflow_dispatch', REQUESTED_TAG: tag });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), `tag=${tag}\nsha=${f.sha}\n`);
});

test('remote requested tag overrides a conflicting local tag and keeps its commit through publication', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  const tagged = f.git('rev-parse', 'v1.2.2^{commit}');
  f.git('--git-dir', f.remote, 'update-ref', `refs/tags/${tag}`, tagged);
  f.git('tag', tag, f.sha);
  const result = f.run('Resolve release version and commit', { REQUESTED_TAG: tag, GITHUB_EVENT_NAME: 'workflow_dispatch' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), `tag=${tag}\nsha=${tagged}\n`);
  assert.equal(f.git('rev-parse', `${tag}^{commit}`), tagged);
  const published = f.run('Publish release', { BUILT_SHA: tagged });
  assert.equal(published.status, 0, published.stderr);
  const create = f.calls().find(args => args[1] === 'create');
  assert.equal(create[create.indexOf('--target') + 1], tagged);
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', `${tag}^{commit}`), tagged);
});

test('a missing requested tag uses HEAD, but a remote lookup failure fails closed', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  const result = f.run('Resolve release version and commit', { REQUESTED_TAG: tag });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), `tag=${tag}\nsha=${f.sha}\n`);
  f.git('remote', 'set-url', 'origin', path.join(f.dir, 'missing.git'));
  assert.notEqual(f.run('Resolve release version and commit', { REQUESTED_TAG: tag }).status, 0);
});

test('automatic version uses first-parent distance and rejects invalid history or latest reads', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  f.git('commit', '--allow-empty', '-m', 'second candidate');
  const sha = f.git('rev-parse', 'HEAD');
  const result = f.run('Resolve release version and commit');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), `tag=v1.2.4\nsha=${sha}\n`);
  for (const env of [{ LATEST_READ_FAIL: '1' }, { PUBLISHED_TAG: 'bad' }, { PUBLISHED_TAG: 'v9.9.9' }]) {
    assert.notEqual(f.run('Resolve release version and commit', env).status, 0);
  }
  f.git('tag', 'v1.2.4');
  assert.notEqual(f.run('Resolve release version and commit', { PUBLISHED_TAG: 'v1.2.4' }).status, 0);
});

test('master publication is latest, targets built SHA and refuses duplicate releases', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  const first = f.run('Publish release');
  assert.equal(first.status, 0, first.stderr);
  const create = f.calls().find(args => args[1] === 'create');
  assert(create);
  assert.equal(create[2], tag);
  assert.equal(create[create.indexOf('--target') + 1], f.sha);
  assert.equal(create[create.indexOf('--title') + 1], `multiprompt ${tag}`);
  assert(create.includes('--latest=true'));
  assert(create.includes('--generate-notes'));
  const second = f.run('Publish release');
  assert.notEqual(second.status, 0);
  assert.match(second.stderr, /already exists; refusing publication/);
  assert.equal(f.calls().filter(args => args[1] === 'create').length, 1);
});

for (const event of ['push', 'workflow_dispatch']) {
  test(`${event} publishes an existing matching tag but refuses a duplicate release`, { skip: process.platform === 'win32' }, t => {
    const f = fixture(t);
    f.git('--git-dir', f.remote, 'update-ref', `refs/tags/${tag}`, f.sha);
    const env = { GITHUB_EVENT_NAME: event, GITHUB_REF: `refs/tags/${tag}` };
    assert.equal(f.run('Publish release', env).status, 0);
    assert.notEqual(f.run('Publish release', { ...env, RELEASE_EXISTS: '1' }).status, 0);
    assert.equal(f.calls().filter(args => args[1] === 'create').length, 1);
  });
}

test('latest lookup and publication failures do not create a release', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  assert.notEqual(f.run('Publish release', { LATEST_READ_FAIL: '1' }).status, 0);
  assert.equal(f.calls().filter(args => args[1] === 'create').length, 0);
  assert.notEqual(f.run('Publish release', { GH_CREATE_FAIL: '1' }).status, 0);
  assert.equal(fs.existsSync(path.join(f.dir, 'release-state.json')), false);
});

test('packaging includes extension contents, excludes current themes and covers every asset', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  fs.mkdirSync(path.join(f.dir, 'dist'));
  fs.writeFileSync(path.join(f.dir, 'src/changelog.zig'), '.{ .ver = "1.2.3", .items = &.{\n        .{ .text = "Updates show what changed.", .ticket = "IGSH-728" },\n    } },\n');
  execFileSync(process.execPath, [path.join(root, 'tools/release-notes.mjs'), 'src/changelog.zig', tag, 'dist/release-notes.json'], { cwd: f.dir });
  fs.mkdirSync(path.join(f.dir, 'extension/themes/current'), { recursive: true });
  fs.writeFileSync(path.join(f.dir, 'extension/themes/current/private.txt'), 'excluded');
  fs.writeFileSync(path.join(f.dir, 'extension/themes/kept.json'), '{}');
  fs.writeFileSync(path.join(f.dir, 'extension/manifest.json'), '{}');
  fs.writeFileSync(path.join(f.dir, 'extension/.included'), 'included');
  for (const name of ['multiprompt-x64.exe', 'multiprompt-arm64.exe', 'zigshell-bridge-x64.exe', 'zigshell-bridge-arm64.exe']) fs.writeFileSync(path.join(f.dir, 'dist', name), name);
  const result = f.run('Package extension and checksums');
  assert.equal(result.status, 0, result.stderr);
  const entries = execFileSync('unzip', ['-Z1', 'dist/multiprompt-extension.zip'], { cwd: f.dir, encoding: 'utf8' });
  assert.match(entries, /manifest.json/);
  assert.match(entries, /\.included/);
  assert.match(entries, /themes\/kept.json/);
  assert.doesNotMatch(entries, /themes\/current/);
  const sums = fs.readFileSync(path.join(f.dir, 'dist/SHA256SUMS.txt'), 'utf8');
  assert.equal(sums.trim().split('\n').length, 6);
  assert.match(sums, /^[a-f0-9]{64}  release-notes\.json$/m);
  execFileSync('sha256sum', ['-c', 'SHA256SUMS.txt'], { cwd: path.join(f.dir, 'dist') });
});

test('automatic admission fixtures reject unsafe heads', { skip: process.platform === 'win32' }, () => {
  const result = spawnSync('bash', ['tools/automerge-admit.test.sh'], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /ADMISSION VERIFIED/);
});

test('automatic release invokes the signed release workflow for master without test admission', () => {
  const auto = fs.readFileSync(path.join(root, '.github/workflows/auto-release.yml'), 'utf8');
  assert.match(auto, /push:\n    branches: \[master\]/);
  assert.match(auto, /if: github.ref == 'refs\/heads\/master'/);
  assert.match(auto, /uses: \.\/\.github\/workflows\/release.yml/);
  assert.doesNotMatch(auto, /workflow_run|schedule:|auto-release-admit|gh pr create|gh release create/);
  assert.deepEqual([...auto.matchAll(/secrets\.(\w+)/g)].map(match => match[1]), ['MULTIPROMPT_RELEASE_SIGNING_KEY']);
});

test('next release increments the latest tag rather than the source version', () => {
  assert.equal(nextReleaseTag('v0.28.869'), 'v0.28.870');
  assert.equal(nextReleaseTag('v1.9.999'), 'v1.9.1000');
  assert.equal(nextReleaseTag('v1.2.9007199254740993'), 'v1.2.9007199254740994');
  for (const previous of ['', '1.2.3', 'v01.2.3', 'v1.2', 'v1.2.3-beta', 'v1.2.3\n', 'v1.2.3;bad']) assert.throws(() => nextReleaseTag(previous), /Invalid previous release tag/);
  const cli = spawnSync(process.execPath, [path.join(root, 'tools/release-version.mjs'), '--next', 'v1.2.8'], { encoding: 'utf8' });
  assert.equal(cli.status, 0, cli.stderr);
  assert.equal(cli.stdout.trim(), 'v1.2.9');
});

test('release resolves a build-input tag even when source history has an older version', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  f.git('tag', 'v1.2.9');
  const result = f.run('Resolve release version and commit', { REQUESTED_TAG: 'v1.2.9' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), `tag=v1.2.9\nsha=${f.sha}\n`);
  for (const requested of ['1.2.9', 'v01.2.9', 'v1.2.9;bad', 'v1.2.9\nother']) assert.notEqual(f.run('Resolve release version and commit', { REQUESTED_TAG: requested }).status, 0);
});

test('release builds inject the tag, stage matching notes and reject wrong embedded versions', { skip: process.platform === 'win32' }, t => {
  const build = script('Build');
  assert.match(build, /node tools\/version-stamp\.mjs build "\$TAG"/);
  assert.match(build, /zig build -Dtarget=\$\{\{ matrix.target \}\} -Drelease=\$\{\{ github.event_name != 'pull_request' \}\} -Dversion="\$\{TAG#v\}"/);
  assert.match(script('Publish plain versioned update notes'), /node tools\/version-stamp\.mjs build "\$TAG"\nnode tools\/release-notes\.mjs/);
  const check = build.match(/<<'NODE'\n([\s\S]*?)\nNODE/)[1];
  const f = fixture(t);
  fs.mkdirSync(path.join(f.dir, 'zig-out/bin'), { recursive: true });
  for (const [bytes, accepted] of [['junk MPVERSION=1.2.9; tail', true], ['MPVERSION=1.2.3;', false], ['', false], ['MPVERSION=1.2.9;MPVERSION=1.2.3;', false]]) {
    fs.writeFileSync(path.join(f.dir, 'zig-out/bin/multiprompt.exe'), bytes);
    const result = spawnSync(process.execPath, ['--input-type=module', '-', 'v1.2.9'], { input: check, cwd: f.dir, encoding: 'utf8' });
    assert.equal(result.status === 0, accepted, result.stderr);
  }
});

test('auto-release creates only a tag ref on the tested commit under a branch-rejecting remote', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  f.git('tag', 'v1.2.8');
  fs.mkdirSync(path.join(f.dir, 'changelog.d'));
  fs.writeFileSync(path.join(f.dir, 'changelog.d/DEMO-1-chat.md'), 'Your chats keep their saved order.\n');
  f.git('add', 'changelog.d');
  f.git('commit', '-m', 'tested improvement');
  const tested = f.git('rev-parse', 'HEAD');
  f.git('push', 'origin', 'master');
  fs.writeFileSync(path.join(f.remote, 'hooks/update'), '#!/bin/sh\ncase "$1" in refs/heads/*) exit 1;; esac\n', { mode: 0o755 });
  const result = f.admit();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `tag=v1.2.9\nsha=${tested}\n`);
  assert.equal(f.git('rev-parse', 'HEAD'), tested);
  assert.equal(f.git('diff', 'HEAD', '--', 'src', 'changelog.d'), '');
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'master'), tested);
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'v1.2.9'), tested);
  assert.deepEqual(f.calls(), [
    ['api', 'repos/example/multiprompt/releases/latest', '--jq', '.tag_name'],
    ['run', 'list', '-R', 'example/multiprompt', '-w', 'test.yml', '-b', 'master', '--commit', tested, '--limit', '100', '--json', 'databaseId,event,status,conclusion'],
    ['run', 'list', '-R', 'example/multiprompt', '-w', 'release-gate.yml', '-b', 'master', '--commit', tested, '--limit', '100', '--json', 'databaseId,event,status,conclusion'],
    ['run', 'list', '-R', 'example/multiprompt', '-w', 'verify.yml', '-b', 'master', '--commit', tested, '--limit', '100', '--json', 'databaseId,event,status,conclusion'],
    ['run', 'view', '700', '-R', 'example/multiprompt', '--json', 'jobs'],
    ['api', '-X', 'POST', 'repos/example/multiprompt/git/refs', '-f', 'ref=refs/tags/v1.2.9', '-f', `sha=${tested}`],
  ]);
  f.git('fetch', '--tags', 'origin');
  const retry = f.admit();
  assert.equal(retry.status, 0, retry.stderr);
  assert.equal(retry.stdout, `tag=v1.2.9\nsha=${tested}\n`);
  const second = f.admit({ PUBLISHED_TAG: 'v1.2.9' });
  assert.equal(second.status, 0, second.stderr);
  assert.equal(second.stdout, '');
});

for (const reason of ['skip', 'red', 'green']) test(`auto-release admission: ${reason}`, { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  f.git('tag', 'v1.2.8');
  fs.mkdirSync(path.join(f.dir, 'changelog.d'));
  fs.writeFileSync(path.join(f.dir, 'changelog.d/DEMO-1-chat.md'), 'Your chats keep their saved order.\n');
  f.git('add', 'changelog.d');
  f.git('commit', '-m', reason === 'skip' ? 'maintenance [skip release]' : 'release candidate');
  const tested = f.git('rev-parse', 'HEAD');
  f.git('push', 'origin', 'master');
  const result = f.admit({ TEST_CONCLUSION: reason === 'red' ? 'failure' : 'success' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, reason === 'green' ? `tag=v1.2.9\nsha=${tested}\n` : '');
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'master'), tested);
  if (reason === 'green') {
    assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'v1.2.9'), tested);
  } else {
    assert.equal(f.git('tag', '--list', 'v1.2.9'), '');
    assert.equal(f.git('--git-dir', f.remote, 'tag', '--list', 'v1.2.9'), '');
  }
});


test('release builds authenticate history reads and publish versioned notes', () => {
  const build = workflow.split('\n  build:\n')[1].split('\n  launch:\n')[0];
  const release = workflow.split('\n  release:\n')[1];
  assert.match(build, /GH_TOKEN: \$\{\{ github\.token \}\}/);
  const notes = release.split('      - name: Publish plain versioned update notes\n')[1].split('      - name: Package extension')[0];
  assert.match(notes, /GH_TOKEN: \$\{\{ github\.token \}\}/);
  assert.match(notes, /node tools\/release-notes\.mjs src\/changelog\.zig "\$TAG" dist\/release-notes\.json/);
});

for (const [published, candidate, latest] of [
  ['v0.28.999', 'v0.28.995', false],
  ['v0.28.999', 'v0.28.1000', true],
  ['v0.29.0', 'v0.28.1000', false],
  ['v1.0.0', 'v0.99.999', false],
  ['v0.28.999', 'v0.28.999', false],
  ['v1.2.9007199254740993', 'v1.2.9007199254740994', true],
]) test(`publication preserves forward-only latest: ${published} then ${candidate}`, { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  const result = f.run('Publish release', { PUBLISHED_TAG: published, TAG: candidate, GITHUB_EVENT_NAME: 'workflow_dispatch' });
  assert.equal(result.status, 0, result.stderr);
  const create = f.calls().find(args => args[1] === 'create');
  assert.ok(create, 'Older releases must still be published for history');
  assert.equal(create[2], candidate);
  assert.ok(create.includes(`--latest=${latest}`), JSON.stringify(create));
  assert.equal(f.calls().filter(args => args[0] === 'api' && args[1].endsWith('/releases/latest')).length, 1);
});

for (const published of ['', 'unknown', 'v1.2', 'v1.2.3-beta']) test(`publication rejects unreadable latest version: ${published}`, { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  const result = f.run('Publish release', { PUBLISHED_TAG: published || 'unknown', GITHUB_EVENT_NAME: 'workflow_dispatch' });
  assert.notEqual(result.status, 0);
  assert.equal(f.calls().filter(args => args[1] === 'create').length, 0);
});

test('finishing an older release retains both downloads and the newer desktop feed', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  for (const candidate of ['v0.28.999', 'v0.28.995']) {
    const result = f.run('Publish release', { TAG: candidate, PUBLISHED_TAG: 'v0.28.994', GITHUB_EVENT_NAME: 'workflow_dispatch' });
    assert.equal(result.status, 0, result.stderr);
  }
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(f.dir, 'release-state.json'), 'utf8')), {
    latest: 'v0.28.999', releases: ['v0.28.999', 'v0.28.995'],
  });
});

test('latest-feed read failures cannot replace the desktop update', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  const result = f.run('Publish release', { LATEST_READ_FAIL: '1', GITHUB_EVENT_NAME: 'workflow_dispatch' });
  assert.notEqual(result.status, 0);
  assert.equal(f.calls().filter(args => args[1] === 'create').length, 0);
});


test('manual release uses the same source-bound publisher', () => {
  assert.match(workflow, /workflow_dispatch:/);
  const release = workflow.split('\n  release:\n')[1];
  assert.match(release, /ref: \$\{\{ needs.prepare.outputs.sha \}\}/);
  assert.match(release, /BUILT_SHA: \$\{\{ needs.prepare.outputs.sha \}\}/);
  assert.match(release, /--target "\$BUILT_SHA"/);
});
