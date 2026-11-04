const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const render = fs.readFileSync('src/chat_render.zig', 'utf8');
const model = fs.readFileSync('src/chat_markdown.zig', 'utf8');
const find = fs.readFileSync('src/chat_find_ui.zig', 'utf8');
const session = fs.readFileSync('src/chat_session.zig', 'utf8');

test('tool runs use a stable head across layout, painting, click and refresh', () => {
  assert.match(model, /pub fn toolGroup\(items: \[\]const Block, index: usize\) \?Range/);
  assert.match(model, /while \(start > 0 and items\[start - 1\]\.role == \.tool\)/);
  assert.match(render, /toolGroup\(tool_blocks, reuse - 1\).*reuse = group\.start/);
  assert.match(render, /tool_blocks\[group\.start\]\.tool_open/);
  assert.match(render, /group\.end - group\.start/);
  assert.match(render, /if \(index != group\.start\) return null/);
  assert.match(find, /g_chat_blocks\[range\.start\]\.tool_open = true/);
  assert.match(session, /open_tools\.contains\(block\.tool_id\)/);
  assert.doesNotMatch(render, /if \(app_state\.g_chat_blocks\[i\]\.role == \.tool or g_reaction_view\.hides\(i\)\) continue/);
});

test('tool painter has no status colors or cards', () => {
  const painter = render.slice(render.indexOf('fn chatPaintProjectedBlock('));
  const tool = painter.slice(painter.indexOf('        .tool => {'), painter.indexOf('        .code => {'));
  assert.match(tool, /ensureChatCodeFont/);
  assert.match(tool, /block\.detail_len/);
  assert.doesNotMatch(tool, /tool_status|fillRoundRectAA|diff_added|diff_removed/);
});

test('group iteration caches each range and previews stay bounded', () => {
  const layout = render.slice(render.indexOf('pub fn chatRelayout('), render.indexOf('pub fn chatImageReady('));
  const paint = render.slice(render.indexOf('pub fn chatPaintTranscriptContent('));
  for (const source of [layout, paint]) {
    assert.match(source, /tool_group == null or i >= tool_group\.\?\.end/);
    assert.match(source, /tool_group = @import\("chat_markdown\.zig"\)\.toolGroup/);
  }
  assert.match(model, /end < 320/);
  assert.match(model, /lines == 4/);
  const measure = render.slice(render.indexOf('fn chatMeasureProjectedBlockRect('), render.indexOf('fn chatMeasureEchoRect('));
  const painter = render.slice(render.indexOf('fn chatPaintProjectedBlock('), render.indexOf('fn chatPaintEcho('));
  for (const source of [measure, painter]) assert.equal((source.match(/\.toolPreview\(/g) || []).length, 2);
});

test('header evidence and shortcut routing cover both chat inputs', () => {
  const composer = fs.readFileSync('src/chat_composer.zig', 'utf8');
  const shortcuts = fs.readFileSync('src/shortcuts.zig', 'utf8');
  assert.match(render, /\[chat\] steps first=\{d\} count=\{d\} open=\{d\} header=\{d\},\{d\},\{d\},\{d\}/);
  assert.match(render, /WM_KEYDOWN => \{\s*if \(@import\("chat_composer\.zig"\)\.chatToolStepsKeyDown\(wp\)\)/);
  assert.match(composer, /msg == WM_KEYDOWN and chatToolStepsKeyDown\(wp\)\) \{\s*dropPendingActivationChar\(hwnd, 0x0A\);/);
  assert.match(composer, /vk == 0x4A and ctrl and shift and !alt/);
  assert.match(composer, /!chatComposerOwnsKey\(WM_KEYDOWN, 0x4A, true, false, 0\)/);
  assert.match(shortcuts, /wp == WM_KEYDOWN and @import\("chat_composer\.zig"\)\.chatToolStepsKeyDown\(kb\.vkCode\)/);
});
