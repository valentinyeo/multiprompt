import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const modulePath = new URL('./chat-working-live-proof.mjs', import.meta.url);

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
