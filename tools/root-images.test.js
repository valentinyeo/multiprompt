const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const image = /\.(png|jpe?g|gif|bmp|webp)$/i;

function strayImages(files) {
  return files.filter((f) => !f.includes('/') && image.test(f));
}

test('no images in the repository top folder', () => {
  const files = execFileSync('git', ['ls-files'], { cwd: root, encoding: 'utf8' }).split('\n');
  const stray = strayImages(files);
  assert.deepEqual(stray, [], `move screenshots out of the top folder: ${stray.join(', ')}`);
});

test('the check catches the screenshots removed in issue', () => {
  const sample = ['zs-ag1.png', 'zsb-spill-test.png', 'screenshot.png', 'webview2-spike/screenshot.png', 'icon.ico'];
  assert.deepEqual(strayImages(sample), ['zs-ag1.png', 'zsb-spill-test.png', 'screenshot.png']);
});
