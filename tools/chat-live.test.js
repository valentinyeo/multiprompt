const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('D1 the live model subscribes with a replay cursor on the existing channel', () => {
  const live = read('src/chat_live.zig');
  assert.match(live, /"events_subscribe"/);
  assert.ok(live.includes('provider\\":\\"claude'));
  assert.ok(live.includes('after\\":{d}'));
  assert.match(live, /"events_unsubscribe"/);
});

test('D1 every live kind the host sends reduces into the model', () => {
  const live = read('src/chat_live.zig');
  for (const kind of [
    'turn.started',
    'text.delta',
    'thinking.delta',
    'text.done',
    'thinking.done',
    'item.started',
    'item.done',
    'turn.ended',
    'host.status',
  ]) assert.ok(live.includes(`"${kind}"`), kind);
});

test('D1 a duplicate seq never moves the cursor and a delta replaces the text', () => {
  const live = read('src/chat_live.zig');
  assert.match(live, /if \(seq <= self\.after\) return false;/);
  assert.match(live, /self\.text\.clearRetainingCapacity\(\);\s*\n\s*try self\.text\.appendSlice\(a, value\[0\.\.@min\(value\.len, MAX_TEXT\)\]\);/);
});

test('D1 the live channel is opened only for a hosted agent chat and feeds the model', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /chatMessageGoesToHost\(shell\.kind, shell\.ai_agent\)/);
  assert.match(session, /chatLiveStreamEnsure\(key\)/);
  assert.match(session, /@import\("chat_live\.zig"\)\.subscribeLine\(/);
  assert.match(session, /@import\("chat_live\.zig"\)\.applyPage\(/);
});

test('D1 the live tail renders inside the same transcript buffer the view reads', () => {
  const session = read('src/chat_session.zig');
  assert.match(session, /const live_tail = if \(len < app_state\.g_chat_capture\.len\)/);
  assert.match(session, /app_state\.g_chat_last_len = total;/);
  assert.match(session, /app_state\.g_chat_block_count \+= live_tail\.blocks;/);
});

test('D1 working dots follow the live turn, not the screen', () => {
  const layout = read('src/window_layout.zig');
  assert.match(layout, /pub fn chatLiveWorking\(\) bool/);
  assert.match(layout, /@import\("chat_live\.zig"\)\.running\(app_state\.shells\[app_state\.active_shell\]\.shell_id\)/);
  assert.match(layout, /app_state\.g_chat_screen_status_len > 0 or chatLiveWorking\(\)\);/);
});
