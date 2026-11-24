import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../', import.meta.url));
const stampTool = path.join(root, 'tools/version-stamp.mjs');
const noteTool = path.join(root, 'tools/check-release-note.mjs');
const fixtures = path.join(root, 'tools/fixtures/MUBO-279');
const readFixture = name => JSON.parse(fs.readFileSync(path.join(fixtures, name), 'utf8'));
const outage = readFixture('pr-1352.json');
const named = readFixture('pr-1354.json');
const main = 'pub const APP_VERSION = "0.28.1913";\n';
const changelog = 'pub const CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.1913", .items = &.{\n        .{ .text = "IGSH-240 Choose project folders across every server", .ticket = "IGSH-240" },\n    } },\n};\n';
const escape = text => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function neutralEnv() {
  const env = { ...process.env };
  for (const key of Object.keys(env)) if (/^GITHUB_(?:HEAD_REF|BASE_REF|REF|REF_NAME)$/.test(key)) delete env[key];
  return env;
}

function repo(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mubo-279-revert-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'MUBO-279 Revert Test');
  git('config', 'user.email', 'mubo-279@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  git('config', 'core.autocrlf', 'false');
  const write = tree => {
    for (const [name, text] of Object.entries(tree)) {
      fs.mkdirSync(path.dirname(path.join(dir, name)), { recursive: true });
      fs.writeFileSync(path.join(dir, name), text);
    }
  };
  const commit = message => {
    git('add', '-A');
    execFileSync('git', ['commit', '-q', '-F', '-'], { cwd: dir, input: `${message}\n`, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
    return git('rev-parse', 'HEAD');
  };
  const run = (tool, args, extra = {}) => spawnSync(process.execPath, [tool, ...args], { cwd: dir, encoding: 'utf8', env: { ...neutralEnv(), ...extra } });
  write({ 'src/main.zig': main, 'src/changelog.zig': changelog });
  git('add', '-A');
  git('commit', '-qm', 'Publish the baseline release');
  const baseline = git('rev-parse', 'HEAD');
  return { dir, git, write, commit, run, baseline };
}

function shippedChange(files) {
  return Object.fromEntries(files.map(file => [file, file.startsWith('changelog.d/') ? 'The chat report shows which chats cannot reach their host.\n' : 'const report = true;\n']));
}

function outageBranch(t) {
  const r = repo(t);
  r.write(shippedChange(outage.revertedFiles));
  const shipped = r.commit(outage.revertedCommit.subject);
  r.git('revert', '--no-commit', shipped);
  const head = r.commit(outage.commitMessage);
  return { ...r, shipped, head };
}

test('the recorded outage revert passes the release check without a changelog note', t => {
  const r = outageBranch(t);
  assert.doesNotMatch(outage.commitMessage, /This reverts commit/);
  assert.deepEqual(r.git('diff', '--name-only', '--no-renames', r.shipped, r.head).split('\n').filter(Boolean).sort(), [...outage.revertedFiles].sort());
  const check = r.run(stampTool, ['check', r.shipped, r.head]);
  assert.equal(check.error, undefined);
  assert.equal(check.status, 0, check.stdout + check.stderr);
  assert.equal(check.stdout.trim(), 'CODE');
  assert.doesNotMatch(check.stderr, /App code changed/);
});

test('the revert decision never reads the branches the outage pull requests used', t => {
  const r = outageBranch(t);
  for (const branch of [outage.branch, named.branch, 'ceo/SOFT-3134']) {
    const check = r.run(stampTool, ['check', r.shipped, r.head], { GITHUB_HEAD_REF: branch, GITHUB_REF_NAME: branch, GITHUB_REF: `refs/heads/${branch}` });
    assert.equal(check.status, 0, `${branch}: ${check.stdout}${check.stderr}`);
    assert.equal(check.stdout.trim(), 'CODE');
  }
});

test('a shipped change carrying the outage commit message still needs a note', t => {
  const r = repo(t);
  r.write(shippedChange(outage.revertedFiles));
  const shipped = r.commit(outage.revertedCommit.subject);
  r.git('revert', '--no-commit', shipped);
  r.write({ 'src/repair.zig': 'const repair = true;\n' });
  const head = r.commit(outage.commitMessage);
  for (const extra of [{}, { GITHUB_HEAD_REF: named.branch, GITHUB_REF_NAME: named.branch }]) {
    const check = r.run(stampTool, ['check', shipped, head], extra);
    assert.equal(check.status, 1, check.stdout);
    assert.match(check.stderr, new RegExp(escape(outage.expectedError)));
  }
});

test('a branch that reverts and also changes something still needs a note', t => {
  const r = outageBranch(t);
  r.write({ 'src/follow-up.zig': 'const followUp = true;\n' });
  const head = r.commit('MUBO-279: Follow up on the outage');
  const check = r.run(stampTool, ['check', r.shipped, head]);
  assert.equal(check.status, 1, check.stdout);
  assert.match(check.stderr, new RegExp(escape(outage.expectedError)));
});

test('the shipped change check accepts the recorded outage revert without a note', t => {
  const r = repo(t);
  r.write(shippedChange(outage.revertedFiles));
  const shipped = r.commit(outage.revertedCommit.subject);
  r.git('tag', 'v0.28.1913', shipped);
  r.git('revert', '--no-commit', shipped);
  r.commit(outage.commitMessage);
  const result = r.run(noteTool, [], { GITHUB_HEAD_REF: named.branch, GITHUB_REF_NAME: named.branch });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /^REVERT/m);
});
