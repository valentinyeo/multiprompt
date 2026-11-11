const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const src = (name) => fs.readFileSync(path.join(__dirname, '..', 'src', name), 'utf8');

function body(text, signature) {
  const start = text.indexOf(signature);
  assert.ok(start >= 0, `${signature} exists`);
  const next = text.indexOf('\npub fn ', start + signature.length);
  const nextPrivate = text.indexOf('\nfn ', start + signature.length);
  const ends = [next, nextPrivate].filter((i) => i > 0);
  return text.slice(start, ends.length ? Math.min(...ends) : undefined);
}

test('sidebar rows outside the repainted area are not drawn again', () => {
  const paint = body(src('sidebar.zig'), 'pub fn paintSidebar(hdc: HANDLE) void {');
  const loop = paint.slice(paint.indexOf('for (0..row_count) |ri| {'));
  const visible = loop.indexOf('RectVisible(hdc, &row_rc) == 0) continue;');
  assert.ok(visible > 0, 'row loop skips rows the dirty rect does not touch');
  for (const call of ['paintChatSidebarRow(', 'paintPinnedBot(', 'paintRoomRow(', 'bot_photo.zig").draw(']) {
    const at = loop.indexOf(call);
    assert.ok(at > visible, `${call} runs only after the visibility check`);
  }
});

test('a scroll check that changes nothing does not invalidate the main window', () => {
  const fn = body(src('chat_render.zig'), 'pub fn chatScrollStateChanged(viewport_h: i32) void {');
  const early = fn.indexOf('was_scrolled_up == app_state.g_chat_scrolled_up) return;');
  const notify = fn.indexOf('chatNewMessagesChanged(had_messages);');
  assert.ok(early > 0, 'unchanged pill state returns early');
  assert.ok(notify > early, 'the pill invalidate runs only after the unchanged check');
  assert.match(fn, /before\.value == app_state\.g_chat_new_messages\.value/);
});

test('IGSH-1907 an empty message poll neither rewrites the outbox nor repaints the window', () => {
  const fn = body(src('chat_send.zig'), 'fn chatMessageSyncFinish() void {');
  const saves = [...fn.matchAll(/saveChatOutbox\(\)/g)].map((m) => m.index);
  assert.equal(saves.length, 1, 'one outbox save per poll');
  assert.match(fn, /if \(items\.len > 0 and !saveChatOutbox\(\)\)/, 'the save is skipped when the poll returned nothing');
  const guard = fn.indexOf('if (items.len == 0) return;');
  const notify = fn.lastIndexOf('chatOutboxChanged();');
  assert.ok(guard > 0 && notify > guard, 'the outbox change notice runs only after the empty-poll return');
});
