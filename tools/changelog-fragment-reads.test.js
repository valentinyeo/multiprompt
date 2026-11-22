const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

function assertNoDirectFragmentReads(source, file) {
  const matches = [...source.matchAll(/changelog\.d[\\/]+IGSH-\d+-[^\s'"`/\\]+\.md/g)];
  assert.equal(matches.length, 0, `${file}: use readChangelogEntry from tools/changelog-entry.js instead of a direct changelog fragment path: ${matches.map(match => match[0]).join(', ')}`);
}

function testFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? testFiles(file) : entry.isFile() && entry.name.endsWith('.test.js') ? [file] : [];
  });
}

test('tools tests use the release-safe changelog helper instead of direct fragment paths', () => {
  for (const file of testFiles(__dirname)) {
    assertNoDirectFragmentReads(fs.readFileSync(file, 'utf8'), path.relative(path.resolve(__dirname, '..'), file));
  }
});

test('the guard rejects both original direct fragment reads and names the shared helper', () => {
  const shortcut = ['changelog.d', 'IGSH-493-tab-url-shortcut.md'].join('/');
  const session = ['changelog.d', 'IGSH-535-session-open.md'].join('/');
  for (const source of [
    `assert.match(read('${shortcut}'), /^Ctrl\\+Shift\\+X inserts[^\\n]+without sending\\.\\n$/);`,
    `const fragment = fs.readFileSync(path.join(root, '${session}'), 'utf8').trim();`,
  ]) {
    assert.throws(() => assertNoDirectFragmentReads(source, 'original.test.js'), /original\.test\.js: use readChangelogEntry from tools\/changelog-entry\.js/);
  }
  assert.doesNotThrow(() => assertNoDirectFragmentReads("readChangelogEntry('IGSH-493')", 'fixed.test.js'));
});

module.exports = { assertNoDirectFragmentReads };
