const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const oldCheck = `set -euo pipefail
sha=$(git rev-parse HEAD)
if [ "$GITHUB_EVENT_NAME" = workflow_run ] && [ "$sha" != "$TESTED_SHA" ]; then
  echo 'master has moved past the tested commit; skipping'
  exit 0
fi
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
  git('commit', '--allow-empty', '-m', 'previous release');
  git('tag', 'v0.0.1');
  const commit = message => {
    git('commit', '--allow-empty', '-m', message);
    return git('rev-parse', 'HEAD');
  };
  const older = commit('older green change');
  const green = commit('newest green change');
  const remote = path.join(dir, 'remote.git');
  git('clone', '--bare', dir, remote);
  git('remote', 'add', 'origin', remote);
  const tip = commit('untested master change');
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  const log = path.join(dir, 'gh-log');
  fs.writeFileSync(log, '');
  fs.writeFileSync(path.join(bin, 'gh'), `#!${process.execPath}
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.appendFileSync(process.env.GH_LOG, JSON.stringify(args) + '\\n');
if (process.env.GH_FAIL === 'true') process.exit(1);
const sha = args[args.indexOf('--commit') + 1];
console.log(JSON.stringify(JSON.parse(process.env.TEST_RUNS)[sha] || []));
`, { mode: 0o755 });
  const success = [{ databaseId: 1, event: 'push', status: 'completed', conclusion: 'success' }];
  const run = (command, args, env = {}) => spawnSync(command, args, { cwd: dir, encoding: 'utf8', env: {
    ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, GH_LOG: log,
    GITHUB_EVENT_NAME: 'workflow_run', TESTED_SHA: green, GITHUB_REPOSITORY: 'example/multiprompt',
    TEST_RUNS: JSON.stringify({ [older]: success, [green]: success }), ...env,
  } });
  const admit = (args = ['--dry-run'], env = {}) => run('bash', [path.join(root, 'tools/auto-release-admit.sh'), ...args], env);
  const calls = () => fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line));
  return { dir, git, commit, older, green, tip, remote, log, run, admit, calls, success };
}

function selected(result, sha) {
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(result.stdout, `tag=v0.0.2\nsha=${sha}\n`);
}

function skipped(f, env = {}) {
  const tags = f.git('show-ref', '--tags');
  const remoteTags = f.git('--git-dir', f.remote, 'show-ref', '--tags');
  const result = f.admit([], env);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(result.stdout, '');
  assert.equal(f.git('show-ref', '--tags'), tags);
  assert.equal(f.git('--git-dir', f.remote, 'show-ref', '--tags'), remoteTags);
  return result;
}

test('HEAD moved past green commits: publishes newest green SHA, not HEAD, and no branch', t => {
  const f = fixture(t);
  selected(f.admit([]), f.green);
  assert.equal(f.git('rev-parse', 'v0.0.2^{commit}'), f.green);
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'v0.0.2^{commit}'), f.green);
  assert.equal(f.git('rev-parse', 'master'), f.tip);
  assert.equal(f.git('--git-dir', f.remote, 'rev-parse', 'master'), f.green);
  assert.deepEqual(f.calls(), [f.tip, f.green].map(sha => [
    'run', 'list', '-R', 'example/multiprompt', '-w', 'test.yml', '-b', 'master',
    '--commit', sha, '--limit', '100', '--json', 'databaseId,event,status,conclusion',
  ]));
  skipped(f);
});

test('no green commit since release: exits successfully without tagging', t => {
  const f = fixture(t);
  skipped(f, { TEST_RUNS: '{}' });
  assert.equal(f.calls().length, 3);
  assert.ok(f.calls().every(args => args[args.indexOf('--commit') + 1] !== f.git('rev-parse', 'v0.0.1')));
});

test('newest green already released: never selects an older commit', t => {
  const f = fixture(t);
  f.git('tag', '-a', 'v0.0.2', f.green, '-m', 'already released');
  skipped(f);
  assert.deepEqual(f.calls().map(args => args[args.indexOf('--commit') + 1]), [f.tip]);
});

test('a non-release tag on newest green makes selection keep walking', t => {
  const f = fixture(t);
  f.git('tag', 'checkpoint', f.green);
  selected(f.admit(), f.older);
});

for (const marker of ['[skip release]', '[release skip]']) {
  test(`${marker} on newest green selects older green`, t => {
    const f = fixture(t);
    const sha = f.commit(`newest change ${marker}`);
    selected(f.admit(['--dry-run'], { TEST_RUNS: JSON.stringify({ [sha]: f.success, [f.green]: f.success }) }), f.green);
  });
}

test('dry-run prints chosen tag and SHA without creating or pushing anything', t => {
  const f = fixture(t);
  const tags = f.git('show-ref', '--tags');
  selected(f.admit(), f.green);
  assert.equal(f.git('show-ref', '--tags'), tags);
  assert.equal(f.git('--git-dir', f.remote, 'show-ref', '--tags'), tags);
  assert.equal(f.git('rev-parse', 'HEAD'), f.tip);
});

test('green HEAD is eligible too', t => {
  const f = fixture(t);
  selected(f.admit(['--dry-run'], { TEST_RUNS: JSON.stringify({ [f.tip]: f.success }) }), f.tip);
});

test('newest first-parent release tag bounds selection, ignoring side-branch releases', t => {
  const f = fixture(t);
  f.git('checkout', '-b', 'side', 'v0.0.1');
  const side = f.commit('side branch change');
  f.git('tag', 'v9.0.0', side);
  f.git('checkout', 'master');
  f.git('merge', '--no-ff', 'side', '-m', 'merge side');
  selected(f.admit(['--dry-run'], { TEST_RUNS: JSON.stringify({ [side]: f.success, [f.green]: f.success }) }), f.green);
  assert.ok(f.calls().every(args => !args.includes(side)));
});

test('an existing next tag is refused without moving or replacing it', t => {
  const f = fixture(t);
  f.git('checkout', '-b', 'side', 'v0.0.1');
  const tagged = f.commit('unrelated release');
  f.git('tag', 'v0.0.2');
  f.git('checkout', 'master');
  const result = f.admit([]);
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /already exists; refusing to move it/);
  assert.equal(f.git('rev-parse', 'v0.0.2'), tagged);
  assert.equal(f.git('--git-dir', f.remote, 'tag', '--list', 'v0.0.2'), '');
});

for (const runs of [
  [],
  [{ databaseId: 1, event: 'push', status: 'completed', conclusion: 'failure' }],
  [{ databaseId: 1, event: 'push', status: 'in_progress', conclusion: null }],
  [{ databaseId: 1, event: 'pull_request', status: 'completed', conclusion: 'success' }],
  [{ databaseId: 2, event: 'workflow_dispatch', status: 'completed', conclusion: 'failure' }, { databaseId: 1, event: 'push', status: 'completed', conclusion: 'success' }],
  [{ databaseId: 2, event: 'push', status: 'in_progress', conclusion: null }, { databaseId: 1, event: 'push', status: 'completed', conclusion: 'success' }],
]) {
  test(`non-green latest eligible Tests cannot release: ${JSON.stringify(runs)}`, t => {
    const f = fixture(t);
    skipped(f, { TEST_RUNS: JSON.stringify({ [f.tip]: runs }) });
  });
}

test('latest eligible dispatch success overrides older failure and newer PR run', t => {
  const f = fixture(t);
  selected(f.admit(['--dry-run'], { TEST_RUNS: JSON.stringify({ [f.tip]: [
    { databaseId: 3, event: 'pull_request', status: 'completed', conclusion: 'failure' },
    { databaseId: 2, event: 'workflow_dispatch', status: 'completed', conclusion: 'success' },
    { databaseId: 1, event: 'push', status: 'completed', conclusion: 'failure' },
  ] }) }), f.tip);
});

test('lookup errors fail without releasing an older commit', t => {
  const f = fixture(t);
  const result = f.admit([], { GH_FAIL: 'true' });
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, '');
  assert.equal(f.git('tag', '--list', 'v0.0.2'), '');
});

test('old moved-master inline check produces no tag in the same green-ancestor scenario', t => {
  const f = fixture(t);
  const output = path.join(f.dir, 'output');
  fs.writeFileSync(output, '');
  const old = f.run('bash', ['-c', `${oldCheck}\nprintf 'tag=v0.0.2\\n' >> "$GITHUB_OUTPUT"\n`], { GITHUB_OUTPUT: output });
  assert.equal(old.status, 0, old.stderr);
  assert.match(old.stdout, /master has moved past the tested commit; skipping/);
  assert.equal(fs.readFileSync(output, 'utf8'), '');
  assert.equal(f.git('tag', '--list', 'v0.0.2'), '');
  selected(f.admit(), f.green);
});
