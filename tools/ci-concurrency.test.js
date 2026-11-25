const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { followDecision } = require('./release-follow.cjs');

const workflowDir = path.join(__dirname, '..', '.github', 'workflows');
const group = 'group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}';
const cancel = 'cancel-in-progress: true';
const cancelPullRequestOnly = "cancel-in-progress: ${{ github.event_name == 'pull_request' }}";
const toCancel = text => text.replace(/^  cancel-in-progress: .+$/m, `  ${cancel}`);

function read(name) {
  return fs.readFileSync(path.join(workflowDir, name), 'utf8');
}

function onBlock(text) {
  const lines = text.split(/\r?\n/);
  const start = lines.findIndex(line => line === 'on:' || line.startsWith('on: '));
  if (start < 0) return '';
  const block = [];
  for (let index = start; index < lines.length; index += 1) {
    const line = lines[index];
    if (index > start && line !== '' && !/^[ \t#]/.test(line)) break;
    block.push(line);
  }
  return block.join('\n');
}

function topConcurrency(text) {
  const lines = text.split(/\r?\n/);
  const start = lines.findIndex(line => line === 'concurrency:');
  if (start < 0) return '';
  const block = [];
  for (let index = start; index < lines.length; index += 1) {
    const line = lines[index];
    if (index > start && !/^[ \t]/.test(line)) break;
    if (line !== '') block.push(line);
  }
  return block.join('\n');
}

function triggersPullRequest(text) {
  return onBlock(text).split('\n').some(line => /^[ \t]*pull_request\s*:?[ \t]*$/.test(line) || /^on:\s*\[.*\bpull_request\b/.test(line));
}

function eventBody(text, event) {
  const lines = onBlock(text).split(/\r?\n/);
  const start = lines.findIndex(line => new RegExp(`^[ \\t]+${event}:\\s*$`).test(line));
  if (start < 0) return null;
  const body = [];
  for (let index = start + 1; index < lines.length; index += 1) {
    if (lines[index].trim() !== '' && !/^[ \t]{4,}/.test(lines[index])) break;
    body.push(lines[index]);
  }
  return body.join('\n');
}

function pushBranches(text) {
  const body = eventBody(text, 'push');
  if (body === null) return null;
  const inline = body.match(/^[ \t]+branches: \[(.*)\]$/m);
  if (inline) return inline[1].split(',').map(entry => entry.trim().replace(/^['"]|['"]$/g, ''));
  const listed = body.match(/^[ \t]+branches:\s*\n((?:[ \t]+- .*\n?)+)/m);
  if (listed) return listed[1].split('\n').map(entry => entry.trim()).filter(Boolean).map(entry => entry.replace(/^- /, '').replace(/^['"]|['"]$/g, ''));
  return [];
}

function triggersMasterPush(text) {
  const branches = pushBranches(text);
  return branches !== null && (branches.length === 0 || branches.includes('master'));
}

function masterPushCancellations(files) {
  return files.filter(([, text]) => triggersMasterPush(text) && topConcurrency(text).includes(cancel)).map(([name]) => name);
}

test('every pull_request workflow cancels only a superseded pull request run', () => {
  const names = fs.readdirSync(workflowDir).filter(name => name.endsWith('.yml')).sort();
  const triggered = names.filter(name => name !== 'release.yml' && name !== 'auto-release.yml' && triggersPullRequest(read(name)));
  assert.ok(triggered.includes('test.yml'));
  assert.ok(triggered.includes('pr-verifier.yml'));
  for (const name of triggered) {
    const concurrency = topConcurrency(read(name));
    if (name === 'pr-verifier.yml') {
      assert.ok(concurrency.includes('group: ${{ github.workflow }}-${{ inputs.pr || github.event.pull_request.number }}'), `${name} group`);
      assert.ok(concurrency.includes(cancel), `${name} cancel-in-progress`);
    } else {
      assert.ok(concurrency.includes(group) || concurrency.includes('github.event.pull_request.number || github.ref }}'), `${name} group`);
      assert.ok(concurrency.includes(cancel) || concurrency.includes(cancelPullRequestOnly), `${name} cancel-in-progress`);
    }
  }
});

test('every workflow cancels superseded work except a release that is already publishing and a master push', () => {
  for (const name of fs.readdirSync(workflowDir).filter(name => /\.ya?ml$/.test(name))) {
    const concurrency = topConcurrency(read(name));
    assert.match(concurrency, /^  group: .+$/m, name);
    if (name === 'auto-release.yml' || name === 'release.yml') {
      assert.match(concurrency, /^  cancel-in-progress: false$/m, name);
      continue;
    }
    assert.match(concurrency, triggersMasterPush(read(name)) ? /^  cancel-in-progress: (?:false|\$\{\{ github\.event_name == 'pull_request' \}\})$/m : /^  cancel-in-progress: true$/m, name);
  }
  assert.doesNotMatch(onBlock(read('release.yml')), /pull_request/);
  assert.doesNotMatch(onBlock(read('auto-release.yml')), /pull_request/);
});

test('a master push never cancels the master run before it', () => {
  const files = fs.readdirSync(workflowDir).filter(name => name.endsWith('.yml')).sort().map(name => [name, read(name)]);
  const masters = files.filter(([, text]) => triggersMasterPush(text)).map(([name]) => name);
  for (const name of ['auto-release.yml', 'dev-build.yml', 'gitleaks.yml', 'test.yml']) assert.ok(masters.includes(name), name);
  assert.ok(masters.length > 1, 'master push workflows are found');
  assert.deepEqual(masterPushCancellations(files), []);
  for (const [name, cancelValue] of [
    ['test.yml', cancelPullRequestOnly],
    ['gitleaks.yml', cancelPullRequestOnly],
    ['chat-auto-switch.yml', cancelPullRequestOnly],
    ['chat-delivery-formal.yml', cancelPullRequestOnly],
    ['chat-switch-ai-formal.yml', cancelPullRequestOnly],
    ['dev-build.yml', 'cancel-in-progress: false'],
  ]) {
    assert.ok(topConcurrency(read(name)).includes(cancelValue), name);
  }
  for (const name of masters) {
    const text = read(name);
    assert.notEqual(toCancel(text), text, name);
    assert.deepEqual(masterPushCancellations([[name, toCancel(text)]]), [name], `${name} is caught when it cancels push runs`);
  }
});

test('a newer master commit still gets a release when this run is not the tip', () => {
  const tip = 'b'.repeat(40);
  const built = 'a'.repeat(40);
  assert.equal(followDecision({ tip, built, releaseResult: 'success', runs: [], selfId: '1' }).dispatch, true);
  assert.equal(followDecision({ tip, built, releaseResult: 'success', runs: [{ id: '9', headSha: tip, status: 'queued', conclusion: '' }], selfId: '1' }).dispatch, false);
  assert.equal(followDecision({ tip, built, releaseResult: 'success', runs: [{ id: '9', headSha: tip, status: 'completed', conclusion: 'success' }], selfId: '1' }).dispatch, false);
  assert.equal(followDecision({ tip: built, built, releaseResult: 'success', runs: [], selfId: '1' }).dispatch, false);
  assert.equal(followDecision({ tip: built, built, releaseResult: 'failure', runs: [], selfId: '4' }).dispatch, false);
  assert.equal(followDecision({ tip: built, built, releaseResult: 'cancelled', runs: [{ id: '4', headSha: built, status: 'in_progress', conclusion: '' }], selfId: '4' }).dispatch, true);
  for (const name of ['release.yml', 'auto-release.yml']) {
    assert.match(read(name), /node tools\/release-follow\.cjs/);
    assert.match(read(name), /gh workflow run auto-release\.yml --ref master/);
  }
});

test('a release-called secret scan has its own cancellation group', () => {
  const text = require('node:fs').readFileSync(require('node:path').join(__dirname, '..', '.github', 'workflows', 'gitleaks.yml'), 'utf8');
  const group = text.match(/^concurrency:\n  group: (.+)$/m)[1];
  require('node:assert').match(group, /inputs\.release_scan && 'release'/);
});

test('SOFT-3094: a nightly measurement run never cancels an unrelated one', () => {
  for (const name of ['chat-bench-ab.yml', 'chat-table-bench.yml', 'check-red-run.yml', 'verify-reconnect.yml']) {
    const text = read(name);
    assert.doesNotMatch(onBlock(text), /pull_request/, `${name} has no pull request trigger`);
    const group = topConcurrency(text).match(/^  group: (.+)$/m)[1];
    assert.match(group, /github\.run_id/, `${name} isolates each run`);
    assert.doesNotMatch(group, /github\.ref(?!_)/, `${name} does not key a shared group on the branch`);
  }
});
