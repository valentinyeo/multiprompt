import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

export const MONO_FACE = 'Nordwand Mono MP SemiBold';

export function readBmp(file) {
  const bytes = fs.readFileSync(file);
  if (bytes.toString('latin1', 0, 2) !== 'BM') throw new Error(`${file} is not a BMP`);
  const offset = bytes.readUInt32LE(10);
  const width = bytes.readInt32LE(18);
  const rawHeight = bytes.readInt32LE(22);
  if (bytes.readUInt16LE(28) !== 32) throw new Error(`${file} is not 32-bit`);
  const height = Math.abs(rawHeight);
  const pixels = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y++) {
    const source = offset + (rawHeight < 0 ? y : height - 1 - y) * width * 4;
    bytes.copy(pixels, y * width * 4, source, source + width * 4);
  }
  return { width, height, pixels };
}

const luminance = (image, x, y) => {
  const i = (y * image.width + x) * 4;
  return 0.114 * image.pixels[i] + 0.587 * image.pixels[i + 1] + 0.299 * image.pixels[i + 2];
};

export function edgeHardness(image, rect, rows) {
  let edges = 0;
  let hardEdges = 0;
  let inkPixels = 0;
  let partialPixels = 0;
  const rowHeight = Math.floor((rect.bottom - rect.top) / rows);
  for (let row = 0; row < rows; row++) {
    const top = rect.top + row * rowHeight;
    const counts = new Map();
    for (let y = top; y < top + rowHeight; y++) {
      for (let x = rect.left; x < rect.right; x++) {
        const value = Math.round(luminance(image, x, y));
        counts.set(value, (counts.get(value) || 0) + 1);
      }
    }
    const background = [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0];
    let span = 1;
    for (let y = top; y < top + rowHeight; y++) {
      for (let x = rect.left; x < rect.right; x++) span = Math.max(span, Math.abs(luminance(image, x, y) - background));
    }
    for (let y = top; y < top + rowHeight; y++) {
      let previous = -1;
      for (let x = rect.left; x < rect.right; x++) {
        const t = Math.abs(luminance(image, x, y) - background) / span;
        if (t > 0.1) {
          inkPixels++;
          if (t < 0.9) partialPixels++;
        }
        if (previous >= 0) {
          const low = Math.min(previous, t);
          const high = Math.max(previous, t);
          if (low <= 0.1 && high > 0.1) {
            edges++;
            if (high >= 0.9) hardEdges++;
          }
        }
        previous = t;
      }
    }
  }
  return { edges, hardEdges, hardEdgeFraction: edges ? hardEdges / edges : 1, inkPixels, partialPixels };
}

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(buffer) {
  let c = 0xffffffff;
  for (const byte of buffer) c = crcTable[(c ^ byte) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'latin1'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([length, body, crc]);
}

export function writeCrop(image, rect, scale, file) {
  const left = Math.max(0, rect.left);
  const top = Math.max(0, rect.top);
  const right = Math.min(image.width, rect.right);
  const bottom = Math.min(image.height, rect.bottom);
  const width = (right - left) * scale;
  const height = (bottom - top) * scale;
  const raw = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) {
    const line = y * (width * 3 + 1);
    for (let x = 0; x < width; x++) {
      const i = ((top + Math.floor(y / scale)) * image.width + left + Math.floor(x / scale)) * 4;
      raw[line + 1 + x * 3] = image.pixels[i + 2];
      raw[line + 2 + x * 3] = image.pixels[i + 1];
      raw[line + 3 + x * 3] = image.pixels[i];
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 2;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}

export function evaluate(evidence) {
  const checks = [];
  const check = (name, passed, detail) => {
    checks.push({ name, passed: Boolean(passed), ...detail });
    return Boolean(passed);
  };
  const dwrite = JSON.parse(fs.readFileSync(path.join(evidence, 'chat-code-proof-dwrite.json'), 'utf8'));
  const gdi = JSON.parse(fs.readFileSync(path.join(evidence, 'chat-code-proof-gdi.json'), 'utf8'));
  const dwriteImage = readBmp(path.join(evidence, 'chat-code-proof-dwrite.bmp'));
  const gdiImage = readBmp(path.join(evidence, 'chat-code-proof-gdi.bmp'));
  check('IGSH-678 painter code font', dwrite.ticket === 'IGSH-678' && dwrite.face === MONO_FACE && dwrite.code_em === dwrite.previous_code_em - 2 && dwrite.code_em < dwrite.body_em, { face: dwrite.face, codeEm: dwrite.code_em, previousCodeEm: dwrite.previous_code_em, bodyEm: dwrite.body_em });
  check('IGSH-678 painter diff rows on DirectWrite', dwrite.dwrite_enabled === true && dwrite.diff_fallback_runs === 0 && dwrite.diff_glyph_runs >= 5 && dwrite.code_fallback_runs === 0 && dwrite.code_glyph_runs > 0 && gdi.dwrite_enabled === false && gdi.diff_glyph_runs === 0, { dwrite: { diffGlyphRuns: dwrite.diff_glyph_runs, diffFallbackRuns: dwrite.diff_fallback_runs, codeGlyphRuns: dwrite.code_glyph_runs, codeFallbackRuns: dwrite.code_fallback_runs }, gdi: { diffGlyphRuns: gdi.diff_glyph_runs, diffFallbackRuns: gdi.diff_fallback_runs } });
  const sameGeometry = JSON.stringify(dwrite.diff_rows) === JSON.stringify(gdi.diff_rows) && dwriteImage.width === gdiImage.width && dwriteImage.height === gdiImage.height;
  const smooth = edgeHardness(dwriteImage, dwrite.diff_rows, 3);
  const hard = edgeHardness(gdiImage, gdi.diff_rows, 3);
  check('IGSH-678 painter diff edges smoother than GDI', sameGeometry && smooth.partialPixels > 0 && smooth.hardEdgeFraction < hard.hardEdgeFraction, { directWrite: smooth, gdi: hard, rows: dwrite.diff_rows });
  const crop = { left: dwrite.diff_rows.left, top: dwrite.diff_rows.top, right: Math.min(dwrite.diff_rows.right, dwrite.diff_rows.left + 240), bottom: dwrite.diff_rows.bottom };
  writeCrop(dwriteImage, crop, 4, path.join(evidence, 'chat-code-diff-4x.png'));
  writeCrop(gdiImage, crop, 4, path.join(evidence, 'chat-code-diff-gdi-4x.png'));
  writeCrop(dwriteImage, dwrite.code, 4, path.join(evidence, 'chat-code-block-4x.png'));
  writeCrop(dwriteImage, { left: 0, top: 0, right: dwriteImage.width, bottom: dwriteImage.height }, 1, path.join(evidence, 'chat-code-render.png'));
  writeCrop(gdiImage, { left: 0, top: 0, right: gdiImage.width, bottom: gdiImage.height }, 1, path.join(evidence, 'chat-code-render-gdi.png'));
  return { passed: checks.every(item => item.passed), checks };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const evidence = path.resolve(process.argv[2] || 'evidence');
  let summary;
  try {
    summary = evaluate(evidence);
  } catch (error) {
    summary = { passed: false, error: String(error && error.stack || error), checks: [] };
  }
  fs.writeFileSync(path.join(evidence, 'chat-code-proof-summary.json'), JSON.stringify(summary, null, 2) + '\n');
  console.log(`IGSH-678 painter proof ${summary.passed ? 'passed' : 'failed'}`);
}
