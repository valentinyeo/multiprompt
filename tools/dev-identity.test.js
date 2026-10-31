const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('IGSH-1266 the dev build names itself Multibot DEV and the stable build keeps Multi Bot', () => {
  const startup = read('src/startup.zig');
  const title = startup.slice(startup.indexOf('pub fn buildWindowTitle'), startup.indexOf('pub fn buildWindowTitle') + 400);
  assert.match(title, /const title = if \(IS_DEV\) "Multibot DEV" else "Multi Bot";/, 'the window and taskbar title must name the build');
  assert.match(startup, /test "IGSH-1266 the dev build names itself in the title bar and taskbar"/);
});

test('IGSH-1266 the dev build never checks for, offers or downloads an update', () => {
  const card = read('src/update_card.zig');
  assert.match(card, /const IS_DEV = @import\("main\.zig"\)\.IS_DEV;/, 'the update card must know the build');
  const visible = card.slice(card.indexOf('pub fn updateCardVisible'), card.indexOf('pub fn updateCardVisible') + 260);
  assert.match(visible, /if \(IS_DEV\) return false;/, 'no update card in the dev build');
  const init = card.slice(card.indexOf('pub fn updateCardInit'), card.indexOf('pub fn updateCardInit') + 120);
  assert.match(init, /if \(IS_DEV\) return;/, 'the dev build must not even stamp the launch path for updates');
  const watch = card.slice(card.indexOf('pub fn startUpdateCardWatch'), card.indexOf('pub fn startUpdateCardWatch') + 120);
  assert.match(watch, /if \(IS_DEV\) return false;/, 'no update watcher thread in the dev build');

  const palette = read('src/command_palette.zig');
  assert.match(palette, /if \(show_update and !@import\("main\.zig"\)\.IS_DEV\) \{/, 'no restart-to-update row in the dev build');
});

test('IGSH-1266 the dev build shows a visible DEV badge in the sidebar header', () => {
  const source = read('src/workspace_switcher.zig');
  assert.match(source, /const IS_DEV = @import\("main\.zig"\)\.IS_DEV;/, 'the header must know the build');
  assert.match(source, /const shown = if \(IS_DEV\) \(std\.fmt\.bufPrint\(&dev_buf, "\{s\} DEV", \.\{name\}\) catch name\) else name;/, 'the workspace header carries the DEV badge');
  assert.match(source, /drawName\(dc, shown, &label/, 'the badge is what gets painted');
});
