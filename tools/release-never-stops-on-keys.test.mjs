import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { releaseNotes } from './release-notes.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const tool = path.join(root, 'tools/version-stamp.mjs');
const main = 'pub const APP_VERSION = "0.28.1913";\n';
const changelog = 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.1913", .items = &.{\n        .{ .text = "IGSH-240 Choose project folders across every server", .ticket = "IGSH-240" },\n    } },\n};\n';
const publishedTags = '["v0.28.1913"]';

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-never-stops-on-keys-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'Release Key Test');
  git('config', 'user.email', 'release-key-test@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  git('config', 'core.autocrlf', 'false');
  const write = tree => {
    for (const [name, text] of Object.entries(tree)) {
      fs.mkdirSync(path.dirname(path.join(dir, name)), { recursive: true });
      fs.writeFileSync(path.join(dir, name), text);
    }
  };
  const commit = subject => {
    git('add', '-A');
    git('commit', '-m', subject);
    return git('rev-parse', 'HEAD');
  };
  const env = { ...process.env };
  delete env.HYPERTASK_AGENT_TOKEN;
  const run = (...args) => spawnSync(process.execPath, [tool, ...args], { cwd: dir, encoding: 'utf8', env });
  write({ 'src/main.zig': main, 'src/changelog.zig': changelog });
  const initial = commit('Publish the baseline release');
  git('tag', 'v0.28.1913', initial);
  return { dir, git, write, commit, run, initial };
}

function release(t, tree, subject) {
  const r = fixture(t);
  r.write(tree);
  r.commit(subject);
  const result = r.run('build', 'v0.28.1914', publishedTags);
  const source = fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8');
  return { result, source, notes: result.status === 0 ? releaseNotes(source, 'v0.28.1914').releases[0] : null };
}

test('case a: a ticket whose lookup fails still publishes a release', t => {
  const { result, notes } = release(t, {
    'tools/note.txt': 'moved ticket\n',
    'changelog.d/IGSH-2701-move-release-card.md': 'The release card moves with the chat.\n',
  }, 'IGSH-2701: Move the release card');
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /Release notes skip IGSH-2701: no-token/);
  assert.deepEqual(notes.changes, ['The release card moves with the chat.']);
  assert.deepEqual(notes.tickets, [null]);
});

test('case b: a squash title naming another board still publishes a release', t => {
  const { result, notes } = release(t, {
    'tools/note.txt': 'heavy builds\n',
  }, "VSTA-162: Block heavy local builds and tests in this repo's chats (#1327)");
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /Release notes skip VSTA-162: unknown-prefix/);
  assert.deepEqual(notes.changes, ["Block heavy local builds and tests in this repo's chats (#1327)"]);
  assert.deepEqual(notes.tickets, [null]);
});

test('case c: a title key that disagrees with the fragment key still publishes a release', t => {
  const { result, notes } = release(t, {
    'tools/note.txt': 'chat health\n',
    'changelog.d/SOFT-3140-chat-health.md': 'Chat health now reaches the update card.\n',
  }, 'SOFT-3134: Report chat health and what the PC shows (SOFT-3140) (#1311)');
  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(result.stderr, /Release notes warning/);
  assert.deepEqual(notes.tickets, [
    'https://app.hypertask.ai/detail/project-2060/3134',
    'https://app.hypertask.ai/detail/project-2060/3140',
  ]);
  assert.deepEqual(notes.changes, [
    'IGSH-3134 Show whether each chat can reach its host and display its history',
    'IGSH-3140 Show why a chat is missing from the sidebar',
  ]);
});

test('a fragment key no commit names warns and still publishes', t => {
  const { result, notes } = release(t, {
    'tools/note.txt': 'release keys\n',
    'changelog.d/IGSH-2711-release-keys.md': 'The release card shows every change.\n',
  }, 'IGSH-2712: Rename the release tool');
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /Release notes warning: v0\.28\.1914: IGSH-2711 fragment has no matching commit ticket; publishing it from its fragment text/);
  assert.deepEqual(notes.changes, ['Rename the release tool', 'The release card shows every change.']);
  assert.deepEqual(notes.tickets, [null, null]);
});
