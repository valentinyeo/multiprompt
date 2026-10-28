const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const exists = file => fs.existsSync(path.join(__dirname, '..', file));

function fn(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `missing fn ${name}`);
  const next = source.slice(start + 1).search(/\n(?:pub )?fn /);
  return source.slice(start, next === -1 ? undefined : start + 1 + next);
}

test('IGSH-992 key routing is a pure function covered by Zig unit tests in the Windows suite', () => {
  assert.ok(exists('src/chat_keynav.zig'), 'src/chat_keynav.zig is missing');
  const logic = read('src/chat_keynav.zig');
  assert.match(logic, /pub fn action\(/);
  assert.match(logic, /pub fn step\(/);
  assert.match(logic, /test "IGSH-992 Up in an empty box starts message focus/);
  assert.match(logic, /test "IGSH-992 Enter in the box still sends/);
  assert.match(read('build.zig'), /"src\/chat_keynav\.zig"/);
});

test('IGSH-992 the composer routes Up Down Enter Esc to message focus without costing a send', () => {
  const composer = read('src/chat_composer.zig');
  const sub = fn(composer, 'chatComposerSubclassProc');
  assert.match(sub, /chat_keynav\.action\(/);
  assert.match(sub, /chatNavKey\(nav_action\)/);
  assert.match(sub, /GetWindowTextLengthW\(hwnd\) == 0/);
  assert.match(sub, /g_chat_ac\.open/);
  assert.match(sub, /nav_action == \.open\) dropPendingEnterChar\(hwnd\)/, 'Enter must drop its own WM_CHAR so the quote is not sent');
  assert.match(fn(composer, 'dropPendingEnterChar'), /PeekMessageW\(&pending, hwnd, 0x0102, 0x0102, 1\)/);
  assert.match(sub, /g_chat_nav_active and \(msg == 0x0201 or msg == 0x0102[^]*chatNavClear\(\)/, 'typing, pasting and clicking return to the box');
});

test('IGSH-992 Enter opens the same menu as right-click through one shared function', () => {
  const render = read('src/chat_render.zig');
  assert.match(render, /WM_RBUTTONDOWN => \{\s*if \(app_state\.g_chat_find_open[^]*?return chatMessageMenu\(hwnd, msg, wp, lp, null\);/);
  const menu = fn(render, 'chatMessageMenu');
  assert.match(menu, /TrackPopupMenu\(/);
  assert.match(menu, /chatContextMenuItems\(/);
  assert.match(menu, /selectChatReply\(/);
  assert.match(menu, /keyboard_block/);
  const nav = fn(render, 'chatNavKey');
  assert.match(nav, /chatMessageMenu\(hwnd, WM_KEYDOWN, 0x0D, lp, index\)/);
});

test('IGSH-992 focus skips tool rows, scrolls into view and draws a ring with no status text', () => {
  const render = read('src/chat_render.zig');
  assert.match(fn(render, 'chatNavEligible'), /role != \.tool/);
  assert.match(fn(render, 'chatNavFocus'), /chatNavReveal\(index\)/);
  assert.match(fn(render, 'chatNavReveal'), /chatScrollBy\(/);
  const ring = fn(render, 'chatPaintNavRing');
  assert.match(ring, /customColorOr\("accent"/);
  assert.doesNotMatch(ring, /DrawText|chatDrawText/);
  assert.match(render, /nav_index != null and nav_index\.\? == i\) chatPaintNavRing\(/);
  assert.match(fn(render, 'chatNavIndex'), /g_chat_nav_shell_id/, 'focus is dropped lazily when the conversation changes');
});

test('IGSH-992 shortcut, Ctrl+K entry and doc row ship together', () => {
  assert.match(read('src/shortcuts.zig'), /\.a = "Up \/ Down \/ Enter in Chat View"/);
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /Up \/ Down \/ Enter in Chat View/);
  assert.match(read('src/command_palette.zig'), /SEARCH_CHAT_FOCUS_MESSAGES_OFFSET/);
  assert.match(read('src/sidebar.zig'), /Chat View: Focus Messages/);
  assert.match(read('src/main.zig'), /SEARCH_CHAT_FOCUS_MESSAGES_OFFSET[^]*chatNavStart\(\)/);
  assert.match(read('src/sidebar.zig'), /is_chat_focus_messages/);
});

test('IGSH-990 focused source survives native text-length queries without recursive messages', () => {
  const sub = fn(read('src/chat_composer.zig'), 'chatComposerSubclassProc');
  const expression = sub.match(/if \((app_state\.g_chat_nav_active[^\n]+)\) @import\("chat_render\.zig"\)\.chatNavClear\(\);/)[1]
    .replace(/\band\b/g, '&&').replace(/\bor\b/g, '||');
  const shouldClear = new Function('app_state', 'msg', 'hwnd', 'GetWindowTextLengthW', 'CallWindowProcW', `return ${expression};`);
  for (const length of [0, 3]) {
    const state = { g_chat_nav_active: true, g_chat_composer_orig_proc: 7 };
    let depth = 0;
    let queries = 0;
    const original = (procedure, hwnd, message, wp, lp) => {
      assert.deepEqual([procedure, hwnd, message, wp, lp], [7, 1, 0x000E, 0, 0]);
      queries++;
      return length;
    };
    const dispatch = message => {
      assert.ok(++depth <= 8, 'text-length query recursively reentered the composer');
      try {
        const clear = shouldClear(state, message, 1, () => dispatch(0x000E), original);
        if (clear) state.g_chat_nav_active = false;
        return length;
      } finally { depth--; }
    };
    dispatch(0x000E);
    assert.equal(state.g_chat_nav_active, length === 0);
    assert.equal(queries, 1);
    state.g_chat_nav_active = true;
    queries = 0;
    dispatch(0x0201);
    assert.equal(state.g_chat_nav_active, false, 'clicking returns focus to the composer');
    assert.equal(queries, 0);
  }
});
