import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
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
