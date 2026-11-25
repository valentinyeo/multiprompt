import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { stampTree, buildChangelog, previousReleaseTag, classifyTrees, fixHint, reviewedCommits } from './version-stamp.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const tool = path.join(root, 'tools/version-stamp.mjs');
const titles = JSON.parse(fs.readFileSync(path.join(root, 'tools/fixtures/IGSH-1681/ticket-titles.json'), 'utf8'));
const line = id => `${id} ${titles[id]}`;
const release = (version, ...ids) => ({ version, changes: ids.map(line), tickets: ids.map(id => `https://app.hypertask.ai/detail/project-${id.startsWith('HYCI-') ? '11514' : '2060'}/${id.split('-')[1]}`) });
const main = 'pub const APP_VERSION = "0.28.735";\nconst untouched = 1;\n';
const changelog = `pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.735", .items = &.{\n        .{ .text = ${JSON.stringify(line('IGSH-240'))}, .ticket = "IGSH-240" },\n    } },\n};\n`;
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
  const env = { ...process.env, GITHUB_OUTPUT: path.join(dir, '.git', 'github-output') };
  delete env.GITHUB_HEAD_REF;
  delete env.GITHUB_REF_NAME;
  const check = (from, to, extra = {}) => spawnSync(process.execPath, [tool, 'check', from, to], { cwd: dir, encoding: 'utf8', env: { ...env, ...extra } });
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
  const files = { ...base(), 'changelog.d/IGSH-232-second.md': ' Last. \n', 'changelog.d/IGSH-127-first.md': '\n First. \r\n\r\nSecond.\n' };
  const saved = { ...files };
  const stamp = stampTree(files);
  assert.equal(stamp.version, '0.28.736');
  assert.deepEqual(stamp.tickets, ['IGSH-127', 'IGSH-232']);
  assert.deepEqual(stamp.removed, ['changelog.d/IGSH-127-first.md', 'changelog.d/IGSH-232-second.md']);
  assert.equal(stamp.files['src/main.zig'], main.replace('735', '736'));
  for (const id of ['IGSH-127', 'IGSH-232']) assert.ok(stamp.files['src/changelog.zig'].includes(`.text = ${JSON.stringify(line(id))}, .ticket = "${id}"`));
  assert.equal((stamp.files['src/changelog.zig'].match(/\.ticket = "IGSH-127"/g) || []).length, 1);
  assert.equal(stamp.files['changelog.d/README.md'], files['changelog.d/README.md']);
  for (const file of stamp.removed) assert.equal(file in stamp.files, false);
  assert.deepEqual(files, saved);
});

test('escapes authoritative quoted Unicode titles and dollar sequences', () => {
  const title = 'Open "saved chats" at the café with $&';
  const stamp = stampTree({ ...base(), 'changelog.d/IGSH-154-escape.md': 'Open chats.\n' }, undefined, { 'IGSH-154': title });
  assert.ok(stamp.files['src/changelog.zig'].includes(`.text = ${JSON.stringify('IGSH-154 ' + title)}, .ticket = "IGSH-154"`));
});

test('README alone is not a fragment', () => assert.equal(stampTree(base()), null));
test('no changelog directory gives null', () => assert.equal(stampTree({ 'src/main.zig': main, 'src/changelog.zig': changelog }), null));
test('rejects bad names and empty fragments', () => {
  for (const name of ['notes.md', 'demo-2-name.md', 'IGSH-154.md', 'IGSH-154-.md', 'IGSH-154-name.txt', 'nested/IGSH-154-name.md']) {
    assert.throws(() => stampTree({ ...base(), [`changelog.d/${name}`]: 'Text.' }), /Bad fragment filename/);
  }
  assert.throws(() => stampTree({ ...base(), 'changelog.d/IGSH-154-empty.md': ' \r\n\t\n' }), /no text/);
});
test('deduplicates ticket names and increments only the patch', () => {
  const stamp = stampTree({ ...base(), 'src/main.zig': main.replace('0.28.735', '1.9.999'), 'changelog.d/IGSH-154-a.md': 'One.', 'changelog.d/IGSH-154-b.md': 'Two.' });
  assert.equal(stamp.version, '1.9.1000');
  assert.deepEqual(stamp.tickets, ['IGSH-154']);
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
  const files = { ...base(), 'changelog.d/IGSH-154-first.md': 'One.\n', 'changelog.d/IGSH-212-second.md': 'Two.\n' };
  const r = repo(t, files);
  const stamp = stampTree(files);
  r.write(stamp.files);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  expectKind(r.check(r.initial, r.commit()), 'STAMP', 0);
  assert.equal(fs.readFileSync(path.join(r.dir, '.git', 'github-output'), 'utf8'), 'kind=STAMP\n');
});

test('check accepts a squashed stamp on a master that gained a newer fragment', t => {
  const first = { ...base(), 'changelog.d/IGSH-154-first.md': 'One.\n' };
  const stamp = stampTree(first);
  const r = repo(t, { ...first, 'changelog.d/IGSH-212-later.md': 'Later.\n' });
  r.write(stamp.files);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  expectKind(r.check(r.initial, r.commit()), 'STAMP', 0);
});

test('check accepts code edits alongside a new fragment', t => {
  const r = repo(t);
  r.write({ 'other.txt': 'Code change.\n', 'changelog.d/IGSH-154-code.md': 'A useful feature.\n' });
  expectKind(r.check(r.initial, r.commit()), 'CODE', 0);
  assert.equal(fs.readFileSync(path.join(r.dir, '.git', 'github-output'), 'utf8'), 'kind=CODE\n');
});

test('app code needs a changelog note except on auto-revert branches', t => {
  const r = repo(t, { ...base(), 'changelog.d/IGSH-154-code.md': 'A useful feature.\n', 'src/feature.zig': 'const on = true;\n' });
  r.git('rm', '-q', 'changelog.d/IGSH-154-code.md', 'src/feature.zig');
  const head = r.commit();
  const normal = r.check(r.initial, head, { GITHUB_HEAD_REF: 'ceo/IGSH-154' });
  assert.equal(normal.status, 1);
  assert.match(normal.stderr, /App code changed: add changelog\.d/);
  const revert = r.check(r.initial, head, { GITHUB_HEAD_REF: 'auto-revert/40533455263' });
  expectKind(revert, 'CODE', 0);
  const dispatched = r.check(r.initial, head, { GITHUB_REF_NAME: 'auto-revert/40533455263' });
  expectKind(dispatched, 'CODE', 0);
});

test('check rejects a stamp with an extra byte in the entry', t => {
  const files = { ...base(), 'changelog.d/IGSH-154-code.md': 'Feature.\n' };
  const r = repo(t, files);
  const stamp = stampTree(files);
  stamp.files['src/changelog.zig'] = stamp.files['src/changelog.zig'].replace(line('IGSH-154'), line('IGSH-154') + '!');
  r.write(stamp.files);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
});

test('check rejects stamp lookalikes with unrelated edits, retained fragments or edited history', t => {
  const files = { ...base(), 'changelog.d/IGSH-154-code.md': 'Feature.\n' };
  const r = repo(t, files);
  const stamp = stampTree(files);
  r.write(stamp.files);
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
  for (const file of stamp.removed) fs.unlinkSync(path.join(r.dir, file));
  r.write({ 'other.txt': 'Extra.\n' });
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
  fs.unlinkSync(path.join(r.dir, 'other.txt'));
  r.write({ 'src/changelog.zig': stamp.files['src/changelog.zig'].replace(line('IGSH-240'), 'Edited history.') });
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
});

test('check rejects version entry removal without an APP_VERSION bump', t => {
  const r = repo(t);
  r.write({ 'src/changelog.zig': 'pub const CHANGELOG = [_]ChangelogEntry{};\n' });
  expectKind(r.check(r.initial, r.commit()), 'HAND_EDIT', 1);
});

test('PR, manual and nightly runs reuse Zig caches without duplicate restore/save steps', () => {
  for (const file of fs.readdirSync(path.join(root, '.github/workflows')).filter(file => /\.ya?ml$/.test(file))) {
    const workflow = fs.readFileSync(path.join(root, '.github/workflows', file), 'utf8');
    const caches = workflow.split(/(?=^      - )/m).filter(step => /uses: actions\/cache(?:\/(?:restore|save))?@/.test(step));
    for (const cache of caches) {
      assert.match(cache, /uses: actions\/cache(?:\/(?:restore|save))?@[a-f0-9]{40}\n/);
      assert.match(cache, /path:/);
      assert.match(cache, /key:/);
      if (cache.includes('.zig-cache') && cache.includes('uses: actions/cache@')) assert.match(cache, /github.sha|inputs.revision|inputs.app_revision/);
    }
    if (file !== 'test.yml') continue;
    for (const name of ['test', 'test-vps', 'build-windows', 'speed-baseline', 'speed-candidate']) {
      const job = workflow.split(`\n  ${name}:\n`)[1].split(/\n  [\w-]+:\n/)[0];
      const caches = job.split(/(?=^      - )/m).filter(step => /uses: actions\/cache@/.test(step));
      assert.equal(caches.length, 2, name);
      const compile = caches.find(step => step.includes('.zig-cache'));
      const toolchain = caches.find(step => step.includes('-toolchain-'));
      assert.ok(compile && toolchain, name);
      assert.match(compile, /github.sha/);
      assert.match(compile, /hashFiles\('build\.zig', 'build\.zig\.zon'\)/);
      assert.match(compile, /restore-keys:/);
      assert.match(toolchain, /zig-toolchain-0.16.0/);
      if (name === 'build-windows') continue;
      const trim = job.split(/(?=^      - )/m).find(step => step.includes('name: Bound Zig cache before save'));
      assert.ok(trim, name);
      assert.match(trim, /python3 tools\/trim-zig-cache.py --cap-mib 1600/);
      assert.doesNotMatch(trim, /github.event_name == 'push'/);
      assert.match(trim, /du -sh \.zig-cache "\$ZIG_GLOBAL_CACHE_DIR"/);
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
  assert.match(release, /gh api "repos\/\$GITHUB_REPOSITORY\/releases\/latest" --jq \.tag_name/);
  assert.match(release, /git rev-list --first-parent --count "\$base\.\.\$sha"/);
  assert.match(release, /node tools\/version-stamp\.mjs build "\$TAG"/);
  assert.match(release, /Executable embedded version does not match release tag/);
  const autoRelease = fs.readFileSync(path.join(root, '.github/workflows/auto-release.yml'), 'utf8');
  assert.match(autoRelease, /branches: \[master\]/);
  assert.ok(fs.readFileSync(path.join(root, 'tools/gates/no-version-bump.mjs'), 'utf8').includes(fixHint));
  const readme = fs.readFileSync(path.join(root, 'changelog.d/README.md'), 'utf8');
  assert.match(readme, /Never edit APP_VERSION or \.ver lines by hand/);
  assert.match(readme, /Release notes use the ticket number and its authoritative board title/);
  assert.match(readme, /Releases without ticketed lines cannot publish/);
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
  const files = { ...base(), 'changelog.d/IGSH-154-new.md': 'A useful improvement.\n' };
  const configured = { ...files, 'src/main.zig': main.replace('= "', '= build_config.app_version orelse "') };
  assert.equal(classifyTrees(files, configured, ['src/main.zig']), 'CODE');
  assert.equal(classifyTrees(configured, { ...configured, 'src/main.zig': configured['src/main.zig'].replace('735', '736') }, ['src/main.zig']), 'HAND_EDIT');
  const stamp = stampTree(configured);
  assert.equal(stamp.files['src/main.zig'], configured['src/main.zig'].replace('735', '736'));
  assert.equal(classifyTrees(configured, stamp.files, ['src/main.zig', 'src/changelog.zig', ...stamp.removed]), 'STAMP');
});

test('build changelog uses the tag and fragments without changing source defaults or consuming fragments', t => {
  const files = { ...base(), 'changelog.d/IGSH-154-new.md': 'A useful improvement.\n' };
  const saved = structuredClone(files);
  const generated = buildChangelog(files, 'v0.28.900');
  assert.match(generated, /\.ver = "0\.28\.900"/);
  assert.ok(generated.includes(line('IGSH-154')));
  assert.deepEqual(files, saved);
  assert.equal(buildChangelog(files, 'v0.28.735'), changelog);
  assert.throws(() => buildChangelog(base(), 'v0.28.900'), /No unpublished product changes/);
  assert.match(buildChangelog({ ...files, 'src/changelog.zig': changelog.replace('pub const CHANGELOG', 'const SOURCE_CHANGELOG') }, 'v0.28.900'), /const SOURCE_CHANGELOG = \[_\]ChangelogEntry\{\n    \.\{ \.ver = "0\.28\.900"/);
  for (const invalid of ['0.28.900', 'v0.28.900;bad', 'v0.28.900\n', 'v00.28.900']) assert.throws(() => buildChangelog(files, invalid), /Invalid release tag/);
  const r = repo(t, files);
  const result = spawnSync(process.execPath, [tool, 'build', 'v0.28.900', '[]'], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8'), generated);
  assert.equal(fs.readFileSync(path.join(r.dir, 'src/main.zig'), 'utf8'), main);
  assert.equal(fs.readFileSync(path.join(r.dir, 'changelog.d/IGSH-154-new.md'), 'utf8'), files['changelog.d/IGSH-154-new.md']);
  assert.equal(r.git('diff', '--name-only'), 'src/changelog.zig');
  const again = spawnSync(process.execPath, [tool, 'build', 'v0.28.900', '[]'], { cwd: r.dir, encoding: 'utf8' });
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
  const old = { 'changelog.d/IGSH-127-old.md': 'An old improvement.\n' };
  const fresh = { ...base(), ...old, 'changelog.d/IGSH-154-new.md': 'A new improvement.\n' };
  const generated = buildChangelog(fresh, 'v0.28.900', [{ tag: 'v0.28.899', files: { ...base(), ...old } }]);
  assert.ok(generated.includes(line('IGSH-154')));
  assert.ok(!generated.includes(line('IGSH-127')));
  assert.throws(() => buildChangelog({ ...base(), ...old }, 'v0.28.900', [{ tag: 'v0.28.899', files: { ...base(), ...old } }]), /No unpublished product changes/);

  const r = repo(t, { ...base(), ...old });
  r.git('tag', 'v0.28.735');
  r.write({ 'changelog.d/IGSH-154-new.md': 'Second release change.\n' });
  r.commit();
  r.git('tag', 'v0.28.736');
  r.write({ 'changelog.d/IGSH-212-skipped.md': 'Third release change.\n' });
  r.commit();
  r.git('tag', 'v0.28.737');
  r.write({ 'changelog.d/IGSH-221-latest.md': 'Latest release change.\n' });
  r.commit();
  r.git('tag', 'v0.28.738');
  const built = spawnSync(process.execPath, [tool, 'build', 'v0.28.738', JSON.stringify(['v0.28.735', 'v0.28.736', 'v0.28.737'])], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(built.status, 0, built.stderr);
  const written = fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8');
  assert.ok(!written.includes(line('IGSH-127')));
  const order = ['0.28.738', '0.28.737', '0.28.736', '0.28.735'].map(v => written.indexOf(`.ver = "${v}"`));
  assert.ok(order.every((at, i) => at >= 0 && (i === 0 || at > order[i - 1])), 'one entry per release, newest first');
  assert.ok(written.slice(order[0], order[1]).includes(line('IGSH-221')));
  assert.ok(written.slice(order[1], order[2]).includes(line('IGSH-212')));
  assert.ok(written.slice(order[2], order[3]).includes(line('IGSH-154')));
});

test('IGSH-1090 maintenance releases wait instead of inventing a note', () => {
  assert.throws(() => buildChangelog(base(), 'v0.28.900'), /No unpublished product changes/);
});

test('IGSH-1090 fragment gate rejects filler and engineering notes, not specific product changes', async () => {
  const { checkFragments } = await import('./version-stamp.mjs');
  const name = 'changelog.d/IGSH-127-update.md';
  for (const line of [
    'Behind the scenes fixes.', 'Plus 2 behind the scenes fixes.',
    'Updates include the latest improvements.', 'Various improvements.', 'Bug fixes.',
    'Chat speed checks now ignore shared-machine pauses.',
    'Session switching checks now preserve slow and stale replies for diagnosis.',
    'Fixed a test so releases stop getting stuck.', 'CI now finishes sooner.',
    'Release workflow is safer.', 'Pipeline changes.', 'Added proof for chat replies.',
  ]) {
    assert.throws(() => checkFragments({}, { [name]: line }, [name]), /specific user-visible change/, line);
  }
  for (const line of [
    'Switching chats is faster.', 'Dictation shortcuts keep working when keys queue up.',
    'Image captions no longer hide replies.', 'Dialogs match your chosen colors.',
    'The update card explains each change.',
  ]) assert.doesNotThrow(() => checkFragments({}, { [name]: line }, ['src/example.zig', name]));
});

test('IGSH-1095 Zig test-only repairs need no invented product note but runtime edits still do', t => {
  const file = 'src/browser.zig';
  const runtime = 'pub fn status() []const u8 { return "connected"; }\n';
  const before = `${runtime}test "health" {\n    const state = "opening";\n    _ = state;\n}\n`;
  const fixed = `${runtime}test "health" {\n    const text = "} test \\"quoted\\" {";\n    if (true) { _ = text; }\n}\n`;
  const r = repo(t, { ...base(), [file]: before });
  r.write({ [file]: fixed });
  expectKind(r.check(r.initial, r.commit()), 'CODE', 0);
  for (const source of [
    fixed.replace('return "connected"', 'return "opening"'),
    fixed + 'pub const deadline = 90000;\n',
    'pub const deadline = 90000;\n' + fixed,
    fixed.replace('pub fn status()', 'pub fn changedStatus()'),
    'pub const config = struct { test "nested" { unreachable; } };\n',
  ]) {
    r.write({ [file]: source });
    const result = r.check(r.initial, r.commit());
    assert.equal(result.status, 1, result.stdout + result.stderr);
    assert.match(result.stderr, /App code changed/);
  }
  r.write({ [file]: `${runtime}test { const char = '}'; _ = char; }\n` });
  expectKind(r.check(r.initial, r.commit()), 'CODE', 0);
  r.write({ [file]: runtime });
  expectKind(r.check(r.initial, r.commit()), 'CODE', 0);
  r.git('rm', file);
  const deleted = r.check(r.initial, r.commit());
  assert.equal(deleted.status, 1);
  assert.match(deleted.stderr, /App code changed/);
});

test('HYCI-158 attributes only the reviewed browser focus merge', () => {
  const commit = { sha: 'a0a4f4e0b177c3a413976bd4e40f7334b5f7f83a', subject: 'Merge pull request #845 from valentinyeo/ci-runner-1/hyci-158' };
  const ticketTitles = { ...titles, 'HYCI-158': '[INFRA] Prove the original browser focus regression' };
  let generated;
  assert.doesNotThrow(() => { generated = buildChangelog(base(), 'v0.28.1600', [], [commit], ticketTitles); });
  assert.match(generated, /\.ticket = "HYCI-158"/);
  const warnings = [];
  const unreviewed = buildChangelog(base(), 'v0.28.1600', [], [{ ...commit, sha: 'a0a4f4e0b177c3a413976bd4e40f7334b5f7f83b' }], ticketTitles, line => warnings.push(line));
  assert.match(unreviewed, /\.ticket = "no-ticket"/);
  assert.deepEqual(warnings, ['v0.28.1600: commit a0a4f4e has no ticket key; publishing its line without a link']);
});

test('HYCI-168 attributes only the reviewed Windows resources merge', () => {
  const commit = { sha: 'ed1a8bb96c8c2d57abacf4b62912a7c95f54c8e1', subject: 'Merge pull request #831' };
  const ticketTitles = { ...titles, 'HYCI-168': '[INFRA] Stop releases with growing Windows resources' };
  let generated;
  assert.doesNotThrow(() => {
    generated = buildChangelog(base(), 'v0.28.1600', [], [commit], ticketTitles);
  });
  assert.match(generated, /\.ticket = "HYCI-168"/);
  const warnings = [];
  const unreviewed = buildChangelog(base(), 'v0.28.1600', [], [{ ...commit, sha: 'ed1a8bb96c8c2d57abacf4b62912a7c95f54c8e2' }], ticketTitles, line => warnings.push(line));
  assert.match(unreviewed, /\.ticket = "no-ticket"/);
  assert.deepEqual(warnings, ['v0.28.1600: commit ed1a8bb has no ticket key; publishing its line without a link']);
});

test('IGSH-1732 attributes the reviewed repository picker merge before publishing', () => {
  const files = { ...base(), 'changelog.d/IGSH-1528-repositories.md': 'Choose project folders across every server.\n' };
  const commits = [{ sha: '03c8a7198930c20e5c4a57bd9799cd2e73b5312c', subject: "Merge remote-tracking branch 'origin/master' into HEAD" }];
  let generated;
  assert.doesNotThrow(() => {
    generated = buildChangelog(files, 'v0.28.1600', [], commits, { ...titles, 'IGSH-1528': 'Choose repository folders across every server' });
  });
  assert.match(generated, /\.ticket = "IGSH-1528"/);
  assert.match(generated, /IGSH-1528 Choose repository folders across every server/);
});

test('IGSH-1113 retains historical ticket titles and validates every fragment', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const maintenance = { 'changelog.d/IGSH-127-maintenance.md': 'Fixed a test so releases stop getting stuck.\n' };
  const product = { 'changelog.d/IGSH-154-chat.md': 'Switching chats is faster.\nAdded proof for chat replies.\n' };
  const latest = { 'changelog.d/IGSH-212-update.md': 'The update card explains each change.\n' };
  const history = [
    { tag: 'v0.28.896', files: base() },
    { tag: 'v0.28.897', files: { ...base(), ...maintenance } },
    { tag: 'v0.28.898', files: { ...base(), ...maintenance, ...product } },
    { tag: 'v0.28.899', files: { ...base(), ...maintenance, ...product, 'changelog.d/IGSH-221-maintenance.md': 'Pipeline changes.\n' } },
  ];
  const files = { ...history.at(-1).files, ...latest };
  const saved = structuredClone({ files, history });
  const generated = buildChangelog(files, 'v0.28.900', history);
  assert.deepEqual(releaseNotes(generated, 'v0.28.900'), {
    version: '0.28.900', releases: [
      release('0.28.900', 'IGSH-212'),
      release('0.28.899', 'IGSH-221'),
      release('0.28.898', 'IGSH-154'),
      release('0.28.897', 'IGSH-127'),
      release('0.28.735', 'IGSH-240'),
    ],
  });
  assert.deepEqual({ files, history }, saved);
  assert.throws(() => buildChangelog(history.at(-1).files, 'v0.28.900', history), /No unpublished product changes/);
  assert.throws(() => buildChangelog({ ...files, 'changelog.d/IGSH-224-empty.md': ' \n' }, 'v0.28.900', history), /Fragment has no text/);
  const invalid = [...history, { tag: 'v0.28.899', files: { ...files, 'changelog.d/IGSH-228-empty.md': ' \n' } }];
  assert.throws(() => buildChangelog(files, 'v0.28.900', invalid), /Fragment has no text/);
});

test('IGSH-1115 failed tags cannot consume unpublished product notes', async t => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const r = repo(t);
  r.git('tag', 'v0.28.735');
  r.write({ 'changelog.d/IGSH-246-recovered.md': 'Your chats keep their saved order.\n' });
  r.commit();
  r.git('tag', 'v0.28.736');
  r.git('tag', 'v0.28.737');
  const built = spawnSync(process.execPath, [tool, 'build', 'v0.28.738', JSON.stringify(['v0.28.735'])], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(built.status, 0, built.stderr);
  const written = fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8');
  assert.deepEqual(releaseNotes(written, 'v0.28.738'), {
    version: '0.28.738', releases: [
      release('0.28.738', 'IGSH-246'),
      release('0.28.735', 'IGSH-240'),
    ],
  });
  assert.doesNotMatch(written, /\.ver = "0\.28\.73[67]"/);
  assert.equal(fs.readFileSync(path.join(r.dir, 'changelog.d/IGSH-246-recovered.md'), 'utf8'), 'Your chats keep their saved order.\n');
});

test('build fetches a newly published tag without changing HEAD or consuming failed tags', { skip: process.platform === 'win32' }, async t => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const r = repo(t);
  r.git('tag', 'v0.28.735');
  r.write({ 'changelog.d/IGSH-127-published.md': 'Previously published change.\n' });
  const published = r.commit();
  r.write({ 'changelog.d/IGSH-154-new.md': 'New release change.\n' });
  const head = r.commit();
  const clone = path.join(r.dir, '.git', 'fixture-clone');
  r.git('clone', '--no-hardlinks', r.dir, clone);
  r.git('tag', 'v0.28.736', published);
  r.git('tag', 'v0.28.737', head);
  const bin = path.join(r.dir, '.git', 'fixture-bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), '#!/usr/bin/env node\nprocess.stdout.write("v0.28.735\\nv0.28.736\\n");\n', { mode: 0o755 });
  const env = { ...process.env, PATH: bin + path.delimiter + process.env.PATH };
  const built = spawnSync(process.execPath, [tool, 'build', 'v0.28.738'], { cwd: clone, encoding: 'utf8', env });
  assert.equal(built.status, 0, built.stderr);
  const git = (...args) => execFileSync('git', args, { cwd: clone, encoding: 'utf8' }).trim();
  assert.equal(git('rev-parse', 'HEAD'), head);
  assert.equal(git('rev-parse', 'refs/tags/v0.28.736^{commit}'), published);
  assert.deepEqual(releaseNotes(fs.readFileSync(path.join(clone, 'src/changelog.zig'), 'utf8'), 'v0.28.738'), {
    version: '0.28.738', releases: [
      release('0.28.738', 'IGSH-154'),
      release('0.28.736', 'IGSH-127'),
      release('0.28.735', 'IGSH-240'),
    ],
  });
  git('remote', 'remove', 'origin');
  fs.writeFileSync(path.join(clone, 'src/changelog.zig'), changelog);
  const offline = spawnSync(process.execPath, [tool, 'build', 'v0.28.738', JSON.stringify(['v0.28.735', 'v0.28.736'])], { cwd: clone, encoding: 'utf8' });
  assert.equal(offline.status, 0, offline.stderr);
});

test('IGSH-1115 production history ignores failed tags without moving their product notes into failed versions', { skip: process.platform === 'win32' }, async t => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const r = repo(t);
  r.git('tag', 'v0.28.735');
  r.write({ 'changelog.d/IGSH-246-recovered.md': 'Your chats keep their saved order.\n' });
  r.commit();
  r.git('tag', 'v0.28.736');
  r.git('tag', 'v0.28.737');
  const bin = path.join(r.dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'gh'), '#!/usr/bin/env node\nprocess.stdout.write("v0.28.735\\n");\n', { mode: 0o755 });
  const built = spawnSync(process.execPath, [tool, 'build', 'v0.28.738'], {
    cwd: r.dir, encoding: 'utf8', env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH },
  });
  assert.equal(built.status, 0, built.stderr);
  assert.deepEqual(releaseNotes(fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8'), 'v0.28.738'), {
    version: '0.28.738', releases: [
      release('0.28.738', 'IGSH-246'),
      release('0.28.735', 'IGSH-240'),
    ],
  });
});


test('IGSH-1131 refuses an empty release and names ticketed maintenance', () => {
  assert.throws(() => stampTree(base(), '0.28.986'), /No unpublished product changes/);
  const stamp = stampTree({ ...base(), 'changelog.d/IGSH-252-check.md': 'Fixed a test so releases stop getting stuck.\n' }, '0.28.986');
  assert.ok(stamp.files['src/changelog.zig'].includes(line('IGSH-252')));
});

test('IGSH-1131 pending notes include only changed unpublished product fragments', t => {
  const r = repo(t);
  r.git('tag', 'v0.28.735');
  r.write({ 'changelog.d/IGSH-252-chat.md': 'Your chats keep their saved order.\n' });
  const product = r.commit();
  const pending = rev => spawnSync(process.execPath, [tool, 'pending', 'v0.28.735', rev], { cwd: r.dir, encoding: 'utf8' });
  const result = pending(product);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'Your chats keep their saved order.');
  r.git('tag', 'v0.28.736');
  r.write({ 'changelog.d/IGSH-278-check.md': 'Fixed a test so releases stop getting stuck.\n' });
  const maintenance = r.commit();
  const quiet = spawnSync(process.execPath, [tool, 'pending', 'v0.28.736', maintenance], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(quiet.status, 0, quiet.stderr);
  assert.equal(quiet.stdout, '');
  assert.equal(pending(maintenance).stdout.trim(), 'Your chats keep their saved order.');
});

test('IGSH-1243 build reads ticketed commits between published tags', async t => {
  const { releaseNotes } = await import('./release-notes.mjs');
  for (const subject of ['IGSH-1111: Repair checks', 'IGSH-1111, IGSH-1112: Repair checks', 'Repair checks']) {
    const r = repo(t);
    r.git('tag', 'v0.29.1');
    r.write({ 'tools/repair.txt': 'Updated checks.\n' });
    r.git('add', 'tools/repair.txt');
    r.git('commit', '-m', subject);
    const sha = r.git('rev-parse', 'HEAD');
    const result = spawnSync(process.execPath, [tool, 'build', 'v0.29.2', '["v0.29.1"]'], { cwd: r.dir, encoding: 'utf8' });
    if (subject.startsWith('IGSH-')) {
      assert.equal(result.status, 0, result.stderr);
      const notes = releaseNotes(fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8'), 'v0.29.2');
      const ids = subject.split(':')[0].split(', ');
      assert.deepEqual(notes.releases[0], release('0.29.2', ...ids));
    } else {
      assert.equal(result.status, 0, result.stderr);
      assert.match(result.stderr, new RegExp(`Release notes warning: v0\\.29\\.2: commit ${sha.slice(0, 7)} has no ticket key`));
      assert.deepEqual(releaseNotes(fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8'), 'v0.29.2').releases[0], { version: '0.29.2', changes: ['Repair checks'], tickets: [null] });
    }
  }
});

test('tests after: a CI-board ticket releases without product notes', async t => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const r = repo(t);
  r.git('tag', 'v0.29.1');
  r.write({ 'tools/repair.txt': 'Updated checks.\n' });
  r.git('add', 'tools/repair.txt');
  r.git('commit', '-m', 'HYCI-101: share one Windows app build cache');
  const result = spawnSync(process.execPath, [tool, 'build', 'v0.29.2', '["v0.29.1"]'], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const source = fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8');
  assert.deepEqual(releaseNotes(source, 'v0.29.2').releases[0], { version: '0.29.2', changes: [], tickets: [] });
  assert.doesNotMatch(source, /Checks and fixes, no visible change/);
});

test('tests after: a CI-board ticket cannot carry a product line', async t => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const r = repo(t);
  r.git('tag', 'v0.29.1');
  r.write({ 'changelog.d/HYCI-101-repair.md': 'Typing feels faster.\n' });
  r.git('add', 'changelog.d/HYCI-101-repair.md');
  r.git('commit', '-m', 'HYCI-101: repair the shared build cache');
  const result = spawnSync(process.execPath, [tool, 'build', 'v0.29.2', '["v0.29.1"]'], { cwd: r.dir, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const source = fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8');
  assert.equal(source.includes('Typing feels faster.'), false);
  assert.deepEqual(releaseNotes(source, 'v0.29.2').releases[0], { version: '0.29.2', changes: [], tickets: [] });
  const forged = 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.1100", .items = &.{\n        .{ .text = "Typing feels faster.", .ticket = "HYCI-101" },\n    } },\n};\n';
  const warnings = [];
  assert.deepEqual(releaseNotes(forged, 'v0.28.1100', line => warnings.push(line)).releases[0], { version: '0.28.1100', changes: ['Typing feels faster.'], tickets: [null] });
  assert.deepEqual(warnings, ['Release 0.28.1100: HYCI-101 has no title after its key; publishing its line without a link']);
});

test('SOFT-2803 attributes the untagged master commits since v0.28.1762', () => {
  const reviewed = {
    'ee394be0c178378919a6d4d3499329f5d3636691': ['docs(verify): complete the desktop feature map (SOFT-2567 Part H) (#1074)', '2567'],
    '2452e248a2fe8ff78be0b342273b7677dd7c3f52': ['fix(chat): load inne commands as the tab owner (SOFT-2584) (#1080)', '2584'],
  };
  for (const [sha, [subject, number]] of Object.entries(reviewed)) {
    const ticketTitles = { ...titles, [`IGSH-${number}`]: 'Reviewed release attribution', [`SOFT-${number}`]: 'Reviewed release attribution' };
    let generated;
    assert.doesNotThrow(() => { generated = buildChangelog(base(), 'v0.28.1781', [], [{ sha, subject }], ticketTitles); });
    assert.match(generated, new RegExp(`\\.ticket = "[A-Z]+-${number}"`));
  }
});

test('SOFT-2958 builds release notes for the ticketless verifier merge on master', () => {
  const commit = { sha: '9ea1f1e25baa3c00a8c0b35906d965bffdcdb1b9', subject: 'ci(verifier): never block a PR on a journey or check already red on master (#1129)' };
  const ticketTitles = { ...titles, 'IGSH-2902': 'Publish master without a release journey gate', 'SOFT-2902': 'Publish master without a release journey gate' };
  let generated;
  assert.doesNotThrow(() => { generated = buildChangelog(base(), 'v0.28.1800', [], [commit], ticketTitles); });
  assert.match(generated, /\.ticket = "IGSH-2902"/);
  assert.match(generated, /\.text = "IGSH-2902 Publish master without a release journey gate"/);
  assert.match(generated, /\.ver = "0\.28\.1800"/);
});

test('SOFT-2958 gives every master commit since v0.28.1762 a ticket or reviewed attribution', t => {
  const lead = /^([A-Z][A-Z0-9]*-\d+(?:,\s*[A-Z][A-Z0-9]*-\d+)*)(?::|,|\s)/;
  const history = ['origin/master', 'refs/remotes/origin/master', 'master', 'HEAD']
    .map(ref => spawnSync('git', ['log', '--format=%H%x09%s', `v0.28.1762..${ref}`], { cwd: root, encoding: 'utf8' }))
    .find(result => result.status === 0 && result.stdout.trim());
  if (!history) return t.skip('this checkout has no history from v0.28.1762 to master');
  const commits = history.stdout.split('\n').filter(Boolean).map(line => {
    const at = line.indexOf('\t');
    return { sha: line.slice(0, at), subject: line.slice(at + 1) };
  });
  const untagged = commits.filter(commit => !lead.test(commit.subject) && !reviewedCommits[commit.sha]);
  assert.deepEqual(untagged, [], 'add every ticketless commit to reviewedCommits before the release');
});
