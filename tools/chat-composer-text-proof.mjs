import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readBmp, edgeHardness, writeCrop } from './chat-code-font-proof.mjs';

export const threshold = 0.18;

export function evaluateLive(image, metadata) {
  const rect = metadata.rect;
  if (!rect || !Object.values(rect).every(Number.isInteger) || rect.left < 0 || rect.top < 0 || rect.right > image.width || rect.bottom > image.height || rect.right <= rect.left || rect.bottom <= rect.top) throw new Error('Invalid composer text rectangle');
  const measurement = edgeHardness(image, rect, 1);
  measurement.partialPerInk = measurement.inkPixels ? measurement.partialPixels / measurement.inkPixels : 0;
  return { name: 'IGSH-731 composer edges', passed: metadata.fontSmoothing === false && measurement.edges >= 100 && measurement.partialPixels > 0 && measurement.hardEdgeFraction < threshold, threshold, measurement };
}

export function evaluateNative(directory) {
  const checks = [];
  for (const scale of [100, 125, 150]) {
    for (const dpi of [96, 120, 144]) {
      const results = {};
      for (const mode of ['gdi', 'dwrite']) {
        const stem = path.join(directory, `composer-${scale}-${dpi}-${mode}`);
        const metadata = JSON.parse(fs.readFileSync(`${stem}.json`, 'utf8'));
        const image = readBmp(`${stem}.bmp`);
        const measurement = edgeHardness(image, { left: 0, top: 0, right: image.width, bottom: image.height }, 1);
        const valid = metadata.ticket === 'IGSH-731' && metadata.ui_scale === scale && metadata.dpi === dpi && metadata.direct_write === (mode === 'dwrite') && metadata.font_smoothing === false && metadata.measurement.edges === measurement.edges && Math.abs(metadata.measurement.hardEdgeFraction - measurement.hardEdgeFraction) < 0.00001;
        results[mode] = { valid, measurement, fontPx: metadata.font_px };
        writeCrop(image, { left: 0, top: 0, right: image.width, bottom: Math.min(image.height, metadata.font_px * 2) }, 4, `${stem}-4x.png`);
      }
      const { gdi, dwrite } = results;
      checks.push({ name: `IGSH-731 composer scale ${scale} DPI ${dpi}`, passed: gdi.valid && dwrite.valid && gdi.fontPx === dwrite.fontPx && dwrite.measurement.edges >= 100 && dwrite.measurement.partialPixels > 0 && dwrite.measurement.hardEdgeFraction < gdi.measurement.hardEdgeFraction && dwrite.measurement.hardEdgeFraction <= 0.15, ...results });
    }
  }
  return { passed: checks.every(check => check.passed), checks };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const directory = path.resolve(process.argv[2] || 'evidence');
  const native = process.argv.includes('--native');
  let summary;
  try {
    if (native) summary = evaluateNative(directory);
    else {
      const metadata = JSON.parse(fs.readFileSync(path.join(directory, 'composer-live.json'), 'utf8').replace(/^\uFEFF/, ''));
      const image = readBmp(path.join(directory, 'composer-live.bmp'));
      summary = evaluateLive(image, metadata);
      writeCrop(image, metadata.rect, 4, path.join(directory, 'composer-text-4x.png'));
    }
  } catch (error) {
    summary = { passed: false, error: String(error.stack || error), measurement: null, threshold };
  }
  fs.writeFileSync(path.join(directory, `composer-${native ? 'native' : 'live'}-summary.json`), JSON.stringify(summary, null, 2) + '\n');
  console.log(JSON.stringify(summary));
  if (!summary.passed) process.exitCode = 1;
}
