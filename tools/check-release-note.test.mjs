import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { escapedNote, newestReleaseTag } from './check-release-note.mjs';
import { stampTree } from './version-stamp.mjs';
import { loadTicketTitles } from './ticket-titles.mjs';

const tool = fileURLToPath(new URL('./check-release-note.mjs', import.meta.url));
const main = 'pub const APP_VERSION = "0.28.735";\n';
const changelog = 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.735", .items = &.{\n        .{ .text = "Existing.", .ticket = "IGSH-1" },\n    } },\n};\n';
const base = () => ({ 'src/main.zig': main, 'src/changelog.zig': changelog, 'changelog.d/README.md': 'Documentation.\n' });

function repo(t, files = base()) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'check-release-note-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'Release Note Test');
  git('config', 'user.email', 'release-note@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  git('config', 'core.autocrlf', 'false');
  const write = tree => {
    for (const [name, content] of Object.entries(tree)) {
      fs.mkdirSync(path.dirname(path.join(dir, name)), { recursive: true });
      fs.writeFileSync(path.join(dir, name), content);
    }
  };
  const commit = message => {
    git('add', '-A');
    git('commit', '-m', message);
    return git('rev-parse', 'HEAD');
  };
  const remove = name => {
    fs.rmSync(path.join(dir, name), { force: true });
    git('rm', '--cached', '--ignore-unmatch', name);
  };
  const run = () => spawnSync(process.execPath, [tool], { cwd: dir, encoding: 'utf8', env: { ...process.env, GITHUB_HEAD_REF: '', GITHUB_REF_NAME: '' } });
  write(files);
  const initial = commit('Initial');
  return { dir, git, write, commit, remove, run, initial };
}

test('the newest release tag is the highest version, not the closest one', () => {
  assert.equal(newestReleaseTag(['v0.28.9', 'v0.28.10', 'v1.0.0', 'nightly', 'v0.28.735']), 'v1.0.0');
  assert.equal(newestReleaseTag(['v0.28.9', 'v0.28.10', 'nightly']), 'v0.28.10');
  assert.equal(newestReleaseTag(['nightly', 'v0.28']), null);
});

test('a No-Note line needs a reason and nothing else', () => {
  assert.equal(escapedNote(['IGSH-1: Move code', 'No-Note: pure rename']), true);
  assert.equal(escapedNote(['No-Note:']), false);
  assert.equal(escapedNote(['no-note: pure rename']), false);
  assert.equal(escapedNote([' Undo: No-Note: pure rename']), false);
});

test('a shipped change since the last release fails without a new fragment', t => {
  const r = repo(t);
  r.git('tag', 'v0.28.735');
  r.write({ 'src/main.zig': `${main}pub const faster = 1;\n` });
  r.commit('IGSH-154: Speed up startup');
  const result = r.run();
  assert.equal(result.status, 1, result.stdout);
  assert.match(result.stderr, /App code changed: add changelog\.d/);
  assert.match(result.stderr, /v0\.28\.735/);
  assert.match(result.stderr, /src\/main\.zig/);
  assert.match(result.stderr, /No-Note/);
});

test('a new fragment passes and a released change before the tag is not counted', t => {
  const r = repo(t);
  r.write({ 'src/main.zig': `${main}pub const shipped = 1;\n` });
  r.commit('IGSH-1: Ship a change');
  r.git('tag', 'v0.28.735');
  r.write({ 'tools/release-note.mjs': 'export const ok = true;\n' });
  r.commit('IGSH-154: Repair the check');
  assert.equal(r.run().status, 0);
  r.write({ 'src/main.zig': `${main}pub const faster = 1;\n`, 'changelog.d/IGSH-3-startup.md': 'The app opens faster.\n' });
  r.commit('IGSH-3: Speed up startup');
  const result = r.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'OK v0.28.735');
});

test('an extension change is a shipped change and needs a note', t => {
  const r = repo(t);
  r.git('tag', 'v0.28.735');
  r.write({ 'extension/manifest.json': '{"version":"1.2.3"}\n' });
  r.commit('IGSH-154: Repair the bridge');
  const result = r.run();
  assert.equal(result.status, 1, result.stdout);
  assert.match(result.stderr, /App code changed/);
});

test('a No-Note commit line passes a change with no visible effect', t => {
  const r = repo(t);
  r.git('tag', 'v0.28.735');
  r.write({ 'src/main.zig': `${main}pub const renamed = 1;\n` });
  r.commit('IGSH-154: Rename a helper\n\nNo-Note: pure rename, no behaviour change');
  const result = r.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'No-Note v0.28.735');
});

test('a release stamp passes without a note', t => {
  const r = repo(t);
  r.write({ 'changelog.d/IGSH-154-startup.md': 'The app opens faster.\n' });
  r.commit('IGSH-154: Speed up startup');
  r.git('tag', 'v0.28.735');
  const stamp = stampTree({ ...base(), 'src/main.zig': main, 'changelog.d/IGSH-154-startup.md': 'The app opens faster.\n' });
  const titles = loadTicketTitles();
  assert.ok(stamp.files['src/changelog.zig'].includes(`IGSH-154 ${titles['IGSH-154']}`));
  r.write(stamp.files);
  for (const file of stamp.removed) r.remove(file);
  r.commit(`v${stamp.version}: release IGSH-154`);
  const result = r.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'STAMP v0.28.735');
});

test('a repository with no release tag skips the check', t => {
  const r = repo(t);
  r.write({ 'src/main.zig': `${main}pub const faster = 1;\n` });
  r.commit('IGSH-154: Speed up startup');
  const result = r.run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'SKIP no release tag');
});

test('the Tests job runs the check beside the version rule with full history', () => {
  const workflow = fs.readFileSync(new URL('../.github/workflows/test.yml', import.meta.url), 'utf8');
  assert.match(workflow, /- name: Check a shipped change carries a release note\n        if: steps\.paths\.outputs\.heavy == 'true'\n        shell: bash\n        run: node tools\/check-release-note\.mjs\n/);
  assert.match(workflow, /tools\/update-card-restart\.test\.js tools\/check-release-note\.test\.mjs/);
});
