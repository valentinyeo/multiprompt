import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

export function measureWidth(image, rect, narrow) {
  const { left, top, width, height } = rect;
  assert.ok([left, top, width, height].every(Number.isSafeInteger));
  assert.ok(left >= 0 && top >= 0 && width > 200 && height > 100);
  assert.ok(left + width <= image.width && top + height <= image.height);
  const colorAt = (x, y) => image.pixels.readUIntLE(((top + y) * image.width + left + x) * 4, 3);
  const counts = new Map();
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const color = colorAt(x, y);
    counts.set(color, (counts.get(color) || 0) + 1);
  }
  const background = [...counts].sort((a, b) => b[1] - a[1])[0][0];
  assert.ok([0, 8, 16].every(shift => ((background >> shift) & 255) < 128), 'dark fixture background');
  const inset = narrow ? 8 : 24;
  const messages = {};
  for (const [role, delta] of [['user', 53], ['assistant', 36]]) {
    const fill = [0, 8, 16].reduce((color, shift) => color | Math.min(255, ((background >> shift) & 255) + delta) << shift, 0);
    let lo = width, hi = 0, first = height, last = 0, ink = 0;
    for (let y = 0; y < height; y++) {
      let start = -1;
      for (let x = 0; x <= width; x++) {
        if (x < width && colorAt(x, y) === fill) { if (start < 0) start = x; }
        else if (start >= 0) {
          if (x - start >= 32) { lo = Math.min(lo, start); hi = Math.max(hi, x); first = Math.min(first, y); last = Math.max(last, y); ink += x - start; }
          start = -1;
        }
      }
    }
    assert.ok(ink > 1000, `${role}: missing visible bubble`);
    const painted = hi - lo;
    if (narrow) assert.ok(painted * 100 >= width * 85 && painted * 100 <= width * 90, `IGSH-898 narrow ${role} width ${painted}/${width} outside 85–90 percent`);
    else {
      const cap = Math.floor((width - 2 * inset) * 0.6);
      assert.ok(painted <= cap + 1 && (role === 'user' ? painted >= cap * 0.85 : Math.abs(painted - cap) <= 1), `${role}: wide 60 percent cap changed`);
    }
    if (role === 'user') assert.ok(Math.abs(hi - (width - inset)) <= 1 && lo > inset, 'user stays right aligned');
    else assert.ok(Math.abs(lo - inset) <= 1 && hi < width - inset, 'assistant stays left aligned');
    messages[role] = { left: lo, right: hi, top: first, bottom: last, width: painted, column: width };
  }
  assert.ok(messages.user.bottom < messages.assistant.top, 'both distinct messages visible');
  return messages;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const dir = process.argv[2];
  try {
    const frames = JSON.parse(fs.readFileSync(path.join(dir, 'layout-frames.json'), 'utf8').replace(/^\uFEFF/, ''));
    assert.deepEqual(frames.map(frame => frame.name), ['wide', 'narrow']);
    const measurements = frames.map(frame => {
      assert.equal(frame.dpi, 96);
      assert.equal(frame.window.width, frame.name === 'wide' ? 1920 : 818);
      assert.equal(frame.transcript.width, frame.name === 'wide' ? 960 : 550);
      return { name: frame.name, messages: measureWidth(readBmp(path.join(dir, `layout-${frame.name}.bmp`)), frame.transcript, frame.name === 'narrow') };
    });
    const cleanup = JSON.parse(fs.readFileSync(path.join(dir, 'cleanup.json'), 'utf8'));
    assert.equal(cleanup.remaining_owned_processes, 0);
    assert.equal(cleanup.scratch_removed, true);
    fs.writeFileSync(path.join(dir, 'layout-measurements.json'), JSON.stringify(measurements, null, 2) + '\n');
    fs.writeFileSync(path.join(dir, 'result.json'), JSON.stringify({ feature: 'chat-width', status: 'passed', measurements }, null, 2) + '\n');
    console.log('IGSH-898 Windows bubble widths proved');
  } catch (error) {
    fs.writeFileSync(path.join(dir, 'result.json'), JSON.stringify({ feature: 'chat-width', status: 'failed', error: error.message }, null, 2) + '\n');
    throw error;
  }
}
