import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const send = fs.readFileSync('src/chat_send.zig', 'utf8');
const echo = fs.readFileSync('src/chat_echo.zig', 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  if (start < 0) return '';
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('IGSH-1812 a host message sending in one chat does not gate sends in other chats', () => {
  const attempt = body(send, 'chatOutboxTrySendEntry');
  assert.ok(attempt.length > 0, 'chatOutboxTrySendEntry exists');
  assert.ok(!attempt.includes('chatOutboxFindSending('), 'the send attempt no longer waits on any sending entry in any chat');
  const blocked = body(send, 'chatOutboxSendBlockedIn');
  assert.match(blocked, /!e\.message_v1 or std\.mem\.eql\(u8, e\.key/, 'a v1 entry only blocks its own chat key');
});

test('IGSH-1812 the outbox settle loop gives host messages a sending deadline', () => {
  const tick = body(send, 'chatOutboxTick');
  assert.ok(tick.length > 0, 'chatOutboxTick exists');
  assert.match(tick, /if \(entry\.message_v1\) \{\s*if \(chat_echo\.v1SendingAbandoned\(/, 'v1 entries are checked for an abandoned send before being skipped');
});

test('IGSH-1812 abandoned-send deadline behaves at its edges', (t) => {
  const predicate = body(echo, 'v1SendingAbandoned');
  assert.ok(predicate.length > 0, 'v1SendingAbandoned exists');
  const zig = process.env.ZIG || 'zig';
  if (spawnSync(zig, ['version']).status !== 0) {
    t.skip('zig is not installed here');
    return;
  }
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh1812-'));
  try {
    const deadline = echo.match(/pub const V1_SENDING_DEADLINE_MS: i64 = [\d_]+;/)[0];
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const OutboxState = enum(u8) { queued = 0, sending = 1, not_sent = 2, delivered = 3, cancelled = 4 };
${deadline}
${predicate}
test "deadline" {
    try std.testing.expect(v1SendingAbandoned(.sending, false, 5_000, 5_000 + V1_SENDING_DEADLINE_MS));
    try std.testing.expect(!v1SendingAbandoned(.sending, false, 5_000, 5_000 + V1_SENDING_DEADLINE_MS - 1));
    try std.testing.expect(!v1SendingAbandoned(.sending, true, 5_000, 5_000 + V1_SENDING_DEADLINE_MS * 3));
    try std.testing.expect(!v1SendingAbandoned(.sending, false, 0, V1_SENDING_DEADLINE_MS * 3));
    try std.testing.expect(!v1SendingAbandoned(.queued, false, 5_000, 5_000 + V1_SENDING_DEADLINE_MS * 3));
    try std.testing.expect(V1_SENDING_DEADLINE_MS <= 120_000);
}
`);
    const run = spawnSync(zig, ['test', path.join(dir, 'test.zig')], { encoding: 'utf8' });
    assert.equal(run.status, 0, run.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
