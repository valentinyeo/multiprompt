const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const src = (name) => fs.readFileSync(path.join(__dirname, '..', 'src', name), 'utf8');

function body(text, signature) {
  const start = text.indexOf(signature);
  assert.ok(start >= 0, `${signature} exists`);
  const next = text.indexOf('\npub fn ', start + signature.length);
  const nextPrivate = text.indexOf('\nfn ', start + signature.length);
  const ends = [next, nextPrivate].filter((i) => i > 0);
  return text.slice(start, ends.length ? Math.min(...ends) : undefined);
}

test('an expired held message does not flip its queued flag on every transcript load', () => {
  const settle = body(src('chat_send.zig'), 'fn chatTmuxSettle() void {');
  assert.doesNotMatch(settle, /entry\.transcript_queued = facts\.enqueued;/, 'raw transcript evidence is never stored unmasked');
  const stale = settle.indexOf('const queue_stale = ');
  const store = settle.indexOf('entry.transcript_queued = enqueued;');
  assert.ok(stale > 0, 'staleness is known before evidence is stored');
  assert.ok(store > stale, 'the stored queued flag comes after the staleness check');
  assert.match(settle, /const enqueued = facts\.enqueued and !queue_stale;/);
  assert.match(settle, /if \(entry\.transcript_queued != enqueued\) changed = true;/);
});

test('reconcile and settle mask expired queue evidence the same way', () => {
  const reconcile = body(src('chat_send.zig'), 'pub fn chatEchoMatchActive() void {');
  assert.match(reconcile, /enqueued = facts\.enqueued and !chat_echo\.pendingExpired\(/);
});
