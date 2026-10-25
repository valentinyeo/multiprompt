const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8').replace(/\r\n/g, '\n');
const sources = Object.fromEntries(['chat_composer', 'window_layout', 'chat_render', 'chat_style', 'app_state'].map(name => [name, read(`src/${name}.zig`)]));
function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, `unterminated ${name}`);
  return source.slice(start, end + 2);
}
function requires(text, ...snippets) {
  for (const snippet of snippets) assert.ok(text.includes(snippet), `missing ${snippet}`);
}
function gate(name, check, file, before, after = 'REMOVED') {
  test(`IGSH-849 ${name}`, () => {
    check(sources);
    assert.ok(sources[file].includes(before), `negative control target: ${before}`);
    const broken = { ...sources, [file]: sources[file].replace(before, after) };
    assert.throws(() => check(broken), assert.AssertionError);
  });
}

gate('progress/working strip is neither painted nor reserved; permissions retain space', s => {
  assert.doesNotMatch(body(s.window_layout, 'paintChatView'), /g_chat_working_applied|workingBarText|[Pp]rogress/);
  assert.match(body(s.window_layout, 'chatWorkingIndicatorH'), /return if \(chatPermissionVisible\(\)\) uiScaled\(36\) else 0;/);
  requires(body(s.chat_composer, 'chatViewLayout'), 'composer_card.top - gap - chatWorkingIndicatorH() - chatNewMessagesHeight()');
}, 'window_layout', 'return if (chatPermissionVisible()) uiScaled(36) else 0;', 'return uiScaled(22);');

for (const [label, token] of [['Archive', 'chatArchiveButton'], ['Remind me', 'chatRemindButton'], ['Wait', 'chatWaitButton']]) {
  gate(`${label} control has no paint, hit target or reserved slot`, s => {
    const ui = [body(s.window_layout, 'paintChatView'), body(s.chat_composer, 'chatButtonAt'), body(s.chat_composer, 'chatViewLayout')].join('\n');
    assert.ok(!ui.includes(token));
    assert.ok(!ui.includes(`L("${label}")`));
    assert.doesNotMatch(ui, /\.(?:archive|remind|wait)_(?:btn|rect|shown)/i);
  }, 'window_layout', 'pub fn paintChatView(hdc: HANDLE) void {', `pub fn paintChatView(hdc: HANDLE) void {\n    ${token}();`);
}

gate('ordinary sender labels are removed along with their header height', s => {
  assert.doesNotMatch(body(s.chat_render, 'chatPaintBlock'), /chatPaintAgentHeader|L\("(?:You|Claude|Codex|Agent)"\)/);
  assert.match(body(s.chat_style, 'headerHeight'), /return 0;/);
}, 'chat_style', 'pub fn headerHeight(_: md.Block, _: i32) i32 {\n    return 0;', 'pub fn headerHeight(_: md.Block, _: i32) i32 {\n    return 22;');

gate('timestamps are absent and reserve no row; attribution and read receipts survive', s => {
  assert.doesNotMatch(body(s.chat_render, 'chatPaintTime'), /block\.time|block\.zone/);
  assert.doesNotMatch(body(s.chat_render, 'chatMeasureBlockRect'), /block\.time/);
  assert.doesNotMatch(body(s.chat_render, 'chatPaintBlock'), /block\.time/);
  requires(body(s.chat_render, 'chatPaintTime'), 'block.sender', 'Read');
  requires(body(s.chat_render, 'chatMeasureBlockRect'), 'chatEchoBlockConfirmed(buf, block)');
}, 'chat_render', 'fn chatPaintTime(hdc: HANDLE, block: ChatBlock, area: RECT, right: bool, confirmed: bool) void {', 'fn chatPaintTime(hdc: HANDLE, block: ChatBlock, area: RECT, right: bool, confirmed: bool) void {\n    _ = block.time;');

gate('chat bubbles and composer use rounded corners rather than the old four pixels', s => {
  assert.match(s.app_state, /CHAT_BUBBLE_RADIUS = 20;/);
  requires(body(s.window_layout, 'chatSurfaceRadius'), 'uiScaled(CHAT_BUBBLE_RADIUS)');
  requires(body(s.chat_render, 'chatPaintBlock'), 'uiScaled(CHAT_BUBBLE_RADIUS)');
  requires(body(s.window_layout, 'paintChatButton'), 'const radius = rc.bottom - rc.top;');
}, 'app_state', 'CHAT_BUBBLE_RADIUS = 20;', 'CHAT_BUBBLE_RADIUS = 4;');
