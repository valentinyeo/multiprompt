const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');

const source = fs.readFileSync(path.join(root, 'src/browser_pane.zig'), 'utf8');

function functionBody(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf('\nfn ', start + 1);
  assert.notEqual(end, -1, `could not find the end of ${name}`);
  return source.slice(start, end);
}

test('IGSH-1941 a window hidden at its dock still needs positioning, so the show flag reaches it', () => {
  const body = functionBody('browserWindowNeedsPosition');
  const hidden = body.indexOf('IsWindowVisible(hwnd) == 0) return true');
  assert.notEqual(hidden, -1, 'a hidden pane must count as needing a position, or it stays on Opening browser');
  assert.ok(hidden < body.indexOf('browserRectMatchesTarget('), 'the visibility check must run before the dock geometry comparison');
});

test('a window already visible at its dock is left alone, so the pane does not move on every frame', () => {
  const body = functionBody('browserWindowNeedsPosition');
  assert.match(body, /if \(GetWindowRect\(hwnd, &current\) == 0\) return true;/);
  assert.match(body, /return !browserRectMatchesTarget\(current, x, y, w, h\);/);
});

test('the skipped position is the same call that shows a docked pane', () => {
  const body = functionBody('positionActiveBrowser');
  const decision = body.indexOf('browserWindowNeedsPosition(bh, target_x, target_y, target_w, target_h)');
  const show = body.indexOf('SWP_SHOWWINDOW');
  assert.ok(decision >= 0, 'positionActiveBrowser decides with browserWindowNeedsPosition');
  assert.ok(show > decision, 'the show flag rides the position call that the decision guards');
});
