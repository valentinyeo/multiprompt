const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = process.env.UPDATE_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('release updater is default on and checks before session restoration', () => {
  const main = read('src/main.zig');
  assert.match(main, /if \(update_release\.startup\(\)\) return;/);
  const updater = read('src/update_release.zig');
  assert.match(updater, /pub const IGSH_246 = true;/);
  assert.ok(main.indexOf('update_release.startup()') < main.indexOf('const restored = restoreSession()'));
  assert.match(main, /update_release\.ready\(\)/);
  assert.match(read('src/update_card.zig'), /update_release\.poll\(\)/);
  assert.match(main, /_ = startUpdateCardWatch\(\);\s*_ = SetTimer\(hwnd, TIMER_UPDATE_CHECK/);
});

test('periodic update never invokes restart and explicit restart uses the verified helper', () => {
  const updater = read('src/update_release.zig');
  const poll = updater.slice(updater.indexOf('pub fn poll()'), updater.indexOf('pub fn restart('));
  assert.doesNotMatch(poll, /restart\(|"Apply"|quitAll/);
  assert.match(updater, /3 \* 60 \* 60 \* 1000/);
  assert.match(read('src/update_card.zig'), /update_release\.restart\(/);
  assert.match(read('src/sidebar.zig'), /Restart to update/);
  assert.match(read('src/update_card.zig'), /Update ready: restart to get v/);
});

test('Windows behavioral update tests are required by CI', () => {
  assert.match(read('.github/workflows/test.yml'), /powershell -NoProfile -File tools\/update-release\.test\.ps1/);
  const suite = read('tools/update-release.test.ps1');
  for (const name of ['checksum mismatch refused', 'rollback after failed start', 'no automatic restart while running', 'version comparison']) assert.ok(suite.includes(name), name);
});
