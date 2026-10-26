import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp } from './chat-code-font-proof.mjs';

export function measure(image, rect, accent) {
  const { left, top, right, bottom } = rect;
  if (![left, top, right, bottom].every(Number.isInteger) || left < 0 || top < 0 || right > image.width || bottom > image.height || right <= left || bottom <= top) throw new Error('Invalid owned control bounds');
  let ink = 0;
  let fill = 0;
  for (let y = top; y < bottom; y++) {
    for (let x = left; x < right; x++) {
      const i = (y * image.width + x) * 4;
      const rgb = [image.pixels[i + 2], image.pixels[i + 1], image.pixels[i]];
      if (rgb.every((v, c) => Math.abs(v - accent[c]) <= 12)) ink++;
      if (rgb[2] - rgb[0] >= 14 && rgb[2] - rgb[0] <= 28 && rgb[1] - rgb[0] >= 5 && rgb[1] - rgb[0] <= 12) fill++;
    }
  }
  return { ink, fill, pill: ink >= 12 && fill >= 60 };
}

export function evaluate(directory) {
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, 'skill-pill.json'), 'utf8').replace(/^\uFEFF/, ''));
  const checks = manifest.captures.map(capture => {
    const image = readBmp(path.join(directory, `${capture.name}.bmp`));
    const actual = measure(image, capture.rect, capture.theme === 'dark' ? [110, 175, 245] : [30, 90, 170]);
    return { ...capture, ...actual, passed: capture.expected ? actual.pill : actual.ink === 0 && actual.fill === 0 };
  });
  const required = ['dark', 'light'].flatMap(theme => ['unknown-draft', 'plain-draft', 'plain-sent', 'skill-draft', 'skill-sent'].map(stage => `${theme}-${stage}`));
  const passed = required.length === checks.length && required.every(name => checks.some(check => check.name === name)) && checks.every(check => check.passed);
  const summary = { passed, checks };
  fs.writeFileSync(path.join(directory, 'skill-pill-summary.json'), JSON.stringify(summary, null, 2));
  return summary;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const summary = evaluate(process.argv[2]);
  console.log(JSON.stringify(summary));
  if (!summary.passed) process.exitCode = 1;
}
