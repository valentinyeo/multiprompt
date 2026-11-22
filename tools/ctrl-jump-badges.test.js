const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.existsSync(path.join(root, file)) ? fs.readFileSync(path.join(root, file), 'utf8') : '';
const between = (text, start, end) => {
  const a = text.indexOf(start);
  const b = text.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `missing ${start}`);
  return text.slice(a, b);
};

test('Ctrl state machine shows on Ctrl alone and hides on release, other keys, Alt and focus loss', () => {
  const machine = read('src/jump_badges.zig');
  assert.match(machine, /pub fn classify\(vk: u32, scan: u32, down: bool\) \?Key/, 'jump badge keys need one classifier');
  assert.match(machine, /if \(vk >= 0x31 and vk <= 0x39\) return \.digit_down;/, 'digits 1 to 9 keep the badges');
  assert.match(machine, /if \(vk == 0xA2 and \(scan & 0x200\) != 0\) return if \(down\) \.alt_down/, 'the AltGr Ctrl never shows badges');
  assert.match(machine, /\.ctrl_up, \.focus_lost => \.\{\}/, 'Ctrl release and focus loss clear the state');
  assert.match(machine, /\.alt_down, \.other_down => \.\{ \.ctrl_held = current\.ctrl_held, \.shown = false \}/, 'other keys and Alt hide the badges');
  for (const name of ['ctrl down shows badges and ctrl up hides them', 'non digit chord hides badges until ctrl is pressed again', 'altgr never shows badges', 'focus loss hides badges']) {
    assert.match(machine, new RegExp(`test "${name}"`), name);
  }
  const build = read('build.zig');
  assert.match(build, /root_source_file = b\.path\("src\/jump_badges\.zig"\)/, 'Windows CI runs the state machine tests');
  assert.match(build, /"tools\/ctrl-jump-badges\.test\.js"/);
});

test('keyboard hook feeds every key event to the badge state before any early return', () => {
  const shortcuts = read('src/shortcuts.zig');
  const hook = between(shortcuts, 'pub fn keyboardHookProc(', 'if (app_state.g_account_locked) return');
  assert.match(hook, /if \(nCode == HC_ACTION\) noteJumpBadgeKey\(wp, lp\);/, 'WM_KEYDOWN and WM_KEYUP must reach the badge state before the hook can return');
  const note = between(shortcuts, 'fn noteJumpBadgeKey(', 'pub fn keyboardHookProc(');
  assert.match(note, /wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN/);
  assert.match(note, /wp != WM_KEYUP and wp != WM_SYSKEYUP/);
  assert.match(note, /key == \.ctrl_down and !app_state\.g_account_locked and foregroundIsOurs\(\)/, 'only Ctrl over Multiprompt shows the badges');
  const main = read('src/main.zig');
  assert.match(between(main, 'WM_ACTIVATEAPP => {', 'return DefWindowProcW'), /applyJumpBadgeKey\(\.focus_lost, false, false\)/, 'leaving the window hides the badges');
});

test('sidebar paint draws a jump badge on each avatar while Ctrl is held, numbered like Ctrl+1..9', () => {
  const sidebar = read('src/sidebar.zig');
  const console = read('src/console.zig');
  assert.match(between(console, 'pub fn nthVisibleShell(', '\n}'), /if \(row\.kind != \.tab and row\.kind != \.inbox\) continue;/, 'Ctrl+1..9 counts session and inbox rows');
  assert.match(between(sidebar, 'pub fn isJumpRow(', '\n}'), /return row\.kind == \.tab or row\.kind == \.inbox;/, 'the badges count the same rows as Ctrl+1..9');
  const paint = between(sidebar, 'pub fn paintSidebar(', 'const content_end_logical:');
  const loop = between(paint, 'for (0..row_count) |ri| {', 'RectVisible(hdc, &row_rc)');
  assert.match(paint, /const show_jump_badges = jumpBadgesVisible\(\);/);
  assert.match(loop, /if \(isJumpRow\(row\)\) jump_slot \+= 1;/, 'numbering must count rows scrolled out of view');
  assert.match(loop, /show_jump_badges and isJumpRow\(row\) and jump_slot <= 9/);
  assert.equal((paint.match(/drawJumpBadge\(hdc, rowAvatarRect\(row, column, y\), digit\)/g) || []).length, 2, 'pinned tiles and expanded or collapsed rows draw the badge');
  assert.match(between(sidebar, 'fn jumpBadgesVisible(', '\n}'), /jump_badges\.zig"\)\.state\.shown and @import\("focus\.zig"\)\.isCtrlDown\(\)/);
  for (const painter of ['fn paintChatSidebarRow(', 'fn paintPinnedBot(']) {
    assert.doesNotMatch(between(sidebar, painter, '\n}'), /const size = uiScaled/, `${painter} uses the shared avatar rect`);
  }
});

test('toggling the badges repaints only the badge rects', () => {
  const sidebar = read('src/sidebar.zig');
  const apply = between(sidebar, 'pub fn applyJumpBadgeKey(', '\n}');
  assert.match(apply, /if \(jump_badges\.state\.shown != was\) invalidateJumpBadges\(\);/);
  const invalidate = between(sidebar, 'fn invalidateJumpBadges(', '\n}');
  assert.match(invalidate, /jumpBadgeRect\(rowAvatarRect\(row, column, row\.y - app_state\.g_sidebar_scroll\)\)/);
  assert.match(invalidate, /InvalidateRect\(app_state\.g_main_hwnd, &rc, 0\)/);
  assert.doesNotMatch(invalidate, /InvalidateRect\([^,]+, null|invalidateSidebar\(/, 'no full sidebar or window repaint');
});

test('shortcut docs say pressing Ctrl shows the numbers', () => {
  const docs = read('openwiki/operations/keyboard-shortcuts.md');
  assert.match(docs, /- Ctrl\+1-9: Switch to tab 1-9\. Pressing Ctrl shows the numbers 1 to 9/);
  assert.match(read('src/shortcuts.zig'), /\.a = "Ctrl\+1 \.\.\. 9", \.b = "Open session 1-9 in this workspace, pinned first"/);
});
