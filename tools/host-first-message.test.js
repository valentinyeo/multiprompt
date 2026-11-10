const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1266 a hosted tab message is submitted to the host and never typed into the pane', () => {
  const send = read('src/chat_send.zig');
  assert.match(send, /pub fn chatMessageGoesToHost\(kind: @import\("app_state\.zig"\)\.ShellKind, ai_agent: u8\) bool \{\s*return kind == \.tmux and \(ai_agent == 1 or ai_agent == 2 or ai_agent == 3 or ai_agent == 7\);/,
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
  assert.doesNotMatch(submit, /chatHistorySendForced/);
  assert.match(send, /history\.send_next_tick = GetTickCount64\(\) \+ chatMessageSyncRetryDelayMs\(history\.send_retry_step\)/);
  assert.match(send, /if \(entry\.message_sid\[0\] == 0\) entry\.message_sid = identity\.sid;/);
});
