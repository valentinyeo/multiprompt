const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1266 a brand new chat never paints the retry note', () => {
  const render = read('src/chat_render.zig');
  assert.match(render, /const brand_new_chat = if \(entry\) \|e\| \(e\.key\.sid\[0\] != 0 and e\.history\.blocks\.items\.len == 0 and e\.loaded_ms == 0 and e\.failures < chat_history\.NEW_CHAT_GRACE\) else false;/, 'a chat with a sid and no transcript yet is new, not failed');
  assert.match(render, /const failed_load = if \(entry\) \|e\| \(e\.failures > 0 and !brand_new_chat\) else false;/, 'the retry note must be suppressed for a new chat');
  assert.match(read('src/chat_history.zig'), /pub const NEW_CHAT_GRACE: usize = 3;/, 'the grace window is named');
});

test('IGSH-1266 a submit that never landed is queued again instead of staying stuck', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /pub fn chatSubmitRetryPatch\(\) ChatSubmitPatch/, 'the retry patch exists');
  assert.match(send, /\.\{ \.write_started = false, \.state = \.queued, \.retryable = false \}/, 'the patch clears write_started and requeues');
  assert.match(send, /if \(job\.message_state\[0\] == 0\) \{\s*const patch = chatSubmitRetryPatch\(\);/, 'the finish path applies it when the submit did not land');
  assert.match(send, /\[chat\] submit not sent: the chat channel is not up yet, will retry/, 'the silent return now logs');
  assert.match(send, /\[chat\] submit skipped: the tab has no session id yet/, 'the missing sid path now logs');
  assert.match(send, /\[chat\] submit ack mismatch, will retry/, 'the ack mismatch path now logs');
  assert.match(send, /\[chat\] submit reply did not parse, will retry/, 'the parse failure path now logs');
});

test('IGSH-1266 the send path is decided at send time, not at enqueue time', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /pub fn chatSendRoute\(kind: @import\("app_state\.zig"\)\.ShellKind, ai_agent: u8, sid_present: bool\) ChatSendRoute/, 'one routing rule');
  assert.match(send, /if \(chatMessageGoesToHost\(kind, ai_agent\)\) return if \(sid_present\) \.host_message else \.wait_for_start;/, 'a hosted tab without a sid waits');
  assert.match(send, /if \(kind == \.tmux and ai_agent == 0\) return \.wait_for_start;/, 'a tmux tab that has not started its agent waits');
  assert.match(send, /if \(route == \.host_message and !entry\.message_v1\) \{/, 'the entry is upgraded at send time');
  assert.match(send, /fn chatUpgradeToHostMessage\(shell_index: u32, entry: \*app_state\.ChatOutboxEntry\) bool/, 'the upgrade helper exists');
  assert.match(send, /\[chat\] send path=\{s\} stage=\{s\} v1=\{\} ai_agent=\{d\} sid_present=\{\} host=\{d\} wire_id=\{s\}/, 'one line per attempt with the fields');
  assert.match(send, /\[chat\] send legacy reply=\{s\} written=\{\}/, 'the legacy branch logs its reply');
  assert.match(send, /if \(!ok\) job\.rejected = true;/, 'an unclear legacy reply is not treated as delivered');
});

test('IGSH-1266 a missing transcript is an empty new chat on both sides', () => {
  assert.match(read('src/chat_history_reader.py'), /status = wire_row\(dict\(role="status", no_transcript=True\)\)/, 'the reader distinguishes no transcript');
  assert.match(read('src/chat_history.zig'), /pub fn noTranscriptYet\(wire: \[\]const u8\) bool/, 'the desktop helper exists');
  assert.match(read('src/chat_session.zig'), /if \(chat_history\.noTranscriptYet\(wire\.items\)\) \{[\s\S]{0,200}entry\.failures = 0;/, 'the empty state clears failures instead of counting them');
});

test('IGSH-1266 the composer never lands outside the live client rect', () => {
  assert.match(read('src/chat_composer.zig'), /const bottom = @min\(slot\.bottom, rc\.bottom\);/, 'the composer is clamped to the live client height');
});

test('IGSH-1266 the reader empty reply is a successful empty chat, not a failure', () => {
  const session = read('src/chat_session.zig');
  const branch = session.slice(session.indexOf('if (chat_history.noTranscriptYet(wire.items)) {'), session.indexOf('} else if (chat_history.missingReason(wire.items, id))'));
  assert.match(branch, /entry\.failures = 0;/, 'failures are cleared');
  assert.match(branch, /ok = true;/, 'the fetch counts as ok so no failure is recorded');
  assert.ok(!/ok = false;/.test(branch), 'a new chat must not be counted as a failed load');
});

test('IGSH-1266 the layout logs its real client, slot and DPI numbers', () => {
  const layout = read('src/window_layout.zig');
  assert.match(layout, /\[chat\] layout rc \{d\},\{d\},\{d\},\{d\} slot \{d\},\{d\},\{d\},\{d\} dpi=\{d\}/, 'one line with the numbers to read');
  assert.match(layout, /@import\("win32\.zig"\)\.GetClientRect\(app_state\.g_main_hwnd, &frame\)/, 'the client rect is read at layout time');
});

test('IGSH-1266 a console is never hidden unless the chat view is actually up', () => {
  const composer = read('src/chat_composer.zig');
  assert.match(composer, /return is_active and !chat_active and !\(tab_wants_chat and chat_active\) and !covered;/, 'the console only hides when chat is live');
  assert.match(composer, /test "IGSH-1266 a tab that wants chat but has no chat window still shows its console"/);
});

test('IGSH-1266 every tab switch logs the view mode and window state', () => {
  const console_zig = read('src/console.zig');
  const marker = '[view] switch tab={d} chat_active={} tab_wants_chat={} chat_visible={} chat_rect={d},{d},{d},{d} console_visible={}';
  assert.ok(console_zig.includes(marker), 'one line per switch');
});

