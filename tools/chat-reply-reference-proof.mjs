import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { readBmp } from './chat-code-font-proof.mjs';

const [mode, evidence] = process.argv.slice(2);
const directory = path.join(evidence || '.', 'reply-reference');
function probe(image, frame) {
  const rect = frame.transcript;
  const rows = [];
  for (let y = rect.top; y < rect.top + rect.height; y++) {
    const ink = [];
    for (let x = rect.left + Math.floor(rect.width * 0.45); x < rect.left + rect.width - 24; x++) {
      const color = image.pixels.readUIntLE((y * image.width + x) * 4, 3);
      if ([0x787c84, 0x8c9098, 0x62666d, 0x445668].includes(color)) ink.push(x);
    }
    if (ink.length < 12) continue;
    let row = rows.at(-1);
    if (!row || y > row.bottom + 3) rows.push(row = { top: y, bottom: y, left: ink[0], right: ink.at(-1) });
    row.bottom = y;
    row.left = Math.min(row.left, ink[0]);
    row.right = Math.max(row.right, ink.at(-1));
  }
  const lines = rows.filter(row => row.bottom - row.top >= 4);
  assert.equal(lines.length, 1, 'Expected one dim reply reference, not a full quoted bubble');
  const row = lines[0];
  assert.ok(row.bottom - row.top <= 24 * frame.scale, 'Reference wrapped onto multiple lines');
  assert.ok(row.right - row.left > 60 * frame.scale, 'Reference lost its source preview');
  return { ...row, x: (row.left + row.right) / 2, y: (row.top + row.bottom) / 2 };
}
function highlight(image, frame) {
  const rect = frame.transcript;
  let pixels = 0;
  for (let y = rect.top + 2; y < rect.top + rect.height - 2; y++) {
    for (let x = rect.left + 20; x < rect.left + rect.width - 20; x++) {
      if ([0x7170ff, 0x6eaff5].includes(image.pixels.readUIntLE((y * image.width + x) * 4, 3))) pixels++;
    }
  }
  assert.ok(pixels > 500 * frame.scale, 'Original source highlight is absent');
}
try {
  if (mode === 'self-test') {
    const frame = { scale: 1, transcript: { left: 0, top: 0, width: 400, height: 200 } };
    const image = { width: 400, height: 200, pixels: Buffer.alloc(400 * 200 * 4) };
    assert.throws(() => probe(image, frame), /one dim reply reference/);
    assert.throws(() => highlight(image, frame), /highlight is absent/);
    for (let y = 100; y < 110; y++) for (let x = 220; x < 360; x++) image.pixels.writeUIntLE(0x62666d, (y * 400 + x) * 4, 3);
    assert.equal(probe(image, frame).top, 100);
    for (let y = 130; y < 140; y++) for (let x = 220; x < 360; x++) image.pixels.writeUIntLE(0x62666d, (y * 400 + x) * 4, 3);
    assert.throws(() => probe(image, frame), /one dim reply reference/);
    for (let x = 30; x < 350; x++) for (let y = 20; y < 22; y++) image.pixels.writeUIntLE(0x7170ff, (y * 400 + x) * 4, 3);
    highlight(image, frame);
    console.log('REPLY_PIXEL_CONTROLS_VERIFIED');
    process.exit(0);
  }
  const frame = JSON.parse(fs.readFileSync(path.join(directory, 'frame.json'), 'utf8'));
  if (mode === 'baseline') {
    assert.equal(frame.baseline, true);
    assert.throws(() => probe(readBmp(path.join(evidence, 'reply-after.bmp')), frame), /Expected one dim reply reference/);
    console.log('RELEASED_REPLY_BASELINE_REJECTED');
  } else if (mode === 'probe') {
    fs.writeFileSync(path.join(directory, 'probe.json'), JSON.stringify(probe(readBmp(path.join(evidence, 'reply-after.bmp')), frame)));
  } else if (mode === 'highlight') {
    highlight(readBmp(path.join(evidence, 'reply-highlighted.bmp')), frame);
  } else {
    assert.equal(mode, 'verify');
    const observation = JSON.parse(fs.readFileSync(path.join(directory, 'observation.json'), 'utf8'));
    assert.equal(observation.error, null, observation.error);
    assert.ok(frame.baseline ? observation.baselineRejected : observation.referenceClicked && observation.originalHighlighted);
    const rows = fs.readFileSync(path.join(directory, 'app-cache.jsonl'), 'utf8').trim().split('\n').slice(1).map(line => JSON.parse(line));
    const original = rows.find(row => row.role === 'assistant' && row.text?.startsWith('The original message starts here.'));
    assert.ok(original);
    const wire = original.text.split('\n').map(line => '> ' + line).join('\n') + '\n\nMy compact answer';
    assert.equal(rows.filter(row => row.role === 'user' && row.text === wire).length, 1, 'Wire quote was changed or duplicated');
    if (frame.baseline) assert.throws(() => probe(readBmp(path.join(evidence, 'reply-after.bmp')), frame), /Expected one dim reply reference/);
    else {
      probe(readBmp(path.join(evidence, 'reply-after.bmp')), frame);
      highlight(readBmp(path.join(evidence, 'reply-highlighted.bmp')), frame);
    }
    const cleanup = JSON.parse(fs.readFileSync(path.join(evidence, 'cleanup.json'), 'utf8'));
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.scratch_removed, true);
    fs.writeFileSync(path.join(evidence, 'result.json'), JSON.stringify({ status: 'passed', baseline: frame.baseline, compactReference: !frame.baseline, sourceJump: !frame.baseline, wirePreserved: true, cleanup }, null, 2));
    console.log(frame.baseline ? 'NATIVE_COMPACT_REPLY_RED_CONTROL_PROVEN' : 'NATIVE_COMPACT_REPLY_AND_SOURCE_JUMP_PROVEN');
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
