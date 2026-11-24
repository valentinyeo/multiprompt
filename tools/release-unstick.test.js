const assert = require('node:assert/strict');
const test = require('node:test');
const fixture = require('./fixtures/SOFT-3018/release-unstick.json');

const tool = import('./version-stamp.mjs');

test('SOFT-3018 releases every ticket in the stalled batch, including the bundled folder picker change', async () => {
  const { buildChangelog } = await tool;
  const { releaseNotes } = await import('./release-notes.mjs');
  const source = buildChangelog(fixture.files, fixture.tag, fixture.history, fixture.commits);
  const notes = releaseNotes(source, fixture.tag);
  assert.equal(notes.version, '0.28.1853');
  assert.deepEqual(notes.releases[0].tickets, [
    'https://app.hypertask.ai/detail/project-2060/2883',
    'https://app.hypertask.ai/detail/project-2060/3075',
    'https://app.hypertask.ai/detail/project-2060/3071',
    'https://app.hypertask.ai/detail/project-2060/3077',
    'https://app.hypertask.ai/detail/project-2060/3055',
  ]);
  assert.ok(notes.releases[0].changes.includes('IGSH-3075 Multiprompt: Ctrl+T folder picker shows the folder name first with the server fully readable'));
});

test('SOFT-3018 can release the repair commit without a ticket title lookup', async () => {
  const { buildChangelog } = await tool;
  const { releaseNotes } = await import('./release-notes.mjs');
  const commits = [...fixture.commits, { sha: 'release-unstick-fix', subject: 'SOFT-3018: Attribute both tickets in the bundled picker commit' }];
  const source = buildChangelog(fixture.files, 'v0.28.1854', fixture.history, commits);
  const notes = releaseNotes(source, 'v0.28.1854');
  assert.equal(notes.releases[0].changes.at(-1), 'IGSH-3018 Multiprompt: releases land within 15 minutes of merge');
});

test('SOFT-3018 releases the bundled ticket of an unreviewed commit with a warning', async () => {
  const { buildChangelog } = await tool;
  const { releaseNotes } = await import('./release-notes.mjs');
  const commits = fixture.commits.map((commit, i) => i === 0 ? { ...commit, sha: 'unreviewed' } : commit);
  const warnings = [];
  const source = buildChangelog(fixture.files, fixture.tag, fixture.history, commits, undefined, line => warnings.push(line));
  assert.ok(warnings.includes('v0.28.1853: IGSH-3075 fragment has no matching commit ticket; publishing it from its fragment text'), warnings.join('\n'));
  assert.ok(releaseNotes(source, fixture.tag).releases[0].tickets.includes('https://app.hypertask.ai/detail/project-2060/3075'));
});

test('SOFT-3018 publishes a fragment without commit attribution and warns', async () => {
  const { buildChangelog } = await tool;
  const { releaseNotes } = await import('./release-notes.mjs');
  const files = { ...fixture.files, 'changelog.d/SOFT-9999-unattributed.md': 'The folder picker opens faster.\n' };
  const warnings = [];
  const source = buildChangelog(files, fixture.tag, fixture.history, fixture.commits, undefined, line => warnings.push(line));
  assert.ok(warnings.includes('v0.28.1853: IGSH-9999 fragment has no matching commit ticket; publishing it from its fragment text'), warnings.join('\n'));
  assert.ok(releaseNotes(source, fixture.tag).releases[0].changes.includes('The folder picker opens faster.'));
});
