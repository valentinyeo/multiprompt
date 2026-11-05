import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp, writeCrop } from './chat-code-font-proof.mjs';
import { dots } from './chat-working-proof.mjs';

function bubbleColors(bg) {
  const channel = (color, shift) => (color >> shift) & 255;
  const dark = (2126 * channel(bg, 0) + 7152 * channel(bg, 8) + 722 * channel(bg, 16)) / 10000 < 128;
  const base = bg === 0x101010 ? 0x3a3a3a : [0, 8, 16].reduce((n, shift) => n | Math.max(0, Math.min(255, channel(bg, shift) + (dark ? 53 : -26))) << shift, 0);
  const normal = new Set(), dim = new Set();
  for (let delta = 0; delta <= (dark ? 8 : 6); delta++) {
    const fill = [0, 8, 16].reduce((n, shift) => n | Math.min(255, channel(base, shift) + delta) << shift, 0);
    normal.add(fill);
    for (const rounding of [-1, 0, 1]) {
      dim.add([0, 8, 16].reduce((n, shift) => n | Math.max(0, Math.min(255, Math.floor((channel(fill, shift) + channel(bg, shift)) / 2) + rounding)) << shift, 0));
    }
  }
  return { normal, dim };
}

export function queuedBubble(image, area) {
  const pixel = (x, y) => image.pixels.readUIntLE((y * image.width + x) * 4, 3);
  const bg = pixel(area.left, area.top);
  const fills = bubbleColors(bg).normal;
  const groups = [];
  for (let y = area.top; y < area.bottom; y++) {
    let start = -1;
    for (let x = area.left; x <= area.right; x++) {
      if (x < area.right && fills.has(pixel(x, y))) { if (start < 0) start = x; }
      else if (start >= 0) {
        if (x - start > 80) {
          const group = groups.find(g => y - g.bottom <= 16 && Math.abs(g.right - x) <= 16 && Math.min(g.right, x) - Math.max(g.left, start) > 80);
          if (group) { group.left = Math.min(group.left, start); group.right = Math.max(group.right, x); group.bottom = y + 1; }
          else groups.push({ left: start, right: x, top: y, bottom: y + 1 });
        }
        start = -1;
      }
    }
  }
  const bubble = groups.filter(g => g.bottom - g.top > 20).sort((a, b) => b.bottom - a.bottom)[0];
  assert.ok(bubble, 'queued message must have a normal bubble');
  const { left, right, top, bottom } = bubble;
  const result = { left, right, top, bottom, bg };
  assert.ok(normalBubble(image, result), 'queued message text must remain visible');
  return result;
}

export function normalBubble(image, bubble, reference) {
  const { left, right, top, bottom, bg } = bubble;
  const palette = bubbleColors(bg);
  const colors = palette.normal;
  const brightest = Math.max(...colors);
  let fill = 0, ink = 0;
  const isInk = value => [0, 8, 16].every(s => ((value >> s) & 255) > ((brightest >> s) & 255) + 20);
  for (let y = top + 4; y < bottom - 4; y++) for (let x = left + 8; x < right - 8; x++) {
    const color = image.pixels.readUIntLE((y * image.width + x) * 4, 3);
    if (colors.has(color)) fill++;
    else if (isInk(color)) ink++;
    if (reference && isInk(color) !== isInk(reference.pixels.readUIntLE((y * reference.width + x) * 4, 3))) return false;
  }
  return fill > (right - left - 16) * (bottom - top - 8) * 0.5 && ink > 20;
}

export function countMessageBubbles(image, area, bubble) {
  const colors = bubbleColors(bubble.bg);
  const fills = [...colors.normal, ...colors.dim];
  let count = 0, run = 0;
  for (let y = area.top; y <= area.bottom; y++) {
    let matches = false;
    if (y < area.bottom) {
      const pixel = x => image.pixels.readUIntLE((y * image.width + x) * 4, 3);
      matches = fills.some(fill => pixel(bubble.left + 4) === fill && pixel(bubble.right - 5) === fill &&
        (bubble.left <= area.left + 4 || pixel(bubble.left - 4) !== fill) &&
        (bubble.right >= area.right - 4 || pixel(bubble.right + 3) !== fill));
    }
    if (matches) run++;
    else if (run > 0) {
      if (run >= (bubble.bottom - bubble.top) / 2) count++;
      run = 0;
    }
  }
  return count;
}

export function evaluateFrames(frames, acceptedMs) {
  assert.ok(Number.isFinite(acceptedMs), 'IGSH-969 acceptance timestamp is invalid');
  const first = frames.find(frame => frame.ms >= acceptedMs);
  assert.ok(first && first.ms - acceptedMs <= 1000, 'IGSH-969 no frame within one second of acceptance');
  for (const frame of frames) {
    assert.ok(frame.normal, 'queued message must remain normal in every frame');
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
    const rows = file => fs.readFileSync(path.join(root, 'accepted-message/stand-in', file), 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line));
    const workers = rows('accepted-worker.jsonl');
    assert.ok(workers.some(row => row.stage === 'started'));
    assert.ok(workers.some(row => row.stage === 'dispatch' && row.result?.message?.text === observation.text));
    const buffers = rows('tmux-buffers.jsonl');
    assert.equal(buffers.filter(row => row.argv[0] === 'paste-buffer').length, 1);
    const inputFrames = rows('frames.jsonl');
    assert.equal(inputFrames.filter(row => row.origin === 'app' && row.op === 'send-keys' && row.argv.includes('-l') && row.argv.at(-1) === observation.text).length, 1);
    const state = json('accepted-message/stand-in/claude.json');
    assert.equal(state.mode, 'busy');
    assert.deepEqual(state.queue, []);
    const outbox = json('accepted-message/outbox-queued.json');
    const waiting = outbox.queues.flatMap(queue => queue.messages).filter(message => message.t === observation.text);
    assert.equal(waiting.length, 1);
    assert.equal(waiting[0].v1, 1);
    assert.equal(waiting[0].phase, 'accepted');
    for (const stage of ['waiting', 'taken']) {
      const copied = fs.readFileSync(path.join(root, `accepted-message/${stage}-copied.txt`), 'utf8');
      assert.equal(copied.split(observation.text).length - 1, 1, `${stage} message must appear once`);
    }
    const transcript = fs.readFileSync(path.join(root, 'accepted-message/transcript.jsonl'), 'utf8');
    const events = transcript.trim().split(/\r?\n/).map(line => JSON.parse(line));
    assert.ok(events.some(e => e.type === 'queue-operation' && e.operation === 'enqueue' && e.content === observation.text));
    assert.ok(events.some(e => e.type === 'queue-operation' && e.operation === 'remove' && e.content === observation.text));
    assert.equal(events.filter(e => e.type === 'queue-operation' && e.operation === 'enqueue' && e.content === observation.text).length, 1);
    assert.equal(events.filter(e => e.type === 'attachment' && e.attachment?.type === 'queued_command' && e.attachment.prompt === observation.text).length, 1);
    const cleanup = json('cleanup.json');
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.scratch_removed, true);
    const queued = readBmp(path.join(root, 'accepted-queued.bmp'));
    const bubble = queuedBubble(queued, observation.area);
    assert.ok(normalBubble(queued, bubble), 'queued message must already have normal fill and text');
    const frames = observation.frames.map(frame => {
      const image = readBmp(path.join(root, frame.name + '.bmp'));
      assert.equal(image.width, queued.width);
      assert.equal(image.height, queued.height);
      for (let y = bubble.top; y < bubble.bottom; y++) for (let x = bubble.left; x < bubble.right; x++) {
        const offset = (y * image.width + x) * 4;
        if (image.pixels.readUIntLE(offset, 3) !== queued.pixels.readUIntLE(offset, 3)) {
          assert.fail(`bubble RGB changed at ${x},${y} in ${frame.name}`);
        }
      }
      let working = null;
      for (let left = observation.area.left; left < observation.area.right - 40 && !working; left += 140) {
        working = dots(image, { ...observation.area, left, top: bubble.bottom + 2 });
      }
      return { ...frame, normal: normalBubble(image, bubble, queued), dots: !!working, count: countMessageBubbles(image, observation.area, bubble) };
    });
    const receipt = json('accepted-message/stand-in/accepted.json');
    assert.equal(receipt.text, observation.text);
    const latencyMs = evaluateFrames(frames, receipt.ms);
    for (const frame of frames) assert.equal(frame.count, 1, 'message vanished or duplicated after pickup');
    assert.ok(observation.transition.length >= 20);
    for (const frame of observation.transition) {
      const image = readBmp(path.join(root, frame.name + '.bmp'));
      assert.ok(normalBubble(image, bubble, queued), 'message vanished or dimmed during transcript handoff');
      assert.equal(countMessageBubbles(image, observation.area, bubble), 1, 'message duplicated during transcript handoff');
    }
    const taken = readBmp(path.join(root, 'accepted-taken.bmp'));
    assert.ok(normalBubble(taken, bubble, queued), 'taken message must stay normal at its original position');
    writeCrop(queued, { ...observation.area, top: Math.max(observation.area.top, bubble.top - 8) }, 1, path.join(root, 'accepted-before.png'));
    writeCrop(taken, { ...observation.area, top: Math.max(observation.area.top, bubble.top - 8) }, 1, path.join(root, 'accepted-after.png'));
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-accepted-message', status: 'passed', latencyMs, frames, transition: observation.transition }, null, 2));
    console.log(`ACCEPTED_MESSAGE_NORMAL_WITH_DOTS ${latencyMs}ms`);
  } catch (error) {
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-accepted-message', status: 'failed', error: error.message }, null, 2));
    throw error;
  }
}
