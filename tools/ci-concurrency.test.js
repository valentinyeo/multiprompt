const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { followDecision } = require('./release-follow.cjs');

const workflowDir = path.join(__dirname, '..', '.github', 'workflows');
const group = 'group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}';
const cancel = "cancel-in-progress: ${{ github.event_name == 'pull_request' }}";

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

test('every pull_request workflow cancels only a superseded pull request run', () => {
  const names = fs.readdirSync(workflowDir).filter(name => name.endsWith('.yml')).sort();
  const triggered = names.filter(name => name !== 'release.yml' && name !== 'auto-release.yml' && triggersPullRequest(read(name)));
  assert.ok(triggered.includes('test.yml'));
  assert.ok(triggered.includes('pr-verifier.yml'));
  for (const name of triggered) {
    const concurrency = topConcurrency(read(name));
    const expected = name === 'pr-verifier.yml' ? group.replace(' || github.ref', ' || inputs.pr || github.ref') : group;
    assert.ok(concurrency.includes(expected), `${name} group`);
    assert.ok(concurrency.includes(cancel), `${name} cancel-in-progress`);
  }
});

test('the release workflow does not cancel an in-progress publication', () => {
  for (const name of ['release.yml', 'auto-release.yml']) {
    assert.doesNotMatch(read(name), /cancel-in-progress:\s*(?:true|\$\{\{\s*true\s*\}\})/);
  }
  assert.match(topConcurrency(read('release.yml')), /cancel-in-progress:\s*false/);
  assert.match(topConcurrency(read('auto-release.yml')), /cancel-in-progress:\s*false/);
  assert.doesNotMatch(onBlock(read('release.yml')), /pull_request/);
  assert.doesNotMatch(onBlock(read('auto-release.yml')), /pull_request/);
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

test('manual verifier runs for different pull requests do not replace each other in the pending queue', () => {
  const template = read('pr-verifier.yml').match(/^  group: (.+)$/m)[1];
  function group(pr, eventNumber) {
    const context = { github: { workflow: 'PR verifier', ref: 'refs/heads/master', event: { pull_request: { number: eventNumber } } }, inputs: { pr } };
    return template.replace(/\$\{\{(.*?)\}\}/g, (_, expression) => expression.trim().split(' || ').map(key => key.split('.').reduce((value, part) => value?.[part], context)).find(Boolean) || '');
  }
  assert.notEqual(group('1038'), group('1039'));
  assert.equal(group('1038'), group(undefined, 1038));
});
