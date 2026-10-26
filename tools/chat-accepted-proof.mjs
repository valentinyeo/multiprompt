import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp, writeCrop } from './chat-code-font-proof.mjs';
import { dots } from './chat-working-proof.mjs';

export function queuedBubble(image, area) {
  const pixel = (x, y) => image.pixels.readUIntLE((y * image.width + x) * 4, 3);
  const bg = pixel(area.left, area.top);
  const fills = [26, 27].map(delta => [0, 8, 16].reduce((n, shift) => n | Math.min(255, ((bg >> shift) & 255) + delta) << shift, 0));
  let left = area.right, right = 0, top = area.bottom, bottom = 0;
  for (let y = area.top; y < area.bottom; y++) {
    let start = -1;
    for (let x = area.left; x <= area.right; x++) {
      if (x < area.right && fills.includes(pixel(x, y))) { if (start < 0) start = x; }
      else if (start >= 0) {
        if (x - start > 80) { left = Math.min(left, start); right = Math.max(right, x); top = Math.min(top, y); bottom = y + 1; }
        start = -1;
      }
    }
  }
  assert.ok(right - left > 80 && bottom - top > 20, 'waiting message must be visibly dimmed');
  return { left, right, top, bottom, bg };
}

export function normalBubble(image, bubble) {
  const { left, right, top, bottom, bg } = bubble;
  const full = bg === 0x101010 ? 0x3A3A3A : [0, 8, 16].reduce((n, shift) => n | Math.min(255, ((bg >> shift) & 255) + 53) << shift, 0);
  let fill = 0, ink = 0;
  for (let y = top + 4; y < bottom - 4; y++) for (let x = left + 8; x < right - 8; x++) {
    const color = image.pixels.readUIntLE((y * image.width + x) * 4, 3);
    if (color === full) fill++;
    else if ([0, 8, 16].every(s => ((color >> s) & 255) > ((full >> s) & 255) + 20)) ink++;
  }
  return fill > (right - left - 16) * (bottom - top - 8) * 0.5 && ink > 20;
}

export function evaluateFrames(frames, acceptedMs) {
  const first = frames.find(frame => frame.normal);
  assert.ok(first, 'IGSH-969 accepted message remains dimmed');
  assert.ok(first.ms >= acceptedMs && first.ms - acceptedMs <= 1000, 'IGSH-969 acceptance took over one second');
  for (const frame of frames.filter(frame => frame.ms >= first.ms)) {
    assert.ok(frame.normal, 'accepted message became dimmed again');
    assert.ok(frame.dots, 'working dots must remain visible for accepted message');
  }
  return first.ms - acceptedMs;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2];
  const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
  try {
    const observation = json('accepted-message/observation.json');
    assert.equal(observation.error, null);
    assert.equal(observation.composerText, '');
    const receipt = json('accepted-message/stand-in/accepted.json');
    assert.equal(receipt.text, observation.text);
    const state = json('accepted-message/stand-in/claude.json');
    assert.equal(state.mode, 'busy');
    assert.deepEqual(state.queue, []);
    const transcript = fs.readFileSync(path.join(root, 'accepted-message/transcript.jsonl'), 'utf8');
    const events = transcript.trim().split(/\r?\n/).map(line => JSON.parse(line));
    assert.ok(events.some(e => e.type === 'queue-operation' && e.operation === 'enqueue' && e.content === observation.text));
    assert.ok(events.some(e => e.type === 'queue-operation' && e.operation === 'remove' && e.content === observation.text));
    assert.ok(!events.some(e => e.type === 'attachment' || e.message?.content === observation.text), 'user transcript intentionally delayed');
    const cleanup = json('cleanup.json');
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.scratch_removed, true);
    const queued = readBmp(path.join(root, 'accepted-queued.bmp'));
    const bubble = queuedBubble(queued, observation.area);
    assert.equal(normalBubble(queued, bubble), false);
    const frames = observation.frames.map(frame => {
      const image = readBmp(path.join(root, frame.name + '.bmp'));
      let working = null;
      for (let left = observation.area.left; left < observation.area.right - 40 && !working; left += 140) {
        working = dots(image, { ...observation.area, left, top: bubble.bottom + 2 });
      }
      return { ...frame, normal: normalBubble(image, bubble), dots: !!working };
    });
    const acceptance = events.find(e => e.type === 'queue-operation' && e.operation === 'remove' && e.content === observation.text);
    const latencyMs = evaluateFrames(frames, Date.parse(acceptance.timestamp));
    const first = frames.find(frame => frame.normal);
    writeCrop(queued, { ...observation.area, top: bubble.top - 8 }, 1, path.join(root, 'accepted-before.png'));
    writeCrop(readBmp(path.join(root, first.name + '.bmp')), { ...observation.area, top: bubble.top - 8 }, 1, path.join(root, 'accepted-after.png'));
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-accepted-message', status: 'passed', latencyMs, frames }, null, 2));
    console.log(`ACCEPTED_MESSAGE_NORMAL_WITH_DOTS ${latencyMs}ms`);
  } catch (error) {
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-accepted-message', status: 'failed', error: error.message }, null, 2));
    throw error;
  }
}
