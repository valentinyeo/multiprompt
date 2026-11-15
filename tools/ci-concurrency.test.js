const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

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
    assert.ok(concurrency.includes(group), `${name} group`);
    assert.ok(concurrency.includes(cancel), `${name} cancel-in-progress`);
  }
});

test('the release workflow does not cancel an in-progress publication', () => {
  for (const name of ['release.yml', 'auto-release.yml']) {
    assert.doesNotMatch(read(name), /cancel-in-progress:\s*(?:true|\$\{\{\s*true\s*\}\})/);
  }
  assert.match(topConcurrency(read('release.yml')), /cancel-in-progress:\s*false/);
  assert.doesNotMatch(onBlock(read('release.yml')), /pull_request/);
  assert.doesNotMatch(onBlock(read('auto-release.yml')), /pull_request/);
});
