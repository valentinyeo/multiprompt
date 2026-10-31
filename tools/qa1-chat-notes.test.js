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
