const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const session = fs.readFileSync(path.join(root, 'src/chat_session.zig'), 'utf8');
const live = fs.readFileSync(path.join(root, 'src/chat_live.zig'), 'utf8');

function block(source, header) {
  const start = source.indexOf(header);
  assert.ok(start >= 0, header);
  let depth = 0;
  for (let i = start; i < source.length; i++) {
    if (source[i] === '{') depth += 1;
    else if (source[i] === '}') {
      depth -= 1;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }
  assert.fail(`${header} is unclosed`);
}

function revisionBranch() {
  const ready = session.indexOf('pub fn chatFileOnReady() void {');
  assert.ok(ready >= 0, 'chatFileOnReady');
  const start = session.indexOf('if (live_revision != g_chat_live_seen_revision) {', ready);
  assert.ok(start >= 0, 'live revision branch');
  const end = session.indexOf('var read_ready', start);
  assert.ok(end > start, 'live revision branch ends');
  return session.slice(start, end);
}

test('a live revision change never repaints the whole window', () => {
  const branch = revisionBranch();
  assert.doesNotMatch(branch, /InvalidateRect\(app_state\.g_main_hwnd, null, 0\)/);
  assert.match(branch, /const pane = chatViewLayout\(\)\.pane;/);
  assert.match(branch, /InvalidateRect\(app_state\.g_main_hwnd, &pane, 0\)/);
});

test('a live revision change redraws the sidebar only when its preview line differs', () => {
  const branch = revisionBranch();
  assert.match(branch, /g_chat_live_preview_shell != live_shell/);
  assert.match(branch, /std\.meta\.eql\(g_chat_live_preview, preview\)/);
  assert.equal((branch.match(/preview_changed = true;/g) || []).length, 1);
  assert.ok(branch.indexOf('std.meta.eql(g_chat_live_preview, preview)') < branch.indexOf('preview_changed = true;'));
  assert.match(session, /var g_chat_live_preview_shell: u32 = 0;/);
  assert.match(session, /var g_chat_live_preview: @import\("agent_second_line\.zig"\)\.Line = \.\{\};/);
});

test('a page that changes nothing on screen does not bump the live revision', () => {
  const apply = block(live, 'pub fn applyPage(');
  assert.doesNotMatch(apply, /if \(changed\) live\.touch\(\);/);
  assert.match(apply, /if \(changed\) _ = live\.touchIfVisible\(\);/);
  assert.match(live, /pub fn touchIfVisible\(self: \*Live\) bool/);
  assert.match(live, /pub fn visibleStamp\(self: \*const Live\) u64/);
  assert.match(block(live, 'pub fn touch(self: *Live) void {'), /self\.stamp = self\.visibleStamp\(\);/);
});

test('the visible stamp covers every field the chat paints from', () => {
  const stamp = block(live, 'pub fn visibleStamp(');
  for (const field of [
    'self.state',
    'self.held',
    'self.ended',
    'self.card_dismissed',
    'self.reply_in_history',
    'self.request.open',
    'self.request.titleSlice()',
    'self.prompt.identity',
    'self.prompt.groups',
    'self.answer_lens',
    'self.settings.model',
    'self.settings.applied',
    'self.sent_id',
    'item.text.items',
    'item.status',
    'item.done',
  ]) assert.ok(stamp.includes(field), field);
});
