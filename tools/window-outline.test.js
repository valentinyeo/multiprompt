const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'themes.zig'), 'utf8');

test('every dark theme gives the app window a visible outline', () => {
  const start = source.indexOf('pub fn applyTitleBarTheme() void {');
  assert.ok(start >= 0);
  const body = source.slice(start, source.indexOf('\n}\n', start));
  const borders = [...body.matchAll(/const border_color: DWORD = ([^;]+);/g)].map(m => m[1]);
  assert.equal(borders.length, 4);
  for (const value of borders) {
    assert.doesNotMatch(value, /RGB\(0, 0, 0\)/, 'black outline is invisible on black themes');
    assert.doesNotMatch(value, /RGB\(35, 37, 42\)/, 'near-black outline is too faint');
    assert.doesNotMatch(value, /border_bg/, 'pane border colours are too dark for the window outline');
  }
  assert.match(source, /pub const DARK_WINDOW_OUTLINE: DWORD = RGB\(86, 86, 86\);/);
});
