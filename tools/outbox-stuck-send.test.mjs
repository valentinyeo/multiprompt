import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { spawnSync } from 'node:child_process';

const send = fs.readFileSync('src/chat_send.zig', 'utf8');

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

test('SOFT-2724 and SOFT-2725 uncertain sends never become failure labels', t => {
  const zig = process.env.ZIG || 'zig';
  if (spawnSync(zig, ['version']).status !== 0) {
    t.skip('zig is not installed here');
    return;
  }
  const run = spawnSync(zig, ['test', '-j1', 'src/chat_echo.zig', '--test-filter', 'SOFT-272'], { encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
});
