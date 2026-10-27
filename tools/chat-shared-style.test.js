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

test('received messages use one below-message panel with real request IDs', () => {
  const render = fs.readFileSync('src/chat_render.zig', 'utf8');
  assert.match(render, /requestIdAlloc/);
  assert.match(render, /message_menu.zig"\)\.track/);
  assert.match(render, /11 => if \(request_id\)/);
  assert.match(render, /if \(action == 1\) chatReplyToBlock\(index\) else _ = chatMessageMenu/);
  const menu = fs.existsSync('src/message_menu.zig') ? fs.readFileSync('src/message_menu.zig', 'utf8') : '';
  assert.match(menu, /scaled\(232\)/);
  assert.match(menu, /scaled\(34\)/);
  assert.match(menu, /ReaderControl/);
  assert.match(menu, /ReaderOutline/);
  assert.match(menu, /ReaderRaised/);
  assert.match(menu, /anchor.bottom \+ scaled\(6\)/);
});

test('pull requests run reaction proof instead of the appearance shortcut', () => {
  const workflow = fs.readFileSync('.github/workflows/verify.yml', 'utf8');
  const matrix = workflow.match(/^        feature: (.+)$/m)[1];
  assert.match(matrix, /!inputs\.chat_reactions_proof && github\.event_name == 'pull_request'/);
  const entry = fs.readFileSync('.github/workflows/chat-style.yml', 'utf8');
  assert.match(entry, /feature: chat-delivery/);
  assert.match(entry, /chat_reactions_proof: true/);
});

test('branch proof uses the full proposed change and installs the regression compiler', () => {
  const tests = fs.readFileSync('.github/workflows/test.yml', 'utf8');
  assert.match(tests, /base: \$\{\{ github\.event\.pull_request\.base\.sha \|\| \(github\.ref != 'refs\/heads\/master' && 'origin\/master'\)/);
  const red = fs.readFileSync('.github/workflows/check-red-run.yml', 'utf8');
  assert.ok(red.indexOf('name: Install Zig 0.16.0') >= 0);
  assert.ok(red.indexOf('name: Install Zig 0.16.0') < red.indexOf('name: Require changed tests'));
});

test('composer separates attachment from its pill and paints the approved send shade', () => {
  const composer = body(fs.readFileSync('src/chat_composer.zig', 'utf8'), 'pub fn chatViewLayout(');
  assert.match(composer, /\.left = left \+ send_size \+ uiScaled\(8\)/);
  assert.match(composer, /const attach_btn = RECT\{\s*\.left = left,[^]*?\.right = left \+ send_size,/);
  assert.match(composer, /\.left = composer_card\.left \+ uiScaled\(14\)/);
  const paint = body(fs.readFileSync('src/window_layout.zig', 'utf8'), 'fn paintChatButton(');
  assert.match(paint, /!app_state\.g_light_theme[^]*?glyph == \.send[^]*?tokens\.ReaderRaised/);
});
