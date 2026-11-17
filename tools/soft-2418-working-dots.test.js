const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const echo = fs.readFileSync(path.join(__dirname, '../src/chat_echo.zig'), 'utf8');
const send = fs.readFileSync(path.join(__dirname, '../src/chat_send.zig'), 'utf8');

function sliceFn(source, name) {
  const pubStart = source.indexOf(`pub fn ${name}(`);
  const start = pubStart >= 0 ? pubStart : source.indexOf(`\nfn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function keepsWorkingFromSource() {
  const src = sliceFn(echo, 'keepsWorking');
  const body = src.slice(src.indexOf('{') + 1, src.lastIndexOf('}'))
    .replaceAll('state == .queued or state == .sending', "state === 'queued' || state === 'sending'")
    .replaceAll('state != .delivered or std.mem.eql(u8, phase, "failed")', "state !== 'delivered' || phase === 'failed'")
    .replaceAll('!reply_started and !chat_stopped', '!reply_started && !chat_stopped');
  const fn = new Function('state', 'phase', 'reply_started', 'chat_stopped', body);
  return (state, phase, reply, stopped) => fn(state, phase, reply, stopped);
}

test('SOFT-2418 an accepted send shows the working dots before the reply or a second message', () => {
  const keeps = keepsWorkingFromSource();
  assert.equal(keeps('queued', '', true, true), true);
  assert.equal(keeps('sending', 'sent', false, false), true);
  assert.equal(keeps('not_sent', 'accepted', false, false), false);
  assert.equal(keeps('cancelled', 'started', false, false), false);
  assert.equal(keeps('delivered', '', false, false), true);
  assert.equal(keeps('delivered', 'queued', false, false), true);
  assert.equal(keeps('delivered', 'sent', false, false), true);
  assert.equal(keeps('delivered', 'failed', false, false), false);
  assert.equal(keeps('delivered', 'accepted', false, false), true);
  assert.equal(keeps('delivered', 'started', false, false), true);
  assert.equal(keeps('delivered', 'accepted', true, false), false);
  assert.equal(keeps('delivered', 'started', false, true), false);
  const landed = sliceFn(echo, 'landedStillWorking');
  assert.match(landed, /return !reply_started and !chat_stopped;/);
  const working = sliceFn(send, 'chatOutboxWorkingForShell');
  assert.match(working, /chat_echo\.keepsWorking\(entry\.state, phase, reply_started, chat_stopped\)/);
  assert.match(working, /return landedSendWorking\(idx, reply_ms, running, reply_present\);/);
  assert.match(sliceFn(send, 'chatEchoMatchActive'), /rememberLandedSend\(app_state\.active_shell, e\);/);
  assert.match(sliceFn(send, 'chatEchoConfirmWithBlock'), /rememberLandedSend\(idx, e\);/);
  assert.match(sliceFn(send, 'chatMessageReduce'), /rememberLandedSend\(idx, app_state\.g_chat_outbox\.items\[i\]\);/);
});
