const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../src/chat_render.zig'), 'utf8');

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\nfn ', start + 1);
  return source.slice(start, end < 0 ? source.length : end);
}

test('SOFT-2441 reaction emoji uses the body-sized colour face, not the bold code font', () => {
  const font = body('chatReactionEmojiFont');
  const paint = body('chatPaintReactions');
  assert.match(font, /g_chat_rich_fonts\[0\]/);
  assert.match(font, /emoji\(-uiScaled\(app_state\.g_chat_font_pt\)\)/);
  assert.doesNotMatch(font, /g_chat_rich_fonts\[11\]/);
  assert.match(paint, /chatReactionEmojiFont\(\)/);
  assert.match(paint, /chatDrawText\(/);
  assert.doesNotMatch(paint, /g_chat_rich_fonts\[11\]/);
  assert.doesNotMatch(paint, /uiScaled\(17\)/);
  assert.match(body('chatRichFont'), /g_chat_rich_fonts\[11\]/);
});

test('SOFT-2441 the hover react button is a colour emoji glyph', () => {
  const paint = body('chatPaintMessageActions');
  assert.doesNotMatch(paint, /\\u\{263A\}/);
  assert.match(paint, /\\u\{1F642\}/);
  assert.match(paint, /chatReactionEmojiFont\(\)/);
  assert.match(paint, /\\u\{1F642\}[\s\S]*chatDrawText\(/);
  assert.match(paint, /\\u\{21A9\}/);
  assert.match(paint, /DrawTextW\(/);
});
