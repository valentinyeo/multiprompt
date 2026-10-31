const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1266 a tab in terminal view schedules no chat fetch', () => {
  const view = read('src/chat_view.zig');
  assert.match(view, /pub fn fetchWanted\(chat_active: bool, tab_wants_chat: bool\) bool \{\s*return chat_active and tab_wants_chat;/,
    'the fetch decision must depend on the active tab, not only on the global Chat View flag');
  assert.match(view, /test "IGSH-1266 a tab in terminal view schedules no chat fetch"/);

  const session = read('src/chat_session.zig');
  assert.match(session, /pub fn chatActiveTabWantsChat\(\) bool \{[\s\S]*?shouldShow\(app_state\.shells\[app_state\.active_shell\]\.chat_view_on\)/,
    'the gate must read the active tab chat_view_on');
  assert.match(session, /pub fn chatFetchWanted\(chat_active: bool\) bool \{\s*return @import\("chat_view\.zig"\)\.fetchWanted\(chat_active, chatActiveTabWantsChat\(\)\);\s*\}/);
  assert.match(session, /if \(\(!delivery and !chatFetchWanted\(app_state\.g_chat_active\)\) or key\.shell_id == 0\) return;/,
    'the request path must refuse a terminal-view tab');
  assert.match(session, /if \(chatFetchWanted\(app_state\.g_chat_active\)\) chatFileRequest\(chatFileIdentity\(\)\);/,
    'the ready path must refuse a terminal-view tab too');
  assert.ok(!/if \(app_state\.g_chat_active\) chatFileRequest\(chatFileIdentity\(\)\);/.test(session),
    'the old chat_active only gate must be gone');
  assert.match(session, /const live_shell_id = if \(app_state\.g_chat_active and app_state\.active_shell < app_state\.shell_count and chatActiveTabWantsChat\(\)\)/,
    'a terminal-view tab must not keep a live history stream');
  assert.match(read('src/main.zig'), /!@import\("chat_session\.zig"\)\.chatActiveTabWantsChat\(\)/,
    'the refresh timer must stop streams for a terminal-view tab');
});
