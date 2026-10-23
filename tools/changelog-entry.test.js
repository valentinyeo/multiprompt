const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const { readChangelogEntry } = require('./changelog-entry');

function fixture(t, files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'changelog-entry-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const [file, text] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, file)), { recursive: true });
    fs.writeFileSync(path.join(root, file), text);
  }
  return root;
}

test('ticket text survives the real release fold with whitespace and escaping normalized', async t => {
  const { stampTree } = await import('./version-stamp.mjs');
  const files = {
    'src/main.zig': 'pub const APP_VERSION = "0.0.1";\n',
    'src/changelog.zig': 'pub const CHANGELOG = [_]ChangelogEntry{\n};\n',
    [path.join('changelog.d', 'IGSH-1-first.md')]: ' First sentence. \r\n\r\nOpen "saved chats" at the café.\r\n',
    [path.join('changelog.d', 'IGSH-1-second.md')]: 'Second fragment.\n',
    [path.join('changelog.d', 'IGSH-10-other.md')]: 'Unrelated ticket.\n',
  };
  const expected = 'First sentence.\nOpen "saved chats" at the café.\nSecond fragment.\n';
  const root = fixture(t, files);
  assert.equal(readChangelogEntry('IGSH-1', root), expected);
  const stamp = stampTree(Object.fromEntries(Object.entries(files).map(([file, text]) => [file.split(path.sep).join('/'), text])));
  fs.writeFileSync(path.join(root, 'src/changelog.zig'), stamp.files['src/changelog.zig']);
  for (const file of stamp.removed) fs.unlinkSync(path.join(root, file));
  assert.equal(readChangelogEntry('IGSH-1', root), expected);
  assert.equal(readChangelogEntry('IGSH-10', root), 'Unrelated ticket.\n');
});

test('unreleased text takes precedence over older released text for the same ticket', t => {
  const root = fixture(t, {
    [path.join('changelog.d', 'IGSH-1-followup.md')]: 'New text.\n',
    'src/changelog.zig': '.{ .text = "Older text.", .ticket = "IGSH-1" },\n',
  });
  assert.equal(readChangelogEntry('IGSH-1', root), 'New text.\n');
});

test('released lookup works without a fragment directory and rejects missing or invalid tickets', t => {
  const root = fixture(t, { 'src/changelog.zig': '.{ .text = "Released text.", .ticket = "IGSH-10" },\n' });
  assert.equal(readChangelogEntry('IGSH-10', root), 'Released text.\n');
  assert.throws(() => readChangelogEntry('IGSH-1', root), /No changelog entry for IGSH-1/);
  assert.throws(() => readChangelogEntry('../IGSH-1', root), /Invalid changelog ticket/);
});

test('an empty unreleased fragment cannot silently use an older release entry', t => {
  const root = fixture(t, {
    [path.join('changelog.d', 'IGSH-1-empty.md')]: ' \n',
    'src/changelog.zig': '.{ .text = "Older text.", .ticket = "IGSH-1" },\n',
  });
  assert.throws(() => readChangelogEntry('IGSH-1', root), /No changelog entry for IGSH-1/);
});
