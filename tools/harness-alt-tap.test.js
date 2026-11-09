const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');

function files(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return entry.name === 'node_modules' ? [] : files(full);
    return /\.(cs|ps1)$/.test(entry.name) ? [full] : [];
  });
}

test('harness Alt taps never open the window menu of the app', () => {
  const bare = [];
  for (const file of files(path.join(root, 'tools'))) {
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    lines.forEach((line, i) => {
      if (!/keybd_event\(0x12, 0, 0,/.test(line)) return;
      if (!/keybd_event\(0xE8, 0, 0,/.test(lines[i + 1] || '') || !/keybd_event\(0xE8, 0, 2,/.test(lines[i + 2] || '')) {
        bare.push(`${path.relative(root, file)}:${i + 1}`);
      }
    });
  }
  assert.deepEqual(bare, [], 'an Alt press without a 0xE8 tap makes Windows enter the keyboard menu loop');
});
