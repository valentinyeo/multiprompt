const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../src/chat_render.zig'), 'utf8');

function sliceFn(name) {
  const start = source.search(new RegExp(`\\n(?:pub )?fn ${name}\\(`));
  assert.ok(start >= 0, `${name} must exist in the chat render path`);
  return source.slice(start + 1, source.indexOf('\n}', start) + 2);
}

function repaintRegion() {
  const body = sliceFn('chatWorkingRepaintRegion');
  const js = body.slice(body.indexOf('{') + 1, body.lastIndexOf('}'))
    .replace('const a = painted orelse return current;', 'if (painted == null) return current; const a = painted;')
    .replace('const b = current orelse return a;', 'if (current == null) return a; const b = current;')
    .replace('return .{', 'return {')
    .replaceAll('@min(', 'Math.min(')
    .replaceAll('@max(', 'Math.max(')
    .replace(/ \.(\w+) = /g, ' $1: ');
  assert.match(js, /left: Math\.min\(a\.left, b\.left\)/, 'the repaint region must span both rects');
  assert.match(js, /bottom: Math\.max\(a\.bottom, b\.bottom\)/, 'the repaint region must span both rects');
  return new Function('painted', 'current', js);
}

const row = (top) => ({ left: 40, top, right: 460, bottom: top + 30 });

function frames(region, moves) {
  const visible = [];
  let painted = null;
  for (const top of moves) {
    const current = row(top);
    const invalidated = region(painted, current);
    painted = current;
    for (let i = visible.length - 1; i >= 0; i--) {
      if (visible[i].top >= invalidated.top && visible[i].top < invalidated.bottom) visible.splice(i, 1);
    }
    if (current.top >= invalidated.top && current.top < invalidated.bottom) visible.push(current);
    painted = region(painted, current);
  }
  return visible;
}

test('SOFT-2642 an empty session keeps one row of working dots while the layout moves it', () => {
  const region = repaintRegion();
  assert.deepEqual(region(null, row(100)), row(100));
  assert.deepEqual(region(row(100), null), row(100));
  assert.deepEqual(region(row(100), row(130)), { left: 40, top: 100, right: 460, bottom: 160 });

  const naive = (painted, current) => current;
  const moves = [100, 130, 160, 190];
  assert.equal(frames(naive, moves).length, moves.length, 'the harness must catch dots left behind by a move');
  assert.deepEqual(frames(region, moves), [row(190)]);
  assert.deepEqual(frames(region, [...moves, 160, 130]), [row(130)]);
});

test('SOFT-2642 the working dots repaint uses one rect for the paint and the invalidation', () => {
  const sync = sliceFn('chatWorkingSync');
  assert.match(sync, /chatWorkingScreenRect\(g_working_rect, app_state\.g_chat_scroll_y\)/);
  assert.match(sync, /chatWorkingRepaintRegion\(g_working_painted, current\)/);
  assert.match(sync, /g_working_painted = current;/);

  const paint = sliceFn('chatPaintWorking');
  assert.equal(paint.match(/chatPaintWorkingDots\(/g).length, 1, 'one paint call per frame');
  assert.match(paint, /chatWorkingScreenRect\(g_working_rect, app_state\.g_chat_scroll_y\)/);
  assert.match(paint, /g_working_painted = chatWorkingRepaintRegion\(g_working_painted, rc\);/);
  assert.match(paint, /if \(!chatWorkingDotsVisible\(\) or !chatRectOverlaps\(rc, paint\)\) return;/);

  const dots = sliceFn('chatPaintWorkingDots');
  assert.match(dots, /for \(0\.\.3\) \|i\|/, 'the indicator is exactly three dots');
  assert.equal((source.match(/chatPaintWorkingDots\(/g) || []).length, 3);
});

test('SOFT-2642 the working row follows the content when the top pad changes', () => {
  const topPad = sliceFn('chatSetTopPad');
  assert.match(topPad, /if \(g_working_rect\) \|\*rect\| \{\n\s+rect\.top \+= delta;\n\s+rect\.bottom \+= delta;/);
});
