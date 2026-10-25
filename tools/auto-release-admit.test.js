const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const workflow = fs.readFileSync(path.join(root, '.github/workflows/auto-release.yml'), 'utf8');
const oldCheck = `set -euo pipefail
sha=$(git rev-parse HEAD)
if [ "$GITHUB_EVENT_NAME" = workflow_run ] && [ "$sha" != "$TESTED_SHA" ]; then
  echo 'master has moved past the tested commit; skipping'
  exit 0
fi
echo 'ready=true'
`;

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'auto-release-admit-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  git('init', '-b', 'master');
  git('config', 'user.name', 'Release Test');
  git('config', 'user.email', 'release@example.invalid');
  git('config', 'commit.gpgsign', 'false');
  git('config', 'tag.gpgsign', 'false');
  git('config', 'core.autocrlf', 'false');
  fs.mkdirSync(path.join(dir, 'tools'));
  fs.copyFileSync(path.join(root, 'tools/release-version.mjs'), path.join(dir, 'tools/release-version.mjs'));
  git('add', '.');
  git('commit', '-m', 'previous release');
  git('tag', 'v1.2.3');
  git('commit', '--allow-empty', '-m', 'tested change');
  const sha = git('rev-parse', 'HEAD');
  git('commit', '--allow-empty', '-m', 'queued change');
  const tip = git('rev-parse', 'HEAD');
  const remote = path.join(dir, 'remote.git');
  git('clone', '--bare', dir, remote);
  git('remote', 'add', 'origin', remote);
  git('fetch', 'origin');
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  const log = path.join(dir, 'gh-log');
  fs.writeFileSync(log, '');
  fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}
const fs = require('node:fs');
fs.appendFileSync(process.env.GH_LOG, JSON.stringify(process.argv.slice(2)) + '\\n');
console.log(process.env.TEST_RUNS);
`, { mode: 0o755 });
  const run = (command, args, env = {}) => spawnSync(command, args, { cwd: dir, encoding: 'utf8', env: {
    ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, GH_LOG: log,
    GITHUB_EVENT_NAME: 'workflow_run', TESTED_SHA: sha, GITHUB_REPOSITORY: 'example/multiprompt',
    TEST_RUNS: JSON.stringify([{ databaseId: 1, event: 'push', status: 'completed', conclusion: 'success' }]), ...env,
  } });
  const admit = (tested = sha, event = 'workflow_run', env = {}) => run('bash', [path.join(root, 'tools/auto-release-admit.sh'), tested, event], env);
  return { dir, git, sha, tip, remote, log, run, admit };
}

function ready(result) {
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'ready=true\ntag=v1.2.4\n');
}

function skipped(f, sha, reason) {
  const tags = f.git('show-ref', '--tags');
  const result = f.admit(sha);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, reason);
  assert.equal(f.git('show-ref', '--tags'), tags);
}

test('master moving reproduces the old skip, but releases the tested SHA without moving master', t => {
  const f = fixture(t);
  const old = f.run('bash', ['-c', oldCheck]);
  assert.equal(old.status, 0, old.stderr);
  assert.match(old.stdout, /master has moved past the tested commit; skipping/);
  assert.doesNotMatch(old.stdout, /ready=true/);
  f.git('checkout', '--detach', f.sha);
  ready(f.admit());
  const block = workflow.match(/      - name: Tag the tested master commit\n[\s\S]*?        run: \|\n((?:          [^\n]*\n|\n)+)/);
  assert.ok(block, 'workflow must tag the admitted commit');
  const tag = f.run('bash', ['-euo', 'pipefail', '-c', block[1].split('\n').map(line => line.slice(10)).join('\n')], {
    RELEASE_TAG: 'v1.2.4', GITHUB_OUTPUT: path.join(f.dir, 'output'),
  });
  assert.equal(tag.status, 0, tag.stdout + tag.stderr);
  assert.equal(f.git('rev-parse', 'v1.2.4^{commit}'), f.sha);
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'v1.2.4^{commit}'), f.sha);
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'master'), f.tip);
  assert.equal(f.git('rev-parse', 'master'), f.tip);
  assert.equal(fs.readFileSync(path.join(f.dir, 'output'), 'utf8'), 'tag=v1.2.4\n');
});

test('a newer release containing the tested SHA skips an older finishing run', t => {
  const f = fixture(t);
  f.git('tag', '-a', 'v1.2.4', f.tip, '-m', 'newer release');
  skipped(f, f.sha, /already included in a release/);
});

test('a containing non-release tag does not block release', t => {
  const f = fixture(t);
  f.git('tag', 'checkpoint', f.tip);
  ready(f.admit());
});

test('a tested SHA outside origin/master skips', t => {
  const f = fixture(t);
  f.git('checkout', '-b', 'side', 'v1.2.3');
  f.git('commit', '--allow-empty', '-m', 'unmerged change');
  skipped(f, f.git('rev-parse', 'HEAD'), /not an ancestor of origin\/master/);
});

test('an already tagged tested SHA skips even for a non-release tag', t => {
  const f = fixture(t);
  f.git('tag', 'checkpoint', f.sha);
  skipped(f, f.sha, /already tagged/);
});

for (const marker of ['[skip release]', '[release skip]']) {
  test(`${marker} on the tested commit skips even when HEAD differs`, t => {
    const f = fixture(t);
    f.git('checkout', '--detach', f.sha);
    f.git('commit', '--allow-empty', '--amend', '-m', `tested change ${marker}`);
    const sha = f.git('rev-parse', 'HEAD');
    f.git('update-ref', 'refs/remotes/origin/master', sha);
    f.git('checkout', '--detach', f.tip);
    skipped(f, sha, /commit asks for no release/);
  });
}

test('a skip marker on newer master does not suppress the tested commit', t => {
  const f = fixture(t);
  f.git('commit', '--allow-empty', '--amend', '-m', 'queued change [skip release]');
  f.git('update-ref', 'refs/remotes/origin/master', 'HEAD');
  ready(f.admit());
});

test('dispatch requires successful Tests for its exact SHA', t => {
  const f = fixture(t);
  ready(f.admit(f.tip, 'workflow_dispatch'));
  const calls = fs.readFileSync(f.log, 'utf8').trim().split('\n').map(line => JSON.parse(line));
  assert.deepEqual(calls, [['run', 'list', '-R', 'example/multiprompt', '-w', 'test.yml', '-b', 'master', '--commit', f.tip, '--limit', '100', '--json', 'databaseId,event,status,conclusion']]);
});

for (const runs of [
  [],
  [{ databaseId: 1, event: 'push', status: 'completed', conclusion: 'failure' }],
  [{ databaseId: 1, event: 'push', status: 'in_progress', conclusion: null }],
  [{ databaseId: 1, event: 'pull_request', status: 'completed', conclusion: 'success' }],
  [{ databaseId: 1, event: 'push', status: 'completed', conclusion: 'success' }, { databaseId: 2, event: 'workflow_dispatch', status: 'completed', conclusion: 'failure' }],
]) {
  test(`dispatch skips non-green latest eligible Tests: ${JSON.stringify(runs)}`, t => {
    const f = fixture(t);
    const result = f.admit(f.tip, 'workflow_dispatch', { TEST_RUNS: JSON.stringify(runs) });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, '');
    assert.match(result.stderr, /Tests are not green/);
  });
}

test('an existing next tag is never moved or replaced', t => {
  const f = fixture(t);
  f.git('checkout', '-b', 'side', 'v1.2.3');
  f.git('commit', '--allow-empty', '-m', 'unrelated release');
  const tagged = f.git('rev-parse', 'HEAD');
  f.git('tag', 'v1.2.4');
  const result = f.admit();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /already exists; refusing to move it/);
  assert.equal(result.stdout, '');
  assert.equal(f.git('rev-parse', 'v1.2.4'), tagged);
});
