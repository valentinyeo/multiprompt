const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

test('SOFT-2442 double-click toggles a thumbs up and drag still selects text', () => {
  const shortcuts = read('src/shortcuts.zig');
  assert.match(shortcuts, /\.a = "Double click a message", \.b = "Add a thumbs up, or remove it"/);
  assert.doesNotMatch(shortcuts, /double-click a word/);
  const doc = read('openwiki/operations/keyboard-shortcuts.md');
  assert.match(doc, /\| Double click a message \| Add a thumbs up, or remove it \|/);
  assert.doesNotMatch(doc, /double-click a word/);
  const render = read('src/chat_render.zig');
  const down = render.slice(render.indexOf('WM_LBUTTONDOWN =>'), render.indexOf('WM_LBUTTONUP =>'));
  assert.match(down, /chatTranscriptMouseDown\(hwnd, GET_X\(lp\), GET_Y\(lp\)\)/);
  const dbl = render.slice(render.indexOf('WM_LBUTTONDBLCLK =>'), render.indexOf('WM_RBUTTONDOWN =>'));
  assert.match(dbl, /chatDoubleClickThumbs\(hwnd, GET_X\(lp\), GET_Y\(lp\)\)/);
  assert.match(dbl, /chatTranscriptMouseDown\(hwnd, GET_X\(lp\), GET_Y\(lp\)\)/);
  assert.match(render, /pub fn chatToggleReaction\(reference: u64, quote: \[\]const u16, emoji: chat_reaction\.Emoji\) void/);
  const menu = render.slice(render.indexOf('switch (cmd)'), render.indexOf('var g_reply_jump'));
  assert.match(menu, /8 => if \(reply_text\) \|quote\| \{\s*chatToggleReaction\(reaction_reference, quote, \.like\);/);
  const reaction = read('src/chat_reaction.zig');
  assert.match(reaction, /fn noteLike\(self: \*View, target: usize, emoji: Emoji, pending: bool\) void/);
  assert.match(reaction, /self\.badges\.items\[target\] \^= emoji\.bit\(\)/);
  assert.match(reaction, /test "SOFT-2442 a second thumbs up removes the badge and one pending copy does not"/);
});
