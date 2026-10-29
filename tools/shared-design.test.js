const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const read = file => fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
const section = (source, signature) => {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} exists`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
};

test('dictation uses foreground and raised theme roles, never accent or selected colours', () => {
  const source = section(read('src/window_layout.zig'), 'fn paintChatMicButton(');
  assert.match(source, /if \(active\) @import\("themes.zig"\)\.themeConsoleFg\(\)/);
  assert.match(source, /if \(active\) @import\("themes.zig"\)\.themeRaised\(\)/);
  assert.doesNotMatch(source, /"accent"|"selected_bg"|RGB\(80, 150, 255\)/);
  const roles = section(read('src/themes.zig'), 'pub fn themeRaised(');
  assert.match(roles, /themeReaderDark\(\)\) return tokens.ReaderRaised/);
  assert.doesNotMatch(roles, /accent|selected_bg/);
});

test('the actual composer calls the shared pill with live timer and microphone bars', () => {
  const source = section(read('src/window_layout.zig'), 'fn paintChatMicPill(');
  assert.match(source, /tokens.micPill\(&canvas/);
  assert.match(source, /chatDictationElapsedNow\(\) \/ 1000/);
  assert.match(source, /chat_dictation_wave/);
  const shared = read('src/design_tokens.zig');
  assert.match(shared, /pub fn micPill\(/);
  assert.match(shared, /test "active pill paints white stop timer and eight bounded level bars at every DPI"/);
  assert.match(shared, /pub const body_size: i32 = 15;/);
  assert.match(shared, /pub const column_width: i32 = 920;/);
  assert.match(read('build.zig'), /"src\/design_tokens.zig"/);
});

test('bubbles composer fields buttons and menus use the same shared painters', () => {
  const layout = read('src/window_layout.zig');
  assert.match(layout, /tokens.roundButton\(&canvas/);
  assert.match(layout, /tokens.field\(&canvas/);
  const bubbles = section(read('src/chat_render.zig'), 'fn fillBubbleStyled(');
  assert.match(bubbles, /design_tokens.zig"\)\.bubble\(&canvas/);
  assert.doesNotMatch(bubbles, /while|gradientColor/);
  const menu = read('src/message_menu.zig');
  assert.match(menu, /tokens.field\(&canvas/);
  assert.match(menu, /tokens.row\(&canvas/);
});
