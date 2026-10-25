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
const auto = fs.readFileSync(path.join(root, '.github/workflows/auto-release.yml'), 'utf8');
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
  for (const file of ['release-version.mjs', 'version-stamp.mjs']) fs.copyFileSync(path.join(root, 'tools', file), path.join(dir, 'tools', file));
  fs.writeFileSync(path.join(dir, 'src/main.zig'), 'pub const APP_VERSION = build_config.app_version orelse "1.2.3";\n');
  git('add', '.');
  git('commit', '-m', 'fixture');
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
if (args[0] === 'run') { console.log(JSON.stringify([{ databaseId: 1, event: 'push', status: 'completed', conclusion: process.env.TEST_CONCLUSION || 'success' }])); process.exit(0); }
if (args[1] === 'view') process.exit(process.env.RELEASE_EXISTS === '1' ? 0 : 1);
if (args[1] !== 'create') process.exit(2);
execFileSync('git', ['--git-dir', process.env.TEST_REMOTE, 'update-ref', 'refs/tags/' + args[2], process.env.BUILT_SHA]);
`, { mode: 0o755 });
  return { dir, git, sha, remote, log,
    run: (name, env = {}, source = workflow) => spawnSync('bash', ['-euo', 'pipefail', '-c', script(name, source)], { cwd: dir, encoding: 'utf8',
      env: { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, GITHUB_EVENT_NAME: 'push', GITHUB_REF: 'refs/heads/master', GITHUB_REPOSITORY: 'example/multiprompt',
        TAG: tag, BUILT_SHA: sha, REQUESTED_TAG: '', RUNNER_TEMP: dir, GITHUB_OUTPUT: path.join(dir, 'output'), GH_LOG: log, TEST_REMOTE: remote, ...env } }),
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

test('workflow preserves tag and manual triggers with reusable release, both architectures, immutable builds and version concurrency', () => {
  assert.match(workflow, /push:\n    tags: \['v\*'\]/);
  assert.doesNotMatch(workflow, /branches: \[master\]/);
  assert.match(workflow, /workflow_call:[\s\S]*tag:[\s\S]*type: string/);
  assert.doesNotMatch(workflow, /pull_request:/);
  assert.match(workflow, /workflow_dispatch:[\s\S]*tag:[\s\S]*required: true/);
  assert.match(workflow, /permissions:\n  contents: write/);
  assert.doesNotMatch(workflow, /--draft/);
  assert.deepEqual([...workflow.matchAll(/secrets\.(\w+)/g)].map(match => match[1]), ['MULTIPROMPT_RELEASE_SIGNING_KEY']);
  assert.match(workflow, /run: node tools\/sign-release\.mjs/);
  assert.match(workflow, /arch: x64\n            target: x86_64-windows-gnu/);
  assert.match(workflow, /arch: arm64\n            target: aarch64-windows-gnu/);
  assert.match(workflow, /if: github.event_name != 'pull_request'/);
  assert.equal((workflow.match(/ref: \$\{\{ needs.prepare.outputs.sha \}\}/g) || []).length, 2);
  assert.match(workflow, /concurrency:\n      group: release-\$\{\{ needs.prepare.outputs.tag \}\}\n      cancel-in-progress: false/);
  assert.match(workflow, /GH_TOKEN: \$\{\{ github.token \}\}/);
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /"tools\/version-stamp.test.mjs", "tools\/release-version.test.mjs"/);
  for (const step of ['test_step', 'vps_test_step']) assert(build.includes(`${step}.dependOn(&version_stamp_tests.step);`));
  assert(fs.readFileSync(path.join(root, 'tools/public_audit.py'), 'utf8').includes('tools/release-version.test.mjs'));
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.equal((tests.match(/node --test tools\/release-version.test.mjs/g) || []).length, 2);
});

test('PR arm64 coverage is path-gated in Tests, not the publishing workflow', () => {
  const jobs = Object.fromEntries([...workflow.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  assert.equal(jobs['pr-build'], undefined);
  assert.match(jobs.prepare, /if: github.event_name != 'pull_request'/);
  assert.match(jobs.build, /needs: prepare/);
  assert.match(jobs.release, /needs: \[prepare, build\]/);
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  assert.match(tests, /name: build-windows \(\$\{\{ matrix.arch \}\}\)\n    runs-on: ubuntu-latest\n/);
  assert.match(tests, /run: zig build -Dtarget=aarch64-windows-gnu/);
  assert.match(tests, /needs: \[test, test-vps, build-windows, test-windows-update, test-worker, test-update-source\]/);
  assert.match(tests, /BUILD: \$\{\{ needs\.build-windows\.result \}\}/);
});

test('aggregate routing requires every test job and rejects every unsuccessful dependency', () => {
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const aggregate = tests.split('\n  test-result:\n')[1];
  assert.match(aggregate, /needs: \[test, test-vps, build-windows, test-windows-update, test-worker, test-update-source\]/);
  for (const [variable, job] of Object.entries({ WINDOWS: 'test', VPS: 'test-vps', BUILD: 'build-windows', UPDATE: 'test-windows-update', WORKER: 'test-worker', UPDATE_SOURCE: 'test-update-source' })) {
    assert.ok(aggregate.includes(`${variable}: $` + `{{ needs.${job}.result }}`));
  }
  assert.match(aggregate, /for result in "\$@"; do\n              \[ "\$result" = success \] \|\| return 1/);
  assert.match(aggregate, /for result in failure cancelled skipped; do/);
  assert.match(aggregate, /require_jobs "\$WINDOWS" "\$VPS" "\$BUILD" "\$UPDATE" "\$WORKER" "\$UPDATE_SOURCE"/);
  assert.doesNotMatch(aggregate, /CHANGES|HEAVY|needs\.changes/);
  const script = aggregate.split('        run: |\n')[1].split('\n').map(line => line.slice(10)).join('\n');
  const success = { WINDOWS: 'success', VPS: 'success', BUILD: 'success', UPDATE: 'success', WORKER: 'success', UPDATE_SOURCE: 'success' };
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

test('lightweight workflows cancel superseded PRs but never master pushes or dispatches', () => {
  for (const file of ['gitleaks', 'no-comments', 'docs-site', 'verify']) {
    const text = fs.readFileSync(path.join(root, `.github/workflows/${file}.yml`), 'utf8');
    assert.match(text, /^  pull_request:/m, file);
    assert.match(text, file === 'verify'
      ? /^concurrency:\n  group: \$\{\{ github\.workflow \}\}-\$\{\{ github\.ref \}\}\$\{\{ github\.event_name == 'workflow_dispatch' && format\('-\{0\}-\{1\}', inputs\.feature, inputs\.tag\) \|\| '' \}\}\n  cancel-in-progress: \$\{\{ github\.event_name == 'pull_request' \}\}$/m
      : /^concurrency:\n  group: \$\{\{ github.workflow \}\}-\$\{\{ github.ref \}\}\n  cancel-in-progress: \$\{\{ github.event_name == 'pull_request' \}\}/m, file);
  }
  const scan = fs.readFileSync(path.join(root, '.github/workflows/gitleaks.yml'), 'utf8');
  assert.match(scan, /^  push:\n    branches: \[master\]\n  pull_request:/m);
  assert.match(scan, /^  schedule:/m);
  assert.match(scan, /^  workflow_dispatch:/m);
});

test('one lightweight workflow preserves both check names and checker suites', () => {
  const checks = fs.readFileSync(path.join(root, '.github/workflows/no-comments.yml'), 'utf8');
  assert.match(checks, /^  push:\n    branches: \[master\]/m);
  for (const name of ['no-comments', 'extension-version']) assert.match(checks, new RegExp(`^    name: ${name}$`, 'm'));
  for (const command of [
    'node --test tools/strip-comments.test.js',
    'node tools/strip-comments.mjs --check',
    'node --test tools/check-extension-version.test.js',
    'node tools/check-extension-version.mjs origin/${{ github.base_ref }}',
  ]) assert(checks.includes(command), command);
  assert(!fs.existsSync(path.join(root, '.github/workflows/extension-version.yml')));
});

for (const event of ['push', 'pull_request', 'workflow_dispatch']) {
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

test('master publication is latest, targets built SHA and skips a competing remote tag', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  const first = f.run('Publish release');
  assert.equal(first.status, 0, first.stderr);
  const create = f.calls().find(args => args[1] === 'create');
  assert(create);
  assert.equal(create[2], tag);
  assert.equal(create[create.indexOf('--target') + 1], f.sha);
  assert.equal(create[create.indexOf('--title') + 1], `multiprompt ${tag}`);
  assert(create.includes('--latest'));
  assert(create.includes('--generate-notes'));
  const second = f.run('Publish release');
  assert.equal(second.status, 0, second.stderr);
  assert.match(second.stdout, /already exists; skipping publication/);
  assert.equal(f.calls().filter(args => args[1] === 'create').length, 1);
});

for (const event of ['push', 'workflow_dispatch']) {
  test(`${event} can publish an existing tag without duplicating an existing release`, { skip: process.platform === 'win32' }, t => {
    const f = fixture(t);
    f.git('--git-dir', f.remote, 'update-ref', `refs/tags/${tag}`, f.sha);
    const env = { GITHUB_EVENT_NAME: event, GITHUB_REF: `refs/tags/${tag}` };
    assert.equal(f.run('Publish release', env).status, 0);
    assert.equal(f.run('Publish release', { ...env, RELEASE_EXISTS: '1' }).status, 0);
    assert.equal(f.calls().filter(args => args[1] === 'create').length, 1);
  });
}

test('master remote failures do not publish', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  f.git('remote', 'set-url', 'origin', path.join(f.dir, 'missing.git'));
  assert.notEqual(f.run('Publish release').status, 0);
  assert.deepEqual(f.calls(), []);
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

test('automatic release admission fixtures', { skip: process.platform === 'win32' }, () => {
  const result = spawnSync(process.execPath, ['--test', 'tools/auto-release-admit.test.js'], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('automatic release only tags a tested master and reuses signed release jobs', () => {
  const auto = fs.readFileSync(path.join(root, '.github/workflows/auto-release.yml'), 'utf8');
  assert.match(auto, /workflows: \[Tests\]/);
  assert.match(auto, /branches: \[master\]/);
  assert.match(auto, /github.event.workflow_run.conclusion == 'success'/);
  assert.match(auto, /github.event.workflow_run.head_repository.full_name == github.repository/);
  assert.match(auto, /cron: '\*\/30 \* \* \* \*'/);
  assert.match(auto, /github.event_name == 'schedule'/);
  assert.match(auto, /ref: master/);
  assert.match(auto, /fetch-depth: 0/);
  assert.match(auto, /fetch-tags: true/);
  assert.match(auto, /bash tools\/auto-release-admit\.sh >> "\$GITHUB_OUTPUT"/);
  const admit = fs.readFileSync(path.join(root, 'tools/auto-release-admit.sh'), 'utf8');
  assert.match(admit, /node tools\/release-version\.mjs --next "\$\(git describe --tags --abbrev=0 "\$sha"\)"/);
  assert.match(admit, /git tag "\$release_tag" "\$sha"/);
  assert.deepEqual(admit.split('\n').filter(line => /\bgit push\b/.test(line)).map(line => line.trim()), ['git push origin "refs/tags/$release_tag" >&2']);
  assert.doesNotMatch(auto, /git (?:commit|add|config)|stampTree|fs\.(?:writeFileSync|unlinkSync)|HEAD:refs\/heads\/master/);
  assert.match(auto, /uses: \.\/\.github\/workflows\/release.yml/);
  assert.doesNotMatch(auto, /zig build|gh pr create|gh release create/);
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

test('auto-release pushes only a tag on the tested commit under a branch-rejecting remote', { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  f.git('tag', 'v1.2.8');
  f.git('commit', '--allow-empty', '-m', 'tested improvement');
  const tested = f.git('rev-parse', 'HEAD');
  f.git('push', 'origin', 'master');
  fs.writeFileSync(path.join(f.remote, 'hooks/update'), '#!/bin/sh\ncase "$1" in refs/heads/*) exit 1;; esac\n', { mode: 0o755 });
  const env = { GITHUB_EVENT_NAME: 'workflow_run', TESTED_SHA: tested };
  const admitted = f.run('Require a tested unreleased master head', env, auto);
  assert.equal(admitted.status, 0, admitted.stderr);
  assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), 'ready=true\n');
  const result = f.run('Tag the tested master commit', env, auto);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(f.git('rev-parse', 'HEAD'), tested);
  assert.equal(f.git('diff', 'HEAD', '--', 'src', 'changelog.d'), '');
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'master'), tested);
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'v1.2.9'), tested);
  assert.match(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), /tag=v1.2.9\n/);
  fs.unlinkSync(path.join(f.dir, 'output'));
  assert.equal(f.run('Require a tested unreleased master head', env, auto).status, 0);
  assert.equal(fs.existsSync(path.join(f.dir, 'output')), false);
});

for (const reason of ['stale', 'skip', 'untested-dispatch', 'tested-dispatch']) test(`auto-release admission: ${reason}`, { skip: process.platform === 'win32' }, t => {
  const f = fixture(t);
  if (reason === 'skip') f.git('commit', '--allow-empty', '-m', 'maintenance [skip release]');
  const result = f.run('Require a tested unreleased master head', {
    GITHUB_EVENT_NAME: reason.endsWith('dispatch') ? 'workflow_dispatch' : 'workflow_run',
    TESTED_SHA: reason === 'stale' ? '0'.repeat(40) : f.git('rev-parse', 'HEAD'),
    TEST_CONCLUSION: reason === 'untested-dispatch' ? 'failure' : 'success',
  }, auto);
  assert.equal(result.status, reason === 'untested-dispatch' ? 1 : 0, result.stderr);
  assert.equal(fs.existsSync(path.join(f.dir, 'output')), reason === 'tested-dispatch');
});
