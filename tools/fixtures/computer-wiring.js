const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

module.exports = function assertComputerWiring(assert) {
  const pane = read('src/computer_pane.zig');
  const shortcuts = read('src/shortcuts.zig');
  const embedded = [...pane.matchAll(/@embedFile\("([^"]+)"\)/g)].map(match => match[1]);
  assert.ok(embedded.length > 0, 'the viewer page is embedded');
  for (const name of embedded) assert.ok(fs.existsSync(path.join(root, 'src', name)), `embedded ${name} lives under src so harness copies carry it`);
  assert.match(shortcuts, /pub fn releaseComputerKeys\(\)/, 'losing control releases the keys Computer held');
  assert.match(pane, /releaseComputerKeys\(\)/, 'revoking control releases those keys');
};
