import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
assert.ok(fs.existsSync(new URL('./live-working-proof.mjs', import.meta.url)), 'Live event painter observations must be available');
const { observe, parseStages, validate } = await import('./live-working-proof.mjs');

const fixture = JSON.parse(fs.readFileSync(new URL('./fixtures/IGSH-1668/observations.json', import.meta.url), 'utf8'));
const log = Object.entries(fixture.cases).flatMap(([name, value]) => fixture.stages.map((stage, i) =>
  `IGSH1668 case=${name} stage=${stage} elapsed_ms=${value.elapsed[i]} live=${i >= 2 && i < 5} screen=false visible=${i !== 1 && i !== 5} slot=${i !== 1 && i !== 5} timer=${i !== 1 && i !== 5} blocks=${value.blocks}`)).join('\n');

function imageFor(name, file) {
  const index = fixture.files.indexOf(file);
  assert.notEqual(index, -1);
  const state = fixture.cases[name].dots[index];
  const image = { width: 80, height: 40, pixels: Buffer.alloc(80 * 40 * 4) };
  if (state) for (const x of [10, 20, 30]) for (let y = 10; y < 15; y++) for (let dx = 0; dx < 5; dx++) {
    const offset = (y * image.width + x + dx) * 4;
    image.pixels.fill(state === 2 && x === 20 ? 90 : 60, offset, offset + 3);
  }
  return image;
}

test('parses independent native stages and measures synthetic pixels', () => {
  const result = observe(log, imageFor);
  assert.deepEqual(result.cases.empty.observations, {
    queuedDots: true, acceptedGapDots: false, startedDotsWithinOneSecondOfSyntheticEnqueue: true,
    animated: true, dotsOnReplyDelta: true, dotsAfterTurnEnded: false,
  });
  assert.deepEqual(result.cases.history.observations, {
    queuedDots: true, acceptedGapDots: false, startedDotsWithinOneSecondOfSyntheticEnqueue: false,
    animated: false, dotsOnReplyDelta: false, dotsAfterTurnEnded: false,
  });
  assert.equal(result.cases.history.stages['turn-started'].blocks, 2);
  assert.equal(result.cases.empty.stages['turn-started'].live, true);
  assert.match(result.boundary, /No actual input, send, transport or provider/);
});

test('rejects incomplete and duplicate evidence', () => {
  assert.throws(() => observe(log.replace(/IGSH1668 case=history stage=tick[^\n]+\n/, ''), imageFor), /Missing native stage history\/tick/);
  assert.throws(() => observe(log.split('\n').filter(line => !line.includes('case=empty')).join('\n'), imageFor), /Missing native case empty/);
  assert.throws(() => parseStages(`${log}\n${log.split('\n')[0]}`), /Duplicate native stage empty\/queued/);
});

test('requires a running timer, a painted reply and no remaining dots', () => {
  const result = observe(log, imageFor);
  for (const value of Object.values(result.cases)) value.stages['reply-delta'].blocks = value.stages['turn-started'].blocks + 1;
  assert.throws(() => validate(result), /dots remain with reply text/);
  for (const value of Object.values(result.cases)) {
    value.observations.startedDotsWithinOneSecondOfSyntheticEnqueue = true;
    value.observations.animated = true;
    value.observations.dotsOnReplyDelta = false;
    value.stages['reply-delta'].slot = false;
    value.stages['reply-delta'].blocks = value.stages['turn-started'].blocks + 1;
  }
  assert.doesNotThrow(() => validate(result));
  result.cases.empty.stages['turn-started'].timer = false;
  assert.throws(() => validate(result), /did not start animation timer/);
  result.cases.empty.stages['turn-started'].timer = true;
  result.cases.empty.stages['reply-delta'].blocks = 0;
  assert.throws(() => validate(result), /reply did not reach transcript/);
});

test('live-ready synchronizes busy state before starting the painter timer', () => {
  const source = fs.readFileSync(new URL('../src/chat_session.zig', import.meta.url), 'utf8');
  const ready = source.slice(source.indexOf('pub fn chatFileOnReady()'), source.indexOf('var read_ready:', source.indexOf('pub fn chatFileOnReady()')));
  const working = ready.indexOf('chatLiveSyncWorking();');
  const indicator = ready.indexOf('chatWorkingIndicatorSync();');
  assert.ok(working >= 0 && indicator > working, 'Live working state must reach the timer before indicator synchronization');
});
