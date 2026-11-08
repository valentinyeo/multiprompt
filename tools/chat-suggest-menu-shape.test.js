const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'chat_composer.zig'), 'utf8');

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}\n', start));
}

test('the @ and / suggestion list uses the plus menu look with rounded corners', () => {
  const paint = body('chatAcPaint');
  assert.match(paint, /more_menu\.zig"\)\.colors\(\)/);
  assert.match(paint, /fillRoundRect\([^)]*chatAcRadius\(\)/);
  assert.doesNotMatch(paint, /selected_bg/);
  assert.doesNotMatch(paint, /var strip = RECT\{ \.left = 0/);
  assert.match(source, /CreateRoundRectRgn\(0, 0, ac_w \+ 1, ac_h \+ 1, chatAcRadius\(\) \* 2/);
});

test('the suggestion list drops the key hint footer and pads rows inside the rounded card', () => {
  const paint = body('chatAcPaint');
  assert.doesNotMatch(source, /Tab or Enter to insert/);
  assert.match(paint, /const top = chatAcPad\(\) \+ y \* row_h;/);
  assert.match(paint, /drawAscii\(dc, "Bot"/);
  assert.match(source, /@divFloor\(GET_Y\(lp\) - chatAcPad\(\)/);
});
