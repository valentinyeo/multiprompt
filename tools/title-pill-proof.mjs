import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

export function evaluateTitle(frame, underlay, metadata) {
  const { pill: p, window: w } = metadata;
  const rgb = (image, x, y) => {
    const i = (y * image.width + x) * 4;
    return [image.pixels[i + 2], image.pixels[i + 1], image.pixels[i]];
  };
  const delta = (a, b) => Math.max(...a.map((v, i) => Math.abs(v - b[i])));
  if (![p, w].every(r => r && ['left', 'top', 'right', 'bottom'].every(k => Number.isInteger(r[k])) && r.right > r.left && r.bottom > r.top) || w.left < 0 || w.top < 0 || w.right > frame.width || w.bottom > frame.height || underlay.width !== w.right - w.left || underlay.height !== w.bottom - w.top || p.left < w.left || p.top < w.top || p.right > w.right || p.bottom > w.bottom) throw new Error('Invalid title geometry');
  const radius = (p.bottom - p.top) / 2;
  const cy = (p.top + p.bottom) / 2;
  const bg = rgb(frame, 0, 0);
  const fill = rgb(frame, p.left + 8, Math.floor(cy));
  let changed = 0, ringInk = 0, leftInk = 0, rightInk = 0, titleInk = 0;
  for (let y = Math.max(w.top, p.top - 8); y < Math.min(w.bottom, p.bottom + 8); y++) {
    for (let x = Math.max(w.left, p.left - 8); x < Math.min(w.right, p.right + 8); x++) {
      const cx = Math.max(p.left + radius, Math.min(p.right - radius, x + 0.5));
      if (Math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= radius + 2) continue;
      const expected = rgb(underlay, x - w.left, y - w.top);
      if (delta(expected, bg) > 10) ringInk++;
      if (delta(rgb(frame, x, y), expected) > 2) changed++;
    }
  }
  for (let y = p.top; y < p.bottom; y++) {
    for (let x = w.left; x < w.right; x++) {
      const color = rgb(frame, x, y);
      const transcript = rgb(underlay, x - w.left, y - w.top);
      if (delta(color, bg) <= 80 || delta(color, transcript) > 2) continue;
      if (x < p.left - 8) leftInk++;
      if (x >= p.right + 8) rightInk++;
    }
  }
  for (let y = p.top + 3; y < p.bottom - 3; y++) for (let x = p.left + 16; x < p.right - 16; x++) if (delta(rgb(frame, x, y), fill) > 80) titleInk++;
  return { changed, ringInk, leftInk, rightInk, titleInk };
}

export function evaluateFolder(folder) {
  const metadata = JSON.parse(fs.readFileSync(path.join(folder, 'chat-title-meta.json'), 'utf8').replace(/^\uFEFF/, ''));
  const frames = [0, 1, 2].map(i => evaluateTitle(readBmp(path.join(folder, `chat-title-${i}-frame.bmp`)), readBmp(path.join(folder, `chat-title-${i}-underlay.bmp`)), metadata));
  const total = key => frames.reduce((n, f) => n + f[key], 0);
  return { theme: metadata.theme, frames, passed: frames.every(f => f.changed === 0 && f.titleInk >= 8) && total('ringInk') > 10 && total('leftInk') > 20 && total('rightInk') > 20 };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const folder = path.resolve(process.argv[2]);
  const result = evaluateFolder(folder);
  fs.writeFileSync(path.join(folder, 'title-pill-result.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result));
  console.log(result.passed ? 'TITLE_PILL_NO_SURROUND' : 'TITLE_PILL_SURROUND_REJECTED');
  process.exitCode = result.passed ? 0 : 1;
}
