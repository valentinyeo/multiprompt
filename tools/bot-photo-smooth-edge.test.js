const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(path.resolve(__dirname, '..', 'src', 'bot_photo.zig'), 'utf8');
const draw = (() => {
  const start = source.indexOf('pub fn draw(');
  assert.ok(start >= 0, 'bot_photo draw exists');
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, 'bot_photo draw closes');
  return source.slice(start, end + 2);
})();

test('IGSH-1894 session photo circles are not cut with an aliased GDI+ clip', () => {
  assert.doesNotMatch(source, /GdipSetClipPath|GdipAddPathEllipseI/);
});

test('IGSH-1894 session photo circles get supersampled anti-aliased edges at the exact avatar rectangle', () => {
  assert.match(draw, /const samples = 4;/);
  assert.match(draw, /CreateDIBSection\(surface, &info, 0, &bits, null, 0\)/);
  assert.match(draw, /\.width = width \* samples, \.height = -height \* samples/);
  assert.match(draw, /GdipDrawImageRectI\(graphics, item\.image, 0, 0, width \* samples, height \* samples\)/);
  assert.match(draw, /smooth\.resolveRounded\(pixels\[0\.\.len\], @intCast\(width\), @intCast\(height\), samples, \.\{ \.x = 0, \.y = 0, \.width = @floatFromInt\(width \* samples\), \.height = @floatFromInt\(height \* samples\), \.radius = @as\(f32, @floatFromInt\(@min\(width, height\) \* samples\)\) \/ 2 \}\)/);
  assert.match(draw, /GdiAlphaBlend\(hdc, rc\.left, rc\.top, width, height, surface, 0, 0, width, height, \.\{\}\)/);
});

test('IGSH-1894 transparent photo pixels keep showing the row behind the avatar', () => {
  const seed = draw.indexOf('w.BitBlt(surface, 0, 0, width, height, hdc, rc.left, rc.top, w.GDI_SRCCOPY)');
  const photo = draw.indexOf('GdipDrawImageRectI(');
  assert.ok(seed > 0 && photo > seed, 'destination is copied under the photo before it is drawn');
  assert.match(draw, /pixels\[y \* stride \+ x\] = pixels\[\(y \/ samples\) \* stride \+ x \/ samples\]/);
});
