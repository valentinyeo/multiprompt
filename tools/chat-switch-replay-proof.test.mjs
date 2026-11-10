import test from 'node:test';
import assert from 'node:assert/strict';

const modulePath = new URL('./chat-switch-replay-proof.mjs', import.meta.url);

test('switching back must resume the live cursor without replaying history', async () => {
  const { checkReplay, liveCounts } = await import(modulePath.href);
  const resumed = liveCounts('[chat-live] start shell=7 n=1200 f=1\n[chat-live] page shell=7 n=64 f=0\n[chat-live] draw shell=7 n=64 f=1\n[chat-live] page shell=8 n=9 f=1\n', 7);
  assert.deepEqual(resumed, {starts: [1200], pages: 1, draws: 1});
  const good = {lastSeq: 1200, counts: resumed, subscribed: [{after: 1200}], pushed: []};
  assert.equal(checkReplay(good).start_cursor, 1200);
  const replayed = liveCounts('[chat-live] start shell=7 n=0 f=1\n' + '[chat-live] page shell=7 n=900 f=1\n'.repeat(5) + '[chat-live] draw shell=7 n=900 f=2\n'.repeat(5), 7);
  assert.throws(() => checkReplay({lastSeq: 1200, counts: replayed, subscribed: [{after: 0}], pushed: [{}, {}, {}, {}]}), /cursor 0.*5 history pages.*5 transcript redraws.*cursor 0.*4 replay pages/);
  assert.throws(() => checkReplay({...good, counts: {...resumed, pages: 2}}), /2 history pages/);
  assert.throws(() => checkReplay({...good, counts: {...resumed, draws: 2}}), /2 transcript redraws/);
  assert.throws(() => checkReplay({...good, counts: {...resumed, starts: []}}), /did not restart/);
  assert.throws(() => checkReplay({...good, subscribed: []}), /never saw a subscription/);
  assert.throws(() => checkReplay({...good, pushed: [{}]}), /1 replay pages/);
});
