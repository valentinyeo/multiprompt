const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(path.resolve(__dirname, '..', 'src', 'bot_photo.zig'), 'utf8');
const fn = (signature) => {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, `${signature} exists`);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, `${signature} closes`);
  return source.slice(start, end + 2);
};

test('IGSH-1907 a repaint of an unchanged photo avatar reuses its finished pixels instead of resampling the photo', () => {
  const draw = fn('pub fn draw(');
  const hit = draw.indexOf('variant.background == background');
  assert.ok(hit > 0, 'draw looks up a finished variant');
  assert.ok(hit < draw.indexOf('GdipCreateFromHDC('), 'the lookup runs before GDI+ is started');
  assert.ok(hit < draw.indexOf('GdipDrawImageRectI('), 'the lookup runs before the photo is resampled');
  assert.ok(hit < draw.indexOf('smooth.resolveRounded('), 'the lookup runs before the circle is resolved');
  const branch = draw.slice(hit, draw.indexOf('\n        }\n', hit));
  assert.match(branch, /return GdiAlphaBlend\(hdc, rc\.left, rc\.top, width, height, surface, 0, 0, width, height, \.\{\}\) != 0;/, 'a hit only blends the stored pixels');
});

test('IGSH-1907 the stored avatar pixels are keyed by size and by the row painted behind them', () => {
  const draw = fn('pub fn draw(');
  assert.match(draw, /variant\.width == width and variant\.height == height and variant\.background == background/);
  const seed = draw.indexOf('w.BitBlt(surface, 0, 0, width, height, hdc, rc.left, rc.top, w.GDI_SRCCOPY)');
  const hash = draw.indexOf('const background = hasher.final();');
  assert.ok(seed > 0 && hash > seed, 'the background key hashes the destination copied under the avatar');
  assert.ok(draw.indexOf('.background = background, .pixels = copy') > draw.indexOf('smooth.resolveRounded('), 'the variant stores the resolved circle');
});

test('IGSH-1907 replacing, evicting or shutting down a photo frees its stored variants', () => {
  const release = fn('fn release(');
  assert.match(release, /for \(&entry\.variants\) \|\*variant\| if \(variant\.pixels\) \|pixels\| std\.heap\.page_allocator\.free\(pixels\);/);
  assert.match(fn('fn invalidate('), /release\(entry\)/);
  assert.match(fn('pub fn shutdown('), /release\(entry\)/);
  assert.match(fn('pub fn draw('), /release\(oldest\);/);
});
