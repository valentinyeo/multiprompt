const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
function body(file, name) {
  const source = read(file);
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}

test('IGSH-1599 shared Windows proof binaries use the same CPU floor as native CI', () => {
  const workflow = read('.github/workflows/verify.yml');
  const shared = workflow.slice(workflow.indexOf('- name: Build the Windows app once for this push'), workflow.indexOf('  reopen-board-contract:'));
  assert.match(shared, /zig build[^\r\n]* -Drelease=false(?:\s|$)/);
  assert.match(shared, /zig build[^\r\n]* -Dcpu=x86_64_v3(?:\s|$)/);
});

test('IGSH-1599 live approval cannot bypass the duplicate-answer guard', () => {
  const send = body('src/chat_send.zig', 'chatPermissionAnswer');
  const guard = send.indexOf('permission_answered');
  assert.ok(guard >= 0, 'a picked permission cannot be sent twice');
  assert.ok(guard < send.indexOf('chatLiveApprovalAnswer('), 'live and console answers share the guard');
});

test('IGSH-1599 permissions use transcript choices instead of a separate composer bar', () => {
  assert.match(body('src/window_layout.zig', 'chatWorkingIndicatorH'), /return 0;/);
  assert.doesNotMatch(body('src/window_layout.zig', 'paintChatView'), /paintChatPermission/);
  const render = read('src/chat_render.zig');
  assert.match(render, /permission_presentation/);
  assert.match(body('src/chat_render.zig', 'chatChoicesRefresh'), /permission/);
});

test('IGSH-1599 double-clicking visible answer rows cannot trigger the blank-space view toggle', () => {
  const render = read('src/chat_render.zig');
  const start = render.indexOf('WM_LBUTTONDBLCLK => {');
  assert.ok(start >= 0);
  const handler = render.slice(start, render.indexOf('const toggle = @import("dblclick_toggle.zig");', start));
  assert.match(handler, /g_choice\.present/);
  assert.match(handler, /for \(g_choice_rects\[0\.\.g_choice_rect_count\]\)/);
  assert.match(handler, /pointInRect\(rc, GET_X\(lp\), GET_Y\(lp\) \+ app_state\.g_chat_scroll_y\)\) return 0;/);
  assert.match(handler, /g_permission_echo_rect/);
});

test('IGSH-1599 approved permission wording stays distinct from provider digits', () => {
  const permission = read('src/chat_permission.zig');
  for (const text of ['Approve', 'Always allow this session', 'Decline', 'Run it once.', 'Don’t ask again in this chat.', 'Skip it. Say why in the chat.']) {
    assert.ok(permission.includes(`"${text}"`), text);
  }
  assert.match(permission, /picked: Action/);
  const send = body('src/chat_send.zig', 'chatPermissionAnswer');
  assert.match(send, /g_chat_permission\.digit\(action\)/);
});
