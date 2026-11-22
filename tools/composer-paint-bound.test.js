const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'src/chat_composer_text.zig'), 'utf8');

test('a very long draft keeps the native EDIT paint', () => {
  assert.match(source, /pub const MAX_CUSTOM_UNITS: usize = 64 \* 1024;/);
  assert.match(source, /if \(length > MAX_CUSTOM_UNITS\) return false;/);
});

test('the direct-write paint stops measuring past the clip edge', () => {
  assert.match(source, /if \(i > begin and point\.x >= clip\.right\) break;/);
  assert.match(source, /if \(next != null and next\.\?\.y == point\.y\) \{\s*right = next\.\?\.x;/);
  assert.match(source, /measured_units \+= 1;/);
});
