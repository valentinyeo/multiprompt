const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const echo = fs.readFileSync(path.join(__dirname, '../src/chat_echo.zig'), 'utf8');
const send = fs.readFileSync(path.join(__dirname, '../src/chat_send.zig'), 'utf8');

function sliceFn(source, name) {
  const start = source.indexOf(`pub fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function keepsWorkingFromSource() {
  const src = sliceFn(echo, 'keepsWorking');
  const body = src.slice(src.indexOf('{') + 1, src.lastIndexOf('}'))
    .replaceAll('state == .queued or state == .sending', "state === 'queued' || state === 'sending'")
    .replaceAll('state != .delivered or !phaseTaken(phase)', "state !== 'delivered' || !phaseTaken(phase)")
    .replaceAll('!reply_started and !chat_stopped', '!reply_started && !chat_stopped');
  const phaseTaken = (phase) => phase === 'accepted' || phase === 'started';
  const fn = new Function('state', 'phase', 'reply_started', 'chat_stopped', 'phaseTaken', body);
  return (state, phase, reply, stopped) => fn(state, phase, reply, stopped, phaseTaken);
}

test('SOFT-2418 an accepted send shows the working dots before the reply or a second message', () => {
  const keeps = keepsWorkingFromSource();
  assert.equal(keeps('queued', '', true, true), true);
  assert.equal(keeps('sending', 'sent', false, false), true);
  assert.equal(keeps('not_sent', 'accepted', false, false), false);
  assert.equal(keeps('cancelled', 'started', false, false), false);
  assert.equal(keeps('delivered', 'queued', false, false), false);
  assert.equal(keeps('delivered', 'sent', false, false), false);
  assert.equal(keeps('delivered', 'accepted', false, false), true);
  assert.equal(keeps('delivered', 'started', false, false), true);
  assert.equal(keeps('delivered', 'accepted', true, false), false);
  assert.equal(keeps('delivered', 'started', false, true), false);
  const working = sliceFn(send, 'chatOutboxWorkingForShell');
  assert.match(working, /chat_echo\.keepsWorking\(entry\.state, phase, reply_started, chat_stopped\)/);
  assert.match(working, /reply_ms > entry\.anchor\.sent_ms/);
  assert.match(working, /const chat_stopped = owns and !running/);
});
