import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

import positionProof from './verify-chat-delivery/chat-open-position.cjs';

const modulePath = new URL('./chat-working-live-proof.mjs', import.meta.url);

test('steady chat observations reject movement, missing counters and short evidence', () => {
  const row = (tick, paints, layouts, y = -24, message = 42) => `[chat] position ms=2000 shell=9 first=0 message=${message} offset=0 y=${y} scroll=80 height=3000 pad=52 opening=0 paints=${paints} layouts=${layouts} tick=${tick}`;
  const trace = [row(1000, 5, 2), row(2500, 5, 2), row(4000, 5, 2), row(5500, 5, 2)].join('\n');
  const result = positionProof.steadyPosition(trace, 1000, 6000);
  assert.equal(result.status, 'passed');
  assert.equal(result.sampled_ms, 4500);
  assert.equal(result.paints, 0);
  assert.equal(result.layouts, 0);
  const churn = positionProof.steadyPosition(trace + '\n' + row(5900, 20, 11), 1000, 6000);
  assert.equal(churn.paints, 15);
  assert.equal(churn.layouts, 9);
  assert.equal(positionProof.steadyPosition(trace + '\n' + row(5900, 5, 2, -23), 1000, 6000).status, 'failed');
  assert.equal(positionProof.steadyPosition(trace + '\n' + row(5900, 5, 2, -24, 43), 1000, 6000).status, 'failed');
  assert.equal(positionProof.steadyPosition(trace + '\n' + row(7000, 8, 6, 20), 1000, 6000).status, 'passed');
  assert.throws(() => positionProof.steadyPosition(trace, 1000, 2000), /multi-second observation/);
  assert.throws(() => positionProof.steadyPosition(row(2500, 5, 2), 1000, 6000), /missing multi-second/);
  assert.throws(() => positionProof.steadyPosition(trace.replaceAll(/ paints=\d+ layouts=\d+/g, ''), 1000, 6000), /missing multi-second/);
});

test('hosted working evidence keeps animated dots through reply and two queued messages', async () => {
  assert.ok(fs.existsSync(modulePath), 'Hosted working evidence checker must exist');
  const { checkFrames } = await import(modulePath.href);
  const dot = active => [10, 20, 30].map((left, index) => ({left, right:left + 6, top:index === active ? 18 : 20, bottom:index === active ? 24 : 26, peak:90}));
  const good = [
    {phase:'busy', startMs:400, startWallMs:1400, endMs:450, dots:dot(0)},
    {phase:'busy', startMs:1200, startWallMs:2200, endMs:1250, dots:dot(0)},
    {phase:'busy', startMs:1500, startWallMs:2500, endMs:1550, dots:dot(1)},
    {phase:'reply', startMs:2200, startWallMs:3200, endMs:2250, dots:dot(0), replyPixels:90},
    {phase:'queued', startMs:3200, startWallMs:4200, endMs:3250, dots:dot(0)},
    {phase:'queued', startMs:3500, startWallMs:4500, endMs:3550, dots:dot(1)},
  ];
  assert.doesNotThrow(() => checkFrames(good, 2000, 1000, 3000, 4000));
  assert.throws(() => checkFrames(good.slice(1), 2000, 1000, 3000, 4000), /within 1000 ms/);
  assert.throws(() => checkFrames(good.map(frame => frame.startMs === 400 ? {...frame, dots:dot(0).slice(0, 2)} : frame), 2000, 1000, 3000, 4000), /within 1000 ms/);
  assert.throws(() => checkFrames(good, 2600, 1000, 3000, 4000), /after turn.started/);
  assert.throws(() => checkFrames(good.filter(frame => frame.startMs !== 1500), 2000, 1000, 3000, 4000), /after turn.started/);
  assert.throws(() => checkFrames(good.map(frame => frame.phase === 'busy' ? {...frame, dots:dot(0)} : frame), 2000, 1000, 3000, 4000), /animate/);
  assert.throws(() => checkFrames(good.map(frame => frame.phase === 'reply' ? {...frame, replyPixels:0} : frame), 2000, 1000, 3000, 4000), /Reply pixels/);
  assert.throws(() => checkFrames(good.map(frame => frame.phase === 'reply' ? {...frame, dots:null} : frame), 2000, 1000, 3000, 4000), /working dots missing/);
  assert.throws(() => checkFrames(good.filter(frame => frame.phase !== 'queued'), 2000, 1000, 3000, 4000), /two messages queued/);
  assert.throws(() => checkFrames(good.map(frame => frame.phase === 'queued' ? {...frame, dots:dot(0)} : frame), 2000, 1000, 3000, 4000), /Queued dots did not animate/);
});
