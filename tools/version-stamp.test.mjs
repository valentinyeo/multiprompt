import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { stampTree, fixHint } from './version-stamp.mjs';

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

test('escapes Zig strings without interpreting replacement dollar sequences', () => {
  const stamp = stampTree({ ...base(), 'changelog.d/DEMO-2-escape.md': 'Open "C:\\new" with $& and $` and $\' and a\tb.\n' });
  assert.ok(stamp.files['src/changelog.zig'].includes('        .{ .text = "Open \\"C:\\\\new\\" with $& and $` and $\' and a\\tb.", .ticket = "DEMO-2" },\n'));
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
    const arm64 = workflow.split('\n  build-arm64:\n')[1]?.split('\n  test-result:\n')[0];
    for (const cache of caches) {
      const guard = arm64?.includes(cache) ? '' : "steps\\.rule\\.outputs\\.kind != 'STAMP' && ";
      assert.match(cache, /uses: actions\/cache(?:\/restore)?@[a-f0-9]{40}\n/);
      assert.match(cache, new RegExp(`if: ${guard}github\\.event_name == '`));
      if (cache.includes('uses: actions/cache/restore@')) {
        assert.match(cache, new RegExp(`if: ${guard}github\\.event_name == 'pull_request'\n`));
      } else {
        assert.match(cache, new RegExp(`if: ${guard}github\\.event_name == 'push' && github\\.ref == 'refs/heads/master'\n`));
      }
    }
    if (file === 'test.yml') {
      assert.equal(caches.length, 12);
      for (let i = 0; i < caches.length; i += 2) {
        assert.ok(caches[i].includes('uses: actions/cache/restore@'));
        assert.ok(caches[i + 1].includes('uses: actions/cache@'));
        assert.equal(caches[i].split('        with:\n')[1], caches[i + 1].split('        with:\n')[1]);
      }
    }
  }
});

test('test-vps skips account Worker build and tests on STAMP PRs', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  const vps = workflow.split('\n  test-vps:\n')[1].split(/\n  [\w-]+:\n/)[0];
  const steps = vps.split(/(?=^      - )/m).filter(step => /worker\.test\.js|wrangler deploy --dry-run/.test(step));
  assert.ok(steps.some(step => step.includes('worker.test.js')));
  assert.ok(steps.some(step => step.includes('wrangler deploy --dry-run')));
  for (const step of steps) {
    assert.match(step, /if: steps\.rule\.outputs\.kind != 'STAMP' && matrix\.group == 1\n/);
  }
});

test('build, CI, installer and documentation use the stamp contract', () => {
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /const version_stamp_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/version-stamp\.test\.mjs", "tools\/release-version\.test\.mjs" \}\);/);
  for (const step of ['test_step', 'vps_test_step']) assert.ok(build.includes(`${step}.dependOn(&version_stamp_tests.step);`));
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/test.yml'), 'utf8');
  for (const job of workflow.split(/\n  test(?:-vps)?:\n/).slice(1)) {
    assert.match(job, /id: rule\n        shell: bash/);
    assert.ok(job.indexOf('actions/setup-node@') < job.indexOf('id: rule'));
    assert.ok(job.indexOf('id: rule') < job.indexOf('name: Install Zig'));
    assert.ok(job.includes('git merge-base ${{ github.event.pull_request.base.sha }} ${{ github.event.pull_request.head.sha }}'));
    assert.ok(job.includes('node tools/version-stamp.mjs check HEAD^ HEAD'));
    assert.match(job, /- name: Run (?:tests|server tool tests)\n        if: steps\.rule\.outputs\.kind != 'STAMP'/);
  }
  assert.equal((workflow.match(/- name: Install Zig 0\.16\.0\n        if: steps\.rule\.outputs\.kind != 'STAMP'/g) || []).length, 2);
  assert.doesNotMatch(workflow, /Compile stamp/);
  const install = fs.readFileSync(path.join(root, 'tools/install-laptop1.sh'), 'utf8');
  assert.doesNotMatch(install, /Measure-Object|unstamped changelog/);
  assert.ok(install.includes('gh release download'));
  assert.ok(install.includes('releases/tags/$release'));
  assert.ok(install.indexOf('receipt.mjs') < install.indexOf('Rename-Item'));
  const release = fs.readFileSync(path.join(root, '.github/workflows/release.yml'), 'utf8');
  assert.match(release, /branches: \[master\]/);
  assert.match(release, /node tools\/release-version\.mjs/);
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
