const assert = require('node:assert/strict');
const test = require('node:test');
const { fragmentKeys, titleKeys, mergeHeadline, checkMergeTitle } = require('./merge-title.js');

test('fragment keys keep the written ticket key in ticket order', () => {
  assert.deepEqual(fragmentKeys([
    'tools/version-stamp.mjs',
    'changelog.d/SOFT-3140-chat-health.md',
    'changelog.d/MUBO-269-merge-titles.md',
    'changelog.d/README.md',
    'changelog.d/SOFT-9-first.md',
    'changelog.d/SOFT-3140-legacy.md',
  ]), ['MUBO-269', 'SOFT-9', 'SOFT-3140']);
  assert.deepEqual(fragmentKeys([]), []);
  assert.deepEqual(fragmentKeys(undefined), []);
  assert.throws(() => fragmentKeys(['changelog.d/VSTA-162-other-board.md']), /Invalid ticket ID: VSTA-162/);
});

test('the squash title names the fragment tickets, not the typed title', () => {
  assert.equal(
    mergeHeadline('SOFT-3134: Report chat health and what the PC shows (SOFT-3140)', ['changelog.d/SOFT-3140-chat-health.md'], 1311),
    'SOFT-3140: Report chat health and what the PC shows (SOFT-3140) (#1311)');
  assert.equal(
    mergeHeadline('SOFT-3018: Release stuck commits', ['changelog.d/SOFT-2883-ctrl-t-folder.md', 'changelog.d/SOFT-3055-session-commands.md'], 1121),
    'SOFT-2883, SOFT-3055: Release stuck commits (#1121)');
});

test('a pull request without fragments keeps its own keys and never repeats its number', () => {
  assert.equal(mergeHeadline('MUBO-269: Merge titles come from the PR', ['tools/merge-title.js'], 1360), 'MUBO-269: Merge titles come from the PR (#1360)');
  assert.equal(mergeHeadline('MUBO-269: Merge titles come from the PR (#1355)', [], 1355), 'MUBO-269: Merge titles come from the PR (#1355)');
  assert.deepEqual(titleKeys('MUBO-269, MUBO-270: Merge titles'), ['MUBO-269', 'MUBO-270']);
  assert.deepEqual(titleKeys('ci(verifier): a ticketless title'), []);
});

test('the pull request check refuses a title whose keys disagree with its fragments', () => {
  assert.throws(
    () => checkMergeTitle('SOFT-3134: Report chat health and what the PC shows (SOFT-3140)', ['changelog.d/SOFT-3140-chat-health.md']),
    /leads with SOFT-3134, but its changelog fragments name SOFT-3140/);
  assert.throws(
    () => checkMergeTitle('MUBO-269, MUBO-270: Merge titles', ['changelog.d/MUBO-269-merge-titles.md']),
    /leads with MUBO-269, MUBO-270, but its changelog fragments name MUBO-269/);
  assert.throws(
    () => checkMergeTitle('Merge titles come from the PR', ['changelog.d/MUBO-269-merge-titles.md']),
    /leads with no ticket key, but its changelog fragments name MUBO-269/);
  assert.throws(
    () => checkMergeTitle('SOFT-3134: Report chat health', ['changelog.d/SOFT-3140-chat-health.md']),
    /for example "SOFT-3140: Report chat health"/);
});

test('the pull request check accepts matching fragments and tooling-only work', () => {
  assert.deepEqual(checkMergeTitle('SOFT-3140: Report chat health', ['changelog.d/SOFT-3140-chat-health.md']), ['SOFT-3140']);
  assert.deepEqual(checkMergeTitle('IGSH-2883, IGSH-3055: Release stuck commits', ['changelog.d/SOFT-2883-a.md', 'changelog.d/SOFT-3055-b.md']), ['SOFT-2883', 'SOFT-3055']);
  assert.deepEqual(checkMergeTitle('MUBO-269: Merge titles come from the PR', ['tools/merge-title.js', '.github/workflows/test.yml']), []);
});
