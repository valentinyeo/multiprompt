const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

const palette = () => read('src/sidebar.zig').split('if (app_state.g_search_active) {')[1].split('if (app_state.g_shortcuts_active)')[0];

test('IGSH-1061: palette paints the approved neutral card, not blue selection or memory tags', () => {
  const paint = palette();
  assert.match(paint, /RGB\(0x35, 0x35, 0x35\)/);
  assert.match(paint, /RGB\(0x18, 0x18, 0x18\)/);
  assert.match(paint, /RECENT SESSIONS/);
  assert.match(paint, /Search sessions and commands/);
  assert.match(paint, /fillRoundRect\(hdc, sel_rc, uiScaled\(20\)/);
  assert.doesNotMatch(paint, /(?:shells\[shell_idx\]|sess)\.ram_mb/);
  assert.match(paint, /workspaceDisplayName\(app_state\.shells\[shell_idx\]\.workspace/);
});

test('IGSH-1061: pointer, wheel, reorder and paint share the new palette geometry', () => {
  const drawing = read('src/drawing.zig');
  assert.match(drawing, /pub fn searchRowH\(\) i32 \{\s*return uiScaled\(40\)/);
  assert.match(drawing, /pub fn searchOverlayW\(\) i32 \{\s*return uiScaled\(560\)/);
  assert.match(drawing, /pub fn searchOverlayOy[\s\S]*?uiScaled\(120\)/);
  assert.match(drawing, /const oy = searchOverlayOy\(win_h, overlay_h\)/);
  const main = read('src/main.zig');
  for (const prefix of ['click', 'wheel', 'drag']) assert.match(main, new RegExp(`const ${prefix}_oy = searchOverlayOy\\(${prefix}_win_h, ${prefix}_oh\\)`));
  assert.match(palette(), /searchOverlayOy\(win_h, overlay_h\)/);
});

test('IGSH-1061: native messages share the custom dialog and preserve confirmation results', () => {
  assert.match(read('src/fonts.zig'), /return @import\("dialog.zig"\)\.messageBox\(hwnd, text, caption, flags\)/);
  const dialog = read('src/dialog.zig');
  assert.doesNotMatch(dialog, /w\.MessageBoxW/);
  assert.match(dialog, /0x181818/);
  assert.match(dialog, /state\.px\(440\)/);
  assert.match(dialog, /state\.px\(40\)/);
  assert.match(dialog, /0x828bf2/);
  assert.match(dialog, /pixel\.\* >> 1/);
  assert.match(dialog, /if \(enabled\) _ = EnableWindow\(owner, 0\)/);
  assert.match(dialog, /EnableWindow\(owner, 1\)/);
  assert.match(dialog, /0x1b => self\.result = closeResult/);
  assert.match(dialog, /button\.result == 2/);
  const account = read('src/account_desktop.zig');
  for (const label of ['Later', 'Use recovery key', 'Enter passphrase', 'Remove']) assert.ok(account.includes(`L("${label}")`), label);
  assert.match(account, /\.label = L\("Remove"\), \.result = 6, \.destructive = true/);
  assert.match(read('src/reminders.zig'), /\.label = L\("Snooze"\), \.result = 1/);
});

test('IGSH-1061: static labels and shortcut hints use the formatter, not user session names', () => {
  const paint = palette();
  assert.match(paint, /paletteDrawText/);
  assert.match(paint, /DrawTextW\(hdc, @ptrCast\(&app_state\.shells\[shell_idx\]\.name\)/);
  const formatter = read('src/palette_text.zig');
  assert.match(formatter, /pub fn sentence/);
  assert.match(formatter, /pub fn keycap/);
  assert.match(formatter, /L\("Ctrl"\)/);
  assert.match(formatter, /L\("Shift"\)/);
});
