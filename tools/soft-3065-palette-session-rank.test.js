const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'command_palette.zig'), 'utf8');

function body(signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} exists`);
  let depth = 0;
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  throw new Error(`${signature} is unbalanced`);
}

test('SOFT-3065: a session named Token Ladder ranks above Token Ladder commands for query token', () => {
  const outranks = body('fn paletteResultOutranks(');
  assert.match(outranks, /if \(key_open != prev_open\) return key_open;/,
    'equal query match must prefer the live session row over commands');
  const zig = source.slice(source.indexOf('test "SOFT-3065'));
  assert.match(zig, /Token Ladder/);
  assert.match(zig, /SEARCH_LADDER_AUTO_OFFSET/);
  assert.match(zig, /SEARCH_LADDER_DASH_OFFSET/);
});