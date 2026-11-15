const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const send = fs.readFileSync(path.join(root, 'src/chat_send.zig'), 'utf8');
const slash = fs.readFileSync(path.join(root, 'src/chat_slash.zig'), 'utf8');
const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
const reader = fs.readFileSync(path.join(root, 'src/chat_history_reader.py'), 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} is missing`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('SOFT-2420 a refused restart says why and clears the badge', () => {
  const thread = body(send, 'chatRestartAiThread');
  assert.match(thread, /chatRestartAiPost\(/);
  assert.match(send, /The AI is still running, so it was not restarted\./);
  assert.doesNotMatch(thread, /if \(std\.mem\.indexOf\(u8, wire\.items, "\\tpane_busy\\t"\) == null\) chatRestartAiNotice/);
  const apply = body(send, 'chatRestartAiApplyRefusal');
  assert.match(apply, /ai_restart_tick = 0/);
  assert.match(apply, /ai_restart_busy = true/);
  assert.match(main, /chatRestartAiApplyRefusal\(/);
});

test('SOFT-2420 slash clear is a typed send that leaves no Not sent row', () => {
  assert.match(slash, /pub fn bareClear\(/);
  const start = body(send, 'chatTmuxSendStart');
  assert.match(start, /bareClear\(text\)/);
  assert.match(start, /message_v1 = false/);
  const finish = body(send, 'chatTmuxSendFinish');
  assert.match(finish, /clear_chat/);
  assert.match(finish, /chatOutboxRemoveAtIn\(/);
  assert.match(finish, /needs_restart/);
  assert.match(reader, /def send_clear\(/);
  assert.match(reader, /def host_clear_session\(/);
});
