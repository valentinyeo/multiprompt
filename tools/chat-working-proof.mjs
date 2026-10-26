import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp, writeCrop } from './chat-code-font-proof.mjs';

export function dots(image, area) {
  const rgb = (x, y) => {
    const n = (y * image.width + x) * 4;
    return [image.pixels[n], image.pixels[n + 1], image.pixels[n + 2]];
  };
  if (!area || !['left', 'top', 'right', 'bottom'].every(k => Number.isInteger(area[k])) || area.left < 0 || area.top < 0 || area.right > image.width || area.bottom > image.height || area.left >= area.right || area.top >= area.bottom) throw new Error('Invalid transcript area');
  const bg = rgb(area.left, area.top);
  const seen = new Set();
  const blobs = [];
  const ink = (x, y) => Math.max(...rgb(x, y).map((v, i) => Math.abs(v - bg[i]))) > 75;
  for (let y = area.top; y < area.bottom; y++) for (let x = area.left; x < Math.min(area.right, area.left + 180); x++) {
    const key = y * image.width + x;
    if (seen.has(key) || !ink(x, y)) continue;
    const queue = [[x, y]];
    seen.add(key);
    const blob = { left: x, right: x + 1, top: y, bottom: y + 1, pixels: 0 };
    for (let i = 0; i < queue.length; i++) {
      const [px, py] = queue[i];
      blob.pixels++;
      blob.left = Math.min(blob.left, px); blob.right = Math.max(blob.right, px + 1);
      blob.top = Math.min(blob.top, py); blob.bottom = Math.max(blob.bottom, py + 1);
      for (const [nx, ny] of [[px - 1, py], [px + 1, py], [px, py - 1], [px, py + 1]]) {
        const n = ny * image.width + nx;
        if (nx < area.left || nx >= Math.min(area.right, area.left + 180) || ny < area.top || ny >= area.bottom || seen.has(n) || !ink(nx, ny)) continue;
        seen.add(n); queue.push([nx, ny]);
      }
    }
    const w = blob.right - blob.left, h = blob.bottom - blob.top;
    if (w >= 4 && w <= 12 && h >= 4 && h <= 12 && Math.abs(w - h) <= 1 && blob.pixels / (w * h) >= 0.55) blobs.push(blob);
  }
  blobs.sort((a, b) => a.left - b.left);
  for (const a of blobs) for (const b of blobs) for (const c of blobs) {
    const dx = b.left - a.left;
    if (dx < 7 || dx > 18 || Math.abs(c.left - b.left - dx) > 1 || Math.max(a.top, b.top, c.top) - Math.min(a.top, b.top, c.top) > 4) continue;
    return [a, b, c];
  }
  return null;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [file, areaFile, output, state, previousFile] = process.argv.slice(2);
  const image = readBmp(file);
  const area = JSON.parse(fs.readFileSync(areaFile, 'utf8'));
  const found = dots(image, area);
  let replyPixels = 0;
  if (state === 'idle') {
    const previous = JSON.parse(fs.readFileSync(previousFile, 'utf8')).dots;
    if (!previous?.length) throw new Error('Missing working frame');
    const bg = (area.top * image.width + area.left) * 4;
    const top = Math.max(area.top, Math.min(...previous.map(dot => dot.top)) - 10);
    const bottom = Math.min(area.bottom, Math.max(...previous.map(dot => dot.bottom)) + 15);
    for (let y = top; y < bottom; y++) for (let x = previous[0].left; x < Math.min(area.right, previous[0].left + 100); x++) {
      const offset = (y * image.width + x) * 4;
      if ([0, 1, 2].some(c => Math.abs(image.pixels[offset + c] - image.pixels[bg + c]) > 75)) replyPixels++;
    }
    if (replyPixels < 60) throw new Error('IGSH-924 reply not painted in the former dots slot');
  }
  fs.writeFileSync(output, JSON.stringify({ dots: found, area, replyPixels }, null, 2));
  if ((state === 'busy') !== !!found) throw new Error(`IGSH-924 ${state === 'busy' ? 'missing inline dots' : 'dots remain after reply'}`);
  if (found) writeCrop(image, { left: Math.max(area.left, found[0].left - 8), top: Math.max(area.top, Math.min(...found.map(d => d.top)) - 8), right: Math.min(area.right, found[2].right + 8), bottom: Math.min(area.bottom, Math.max(...found.map(d => d.bottom)) + 8) }, 4, output.replace(/\.json$/, '.png'));
  console.log(state === 'busy' ? 'INLINE_DOTS_VISIBLE' : 'INLINE_DOTS_ABSENT');
}
