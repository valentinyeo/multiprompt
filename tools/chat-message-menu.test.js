const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const read = file => fs.readFileSync(file, 'utf8');
const chat = read('src/chat_render.zig');
const fonts = read('src/fonts.zig');
const layout = read('src/window_layout.zig');
const control = read('.claude/skills/verify-multiprompt/control.ps1');

function menuModel(source) {
  const body = source.match(/fn chatContextMenuItems\([^]*?\n\}/)?.[0];
  assert.ok(body, 'pure menu item function exists');
  assert.doesNotMatch(body, /app_state|AppendMenu|debugLog/);
  const actions = body.match(/const actions = \[_\]\?Item\{ (.+) \};/)[1]
    .replace(/if \((\w+)\) \.(\w+) else null/g, '$1 ? "$2" : null')
    .replace(/\.copy\b/g, '"copy"');
  const copy = source.match(/fn chatContextCopyTarget\([^]*?return (.+);\n\}/)[1]
    .replace(/if \((\w+)\) \.(\w+) else /g, '$1 ? "$2" : ')
    .replace(/\.(\w+)$/g, '"$1"');
  const items = new Function('selected', 'message', 'reply', 'link', 'unsent', `return [${actions}].filter(item => item !== null)`);
  const target = new Function('selected', 'message', `return ${copy}`);
  return (...input) => ({ items: items(...input), target: target(...input) });
}

test('IGSH-718 production pure item expressions preserve ordering and selection priority', () => {
  const menu = menuModel(chat);
  assert.deepEqual(menu(false, true, true, false, false), { items: ['reply', 'copy'], target: 'message' });
  assert.deepEqual(menu(false, true, false, false, false).items, ['copy']);
  assert.equal(menu(true, true, true, false, false).target, 'selection');
  assert.equal(menu(true, false, false, false, false).target, 'selection');
  assert.deepEqual(menu(false, true, true, true, false).items, ['reply', 'copy', 'copy_link']);
  assert.deepEqual(menu(false, true, true, false, true).items, ['reply', 'copy', 'send_again', 'remove']);
  assert.deepEqual(menu(false, true, true, true, true).items, ['reply', 'copy', 'copy_link', 'send_again', 'remove']);
  assert.equal(menu(false, false, false, false, false).target, 'nothing');
  assert.throws(() => menuModel(chat.replace('fn chatContextMenuItems(', 'fn removedMenu(')));
});

test('IGSH-718 and IGSH-892 native popups share the chat bubble theme with icons, mnemonics and existing contextual actions', () => {
  const handler = chat.slice(chat.indexOf('        WM_RBUTTONDOWN => {'), chat.indexOf('        WM_MOUSEWHEEL, WM_MOUSEHWHEEL => {'));
  assert.doesNotMatch(handler, /Copy Message|Select All|2 => chatSelectAll|3 => chatCopyTextToClipboard/);
  assert.match(chat, /const TrackPopupMenu = @import\("fonts.zig"\).trackMessagePopupMenu/);
  assert.match(handler, /reply_text != null, link_text != null, unsent_actions/);
  assert.match(handler, /pendingActions\(app_state.g_chat_outbox.items\[ei\].state\).send_again/);
  assert.match(handler, /items.copy_target == .selection\) selection_text else message_text/);
  assert.match(handler, /debugLog\(menu_log\[0\.\.menu_log_len\]\)/);
  assert.match(handler, /\[chat\] message menu items=/);
  assert.match(fonts, /pub fn trackPopupMenu\([^]*?return trackThemedPopupMenu\(menu, flags, x, y, reserved, owner, rect, false\);/);
  assert.match(fonts, /pub fn trackMessagePopupMenu\([^]*?return trackThemedPopupMenu\(menu, flags, x, y, reserved, owner, rect, true\);/);
  assert.match(fonts, /chat_style.menuLook\(if \(bound\) \|theme\| theme.background\(\) else unboundBackground\(\)\)/);
  assert.match(read('src/main.zig'), /bindMenuTheme\(\.\{\s*\.background = &@import\("themes.zig"\).themeConsoleBg,\s*\.foreground = &@import\("themes.zig"\).themeConsoleFg,\s*\.fill_round_rect = &@import\("smooth.zig"\).fillRoundRect/);
  assert.match(fonts, /DWMWCP_ROUND/);
  assert.match(fonts, /mask: u32 = 2/);
  assert.match(fonts, /SetMenuInfo\(menu, &info\)[^]*?defer _ = SetMenuInfo\(menu, &MenuInfo\{ \.background = null \}\)/);
  assert.match(fonts, /theme.foreground\(\)/);
  assert.match(fonts, /previous_style = message_menu_style[^]*?defer message_menu_style = previous_style/);
  assert.match(fonts, /GetTextFaceW[^]*?Segoe Fluent Icons[^]*?Segoe MDL2 Assets/);
  for (const [item, glyph] of [['reply', 'E97A'], ['copy', 'E8C8'], ['copy_link', 'E71B'], ['send_again', 'E724'], ['remove', 'E74D']]) {
    assert.match(fonts, new RegExp(`\\.${item} => 0x${glyph}`));
  }
  assert.match(handler, /4 => if \(reply_text\) \|text\|[^]*?selectChatReply\(text\)/);
  assert.match(chat, /wp == 0x41\) \{\s*chatSelectAll\(\)/);
  assert.match(read('src/main.zig'), /menuChar\(wp\)/);
});

test('IGSH-718 enabled button backgrounds are neutral, hover is lighter, disabled colours and geometry remain', () => {
  const paint = layout.match(/fn paintChatButton\([^]*?\n\}/)?.[0];
  assert.ok(paint, 'send/stop button paint function exists');
  assert.match(paint, /const hover = glyph == .stop and app_state.g_chat_stop_hover/);
  const shades = paint.match(/if \(app_state.g_light_theme\) \(if \(hover\) (\d+) else (\d+)\) else \(if \(hover\) (\d+) else (\d+)\)/);
  assert.ok(shades);
  assert.deepEqual(shades.slice(1).map(Number), [128, 104, 84, 64]);
  assert.ok(Number(shades[1]) > Number(shades[2]));
  assert.ok(Number(shades[3]) > Number(shades[4]));
  assert.match(paint, /if \(enabled\) RGB\(grey, grey, grey\) else customColorOr\("overlay_input_bg", if \(app_state.g_light_theme\) RGB\(236, 238, 243\) else RGB\(38, 42, 52\)\)/);
  assert.match(paint, /RGB\(255, 255, 255\) else RGB\(235, 235, 235\)/);
  assert.doesNotMatch(paint, /selected_bg|const accent/);
  assert.match(paint, /drawRoundRect\(hdc, rc.left, rc.top, rc.right, rc.bottom, radius, radius\)/);
});

test('IGSH-718 journey requires real owned mouse input, exact new log, popup dismissal and screenshot pixel checks', () => {
  assert.match(control, /actualPid != pid \|\| Class\(hwnd\) != "ZigShellChatTranscript"/);
  assert.match(control, /GetForegroundWindow\(\) != owner \|\| WindowFromPoint\(point\) != hwnd/);
  assert.match(control, /MouseAt\(point.X, point.Y, 8\);\s*MouseAt\(point.X, point.Y, 16\)/);
  assert.match(control, /\$menuLines.Count -ne \$menuLinesBefore \+ 1/);
  assert.ok(control.includes("items=Reply,Copy$'"));
  assert.match(control, /Snapshot 'message-menu'\s*Press @\(0x1B\)/);
  assert.match(control, /\$menuLook = \[VerifyNative\]::MenuLook\(/);
  assert.match(control, /\$menuLook\.corner -eq \$menuLook\.fill\) \{ throw/);
  assert.match(control, /\$menuLook\.leftEdge -ne \$menuLook\.fill -or \$menuLook\.rightEdge -ne \$menuLook\.fill\) \{ throw/);
  assert.match(control, /class -eq '#32768' -and \$_.visible \}\).Count -eq 0/);
  for (const name of ['message-menu', 'grey-buttons']) assert.ok(control.includes(`name = '${name}'; passed = $false; reason = 'not reached'`));
  assert.match(control, /new System.Drawing.Bitmap\(image\)/);
  assert.match(control, /Math.Max\(c.R, Math.Max\(c.G, c.B\)\) - Math.Min\(c.R, Math.Min\(c.G, c.B\)\) > 12 \|\| c.ToArgb\(\) == bg.ToArgb\(\)/);
  assert.doesNotMatch(control, /grey-buttons-stop|\$greyCheck\.empty/);
  assert.equal((control.match(/\[VerifyNative\]::GreyButtonPixels\(/g) || []).length, 1);
  assert.match(control, /GreyButtonPixels\(\(Join-Path \$Evidence 'grey-buttons\.png'\), \$script:window, \$typed\.card, \$typed\.stop, \$typed\.send\)/);
  assert.match(control, /\$stopCheck\.reason = \$_\.Exception\.Message\s*throw\s*\}\s*try \{\s*\$greyCheck\.typed = \[VerifyNative\]::GreyButtonPixels/);
  assert.match(control, /Snapshot 'grey-buttons'/);
  assert.match(control, /\$menuCheck.reason = \$_.Exception.Message\s*throw/);
  assert.match(control, /\$greyCheck.reason = \$_.Exception.Message\s*throw/);
  const neutral = ([r, g, b], bg) => Math.max(r, g, b) - Math.min(r, g, b) <= 12 && [r, g, b].join() !== bg.join();
  assert.equal(neutral([64, 64, 64], [24, 24, 24]), true);
  assert.equal(neutral([125, 211, 252], [24, 24, 24]), false);
  assert.equal(neutral([54, 118, 232], [243, 243, 243]), false);
  assert.equal(neutral([24, 24, 24], [24, 24, 24]), false);
});
