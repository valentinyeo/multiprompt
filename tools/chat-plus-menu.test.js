const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const exists = file => fs.existsSync(path.join(root, file));
const read = file => (exists(file) ? fs.readFileSync(path.join(root, file), 'utf8') : '');

test('IGSH-1521 the plus menu source exists and holds model, effort and permission level', () => {
  assert.ok(exists('src/plus_menu.zig'), 'src/plus_menu.zig exists');
  const plus = read('src/plus_menu.zig');
  for (const title of ['"Model"', '"Effort"', '"Permission level"']) assert.ok(plus.includes(title), title);
  for (const name of ['attach', 'model_opus', 'model_sonnet', 'model_haiku', 'effort_low', 'effort_medium', 'effort_high', 'mode_ask', 'mode_edits', 'mode_plan', 'mode_bypass']) {
    assert.match(plus, new RegExp(`\\b${name}\\b`), name);
  }
  assert.match(plus, /std\.mem\.eql\(u8, identity\.provider\(\), "claude"\)/);
  assert.match(plus, /chatModePickerAvailable\(\)/);
  assert.match(plus, /chatSettingsEligible\(\)/);
});

test('IGSH-1521 the plus button opens the menu instead of attaching directly', () => {
  const main = read('src/main.zig');
  assert.match(main, /4 => plus_menu\.open\(\)/);
  assert.doesNotMatch(main, /4 => _ = PostMessageW\(hwnd, WM_APP_CHAT_ATTACH/);
  assert.match(main, /WM_APP_PLUS_MENU_ACTION =>/);
  assert.match(main, /\.attach => _ = PostMessageW\(hwnd, WM_APP_CHAT_ATTACH/);
  assert.match(main, /plus_menu\.close\(\)/);
  assert.match(read('src/chat_composer.zig'), /plus_menu\.zig"\)\.key\(wp\)/);
});

test('IGSH-1521 the message box carries no model or effort text', () => {
  const layout = read('src/window_layout.zig');
  assert.doesNotMatch(layout, /chatSettingsEligible/);
  assert.doesNotMatch(layout, /"Default"/);
  assert.doesNotMatch(layout, / · Next/);
  const composer = read('src/chat_composer.zig');
  assert.doesNotMatch(composer, /settings_h/);
  assert.doesNotMatch(composer, /chatSettingsEligible/);
});

test('IGSH-1521 bypass is a permission mode and the palette opens the plus menu', () => {
  assert.match(read('src/chat_slash.zig'), /bypassPermissions/);
  assert.match(read('src/app_state.zig'), /pub const SEARCH_CHAT_MODE_BYPASS_OFFSET: usize/);
  assert.match(read('src/app_state.zig'), /pub const SEARCH_CHAT_PLUS_MENU_OFFSET: usize/);
  assert.ok(read('src/command_palette.zig').includes('Chat View: Plus Menu'));
  assert.ok(read('src/sidebar.zig').includes('L("Chat View: Plus Menu")'));
  assert.match(read('src/main.zig'), /target == app_state\.SEARCH_CHAT_PLUS_MENU_OFFSET/);
});

test('IGSH-1521 the shortcut table and the keyboard doc list the plus menu', () => {
  for (const file of ['src/shortcuts.zig', 'openwiki/operations/keyboard-shortcuts.md']) {
    assert.ok(read(file).includes('Chat View: Plus Menu'), file);
  }
});
