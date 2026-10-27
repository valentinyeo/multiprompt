const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('Chat View and reaction menu share the native color-font painter', () => {
  assert.match(read('src/dwrite_text.zig'), /mp_draw_color_text\(hdc, text,/);
  assert.match(read('src/fonts.zig'), /if \(reaction\) \{\s*_ = @import\("dwrite_text.zig"\)\.draw/);
  assert.match(read('src/color_emoji.cpp'), /D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT/);
  assert.match(read('src/color_emoji.cpp'), /Segoe UI Emoji/);
});

test('Color clusters retain source text and original GDI selection advances', () => {
  assert.match(read('src/dwrite_text.zig'), /IGSH-1089.*color.*source/);
  assert.match(read('src/color_emoji.cpp'), /const wchar_t \*input/);
  assert.match(read('src/color_emoji.cpp'), /GetTextExtentPoint32W\(dc, text, end, &prefix\)/);
  assert.match(read('src/color_emoji.cpp'), /0x200d/);
  assert.match(read('src/color_emoji.cpp'), /0x1f3fb/);
  assert.match(read('src/color_emoji.cpp'), /0x1f1e6/);
});
