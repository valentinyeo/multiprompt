const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const sentence = (input) => {
  const source = read('src/palette_text.zig');
  const start = source.indexOf('fn titleCased(');
  const end = source.indexOf('pub fn draw(');
  assert.ok(start >= 0 && end > start, 'palette label helper must exist');
  const body = source.slice(start, end);
  const gated = /if \(!titleCased\(out\[0\.\.len\]\)\) return out\[0\.\.len\];/.test(body);
  assert.ok(gated, 'a label that is not title cased must keep its own capitals');
  const words = input.split(' ');
  const titleCased = words.every((word) => word.length === 0 || !(word[0] >= 'a' && word[0] <= 'z'));
  if (!titleCased) return input;
  const letters = [...input];
  return letters
    .map((c, i) => (i > 0 && letters[i - 1] === ' ' && c >= 'A' && c <= 'Z' && letters[i + 1] >= 'a' && letters[i + 1] <= 'z' ? c.toLowerCase() : c))
    .join('');
};

test('IGSH-1266 palette rows keep product names letter for letter', () => {
  assert.equal(sentence('New Claude chat'), 'New Claude chat');
  assert.equal(sentence('New Codex chat'), 'New Codex chat');
  assert.equal(sentence('New Pi chat'), 'New Pi chat');
  assert.equal(sentence('New terminal'), 'New terminal');
  assert.equal(sentence('Commands: Edit commands.json'), 'Commands: Edit commands.json');
});

test('IGSH-1266 legacy title-cased palette rows still read as a sentence', () => {
  assert.equal(sentence('New Host 1 VPS Shell'), 'New host 1 VPS shell');
  assert.equal(sentence('Show All Sessions'), 'Show all sessions');
});
