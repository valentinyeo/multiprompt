import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { releaseVersion } from './release-version.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const workflow = fs.readFileSync(path.join(root, '.github/workflows/release.yml'), 'utf8');
const tag = 'v1.2.3';
const changelog = '.{ .ver = "1.2.3" },\n.{ .ver = "1.2.2" },\n';
const script = name => {
  const block = workflow.match(new RegExp(`      - name: ${name}\\n[\\s\\S]*?        run: \\|\\n((?:          [^\\n]*\\n|\\n)+)`));
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
  fs.copyFileSync(path.join(root, 'tools/release-version.mjs'), path.join(dir, 'tools/release-version.mjs'));
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
if (args[1] === 'view') process.exit(process.env.RELEASE_EXISTS === '1' ? 0 : 1);
if (args[1] !== 'create') process.exit(2);
execFileSync('git', ['--git-dir', process.env.TEST_REMOTE, 'update-ref', 'refs/tags/' + args[2], process.env.BUILT_SHA]);
`, { mode: 0o755 });
  return { dir, git, sha, remote, log,
    run: (name, env = {}) => spawnSync('bash', ['-euo', 'pipefail', '-c', script(name)], { cwd: dir, encoding: 'utf8',
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

test('workflow preserves all triggers, both architectures, immutable builds and version concurrency', () => {
  assert.match(workflow, /push:\n    branches: \[master\]\n    tags: \['v\*'\]/);
  assert.doesNotMatch(workflow, /pull_request:/);
  assert.match(workflow, /workflow_dispatch:[\s\S]*tag:[\s\S]*required: true/);
  assert.match(workflow, /permissions:\n  contents: write/);
  assert.doesNotMatch(workflow, /secrets\.|--draft/);
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
  assert.match(tests, /name: build-arm64\n    needs: changes\n    if: needs.changes.outputs.heavy == 'true'\n/);
  assert.match(tests, /run: zig build -Dtarget=aarch64-windows-gnu/);
  assert.match(tests, /needs: \[changes, test, test-vps, build-arm64\]/);
  assert.match(tests, /ARM64: \$\{\{ needs\.build-arm64\.result \}\}/);
});

test('four Windows and two VPS jobs retain the upstream test graph and folded service checks', () => {
  const tests = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  const matrices = [...tests.matchAll(/^        group: \[([^\]]+)\]$/gm)].map(match => match[1].split(',').map(value => Number(value.trim())));
  assert.deepEqual(matrices, [[1, 2, 3, 4], [1, 2]]);
  assert.deepEqual([...build.matchAll(/b.step\("test-group-(\d+)"/g)].map(match => Number(match[1])), matrices[0]);
  assert.deepEqual([...build.matchAll(/b.step\("test-vps-group-(\d+)"/g)].map(match => Number(match[1])), matrices[1]);
  assert.match(tests, /run: zig build test --summary all -Dtest-group=\$\{\{ matrix.group \}\}/);
  assert.match(tests, /run: zig build test-vps --summary all -Dtest-vps-group=\$\{\{ matrix.group \}\}/);
  const vps = tests.split('\n  test-vps:\n')[1].split('\n  build-arm64:\n')[0];
  assert.match(vps, /name: Build the account Worker\n        if: matrix.group == 1/);
  assert.match(vps, /name: Run account Worker tests\n        if: matrix.group == 1/);
  assert.match(build, /const zsb_help_tests = b.addSystemCommand\(&\.\{ "node", "--test", "tools\/zsb-help.test.js" \}\)/);
  assert.match(build, /zsb_help_tests.step.dependOn\(&bridge_install.step\)/);
  assert.match(build, /test_step.dependOn\(&zsb_help_tests.step\)/);
});

test('lightweight workflows cancel superseded PRs but never master pushes or dispatches', () => {
  for (const file of ['gitleaks', 'no-comments', 'docs-site', 'verify']) {
    const text = fs.readFileSync(path.join(root, `.github/workflows/${file}.yml`), 'utf8');
    assert.match(text, /^  pull_request:/m, file);
    assert.match(text, /^concurrency:\n  group: \$\{\{ github.workflow \}\}-\$\{\{ github.ref \}\}\n  cancel-in-progress: \$\{\{ github.event_name == 'pull_request' \}\}/m, file);
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
  assert.equal(sums.trim().split('\n').length, 5);
  execFileSync('sha256sum', ['-c', 'SHA256SUMS.txt'], { cwd: path.join(f.dir, 'dist') });
});
