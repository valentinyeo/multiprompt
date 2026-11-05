const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = require('./app-source').readAppSource();
const echoSource = fs.readFileSync(path.join(__dirname, '..', 'src', 'chat_echo.zig'), 'utf8');

function body(name, text = source) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}

test('IGSH-1766 a host message the agent took settles by receipt and idle time, not by transcript row alone', () => {
  const settle = body('takenSettled', echoSource);
  assert.match(settle, /state != \.delivered/);
  assert.match(settle, /phaseTaken\(phase\)/);
  assert.match(settle, /if \(busy\) return false;/);
  assert.match(settle, /idle_since_ms == 0\) watch\.idle_since_ms = now_ms/);
  assert.match(settle, /watch\.due\(now_ms, loaded_ms\)/);
  const taken = body('phaseTaken', echoSource);
  assert.match(taken, /"accepted"/);
  assert.match(taken, /"started"/);
  assert.doesNotMatch(taken, /"queued"|"sent"/);
});

test('IGSH-1766 chatEchoMatchActive forces a pass and retires settled host messages', () => {
  const match = body('chatEchoMatchActive');
  const calls = match.match(/chatEchoTakenSettledIn\(/g) || [];
  assert.equal(calls.length, 2, 'one probe that forces the reconcile pass and one that removes');
  assert.match(match, /chatEchoTakenSettledIn\([^)]*false\)\) expired = true/);
  assert.match(match, /chatEchoTakenSettledIn\([^)]*true\)\) changed = true/);
  const helper = body('chatEchoTakenSettledIn');
  assert.match(helper, /!e\.message_v1/);
  assert.match(helper, /chat_echo\.takenSettled\(&e\.delivery_watch, e\.state, std\.mem\.sliceTo\(&e\.message_phase, 0\), busy, now_ms, loaded_ms\)/);
  assert.match(helper, /chatOutboxRemoveAtIn\(list, allocator, i\)/);
});
