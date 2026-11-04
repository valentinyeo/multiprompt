import fs from 'node:fs';
import path from 'node:path';
import { readBmp } from './chat-code-font-proof.mjs';
import { dots } from './chat-working-proof.mjs';

const dir = process.argv[2];
const log = fs.readFileSync(path.join(dir, 'live-working-native.log'), 'utf8');
const stages = {};
for (const match of log.matchAll(/IGSH1668 stage=([\w-]+) elapsed_ms=(\d+) live=(true|false) screen=(true|false) visible=(true|false) slot=(true|false) timer=(true|false) blocks=(\d+)/g)) {
  const [, stage, elapsed, live, screen, visible, slot, timer, blocks] = match;
  stages[stage] = { elapsedMs: Number(elapsed), live: live === 'true', screen: screen === 'true', visible: visible === 'true', slot: slot === 'true', timer: timer === 'true', blocks: Number(blocks) };
}
const files = {
  queued: 'queued',
  'accepted-before-event': 'accepted',
  'turn-started': 'busy-0',
  tick: 'busy-1',
  'reply-delta': 'reply-delta',
  'turn-ended': 'answered',
};
for (const [stage, file] of Object.entries(files)) {
  if (!stages[stage]) throw new Error(`Missing native stage ${stage}`);
  const image = readBmp(path.join(dir, `live-working-${file}.bmp`));
  stages[stage].dots = dots(image, { left: 0, top: 0, right: image.width, bottom: image.height });
}
const first = stages['turn-started'];
const next = stages.tick;
const result = {
  boundary: 'Synthetic outbox states and live event pages; production event reducer, ready callback, layout, timer tick and Windows transcript painter. No real send, transport, input or provider.',
  stages,
  observations: {
    queuedDots: !!stages.queued.dots,
    acceptedGapDots: !!stages['accepted-before-event'].dots,
    startedDotsWithinOneSecondOfSyntheticEnqueue: !!first.dots && first.elapsedMs <= 1000,
    animated: !!first.dots && !!next.dots && JSON.stringify(first.dots) !== JSON.stringify(next.dots),
    dotsOnReplyDelta: !!stages['reply-delta'].dots,
    dotsAfterTurnEnded: !!stages['turn-ended'].dots,
  },
};
fs.writeFileSync(path.join(dir, 'live-working-observations.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify(result.observations));
