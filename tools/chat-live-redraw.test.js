const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const session = fs.readFileSync(path.join(root, 'src/chat_session.zig'), 'utf8');
const live = fs.readFileSync(path.join(root, 'src/chat_live.zig'), 'utf8');

function body(source, header) {
  const start = source.indexOf(header);
  assert.ok(start >= 0, header);
  const next = source.indexOf('\n}\n', start);
  return source.slice(start, next);
}

function revisionBranch() {
  const fn = body(session, 'pub fn chatFileOnReady() void {');
  const start = fn.indexOf('if (live_revision != g_chat_live_seen_revision) {');
  assert.ok(start >= 0, 'live revision branch');
  const end = fn.indexOf('var read_ready', start);
  return fn.slice(start, end);
}

test('a live revision change never repaints the whole window', () => {
  const branch = revisionBranch();
  assert.ok(!/InvalidateRect\(app_state\.g_main_hwnd, null, 0\)/.test(branch));
  assert.ok(/chatViewLayout\(\)\.pane/.test(branch));
});

test('a live revision change redraws the sidebar only when the preview line differs', () => {
  const branch = revisionBranch();
  assert.ok(!/^\s*preview_changed = true;/m.test(branch.split('if (g_chat_live_preview_shell')[0]));
  assert.ok(/std\.meta\.eql\(g_chat_live_preview, preview\)/.test(branch));
  assert.ok(/g_chat_live_preview_shell != live_shell/.test(branch));
});

test('a page that changes nothing on screen does not bump the live revision', () => {
  const apply = body(live, 'pub fn applyPage(');
  assert.ok(!/if \(changed\) live\.touch\(\);/.test(apply));
  assert.ok(/if \(changed\) _ = live\.touchIfVisible\(\);/.test(apply));
  assert.ok(/pub fn touchIfVisible\(self: \*Live\) bool/.test(live));
  assert.ok(/pub fn visibleStamp\(self: \*const Live\) u64/.test(live));
});

test('the visible stamp covers every field the chat paints from', () => {
  const stamp = body(live, 'pub fn visibleStamp(');
  for (const field of ['self.state', 'self.held', 'self.ended', 'self.request.open', 'self.prompt.identity', 'self.settings.model', 'self.settings.applied', 'item.text.items', 'item.status', 'item.done']) {
    assert.ok(stamp.includes(field), field);
  }
});
