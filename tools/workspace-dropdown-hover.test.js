const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const switcher = fs.readFileSync(path.join(root, 'src/workspace_switcher.zig'), 'utf8');

function sliceBetween(source, start, end) {
  const at = source.indexOf(start);
  assert.ok(at >= 0, `missing ${start}`);
  const stop = source.indexOf(end, at + start.length);
  assert.ok(stop > at, `missing ${end}`);
  return source.slice(at, stop);
}

test('SOFT-2580 hovering a workspace row moves the highlight', () => {
  const paint = sliceBetween(switcher, 'fn paint(', 'pub fn close(');
  const mouse = sliceBetween(switcher, 'w.WM_MOUSEMOVE =>', 'w.WM_MOUSEWHEEL =>');
  const keys = sliceBetween(switcher, 'fn step(', 'pub fn key(');
  assert.match(mouse, /hit\(startup\.GET_X\(lp\), startup\.GET_Y\(lp\)\)/);
  assert.match(mouse, /selected = index/);
  assert.match(keys, /selected =/);
  assert.match(paint, /if \(rowHighlight\(index\) == \.selected\) fillRoundRect\(dc, rc, scale\(10\), divider\)/);
  assert.doesNotMatch(paint, /is_current or selected == index/);
  assert.doesNotMatch(paint, /if \(is_current\) divider else/);
  assert.match(switcher, /fn rowHighlight\(index: usize\) RowHighlight \{\n    return if \(selected == index\) \.selected else \.none;\n\}/);
  assert.match(switcher, /test "SOFT-2580 the menu highlight follows the pointer instead of the current workspace"/);
});
