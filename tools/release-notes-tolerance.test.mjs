import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { releaseNotes } from './release-notes.mjs';
import { resolveReleaseTitles } from './ticket-titles.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const tool = path.join(root, 'tools/version-stamp.mjs');
const revertBranch = JSON.parse(fs.readFileSync(path.join(root, 'tools/fixtures/MUBO-279/pr-1354.json'), 'utf8'));
const main = 'pub const APP_VERSION = "0.28.1913";\n';
const changelog = 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.1913", .items = &.{\n        .{ .text = "IGSH-240 Choose project folders across every server", .ticket = "IGSH-240" },\n    } },\n};\n';
const publishedTags = '["v0.28.1913"]';

function fixture(t, extraEnv = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-notes-tolerance-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'Release Notes Tolerance Test');
  git('config', 'user.email', 'release-notes-tolerance@example.invalid');
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
  for (const key of ['GITHUB_HEAD_REF', 'GITHUB_REF_NAME', 'GITHUB_REF', 'GITHUB_BASE_REF']) delete env[key];
  const run = (...args) => spawnSync(process.execPath, [tool, ...args], { cwd: dir, encoding: 'utf8', env: { ...env, ...extraEnv } });
  write({ 'src/main.zig': main, 'src/changelog.zig': changelog });
  const initial = commit('Publish the baseline release');
  git('tag', 'v0.28.1913', initial);
  return { dir, git, write, commit, run, initial };
}

function released(t, subject) {
  const r = fixture(t);
  r.write({ 'tools/note.txt': `${subject}\n` });
  r.commit(subject);
  const build = r.run('build', 'v0.28.1914', publishedTags);
  const source = fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8');
  return { r, build, source };
}

const unlinkedCases = [
  ['an unknown ticket prefix', 'XYZ-1: Tidy the sidebar', 'Tidy the sidebar'],
  ['another board key', 'VSTA-162: Block heavy local builds and tests in this repo\'s chats', 'Block heavy local builds and tests in this repo\'s chats'],
  ['a typo ticket key', 'IGHS-12: Fix the update card', 'Fix the update card'],
  ['a missing ticket', 'IGSH-9999: Switch AI when a plan runs out', 'Switch AI when a plan runs out'],
];

for (const [name, subject, text] of unlinkedCases) {
  test(`${name} never blocks the release`, t => {
    const { build, source } = released(t, subject);
    assert.equal(build.status, 0, build.stderr);
    assert.deepEqual(releaseNotes(source, 'v0.28.1914').releases[0], {
      version: '0.28.1914',
      changes: [text],
      tickets: [null],
    });
  });
}

test('a ticket that still resolves keeps its link', t => {
  const { build, source } = released(t, 'IGSH-240: Choose project folders across every server');
  assert.equal(build.status, 0, build.stderr);
  const notes = releaseNotes(source, 'v0.28.1914').releases[0];
  assert.equal(notes.tickets.length, 1);
  assert.equal(notes.tickets[0], 'https://app.hypertask.ai/detail/project-2060/240');
  assert.equal(notes.changes.length, 1);
});

test('every skipped ticket key gets one log line and the release still publishes', t => {
  const r = fixture(t);
  for (const subject of [
    "VSTA-162: Block heavy local builds and tests in this repo's chats",
    'IGSH-9999: Switch AI when a plan runs out',
    'IGSH-240: Choose project folders across every server',
  ]) {
    r.write({ 'tools/note.txt': `${subject}\n` });
    r.commit(subject);
  }
  const build = r.run('build', 'v0.28.1914', publishedTags);
  assert.equal(build.status, 0, build.stderr);
  const lines = build.stderr.split(/\r?\n/).filter(line => line.startsWith('Release notes skip '));
  assert.deepEqual(lines, [
    'Release notes skip VSTA-162: unknown-prefix',
    'Release notes skip IGSH-9999: no-token',
  ]);
  const notes = releaseNotes(fs.readFileSync(path.join(r.dir, 'src/changelog.zig'), 'utf8'), 'v0.28.1914').releases[0];
  assert.equal(notes.tickets.length, notes.changes.length);
  assert.equal(notes.tickets.filter(link => link === null).length, 2);
  assert.equal(notes.tickets.filter(link => link).length, 1);
  assert.ok(notes.changes.includes("Block heavy local builds and tests in this repo's chats"));
  assert.ok(notes.changes.includes('Switch AI when a plan runs out'));
});

const tasks = task => async () => ({ ok: true, json: async () => ({ success: true, tasks: [task] }) });
test('a ticket moved to another board publishes without a link', async () => {
  const moved = await resolveReleaseTitles(['IGSH-9999'], { 'IGSH-240': 'Kept title' }, 'token', tasks({ boardId: 11514, ticketNumber: 'HYCI-1', title: 'Other board' }));
  assert.deepEqual(moved.titles, { 'IGSH-240': 'Kept title' });
  assert.deepEqual(moved.unresolved.map(([id]) => id), ['IGSH-9999']);
});

test('a deleted ticket publishes without a link', async () => {
  const deleted = await resolveReleaseTitles(['IGSH-9999'], {}, 'token', tasks(null));
  assert.deepEqual(deleted.titles, {});
  assert.deepEqual(deleted.unresolved.map(([id]) => id), ['IGSH-9999']);
});

test('a failing ticket lookup publishes without a link', async () => {
  const requests = [
    async () => { throw new Error('network down'); },
    async () => ({ ok: false, json: async () => ({ success: false }) }),
    async () => ({ ok: true, json: async () => ({ success: true, tasks: [] }) }),
  ];
  for (const request of requests) {
    const lookup = await resolveReleaseTitles(['IGSH-9999'], { 'IGSH-240': 'Kept title' }, 'token', request);
    assert.deepEqual(lookup.titles, { 'IGSH-240': 'Kept title' });
    assert.deepEqual(lookup.unresolved.map(([id]) => id), ['IGSH-9999']);
  }
  let called = false;
  const noToken = await resolveReleaseTitles(['IGSH-9999'], {}, '', async () => {
    called = true;
    throw new Error('must not be called');
  });
  assert.equal(called, false);
  assert.deepEqual(noToken.unresolved.map(([id]) => id), ['IGSH-9999']);
});

test('the pull request check still rejects a typo ticket key', t => {
  const r = fixture(t);
  r.write({ 'changelog.d/IGHS-12-typo.md': 'The update card shows the newest change.\n' });
  const head = r.commit('IGHS-12: typo fragment');
  const check = r.run('check', r.initial, head);
  assert.equal(check.status, 1, check.stdout);
  assert.match(check.stderr, /Invalid ticket ID: IGHS-12/);
});

test('the pull request check rejects the typo key on the branch the outage revert used', t => {
  const branch = revertBranch.branch;
  const r = fixture(t, { GITHUB_HEAD_REF: branch, GITHUB_REF_NAME: branch, GITHUB_REF: `refs/heads/${branch}` });
  r.write({ [revertBranch.typoFragment]: 'The update card shows the newest change.\n' });
  const head = r.commit(revertBranch.typoCommit);
  const check = r.run('check', r.initial, head);
  assert.equal(check.status, 1, check.stdout);
  assert.match(check.stderr, new RegExp(revertBranch.expectedError));
});
