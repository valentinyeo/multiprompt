const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const sidebar = fs.readFileSync('src/sidebar.zig', 'utf8');
const drawing = fs.readFileSync('src/drawing.zig', 'utf8');

function body(source, signature) {
  const at = source.indexOf(signature);
  assert.notEqual(at, -1, `${signature} exists`);
  return source.slice(at, source.indexOf('\n}', at) + 2);
}

test('chat sidebar shows names and unread only, with details on hover', () => {
  const row = body(sidebar, 'fn paintChatSidebarRow(');
  assert.doesNotMatch(row, /drawAgentIcon|DrawIconEx|DRAFT|browser_frozen|browser_suspended|drawFavoriteDot/);
  assert.match(row, /needs_attention[^]*?RGB\(137, 180, 248\)/);
  assert.match(row, /g_sidebar_hover == index/);
  assert.match(row, /if \(hovered\)[^]*?inboxRelTime/);
  assert.match(row, /if \(hovered\)[^]*?00d7/);
  assert.match(sidebar, /if \(app_state\.g_chat_active and !app_state\.g_sidebar_collapsed\) \{\s*paintChatSidebarRow/);
});

test('chat title is regular text without agent icons', () => {
  const layout = body(drawing, 'pub fn chatTitleLayout(');
  assert.doesNotMatch(layout, /shell\.ai_agent|shell\.needs_attention/);
  assert.match(layout, /measureTitleText\(uiFontTitle\(\), name\)/);
  const paint = body(drawing, 'fn paintChatTitlePill(');
  assert.match(paint, /SelectObject\(hdc, uiFontTitle\(\)\)/);
  assert.doesNotMatch(paint, /drawAgentIcon|drawAttentionDot/);
});
