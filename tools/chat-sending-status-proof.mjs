import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

export function measureStatus(image, rect, dimmed = false) {
  const { left, top, width, height } = rect;
  assert.ok([left, top, width, height].every(Number.isSafeInteger));
  assert.ok(left >= 0 && top >= 0 && width > 200 && height > 100);
  assert.ok(left + width <= image.width && top + height <= image.height);
  const pixel = (x, y) => image.pixels.readUIntLE(((top + y) * image.width + left + x) * 4, 3);
  const counts = new Map();
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const color = pixel(x, y);
    counts.set(color, (counts.get(color) || 0) + 1);
  }
  const background = [...counts].sort((a, b) => b[1] - a[1])[0][0];
  assert.ok([0, 8, 16].every(shift => ((background >> shift) & 255) < 128), 'dark fixture background');
  const fills = (dimmed ? [26, 27] : [53]).map(delta => [0, 8, 16].reduce((color, shift) => color | Math.min(255, ((background >> shift) & 255) + delta) << shift, 0));
  let bottom = -1, right = 0, lo = width, ink = 0;
  for (let y = 0; y < height; y++) {
    let start = -1;
    for (let x = 0; x <= width; x++) {
      if (x < width && fills.includes(pixel(x, y))) { if (start < 0) start = x; }
      else if (start >= 0) {
        if (x - start > 40) { bottom = y; right = Math.max(right, x); lo = Math.min(lo, start); ink += x - start; }
        start = -1;
      }
    }
  }
  assert.ok(ink > 500 && bottom > 20 && bottom + 26 < height, 'outgoing bubble must be visibly painted');
  let bodyInk = 0;
  for (let y = Math.max(0, bottom - 35); y < bottom - 5; y++) for (let x = lo + 12; x < right - 12; x++) {
    if (!fills.includes(pixel(x, y)) && pixel(x, y) !== background) bodyInk++;
  }
  assert.ok(bodyInk > 20, 'outgoing bubble contains message text');
  let statusInk = 0;
  for (let y = bottom + 3; y <= bottom + 24; y++) for (let x = Math.max(0, lo - 320); x < right; x++) {
    if (pixel(x, y) !== background) statusInk++;
  }
  assert.equal(statusInk, 0, 'IGSH-931 ordinary message status is still painted below the bubble');
  return { bottom, right, bodyInk, statusInk };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = process.argv[2];
  const json = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, ''));
  try {
    const observation = json('busy-send/observation.json');
    assert.equal(observation.error, null);
    assert.equal(observation.blockedAtCapture, true, 'first screenshot precedes transport release');
    assert.equal(observation.composerText, 'busy delivery alpha');
    assert.deepEqual(json('busy-send/stand-in/claude.json').queue, ['busy delivery alpha']);
    const events = fs.readFileSync(path.join(root, 'agent-buffer.jsonl'), 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line));
    assert.deepEqual(events.map(event => event.argv), [
      ['send-keys', '-t', '=verify-agent:', '-l', '--', 'busy delivery alpha'],
      ['send-keys', '-t', '=verify-agent:', 'Enter'],
    ]);
    const cleanup = json('cleanup.json');
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.scratch_removed, true);
    const frames = ['sending-immediate', 'sending-delivered'].map(name => ({ name, ...measureStatus(readBmp(path.join(root, name + '.bmp')), observation.transcript, name === 'sending-delivered') }));
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-sending-status', status: 'passed', frames }, null, 2));
    console.log('IGSH-931 Windows send frames have no status row');
  } catch (error) {
    fs.writeFileSync(path.join(root, 'result.json'), JSON.stringify({ feature: 'chat-sending-status', status: 'failed', error: error.message }, null, 2));
    throw error;
  }
}
