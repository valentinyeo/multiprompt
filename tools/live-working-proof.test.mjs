import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { observe, parseStages } from './live-working-proof.mjs';

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
