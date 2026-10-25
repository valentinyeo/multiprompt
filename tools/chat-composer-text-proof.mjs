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

export const typingThresholds = Object.freeze({ minFrames: 30, minDurationMs: 1000, maxGapMs: 100, minInk: 20, minInkRatio: 0.8, inkContrast: 24, maxColorDelta: 2 });

export function evaluateTypingFrames(frames, metadata) {
  const limits = typingThresholds;
  const settled = frames.at(-1)?.image;
  if (!settled) throw new Error('Missing typing frames');
  const { inkRect, rowRect, typingStartMs, typingEndMs } = metadata;
  for (const rect of [inkRect, rowRect]) {
    if (!rect || !['left', 'top', 'right', 'bottom'].every(key => Number.isInteger(rect[key])) || rect.left < 0 || rect.top < 0 || rect.right > settled.width || rect.bottom > settled.height || rect.right <= rect.left || rect.bottom <= rect.top) throw new Error('Invalid typing rectangle');
  }
  const rgb = (image, x, y) => {
    const offset = (y * image.width + x) * 4;
    return image.pixels[offset] | image.pixels[offset + 1] << 8 | image.pixels[offset + 2] << 16;
  };
  const delta = (a, b) => Math.max(Math.abs((a & 255) - (b & 255)), Math.abs((a >>> 8 & 255) - (b >>> 8 & 255)), Math.abs((a >>> 16 & 255) - (b >>> 16 & 255)));
  const background = image => {
    const counts = new Map();
    for (let y = rowRect.top; y < rowRect.bottom; y++) for (let x = rowRect.left; x < rowRect.right; x++) {
      const color = rgb(image, x, y);
      counts.set(color, (counts.get(color) || 0) + 1);
    }
    return [...counts].reduce((best, entry) => entry[1] > best[1] ? entry : best)[0];
  };
  const settledBackground = background(settled);
  const ink = (image, rect) => {
    let count = 0;
    for (let y = rect.top; y < rect.bottom; y++) for (let x = rect.left; x < rect.right; x++) if (delta(rgb(image, x, y), settledBackground) >= limits.inkContrast) count++;
    return count;
  };
  const settledInk = ink(settled, inkRect);
  const probes = [[0, 0], [1, 1], [settled.width - 1, 1], [1, settled.height - 1]];
  const settledBorder = probes.map(([x, y]) => rgb(settled, x, y));
  const measurements = frames.map(({ image, timeMs }, index) => {
    if (image.width !== settled.width || image.height !== settled.height || !Number.isFinite(timeMs)) throw new Error('Invalid typing frame');
    const rowBackground = background(image);
    return { index, timeMs, ink: ink(image, inkRect), rowInk: ink(image, rowRect), background: rowBackground, backgroundDelta: delta(rowBackground, settledBackground), borderDelta: Math.max(...probes.map(([x, y], probe) => delta(rgb(image, x, y), settledBorder[probe]))) };
  });
  const typing = measurements.filter(frame => frame.timeMs >= typingStartMs && frame.timeMs <= typingEndMs);
  const gaps = typing.slice(1).map((frame, index) => frame.timeMs - typing[index].timeMs);
  const durationMs = typingEndMs - typingStartMs;
  const samplingPassed = Number.isFinite(durationMs) && frames.at(-1).timeMs >= typingEndMs && durationMs >= limits.minDurationMs && typing.length >= limits.minFrames && typing[0].timeMs - typingStartMs <= limits.maxGapMs && typingEndMs - typing.at(-1).timeMs <= limits.maxGapMs && gaps.every(gap => gap > 0 && gap <= limits.maxGapMs);
  const mismatchedFrames = [];
  let previous = null;
  for (const frame of typing) {
    const reasons = [];
    frame.inkRatio = previous?.ink ? frame.ink / previous.ink : 1;
    frame.rowInkRatio = previous?.rowInk ? frame.rowInk / previous.rowInk : 1;
    if (frame.ink < limits.minInk || frame.ink < settledInk * limits.minInkRatio || frame.inkRatio < limits.minInkRatio || frame.rowInkRatio < limits.minInkRatio) reasons.push('ink-drop');
    if (frame.backgroundDelta > limits.maxColorDelta) reasons.push('row-background');
    if (frame.borderDelta > limits.maxColorDelta) reasons.push('border-background');
    if (reasons.length) mismatchedFrames.push({ ...frame, reasons });
    previous = frame;
  }
  const values = typing.map(frame => frame.ink);
  const rowValues = typing.map(frame => frame.rowInk);
  return { name: 'IGSH-760 typing frames steady', passed: samplingPassed && settledInk >= limits.minInk && mismatchedFrames.length === 0, thresholds: limits, frames: typing.length, capturedFrames: frames.length, durationMs, maxGapMs: gaps.length ? Math.max(...gaps) : null, samplingPassed, inkSeries: { values, min: values.length ? Math.min(...values) : null, max: values.length ? Math.max(...values) : null, settled: settledInk }, rowInkSeries: { min: rowValues.length ? Math.min(...rowValues) : null, max: rowValues.length ? Math.max(...rowValues) : null }, settledBackground, settledBorder, mismatchedFrames, measurements };
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
  const typing = process.argv.includes('--typing');
  let summary;
  try {
    if (native) summary = evaluateNative(directory);
    else if (typing) {
      const metadata = JSON.parse(fs.readFileSync(path.join(directory, 'composer-typing.json'), 'utf8').replace(/^\uFEFF/, ''));
      const frames = metadata.timesMs.map((timeMs, index) => ({ timeMs, image: readBmp(path.join(directory, `composer-typing-${String(index).padStart(4, '0')}.bmp`)) }));
      summary = evaluateTypingFrames(frames, metadata);
    } else {
      const metadata = JSON.parse(fs.readFileSync(path.join(directory, 'composer-live.json'), 'utf8').replace(/^\uFEFF/, ''));
      const image = readBmp(path.join(directory, 'composer-live.bmp'));
      summary = evaluateLive(image, metadata);
      writeCrop(image, metadata.rect, 4, path.join(directory, 'composer-text-4x.png'));
    }
  } catch (error) {
    summary = { passed: false, error: String(error.stack || error), measurement: null, threshold };
  }
  fs.writeFileSync(path.join(directory, `composer-${native ? 'native' : typing ? 'typing' : 'live'}-summary.json`), JSON.stringify(summary, null, 2) + '\n');
  console.log(JSON.stringify(summary));
  if (!summary.passed) process.exitCode = 1;
}
