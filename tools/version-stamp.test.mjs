import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { stampTree, buildChangelog, previousReleaseTag, classifyTrees, fixHint } from './version-stamp.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const tool = path.join(root, 'tools/version-stamp.mjs');
const main = 'pub const APP_VERSION = "0.28.735";\nconst untouched = 1;\n';
const changelog = 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.735", .items = &.{\n        .{ .text = "Existing.", .ticket = "DEMO-360" },\n    } },\n};\n';
const base = () => ({ 'src/main.zig': main, 'src/changelog.zig': changelog, 'changelog.d/README.md': 'Documentation.\n' });

function repo(t, files = base()) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'version-stamp-test-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'Version Stamp Test');
  git('config', 'user.email', 'version-stamp@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  git('config', 'core.autocrlf', 'false');
  const write = tree => {
    for (const [name, content] of Object.entries(tree)) {
      fs.mkdirSync(path.dirname(path.join(dir, name)), { recursive: true });
      fs.writeFileSync(path.join(dir, name), content);
    }
  };
  const commit = () => { git('add', '-A'); git('commit', '-m', 'fixture'); return git('rev-parse', 'HEAD'); };
  const check = (from, to) => spawnSync(process.execPath, [tool, 'check', from, to], { cwd: dir, encoding: 'utf8', env: { ...process.env, GITHUB_OUTPUT: path.join(dir, '.git', 'github-output') } });
  write(files);
  const initial = commit();
  return { dir, git, write, commit, check, initial };
}

function expectKind(result, kind, status) {
  assert.equal(result.error, undefined);
  assert.equal(result.status, status, result.stderr);
  assert.equal(result.stdout.trim(), kind);
}

test('folds fragments in filename then line order into one new entry', () => {
  const files = { ...base(), 'changelog.d/DEMO-9-second.md': ' Last. \n', 'changelog.d/DEMO-1-first.md': '\n First. \r\n\r\nSecond.\n' };
  const saved = { ...files };
  const stamp = stampTree(files);
  assert.equal(stamp.version, '0.28.736');
  assert.deepEqual(stamp.tickets, ['DEMO-1', 'DEMO-9']);
  assert.deepEqual(stamp.removed, ['changelog.d/DEMO-1-first.md', 'changelog.d/DEMO-9-second.md']);
  assert.equal(stamp.files['src/main.zig'], main.replace('735', '736'));
  assert.equal(stamp.files['src/changelog.zig'], changelog.replace('pub const CHANGELOG = [_]ChangelogEntry{\n', 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.736", .items = &.{\n        .{ .text = "First.", .ticket = "DEMO-1" },\n        .{ .text = "Second.", .ticket = "DEMO-1" },\n        .{ .text = "Last.", .ticket = "DEMO-9" },\n    } },\n'));
  assert.equal(stamp.files['changelog.d/README.md'], files['changelog.d/README.md']);
  for (const file of stamp.removed) assert.equal(file in stamp.files, false);
  assert.deepEqual(files, saved);
});

test('escapes plain quoted text without interpreting replacement dollar sequences', () => {
  const stamp = stampTree({ ...base(), 'changelog.d/DEMO-2-escape.md': 'Open "saved chats" with $&.\n' });
  assert.ok(stamp.files['src/changelog.zig'].includes('        .{ .text = "Open \\"saved chats\\" with $&.", .ticket = "DEMO-2" },\n'));
});

test('README alone is not a fragment', () => assert.equal(stampTree(base()), null));
test('no changelog directory gives null', () => assert.equal(stampTree({ 'src/main.zig': main, 'src/changelog.zig': changelog }), null));
test('rejects bad names and empty fragments', () => {
  for (const name of ['notes.md', 'demo-2-name.md', 'DEMO-2.md', 'DEMO-2-.md', 'DEMO-2-name.txt', 'nested/DEMO-2-name.md']) {
    assert.throws(() => stampTree({ ...base(), [`changelog.d/${name}`]: 'Text.' }), /Bad fragment filename/);
  }
  assert.throws(() => stampTree({ ...base(), 'changelog.d/DEMO-2-empty.md': ' \r\n\t\n' }), /no text/);
});
test('deduplicates ticket names and increments only the patch', () => {
  const stamp = stampTree({ ...base(), 'src/main.zig': main.replace('0.28.735', '1.9.999'), 'changelog.d/DEMO-2-a.md': 'One.', 'changelog.d/DEMO-2-b.md': 'Two.' });
  assert.equal(stamp.version, '1.9.1000');
  assert.deepEqual(stamp.tickets, ['DEMO-2']);
});

test('check rejects a hand bump and reports offending lines and the fix', t => {
  const r = repo(t);
  r.write({ 'src/main.zig': main.replace('735', '736'), 'src/changelog.zig': changelog.replace('pub const CHANGELOG = [_]ChangelogEntry{', 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.736", .items = &.{} },') });
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
  const result = r.check(r.initial, 'HEAD');
  assert.ok(result.stderr.includes('+pub const APP_VERSION = "0.28.736";'));
  assert.ok(result.stderr.includes('+    .{ .ver = "0.28.736"'));
  assert.ok(result.stderr.includes(fixHint));
  assert.equal(fs.readFileSync(path.join(r.dir, '.git', 'github-output'), 'utf8'), 'kind=HAND_EDIT\nkind=HAND_EDIT\n');
});

test('check accepts an exact stamp with fragment deletion', t => {
  const files = { ...base(), 'changelog.d/DEMO-2-first.md': 'One.\n', 'changelog.d/DEMO-3-second.md': 'Two.\n' };
  const r = repo(t, files);
  const stamp = stampTree(files);
  r.write(stamp.files);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  expectKind(r.check(r.initial, r.commit()), 'STAMP', 0);
  assert.equal(fs.readFileSync(path.join(r.dir, '.git', 'github-output'), 'utf8'), 'kind=STAMP\n');
});

test('check accepts a squashed stamp on a master that gained a newer fragment', t => {
  const first = { ...base(), 'changelog.d/DEMO-2-first.md': 'One.\n' };
  const stamp = stampTree(first);
  const r = repo(t, { ...first, 'changelog.d/DEMO-3-later.md': 'Later.\n' });
  r.write(stamp.files);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  expectKind(r.check(r.initial, r.commit()), 'STAMP', 0);
});

test('check accepts code edits alongside a new fragment', t => {
  const r = repo(t);
  r.write({ 'other.txt': 'Code change.\n', 'changelog.d/DEMO-2-code.md': 'A useful feature.\n' });
  expectKind(r.check(r.initial, r.commit()), 'CODE', 0);
  assert.equal(fs.readFileSync(path.join(r.dir, '.git', 'github-output'), 'utf8'), 'kind=CODE\n');
});

test('check rejects a stamp with an extra byte in the entry', t => {
  const files = { ...base(), 'changelog.d/DEMO-2-code.md': 'Feature.\n' };
  const r = repo(t, files);
  const stamp = stampTree(files);
  stamp.files['src/changelog.zig'] = stamp.files['src/changelog.zig'].replace('Feature.', 'Feature!');
  r.write(stamp.files);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
});

test('check rejects stamp lookalikes with unrelated edits, retained fragments or edited history', t => {
  const files = { ...base(), 'changelog.d/DEMO-2-code.md': 'Feature.\n' };
  const r = repo(t, files);
  const stamp = stampTree(files);
  r.write(stamp.files);
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  r.write({ 'other.txt': 'Extra.\n' });
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
  fs.unlinkSync(path.join(r.dir, 'other.txt'));
  r.write({ 'src/changelog.zig': stamp.files['src/changelog.zig'].replace('Existing.', 'Edited history.') });
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
});

test('check rejects version entry removal without an APP_VERSION bump', t => {
  const r = repo(t);
  r.write({ 'src/changelog.zig': 'pub const CHANGELOG = [_]ChangelogEntry{};\n' });
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
});

test('PR runs only restore Zig caches while master pushes can save them', () => {
  for (const file of fs.readdirSync(path.join(root, '.github/workflows')).filter(file => /\.ya?ml$/.test(file))) {
    const workflow = fs.readFileSync(path.join(root, '.github/workflows', file), 'utf8');
    const caches = workflow.split(/(?=^      - )/m).filter(step => /uses: actions\/cache(?:\/(?:restore|save))?@/.test(step));
    const windows = workflow.split('\n  build-windows:\n')[1]?.split('\n  test-result:\n')[0];
    const updateSource = workflow.split('\n  test-update-source:\n')[1]?.split(/\n  [\w-]+:\n/)[0];
    for (const cache of caches) {
      const pathGuard = file === 'test.yml' ? "steps\\.paths\\.outputs\\.heavy == 'true' && " : '';
      const guard = windows?.includes(cache) || updateSource?.includes(cache) ? '' : "steps\\.rule\\.outputs\\.kind != 'STAMP' && ";
      assert.match(cache, /uses: actions\/cache(?:\/restore)?@[a-f0-9]{40}\n/);
      assert.match(cache, new RegExp(`if: ${pathGuard}${guard}github\\.event_name == '`));
      if (cache.includes('uses: actions/cache/restore@')) {
        assert.match(cache, new RegExp(`if: ${pathGuard}${guard}github\\.event_name == 'pull_request'\n`));
      } else {
        assert.match(cache, new RegExp(`if: ${pathGuard}${guard}github\\.event_name == 'push' && github\\.ref == 'refs/heads/master'\n`));
      }
    }
    if (file === 'test.yml') {
      assert.equal(caches.length, 16);
      for (let i = 0; i < caches.length; i += 2) {
        assert.ok(caches[i].includes('uses: actions/cache/restore@'));
        assert.ok(caches[i + 1].includes('uses: actions/cache@'));
        assert.equal(caches[i].split('        with:\n')[1], caches[i + 1].split('        with:\n')[1]);
      }
      for (const [name, cap, prefix, run] of [
        ['test', 1600, 'shards-v7-group-', 'Run tests'],
        ['test-vps', 1600, 'shards-v6-vps-', 'Run server tool tests'],
      ]) {
        const job = workflow.split(`\n  ${name}:\n`)[1].split(/\n  [\w-]+:\n/)[0];
        const steps = job.split(/(?=^      - )/m);
        const trim = steps.filter(step => step.includes('name: Bound Zig cache before save'));
        assert.equal(trim.length, 1);
        assert.match(trim[0], /if: steps\.paths\.outputs\.heavy == 'true' && steps\.rule\.outputs\.kind != 'STAMP' && github\.event_name == 'push' && github\.ref == 'refs\/heads\/master'\n/);
        assert.match(trim[0], /shell: bash\n/);
        assert.equal((trim[0].match(/du -sh \.zig-cache "\$ZIG_GLOBAL_CACHE_DIR"/g) || []).length, 1);
        assert.ok(trim[0].includes('du -sh "$ZIG_GLOBAL_CACHE_DIR"\n'));
        assert.ok(trim[0].includes('if [ -d .zig-cache ]; then du -sh .zig-cache; fi\n'));
        assert.ok(trim[0].includes(`python3 tools/trim-zig-cache.py --cap-mib ${cap}\n`));
        assert.ok(job.indexOf(`name: ${run}\n`) < job.indexOf('name: Bound Zig cache before save\n'));
        const buildCaches = steps.filter(step => /name: (?:Restore Zig \(PR\)|Cache Zig)\n/.test(step));
        assert.equal(buildCaches.length, 2);
        for (const cache of buildCaches) {
          assert.equal((cache.match(new RegExp(prefix, 'g')) || []).length, 2);
          assert.match(cache, /hashFiles\('build\.zig', 'build\.zig\.zon'\)/);
          assert.match(cache, /path: \|\n            \.zig-cache\n            \$\{\{ env\.ZIG_GLOBAL_CACHE_DIR \}\}/);
        }
      }
    }
  }
});

test('test-worker skips Zig installation, account Worker build and tests on STAMP PRs', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const worker = workflow.split('\n  test-worker:\n')[1].split(/\n  [\w-]+:\n/)[0];
  const steps = worker.split(/(?=^      - )/m).filter(step => /Install Zig|worker\.test\.js|wrangler deploy --dry-run/.test(step));
  assert.ok(steps.some(step => step.includes('Install Zig 0.16.0')));
  assert.ok(steps.some(step => step.includes('worker.test.js')));
  assert.ok(steps.some(step => step.includes('wrangler deploy --dry-run')));
  for (const step of steps) {
    assert.match(step, /if: steps\.paths\.outputs\.heavy == 'true' && steps\.rule\.outputs\.kind != 'STAMP'\n/);
  }
});

test('build, CI, installer and documentation use the stamp contract', () => {
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /const version_stamp_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/version-stamp\.test\.mjs", "tools\/release-version\.test\.mjs" \}\);/);
  for (const step of ['test_step', 'vps_test_step']) assert.ok(build.includes(`${step}.dependOn(&version_stamp_tests.step);`));
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const jobs = Object.fromEntries([...workflow.matchAll(/^  ([\w-]+):\n((?:(?!^  [\w-]+:)[\s\S])*)/gm)].map(match => [match[1], match[2]]));
  for (const name of ['test', 'test-vps', 'test-windows-update', 'test-worker']) {
    const job = jobs[name];
    assert.match(job, /id: rule\n        shell: bash/);
    assert.ok(job.indexOf('actions/setup-node@') < job.indexOf('id: rule'));
    if (name !== 'test-windows-update') {
      assert.ok(job.indexOf('id: rule') < job.indexOf('name: Install Zig'));
    } else {
      assert.doesNotMatch(job, /Install Zig|zig build/);
      assert.ok(job.indexOf('id: rule') < job.indexOf('actions/download-artifact@'));
    }
    if (name === 'test-worker') assert.ok(job.indexOf('id: rule') < job.indexOf('name: Build the account Worker'));
    assert.ok(job.includes('git merge-base ${{ github.event.pull_request.base.sha }} ${{ github.event.pull_request.head.sha }}'));
    assert.ok(job.includes('node tools/version-stamp.mjs check HEAD^ HEAD'));
    const step = name === 'test-windows-update' ? 'Test safe release updates' : name === 'test-worker' ? 'Build the account Worker' : 'Run (?:tests|server tool tests)';
    assert.match(job, new RegExp(`- name: ${step}\\n        if: steps\\.paths\\.outputs\\.heavy == 'true' && steps\\.rule\\.outputs\\.kind != 'STAMP'`));
  }
  assert.equal((workflow.match(/- name: Install Zig 0\.16\.0\n        if: steps\.paths\.outputs\.heavy == 'true' && steps\.rule\.outputs\.kind != 'STAMP'/g) || []).length, 3);
  assert.doesNotMatch(workflow, /Compile stamp/);
  const install = fs.readFileSync(path.join(root, 'tools/install-laptop1.sh'), 'utf8');
  assert.doesNotMatch(install, /Measure-Object|unstamped changelog/);
  assert.ok(install.includes('gh release download'));
  assert.ok(install.includes('releases/tags/$release'));
  assert.ok(install.indexOf('receipt.mjs') < install.indexOf('Rename-Item'));
  const release = fs.readFileSync(path.join(root, '.github/workflows/release.yml'), 'utf8');
  assert.doesNotMatch(release, /branches: \[master\]/);
  assert.match(release, /node tools\/release-version\.mjs/);
  const autoRelease = fs.readFileSync(path.join(root, '.github/workflows/auto-release.yml'), 'utf8');
  assert.match(autoRelease, /branches: \[master\]/);
  assert.ok(fs.readFileSync(path.join(root, 'tools/gates/no-version-bump.mjs'), 'utf8').includes(fixHint));
  const readme = fs.readFileSync(path.join(root, 'changelog.d/README.md'), 'utf8');
  assert.ok(readme.trim().split('\n').length <= 6);
  assert.ok(readme.includes('node tools/version-stamp.mjs release'));
});

for (const race of [false, true]) test(race ? 'release retries a competing branch and waits for its PR' : 'release stamps, opens and waits for the PR, then reports nothing pending', { skip: process.platform === 'win32' }, t => {
  const files = { ...base(), 'changelog.d/DEMO-2-release.md': 'Feature.\n' };
  const r = repo(t, files);
  const remote = path.join(r.dir, 'origin.git');
  r.git('init', '--bare', remote);
  r.git('remote', 'add', 'origin', remote);
  r.git('push', 'origin', 'master');
  if (race) {
    const stamp = stampTree(files);
    r.write(stamp.files);
    for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
    r.initial = r.commit();
    r.git('push', 'origin', 'HEAD:refs/heads/release/0.28.736');
  }
  const bin = path.join(r.dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}\nimport fs from 'node:fs';\nimport { execFileSync } from 'node:child_process';\nconst args = process.argv.slice(2);\nfs.appendFileSync(process.env.GH_LOG, JSON.stringify(args) + '\\n');\nconst stateFile = process.env.GH_STATE;\nlet state = fs.existsSync(stateFile) ? fs.readFileSync(stateFile, 'utf8') : '';\nconst git = args => execFileSync('git', ['--git-dir', process.env.TEST_REMOTE, ...args]);\nif (args[1] === 'list' && process.env.GH_RACE === '1' && fs.readFileSync(process.env.GH_LOG, 'utf8').split('\\n').filter(line => line.includes('\"list\"')).length > 1 && !state) { state = 'OPEN'; fs.writeFileSync(stateFile, state); }\nif (args[1] === 'list') console.log(JSON.stringify(state === 'OPEN' ? [{ number: 1, url: 'https://example.invalid/pr/1' }] : []));\nelse if (args[1] === 'create') { fs.writeFileSync(stateFile, 'OPEN'); console.log('https://example.invalid/pr/1'); }\nelse if (args[1] === 'view') { if (state === 'OPEN') { git(['update-ref', 'refs/heads/master', 'refs/heads/release/0.28.736']); state = 'MERGED'; fs.writeFileSync(stateFile, state); } console.log(JSON.stringify({ state, statusCheckRollup: [{ name: 'test', conclusion: 'SUCCESS' }] })); }\nelse if (args[1] !== 'merge') process.exit(1);\n`, { mode: 0o755 });
  const result = spawnSync(process.execPath, [tool, 'release'], { cwd: path.join(r.dir, 'src'), encoding: 'utf8', timeout: 60000, env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, TEST_REMOTE: remote, GH_RACE: race ? '1' : '0', GH_LOG: path.join(r.dir, 'gh-log'), GH_STATE: path.join(r.dir, 'gh-state') } });
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /https:\/\/example\.invalid\/pr\/1[\s\S]*NOTHING_TO_STAMP 0\.28\.736/);
  const requests = fs.readFileSync(path.join(r.dir, 'gh-log'), 'utf8').trim().split('\n').map(line => JSON.parse(line));
  if (!race) assert.deepEqual(requests.find(args => args[1] === 'create'), ['pr', 'create', '--base', 'master', '--head', 'release/0.28.736', '--title', 'v0.28.736: release DEMO-2', '--body', 'Stamped by tools/version-stamp.mjs from changelog.d.']);
  if (!race) assert.deepEqual(requests.find(args => args[1] === 'merge'), ['pr', 'merge', 'https://example.invalid/pr/1', '--squash', '--auto', '--delete-branch']);
  assert.deepEqual(requests.find(args => args[1] === 'view'), ['pr', 'view', '1', '--json', 'state,statusCheckRollup']);
  assert.equal(requests.some(args => args[1] === 'checks'), false);
  assert.equal(r.git('rev-parse', 'HEAD'), r.initial);
  assert.equal(r.git('worktree', 'list', '--porcelain').match(/^worktree /gm).length, 1);
  assert.equal(r.git('show', 'origin/master:src/main.zig'), main.replace('735', '736').trim());
  assert.equal(r.git('ls-tree', '-r', '--name-only', 'origin/master', '--', 'changelog.d'), 'changelog.d/README.md');
});

for (const outcome of ['green', 'red', 'pending']) test({ green: 'release merges its own PR after green checks when auto-merge is refused', red: 'release does not merge on a red check when auto-merge is refused', pending: 'release does not merge while checks are pending when auto-merge is refused' }[outcome], { skip: process.platform === 'win32' }, t => {
  const r = repo(t, { ...base(), 'changelog.d/DEMO-2-release.md': 'Feature.\n' });
  const remote = path.join(r.dir, 'origin.git');
  r.git('init', '--bare', remote);
  r.git('remote', 'add', 'origin', remote);
  r.git('push', 'origin', 'master');
  const bin = path.join(r.dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}\nimport fs from 'node:fs';\nimport { execFileSync } from 'node:child_process';\nconst args = process.argv.slice(2);\nconst log = event => fs.appendFileSync(process.env.GH_LOG, JSON.stringify(event) + '\\n');\nlog({ args });\nconst stateFile = process.env.GH_STATE;\nconst state = fs.existsSync(stateFile) ? JSON.parse(fs.readFileSync(stateFile, 'utf8')) : { created: false, merged: false, views: 0 };\nconst outcome = process.env.GH_OUTCOME;\nif (args[1] === 'create') { state.created = true; console.log('https://example.invalid/pr/1'); }\nelse if (args[1] === 'list') console.log(JSON.stringify(state.created && !state.merged ? [{ number: 1, url: 'https://example.invalid/pr/1' }] : []));\nelse if (args[1] === 'merge' && args.includes('--auto')) { console.error('GraphQL: Auto merge is not allowed for this repository (enablePullRequestAutoMerge)'); process.exit(1); }\nelse if (args[1] === 'merge') { execFileSync('git', ['--git-dir', process.env.TEST_REMOTE, 'update-ref', 'refs/heads/master', 'refs/heads/release/0.28.736']); state.merged = true; }\nelse if (args[1] === 'view') { state.views++; const green = outcome === 'green' && state.views >= 4; const checks = outcome === 'red' ? [{ __typename: 'CheckRun', name: 'windows-release', status: 'COMPLETED', conclusion: 'FAILURE' }] : green ? [{ __typename: 'CheckRun', name: 'test', status: 'COMPLETED', conclusion: 'SUCCESS' }, { __typename: 'CheckRun', name: 'optional', status: 'COMPLETED', conclusion: 'SKIPPED' }, { __typename: 'CheckRun', name: 'neutral', status: 'COMPLETED', conclusion: 'NEUTRAL' }, { __typename: 'StatusContext', context: 'external', state: 'SUCCESS' }] : outcome === 'green' && state.views === 2 ? [] : outcome === 'green' && state.views === 3 ? [{ __typename: 'StatusContext', context: 'external', state: 'EXPECTED' }] : [{ __typename: 'CheckRun', name: 'test', status: 'IN_PROGRESS', conclusion: null }, { __typename: 'CheckRun', name: 'optional', status: 'QUEUED', conclusion: null }]; const view = { state: state.merged ? 'MERGED' : outcome === 'pending' && state.views >= 5 ? 'CLOSED' : 'OPEN', statusCheckRollup: state.views % 2 ? checks.reverse() : checks }; log({ view }); console.log(JSON.stringify(view)); }\nelse process.exit(2);\nfs.writeFileSync(stateFile, JSON.stringify(state));\n`, { mode: 0o755 });
  const result = spawnSync(process.execPath, [tool, 'release'], { cwd: r.dir, encoding: 'utf8', timeout: 10000, env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, VERSION_STAMP_POLL_MS: '50', TEST_REMOTE: remote, GH_OUTCOME: outcome, GH_LOG: path.join(r.dir, 'gh-log'), GH_STATE: path.join(r.dir, 'gh-state') } });
  assert.equal(result.error, undefined);
  assert.equal(result.status, outcome === 'green' ? 0 : 1, result.stderr);
  assert.match(result.stderr, /Auto merge is not allowed for this repository/);
  const events = fs.readFileSync(path.join(r.dir, 'gh-log'), 'utf8').trim().split('\n').map(line => JSON.parse(line));
  const requests = events.filter(event => event.args).map(event => event.args);
  assert.equal(requests.some(args => args.includes('--admin')), false);
  assert.equal(requests.filter(args => args[1] === 'merge' && args.includes('--auto')).length, 1);
  const merges = requests.filter(args => args[1] === 'merge' && !args.includes('--auto'));
  if (outcome === 'green') {
    assert.match(result.stdout, /NOTHING_TO_STAMP 0\.28\.736/);
    assert.deepEqual(merges, [['pr', 'merge', '1', '--squash', '--delete-branch']]);
    const mergeIndex = events.findIndex(event => event.args?.[1] === 'merge' && !event.args.includes('--auto'));
    const views = events.slice(0, mergeIndex).filter(event => event.view).map(event => event.view);
    assert.equal(views.length, 5);
    assert.deepEqual(views.slice(-2).map(view => view.statusCheckRollup.map(check => check.name || check.context).sort()), [['external', 'neutral', 'optional', 'test'], ['external', 'neutral', 'optional', 'test']]);
    for (const view of views.slice(-2)) assert.ok(view.statusCheckRollup.every(check => check.__typename === 'CheckRun' ? check.status === 'COMPLETED' && ['SUCCESS', 'SKIPPED', 'NEUTRAL'].includes(check.conclusion) : check.state === 'SUCCESS'));
    assert.ok(events.slice(mergeIndex + 1).some(event => event.view?.state === 'MERGED'));
    assert.equal(r.git('show', 'origin/master:src/main.zig'), main.replace('735', '736').trim());
  } else {
    assert.equal(merges.length, 0);
    assert.match(result.stderr, outcome === 'red' ? /Release PR check failed \(windows-release\)/ : /Release PR closed without merging/);
    assert.equal(events.filter(event => event.view).length, outcome === 'red' ? 1 : 5);
    assert.equal(r.git('show', 'origin/master:src/main.zig'), main.trim());
  }
  assert.equal(r.git('worktree', 'list', '--porcelain').match(/^worktree /gm).length, 1);
});

test('installer rejects obsolete PC source directory usage without consulting gh or lh', { skip: process.platform === 'win32' }, t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'version-install-test-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const log = path.join(dir, 'calls');
  for (const name of ['gh', 'lh']) fs.writeFileSync(path.join(dir, name), `#!${process.execPath}\nrequire('node:fs').writeFileSync(process.env.INSTALL_LOG, 'unexpected call'); process.exit(37);\n`, { mode: 0o755 });
  const result = spawnSync('bash', [path.join(root, 'tools/install-laptop1.sh'), '--extension-only', '--release', 'v0.28.735', 'C:\\source'], {
    encoding: 'utf8', env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, INSTALL_LOG: log },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /unknown argument/);
  assert.equal(fs.existsSync(log), false);
});

test('existing no-version-bump gate retains its behavior and supplies the fix', t => {
  const r = repo(t, { ...base(), 'src/main.zig': 'const APP_VERSION = "0.28.735";\n' });
  const run = () => spawnSync(process.execPath, [path.join(root, 'tools/gates/no-version-bump.mjs')], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(run().stdout.trim(), 'NO-VERSION-BUMP-OK');
  r.write({ 'src/main.zig': 'const APP_VERSION = "0.28.736";\n' });
  const result = run();
  assert.equal(result.status, 1);
  assert.ok(result.stdout.includes(fixHint));
});

test('release fails when an existing PR is closed without merging', { skip: process.platform === 'win32' }, t => {
  const r = repo(t);
  const remote = path.join(r.dir, 'origin.git');
  r.git('init', '--bare', remote);
  r.git('remote', 'add', 'origin', remote);
  r.git('push', 'origin', 'master');
  const bin = path.join(r.dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}\nconst command = process.argv[3];\nif (command === 'list') console.log('[{"number":2,"url":"https://example.invalid/pr/2"}]');\nelse if (command === 'view') console.log('{"state":"CLOSED"}');\nelse process.exit(1);\n`, { mode: 0o755 });
  const result = spawnSync(process.execPath, [tool, 'release'], { cwd: r.dir, encoding: 'utf8', timeout: 60000, env: { ...process.env, PATH: `${bin}:${process.env.PATH}` } });
  assert.equal(result.error, undefined);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Release PR closed without merging: https:\/\/example\.invalid\/pr\/2/);
  assert.equal(r.git('worktree', 'list', '--porcelain').match(/^worktree /gm).length, 1);
});

test('build options preserve the source default and feed both app channels and their marker', () => {
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  const source = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  const fallback = source.match(/^pub const APP_VERSION = build_config\.app_version orelse "(\d+\.\d+\.\d+)";$/m)?.[1];
  assert.ok(fallback);
  assert.equal(fallback, fs.readFileSync(path.join(root, 'src/changelog.zig'), 'utf8').match(/\.ver = "([^"]+)"/)[1]);
  assert.match(build, /const app_version = b\.option\(\[\]const u8, "version", "Override the embedded app version"\);/);
  for (const [options, module] of [['stable_opts', 'exe'], ['dev_opts', 'dev_exe']]) {
    assert.ok(build.includes(`${options}.addOption(?[]const u8, "app_version", app_version);`));
    assert.ok(build.includes(`${module}.root_module.addOptions("build_config", ${options});`));
  }
  const bench = fs.readFileSync(path.join(root, 'tools/chat-table-bench/build.zig'), 'utf8');
  assert.ok(bench.includes('options.addOption(?[]const u8, "app_version", null);'));
  assert.match(source, /export const mp_version_marker[^\n]*"MPVERSION=" \+\+ APP_VERSION \+\+ ";"/);
  const entries = fs.readFileSync(path.join(root, 'src/changelog.zig'), 'utf8');
  assert.match(entries, /var entries = SOURCE_CHANGELOG;\n    if \(@import\("build_config"\)\.app_version != null and entries.len > 0\) @field\(entries\[0\], "ver"\) = APP_VERSION;/);
  assert.match(entries, /CHANGELOG.len == 0 or !std.mem.eql\(u8, CHANGELOG\[0\].ver, APP_VERSION\)/);
});

test('stamp and admission preserve the build fallback without allowing a version hand bump', () => {
  const files = { ...base(), 'changelog.d/DEMO-2-new.md': 'A useful improvement.\n' };
  const configured = { ...files, 'src/main.zig': main.replace('= "', '= build_config.app_version orelse "') };
  assert.equal(classifyTrees(files, configured, ['src/main.zig']), 'CODE');
  assert.equal(classifyTrees(configured, { ...configured, 'src/main.zig': configured['src/main.zig'].replace('735', '736') }, ['src/main.zig']), 'HAND_EDIT');
  const stamp = stampTree(configured);
  assert.equal(stamp.files['src/main.zig'], configured['src/main.zig'].replace('735', '736'));
  assert.equal(classifyTrees(configured, stamp.files, ['src/main.zig', 'src/changelog.zig', ...stamp.removed]), 'STAMP');
});

test('build changelog uses the tag and fragments without changing source defaults or consuming fragments', t => {
  const files = { ...base(), 'changelog.d/DEMO-2-new.md': 'A useful improvement.\n' };
  const saved = structuredClone(files);
  const generated = buildChangelog(files, 'v0.28.900');
  assert.match(generated, /\.ver = "0\.28\.900"/);
  assert.match(generated, /A useful improvement/);
  assert.deepEqual(files, saved);
  assert.equal(buildChangelog(files, 'v0.28.735'), changelog);
  assert.match(buildChangelog(base(), 'v0.28.900'), /Updates include the latest improvements/);
  assert.match(buildChangelog({ ...files, 'src/changelog.zig': changelog.replace('pub const CHANGELOG', 'const SOURCE_CHANGELOG') }, 'v0.28.900'), /const SOURCE_CHANGELOG = \[_\]ChangelogEntry\{\n    \.\{ \.ver = "0\.28\.900"/);
  for (const invalid of ['0.28.900', 'v0.28.900;bad', 'v0.28.900\n', 'v00.28.900']) assert.throws(() => buildChangelog(files, invalid), /Invalid release tag/);
  const r = repo(t, files);
  const result = spawnSync(process.execPath, [tool, 'build', 'v0.28.900'], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8'), generated);
  assert.equal(fs.readFileSync(path.join(r.dir, 'src/main.zig'), 'utf8'), main);
  assert.equal(fs.readFileSync(path.join(r.dir, 'changelog.d/DEMO-2-new.md'), 'utf8'), files['changelog.d/DEMO-2-new.md']);
  assert.equal(r.git('diff', '--name-only'), 'src/changelog.zig');
  const again = spawnSync(process.execPath, [tool, 'build', 'v0.28.900'], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(again.status, 0, again.stderr);
  assert.equal(fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8'), generated);
});

test('IGSH-889 picks the newest older release tag by number', () => {
  const tags = ['v0.28.9', 'v0.28.10', 'v0.28.11', 'v0.28.12', 'v1.0.0', 'nightly', 'v0.28.10-rc1'];
  assert.equal(previousReleaseTag(tags, 'v0.28.11'), 'v0.28.10');
  assert.equal(previousReleaseTag(tags, 'v0.28.10'), 'v0.28.9');
  assert.equal(previousReleaseTag(tags, 'v0.28.9'), null);
  assert.equal(previousReleaseTag(tags, 'v2.0.0'), 'v1.0.0');
});

test('IGSH-889 a release lists only fragments added since the previous release', t => {
  const old = { 'changelog.d/DEMO-1-old.md': 'An old improvement.\n' };
  const generated = buildChangelog({ ...base(), ...old, 'changelog.d/DEMO-2-new.md': 'A new improvement.\n' }, 'v0.28.900', old);
  assert.match(generated, /A new improvement/);
  assert.doesNotMatch(generated, /An old improvement/);
  const quiet = buildChangelog({ ...base(), ...old }, 'v0.28.900', old);
  assert.match(quiet, /Updates include the latest improvements/);
  assert.doesNotMatch(quiet, /An old improvement/);
  const edited = buildChangelog({ ...base(), 'changelog.d/DEMO-1-old.md': 'An old improvement, reworded.\n' }, 'v0.28.900', old);
  assert.match(edited, /reworded/);

  const r = repo(t, { ...base(), ...old });
  r.git('tag', 'v0.28.899');
  r.write({ 'changelog.d/DEMO-2-new.md': 'A new improvement.\n' });
  r.commit();
  r.git('tag', 'v0.28.900');
  const built = spawnSync(process.execPath, [tool, 'build', 'v0.28.900'], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(built.status, 0, built.stderr);
  const written = fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8');
  assert.match(written, /A new improvement/);
  assert.doesNotMatch(written, /An old improvement/);
  assert.equal(written.match(/\.ver = "0\.28\.900"/g).length, 1);
});
