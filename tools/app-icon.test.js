const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

test('Windows executable resource carries each approved robot frame', () => {
  assert.match(fs.readFileSync(path.join(root, 'assets/zigshell.rc'), 'utf8'), /ICON\s+"icon\.ico"/);
  const icon = fs.readFileSync(path.join(root, 'assets/icon.ico'));
  assert.equal(icon.readUInt16LE(0), 0);
  assert.equal(icon.readUInt16LE(2), 1);
  assert.equal(icon.readUInt16LE(4), 5);
  const sizes = [];
  for (let i = 0; i < 5; i++) {
    const entry = 6 + 16 * i;
    const size = icon[entry] || 256;
    sizes.push(size);
    assert.equal(icon[entry + 1] || 256, size);
    const length = icon.readUInt32LE(entry + 8);
    const offset = icon.readUInt32LE(entry + 12);
    assert.deepEqual(icon.subarray(offset, offset + length), fs.readFileSync(path.join(root, `assets/icon${size}.png`)));
  }
  assert.deepEqual(sizes.sort((a, b) => a - b), [16, 32, 48, 64, 256]);
});

test('small taskbar and large launcher artwork match the approved robot', () => {
  const approved = {16: "eb121a06918fca2e2b0575e39e29fbafce80bab11eb8b563cf45bb32492c4df8", 256: "65dc4dd6f9cd37427d3edca721342f47bf281017110dc0944f4354b57e1d6613"};
  for (const [size, hash] of Object.entries(approved)) {
    const image = fs.readFileSync(path.join(root, `assets/icon${size}.png`));
    assert.equal(image.readUInt32BE(16), Number(size));
    assert.equal(image.readUInt32BE(20), Number(size));
    assert.equal(createHash('sha256').update(image).digest('hex'), hash);
  }
});
