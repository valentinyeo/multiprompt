import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const checker = fileURLToPath(new URL('./check-commit-identities.mjs', import.meta.url));
const bot = '348741585+software-factory-runners[bot]@users.noreply.github.com';
const valentin = '3296316+valentinyeo@users.noreply.github.com';
const github = 'noreply@github.com';
const oldWorker = '2713+soft-worker@users.noreply.github.com';

function fixture(t) {
  assert.ok(existsSync(checker), 'PR commit identity enforcement must provide its CLI');
  const cwd = mkdtempSync(join(tmpdir(), 'commit-identities-'));
  t.after(() => rmSync(cwd, { recursive: true, force: true }));
  const env = { ...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null' };
  const git = (...args) => execFileSync('git', args, { cwd, env, encoding: 'utf8' }).trim();
  git('init', '--quiet');
  const tree = git('mktree');
  function commit({ author = bot, committer = bot, message = 'Clean commit', parents = [] } = {}) {
    return execFileSync('git', ['commit-tree', tree, ...parents.flatMap(parent => ['-p', parent])], {
      cwd,
      encoding: 'utf8',
      input: message,
      env: { ...env, GIT_AUTHOR_NAME: 'Fixture', GIT_AUTHOR_EMAIL: author, GIT_COMMITTER_NAME: 'Fixture', GIT_COMMITTER_EMAIL: committer },
    }).trim();
  }
  const base = commit({ author: oldWorker });
  const check = (...refs) => spawnSync(process.execPath, [checker, ...refs], { cwd, env, encoding: 'utf8' });
  return { cwd, base, git, commit, check };
}

function rejected(result, reason) {
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, reason);
  assert.ok(result.stderr.includes(`software-factory-runners[bot] <${bot}>`));
  for (const email of [bot, valentin, github]) assert.ok(result.stderr.includes(email));
}

test('accepts all allowed author and committer identities and excludes base history', t => {
  const { base, commit, check } = fixture(t);
  let head = base;
  for (const author of [bot, valentin, github]) {
    for (const committer of [bot, valentin, github]) head = commit({ author, committer, parents: [head] });
  }
  const result = check(base, head);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /OK \(9 commits\)/);
});

test('rejects the PR 1094 identity even when followed by a clean commit', t => {
  const { base, commit, check } = fixture(t);
  const bad = commit({ author: oldWorker, committer: oldWorker, message: 'fix(chat-focus): restore missing sidebar palette rows', parents: [base] });
  const head = commit({ parents: [bad] });
  const result = check(base, head);
  rejected(result, /author email is not allowed/);
  assert.match(result.stderr, /committer email is not allowed/);
  assert.ok(result.stderr.includes(bad));
});

for (const role of ['author', 'committer']) {
  test(`rejects unlisted ${role} emails without trusting mailmap`, t => {
    const { cwd, base, commit, check } = fixture(t);
    writeFileSync(join(cwd, '.mailmap'), `Fixture <${bot}> Fixture <${oldWorker}>\n`);
    const head = commit({ [role]: oldWorker, parents: [base] });
    rejected(check(base, head), new RegExp(`${role} email is not allowed`));
  });
}

for (const line of ['Co-authored-by: Fixture', '  cO-aUtHoReD-bY: Fixture']) {
  test(`rejects a message line ${JSON.stringify(line)}`, t => {
    const { base, commit, check } = fixture(t);
    const head = commit({ message: `Subject\n\n${line} <${bot}>\n`, parents: [base] });
    rejected(check(base, head), /Co-authored-by lines are forbidden/);
  });
}

test('checks merged side-branch commits, not only the first-parent chain', t => {
  const { base, commit, check } = fixture(t);
  const clean = commit({ parents: [base] });
  const bad = commit({ author: oldWorker, parents: [base] });
  const head = commit({ parents: [clean, bad] });
  rejected(check(base, head), /author email is not allowed/);
});

test('does not trust replacement objects to hide the original identity', t => {
  const { base, git, commit, check } = fixture(t);
  const bad = commit({ author: oldWorker, parents: [base] });
  const replacement = commit({ parents: [base] });
  git('replace', bad, replacement);
  rejected(check(base, bad), /author email is not allowed/);
});

test('fails closed for missing arguments or unavailable revisions', t => {
  const { base, check } = fixture(t);
  assert.equal(check().status, 1);
  assert.equal(check(base, 'missing-revision').status, 1);
});

test('rejects the bad commit a master push introduces', t => {
  const { base, commit, check } = fixture(t);
  const before = commit({ parents: [base] });
  const bad = commit({ message: 'SOFT-2776: Squash a branch\n\nCo-authored-by: Fixture <' + bot + '>\n', parents: [before] });
  rejected(check(before, bad), /Co-authored-by lines are forbidden/);
});

test('accepts a master push whose new commit is clean', t => {
  const { base, commit, check } = fixture(t);
  const before = commit({ author: oldWorker, parents: [base] });
  const head = commit({ message: 'SOFT-2776: Squash a branch\n\nUndo: revert this commit.\n', parents: [before] });
  const result = check(before, head);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /OK \(1 commits\)/);
});

test('a branch that merged master checks only the commits it adds', t => {
  const { base, commit, check } = fixture(t);
  const master = commit({ author: oldWorker, committer: oldWorker, message: 'Old master commit\n\nCo-authored-by: Fixture <' + bot + '>\n', parents: [base] });
  const branch = commit({ message: 'SOFT-2776: Fix the check', parents: [base] });
  const merged = commit({ message: 'Merge master into the branch', parents: [branch, master] });
  const result = check(master, merged);
  assert.equal(result.status, 0, result.stderr);
});

test('refuses a base that is not an ancestor of the head', t => {
  const { base, commit, check } = fixture(t);
  const left = commit({ message: 'Left', parents: [base] });
  const right = commit({ message: 'Right', parents: [base] });
  const result = check(left, right);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /is not an ancestor/);
});

test('master pushes run the identity check over only the pushed commits', () => {
  const workflow = readFileSync(new URL('../.github/workflows/test.yml', import.meta.url), 'utf8');
  const step = workflow.split('- name: Check every pushed commit identity\n')[1]?.split('\n      - name: ')[0] ?? '';
  assert.match(step, /github\.event_name == 'pull_request'.*github\.event_name == 'push'/);
  assert.match(step, /github\.event\.before/);
  assert.match(step, /git merge-base/);
  assert.match(step, /node tools\/check-commit-identities\.mjs/);
});
