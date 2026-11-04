import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';
import { dots } from './chat-working-proof.mjs';

const files = {
  queued: 'queued',
  'accepted-before-event': 'accepted',
  'turn-started': 'busy-0',
  tick: 'busy-1',
  'reply-delta': 'reply-delta',
  'turn-ended': 'answered',
};

export function parseStages(log) {
  const cases = {};
  for (const match of log.matchAll(/IGSH1668 case=([\w-]+) stage=([\w-]+) elapsed_ms=(\d+) live=(true|false) screen=(true|false) visible=(true|false) slot=(true|false) timer=(true|false) blocks=(\d+)/g)) {
    const [, name, stage, elapsed, live, screen, visible, slot, timer, blocks] = match;
    cases[name] ??= {};
    if (cases[name][stage]) throw new Error(`Duplicate native stage ${name}/${stage}`);
    cases[name][stage] = { elapsedMs: Number(elapsed), live: live === 'true', screen: screen === 'true', visible: visible === 'true', slot: slot === 'true', timer: timer === 'true', blocks: Number(blocks) };
  }
  return cases;
}

export function observe(log, imageFor) {
  const cases = parseStages(log);
  for (const name of ['empty', 'history']) {
    const stages = cases[name];
    if (!stages) throw new Error(`Missing native case ${name}`);
    for (const [stage, file] of Object.entries(files)) {
      if (!stages[stage]) throw new Error(`Missing native stage ${name}/${stage}`);
      const image = imageFor(name, file);
      stages[stage].dots = dots(image, { left: 0, top: 0, right: image.width, bottom: image.height });
    }
    const first = stages['turn-started'];
    const next = stages.tick;
    cases[name] = {
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
  }
  return {
    boundary: 'Primed synthetic history and outbox states and live event pages; production event reducer, ready callback, layout, timer tick and Windows transcript painter. No actual input, send, transport or provider. Pixel detection scans the whole frame and can mistake history for dots.',
    cases,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const dir = process.argv[2];
  const result = observe(fs.readFileSync(path.join(dir, 'live-working-native.log'), 'utf8'), (name, file) => readBmp(path.join(dir, `live-working-${name}-${file}.bmp`)));
  fs.writeFileSync(path.join(dir, 'live-working-observations.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result.cases));
}
