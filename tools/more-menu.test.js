const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');
const menu = read('src/more_menu.zig');
const main = read('src/main.zig');
const drawing = read('src/drawing.zig');
const composer = read('src/chat_composer.zig');
const render = read('src/chat_render.zig');
const palette = read('src/command_palette.zig');
const verify = read('.github/workflows/verify.yml');

test('IGSH-1020 menu lists the Android items in the Android order with no submenus', () => {
  assert.match(menu, /enum\(usize\) \{ approve, stop, terminal, rename, computer, history, resync, waiting, remind, archive, model, end_session, remove, bot_face, bot_color \}/);
  assert.match(menu, /&\.\{ \.rename, \.computer, \.history, \.resync, \.bot_face, \.bot_color \}[\s\S]*&\.\{ \.waiting, \.remind, \.archive \}[\s\S]*&\.\{\.model\}[\s\S]*&\.\{ \.end_session, \.remove \}/);
  assert.match(menu, /RGB\(0x18, 0x18, 0x18\)[\s\S]*RGB\(0x2E, 0x2E, 0x2E\)[\s\S]*RGB\(0xF2, 0x8B, 0x82\)/);
  assert.match(menu, /uiScaled\(20\)/);
});

test('IGSH-1020 round button opens the menu and each item keeps its existing action', () => {
  assert.match(drawing, /more: RECT/);
  assert.match(main, /chatTitleLayout\(\)\) \|title\|[\s\S]*more_menu\.open\(\)/);
  for (const call of ['chatPermissionAnswer(shell, .allow)', 'chatStopAgent(shell)', 'WM_APP_CHAT_TOGGLE', 'beginPaletteRenameInput(shell)', 'AS_TAB_ARCHIVED', 'hideActiveTabUntilAttention()', 'WM_APP_REMIND_PRESETS_OPEN', 'archiveActiveTab()', 'endActiveTmuxSession()', 'closeNonTmuxTabAt(shell)']) {
    assert.ok(main.includes(call), call);
  }
});

test('IGSH-1020 keyboard, palette and screenshot proof are wired', () => {
  assert.match(composer, /more_menu\.zig"\)\.key\(wp\)/);
  assert.match(palette, /SEARCH_CHAT_MORE_MENU_OFFSET/);
  assert.match(render, /more_menu\.paint\(menu_dc/);
  assert.match(verify, /evidence\/chat-more-menu\.png/);
});

test('IGSH-1630 Computer reuses the captured chat identity without adding a header button', () => {
  assert.match(menu, /\.computer => @import\("ui_words\.zon"\)\.computer_title/);
  assert.match(menu, /state\.enabled\[@intFromEnum\(Item\.computer\)\] = tmux;/);
  assert.match(menu, /item == \.computer or item == \.bot_face or item == \.bot_color\) @intCast\(target_sid\)/);
  const action = main.slice(main.indexOf('if (wp == @intFromEnum(more_menu.Item.computer))'), main.indexOf('if (wp == @intFromEnum(more_menu.Item.bot_face)'));
  assert.match(action, /findShellById\(@intCast\(lp\)\) orelse return 0;[\s\S]*@import\("computer_pane\.zig"\)\.toggle\(target_idx\)/);
  const header = drawing.slice(drawing.indexOf('pub const ChatTitleLayout = struct'), drawing.indexOf('pub fn paintThreadTitle'));
  assert.doesNotMatch(header, /computer/i);
});

test('IGSH-1020 menu shows the model only inside the menu, never around messages', () => {
  assert.match(menu, /item == \.model and state\.model_len > 0/);
  assert.doesNotMatch(read('src/chat_render.zig').split('fn moreMenuProof')[0], /more_menu/);
});
