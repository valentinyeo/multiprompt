const { test } = require('node:test');
const assert = require('node:assert/strict');
const source = require('./app-source').readAppSource();

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} is missing`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('IGSH-1266 a host message still sends while the tab console reconnects', () => {
  assert.match(body('chatOutboxHeldByLink'), /return link_down and !\(message_v1 and channel\);/);
  const trySend = body('chatOutboxTrySendEntry');
  assert.doesNotMatch(trySend, /if \(chatLinkLooksDown\(shell_index\)\) return false;/);
  assert.match(trySend, /chatOutboxHeldByLink\(chatLinkLooksDown\(shell_index\), g_chat_outbox\.items\[e\]\.message_v1, channel\)/);
  const tick = body('chatOutboxTick');
  assert.doesNotMatch(tick, /if \(chatLinkLooksDown\(idx\)\) continue;/);
  assert.match(tick, /chatOutboxHeldByLink\(chatLinkLooksDown\(idx\), g_chat_outbox\.items\[e\]\.message_v1, chatTmuxSendEligible\(idx\)\)/);
  assert.match(body('chatOutboxFlushActiveNow'), /const claude_buffer = chatTmuxSendEligible\(active_shell\) or \(!chatLinkLooksDown/);
});

test('IGSH-1266 a reset the server confirmed clears on its nonces alone', () => {
  assert.match(body('chatResetConfirmed'), /server_ok and pending\.nonce != 0 and pending\.nonce == nonce and pending\.request_nonce == request_nonce/);
  const finish = body('chatTmuxSendFinish');
  const reset = finish.slice(finish.indexOf('if (job.message_reset) {'), finish.indexOf('const ei = chatOutboxIndexById(job.echo_id);'));
  assert.match(reset, /if \(chatResetConfirmed\(job\.message_state\[0\] == '1', pending_reset, job\.message_nonce, job\.request_nonce\)\)/);
  assert.doesNotMatch(reset, /chatHistoryEntry\(current\) orelse return/);
  assert.doesNotMatch(reset, /history_instance|job\.message_generation/);
});

test('IGSH-1266 a reset the server never confirms stops holding sends', () => {
  assert.match(source, /const CHAT_RESET_UNCONFIRMED_LIMIT: u8 = 12;/);
  assert.match(body('chatResetGiveUp'), /pending\.unconfirmed \+\|= 1;\s*return pending\.unconfirmed >= CHAT_RESET_UNCONFIRMED_LIMIT;/);
  const finish = body('chatTmuxSendFinish');
  assert.match(finish, /else if \(chatResetGiveUp\(&g_chat_pending_reset\.\?\)\) \{\s*g_chat_pending_reset = null;\s*for \(g_chat_outbox\.items\) \|\*entry\| entry\.reset_pending = false;/);
});
