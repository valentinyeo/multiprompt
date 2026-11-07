const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const echo = fs.readFileSync('src/chat_echo.zig', 'utf8');
const send = fs.readFileSync('src/chat_send.zig', 'utf8');
const session = fs.readFileSync('src/chat_session.zig', 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function settle() {
  const source = body(echo, 'takenSettled');
  const names = source.slice(source.indexOf('(') + 1, source.indexOf(')')).split(',').map(arg => arg.trim().split(':')[0]);
  const code = source.slice(source.indexOf('{') + 1, -1)
    .replaceAll('.delivered', '"delivered"').replaceAll(' and ', ' && ').replaceAll(' or ', ' || ')
    .replace('if (sent_tick_ms != 0) sent_tick_ms else now_ms', '(sent_tick_ms != 0 ? sent_tick_ms : now_ms)');
  const max = Number((echo.match(/TAKEN_MAX_AGE_MS: i64 = ([\d_]+)/)?.[1] || '60000').replaceAll('_', ''));
  const run = new Function(...names, 'phaseTaken', 'TAKEN_MAX_AGE_MS', code);
  return {max, run: (watch, state, phase, replied, now, sent) => run(watch, state, phase, replied, now, sent,
    phase => phase === 'accepted' || phase === 'started', max)};
}

function watch() {
  return {busy_seen: false, idle_since_ms: 0, taken_since_ms: 0,
    observe(busy, now) { if (busy) { this.busy_seen = true; this.idle_since_ms = 0; } else if (this.busy_seen && !this.idle_since_ms) this.idle_since_ms = now; },
    due(now, loaded) { return this.idle_since_ms > 0 && now >= this.idle_since_ms + 20000 && loaded >= this.idle_since_ms + 20000; }};
}

for (const kind of ['normal', 'slash command', 'mid-turn', 'reordered skills']) {
  test(`${kind}: a confirmed message retires after a later reply, without idle`, () => {
    const {run} = settle();
    for (const phase of ['accepted', 'started']) assert.equal(run(watch(), 'delivered', phase, true, 2000, 1000), true);
  });
}

test('confirmed age is bounded without an active history, including after boot', () => {
  const {run, max} = settle();
  for (const sent of [1000, -max + 1000]) {
    const receipt = watch();
    assert.equal(run(receipt, 'delivered', 'accepted', false, sent + max - 1, sent), false);
    assert.equal(run(receipt, 'delivered', 'accepted', false, sent + max, sent), true);
  }
});

test('no reply, age or Resync can retire an unconfirmed phase', () => {
  const {run, max} = settle();
  for (const phase of ['', 'queued', 'sent', 'failed', 'cancelled']) {
    assert.equal(run(watch(), 'delivered', phase, true, max * 100, 1), false);
  }
  for (const state of ['queued', 'sending', 'not_sent', 'cancelled']) {
    assert.equal(run(watch(), state, 'accepted', true, max * 100, 1), false);
  }
});

test('load, background tick and Resync all apply receipt-gated retirement', () => {
  assert.match(body(send, 'chatOutboxParseJson'), /chat_echo\.takenSettled/);
  assert.match(body(send, 'chatOutboxTick'), /chatEchoTakenSettledIn/);
  assert.match(body(send, 'chatMessageSyncFinish'), /"text\.done"/);
  assert.match(body(session, 'chatResync'), /chatEchoClearConfirmedForShell/);
  assert.match(body(send, 'chatEchoClearConfirmedForShell'), /chatEchoTakenSettledIn/);
});

test('skill order matching requires receipt confirmation and preserves ordinary word order', () => {
  assert.match(body(send, 'chatEchoAssignForKey'), /\.confirmed = .*phaseTaken/);
  assert.match(body(echo, 'messageMatches'), /p\.confirmed and sameSkillText/);
  assert.match(echo, /test "IGSH-1831 reordered skills/);
});
