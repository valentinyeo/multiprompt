const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1266 a hosted tab message is submitted to the host and never typed into the pane', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /pub fn chatMessageGoesToHost\(kind: @import\("app_state\.zig"\)\.ShellKind, ai_agent: u8\) bool \{\s*return kind == \.tmux and \(ai_agent == 1 or ai_agent == 2\);/,
    'the host routing rule must be one named function');
  assert.match(send, /app_state\.g_chat_outbox\.items\[added\]\.message_v1 = true;/);
  const enqueue = send.slice(send.indexOf('fn chatEchoEnqueueForShell('), send.indexOf('fn chatEchoMarkNotSent('));
  assert.match(enqueue, /chatMessageGoesToHost\(app_state\.shells\[idx\]\.kind, app_state\.shells\[idx\]\.ai_agent\)/,
    'a hosted Claude tab must be enqueued as a host message, not a terminal one');
  assert.match(send, /if \(app_state\.g_chat_outbox\.items\[ei\]\.message_v1\) return \.write_failed;/,
    'a host message must never fall through to the console writer');
});

test('IGSH-1266 a first hosted message survives a reconnecting channel', () => {
  const send = read('src/chat_send.zig');
  const submit = send.slice(send.indexOf('fn chatTmuxSendThread('), send.indexOf('fn chatMessageReduce('));
  assert.ok(submit.includes('chatHistoryPersistent(job.key.host, id, query, 65536, &response, &job.written)'),
    'the submit still runs on the persistent channel first');
  assert.match(submit, /if \(!@import\("chat_session\.zig"\)\.chatHistoryPersistent\(job\.key\.host, id, query, 65536, &response, &job\.written\)\) \{\s*response\.clearRetainingCapacity\(\);\s*if \(!@import\("chat_session\.zig"\)\.chatHistorySendForced\(job\.key\.host, id, query, 65536, &response, &job\.written\)\) return;\s*\}/,
    'a message typed while the channel reconnects must be submitted over a forced fresh channel instead of being dropped');
  const session = read('src/chat_session.zig');
  assert.match(session, /pub fn chatHistorySendForced\(host: u8, id: u32, query: \[\]const u8, wire_limit: usize, out: \*std\.ArrayList\(u8\), request_written: \?\*bool\) bool \{/,
    'the forced submit must drop the reconnect backoff and start a fresh serve channel');
  assert.match(session, /ch\.retry_at = 0;\s*chatHistoryChannelClose\(ch\);/);
});
