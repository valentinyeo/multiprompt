const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('engineering release lines stay out of the update card', async () => {
  const { userFacingReleaseLine } = await import('./version-stamp.mjs');
  const engineering = [
    'IGSH-900 Release gate: 3 launches on saved sessions must pass before every release',
    'IGSH-893 Multiprompt verify: chat-dictation journey hangs with no output for 25 minutes and has never run green 17/30',
    'IGSH-2567 Multiprompt verification playbook: test the app as Valentin uses it',
    'IGSH-1115 [INFRA] Repair releases with empty update notes',
    'IGSH-837 CI: fast PR gate, journeys on master, auto-revert',
    'HYCI-101 share one Windows app build cache',
    'IGSH-12 Checks and fixes, no visible change',
  ];
  for (const line of engineering) assert.equal(userFacingReleaseLine(line), false, line);
  assert.equal(userFacingReleaseLine('IGSH-895 Chat View: pasting text adds an extra line break'), true);
});

test('signed release notes keep user-facing lines first when newer releases are engineering-only', async () => {
  const { releaseNotes } = await import('./release-notes.mjs');
  const source = `pub const CHANGELOG = [_]ChangelogEntry{
    .{ .ver = "0.28.1815", .items = &.{
        .{ .text = "IGSH-2930 Multiprompt verify: master journey stays green", .ticket = "IGSH-2930" },
        .{ .text = "IGSH-2929 Release gate: signed notes journey must pass", .ticket = "IGSH-2929" },
        .{ .text = "IGSH-2928 CI: shrink nightly matrix", .ticket = "IGSH-2928" },
    } },
    .{ .ver = "0.28.1814", .items = &.{
        .{ .text = "IGSH-2925 Chat View: sidebar search keeps your place", .ticket = "IGSH-2925" },
    } },
    .{ .ver = "0.28.1813", .items = &.{
        .{ .text = "IGSH-2920 Dictation shortcuts keep working when keys queue up", .ticket = "IGSH-2920" },
    } },
};`;
  const { userFacingReleaseLine } = await import('./version-stamp.mjs');
  const notes = releaseNotes(source, 'v0.28.1815');
  assert.deepEqual(notes.releases[0].changes, []);
  assert.deepEqual(notes.releases[1].changes, ['IGSH-2925 Chat View: sidebar search keeps your place']);
  assert.deepEqual(notes.releases[2].changes, ['IGSH-2920 Dictation shortcuts keep working when keys queue up']);
  assert.ok(notes.releases.every(release => release.changes.every(line => userFacingReleaseLine(line))));
  assert.doesNotMatch(JSON.stringify(notes), /Release gate:|Multiprompt verify:/);
  assert.ok(read('src/update_notes.zig').includes('Release gate: '));
  assert.ok(read('tools/release-notes.mjs').includes('userFacingReleaseLine'));
});