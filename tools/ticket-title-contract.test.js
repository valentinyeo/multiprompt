const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

test('generation shares ticket titles with both historical and current release notes', async () => {
  const { buildChangelog } = await import('./version-stamp.mjs');
  const { releaseNotes } = await import('./release-notes.mjs');
  const files = {
    'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.883", .items = &.{\n        .{ .text = "Old product text", .ticket = "IGSH-1" },\n    } },\n};\n',
    [['changelog.d', 'IGSH-2-change.md'].join('/')]: 'A product sentence.\n',
  };
  const titles = { 'IGSH-1': 'Earlier café title', 'IGSH-2': 'Full current title' };
  const source = buildChangelog(files, 'v0.28.1100', [], [{ sha: 'x', subject: 'IGSH-2: Change' }], titles);
  const notes = releaseNotes(source, 'v0.28.1100');
  assert.deepEqual(notes.releases.map(row => row.changes), [['IGSH-2 Full current title'], ['IGSH-1 Earlier café title']]);
  assert.equal(notes.releases[0].tickets[0], 'https://app.hypertask.ai/detail/project-2060/2');
  assert.doesNotMatch(source, /Checks and fixes/);
  assert.throws(() => buildChangelog(files, 'v0.28.1100', [], [{ sha: 'x', subject: 'IGSH-2: Change' }], { 'IGSH-2': 'Current' }), /IGSH-1/);
  assert.throws(() => buildChangelog(files, 'v0.28.1100', [], [{ sha: 'x', subject: 'IGSH-2: Change' }], { 'IGSH-1': 'Earlier', 'IGSH-2': '' }), /IGSH-2/);
});

test('checked-in visible history has authoritative titles and release notes preserve them', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  assert.ok(fs.existsSync('tools/ticket-titles.mjs'), 'ticket title module exists');
  assert.ok(fs.existsSync('tools/ticket-titles.json'), 'release title catalog exists');
  const { ticketLine, ticketRecord } = await import('./ticket-titles.mjs');
  const titles = JSON.parse(fs.readFileSync('tools/fixtures/IGSH-1681/ticket-titles.json', 'utf8'));
  assert.deepEqual(JSON.parse(fs.readFileSync('tools/ticket-titles.json', 'utf8')), titles);
  const source = fs.readFileSync('src/changelog.zig', 'utf8');
  const rows = [...source.matchAll(/\.text = ("(?:\\.|[^"\\])*"), \.ticket = "([^"]+)"/g)];
  assert.ok(rows.length > 0);
  for (const [, literal, id] of rows) assert.equal(JSON.parse(literal), ticketLine(ticketRecord(id, titles[id])));
  const version = /\.ver = "([^"]+)"/.exec(source)[1];
  const notes = releaseNotes(source, `v${version}`);
  assert.equal(notes.releases.flatMap(row => row.changes).length, rows.length);
  assert.doesNotMatch(JSON.stringify(notes), /Checks and fixes, no visible change/);
});

test('CI tickets remain linked alongside product tickets', async () => {
  const { buildChangelog } = await import('./version-stamp.mjs');
  const { releaseNotes } = await import('./release-notes.mjs');
  const files = { 'src/changelog.zig': 'const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "0.28.883", .items = &.{\n    } },\n};\n' };
  const titles = { 'IGSH-7': 'Product title', 'HYCI-9': 'Build title' };
  const source = buildChangelog(files, 'v0.28.1100', [], [{ sha: 'a', subject: 'IGSH-7: Change' }, { sha: 'b', subject: 'HYCI-9: Change' }], titles);
  const release = releaseNotes(source, 'v0.28.1100').releases[0];
  assert.deepEqual(release.changes, ['IGSH-7 Product title', 'HYCI-9 Build title']);
  assert.equal(release.tickets[1], 'https://app.hypertask.ai/detail/project-11514/9');
});

test('modern releases cannot publish an empty ticket list', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const source = '.{ .ver = "0.28.1027", .items = &.{\n    } },';
  assert.throws(() => releaseNotes(source, 'v0.28.1027'), /needs plain ticketed lines/);
});

test('malformed ticketed release lines fail instead of disappearing', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  for (const text of ['IGSH-7 ', 'A previous description', 'IGSH-7 Checks and fixes, no visible change']) {
    const source = `const SOURCE_CHANGELOG = [_]ChangelogEntry{\n    .{ .ver = "1.0.0", .items = &.{\n        .{ .text = ${JSON.stringify(text)}, .ticket = "IGSH-7" },\n    } },\n};\n`;
    assert.throws(() => releaseNotes(source, 'v1.0.0'));
  }
});
