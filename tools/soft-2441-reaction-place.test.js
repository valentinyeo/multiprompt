const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('SOFT-2441 reaction paint uses body-sized color emoji and the message tail', () => {
  const reaction = read('src/chat_reaction.zig');
  assert.match(reaction, /fn anchorBadges/);
  assert.match(reaction, /test "SOFT-2441 a code-free reaction anchors on the last paragraph block"/);
  const resolve = reaction.slice(reaction.indexOf('fn resolveQuote'), reaction.indexOf('fn resolve('));
  assert.match(resolve, /indexOf\(u16, normalized\(body, buffer\), needle\)/);
  assert.match(resolve, /found = target\.last/);
  const render = read('src/chat_render.zig');
  const fonts = read('src/chat_fonts.zig');
  assert.match(fonts, /fn ensureChatEmojiFont\(\) HANDLE/);
  assert.match(fonts, /emoji\(-uiScaled\(app_state\.g_chat_font_pt\)\)/);
  const paint = render.slice(render.indexOf('fn chatPaintReactions'), render.indexOf('fn chatMessageBounds'));
  assert.doesNotMatch(paint, /g_chat_rich_fonts\[11\]/);
  assert.match(paint, /ensureChatEmojiFont\(\)/);
  assert.match(paint, /uiScaled\(app_state\.g_chat_font_pt\)/);
  assert.match(render, /chat_style\.runBounds\(app_state\.g_chat_bubble_pos/);
  assert.match(read('src/app_state.zig'), /g_chat_emoji_font/);
});