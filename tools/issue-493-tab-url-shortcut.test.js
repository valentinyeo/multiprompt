const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const shortcuts = read('src/shortcuts.zig');
const render = read('src/chat_render.zig');
const browser = read('src/browser_pane.zig');
const main = read('src/main.zig');
const state = read('src/app_state.zig');

function section(source, start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first, `missing source section: ${start}`);
  return source.slice(first, last);
}

test('ISSUE-493 Ctrl+Shift+X reaches Chat View and browser focus once per press', () => {
  const hook = section(shortcuts, 'pub fn keyboardHookProc(', '\nfn pointOverActiveShell');
  const chord = hook.match(/if \(\(wp == WM_KEYDOWN or wp == WM_SYSKEYDOWN\) and !app_state\.g_win_held and\s*kb\.vkCode == 0x58[^]*?\n        \}/);
  assert.ok(chord, 'Ctrl+Shift+X must have an early hook route');
  assert.match(chord[0], /isCtrlDown\(\) and !isAltDown\(kb\.flags\)/);
  assert.match(chord[0], /GetAsyncKeyState\(0x10\)[^]*?!= 0 and foregroundIsOurs\(\)/);
  assert.match(chord[0], /claimBrowserFocusPress\(true, &app_state\.g_tab_url_chord_held\)[^]*?PostMessageW\(app_state\.g_main_hwnd, WM_APP_CHAT_TAB_URL, 0, 0\);\s*return 1;/);
  for (const route of ['if (app_state.g_browser_focus_mode and activeBrowserSurfaceHasForegroundFocus())', 'if (chatViewOwnsInput() and chatComposerOwnsKey(']) {
    assert.ok(hook.indexOf(route) > chord.index, `URL shortcut must precede ${route}`);
  }
  assert.match(hook, /kb\.vkCode == 0x58 and \(wp == WM_KEYUP or wp == WM_SYSKEYUP\) and app_state\.g_tab_url_chord_held\) \{\s*_ = claimBrowserFocusPress\(false, &app_state\.g_tab_url_chord_held\);\s*return 1;/);
  assert.match(state, /pub var g_tab_url_chord_held: bool = false;/);
  assert.match(read('src/focus.zig'), /app_state\.g_tab_url_chord_held = false;/);
  assert.match(main, /const WM_APP_CHAT_TAB_URL = @import\("win32.zig"\)\.WM_APP_CHAT_TAB_URL;/);
  assert.match(main, /WM_APP_CHAT_TAB_URL => \{\s*@import\("chat_render.zig"\)\.chatInsertBrowserTabUrl\(\);\s*return 0;/);
});

test('ISSUE-493 current pane URL precedes the remembered browser tab URL', () => {
  const resolve = section(browser, 'pub fn browserTabUrlForChat()', '\nfn browserUrlDisplaySlice(');
  assert.match(resolve, /const idx = app_state\.active_shell;/);
  assert.match(resolve, /shells\[idx\]\.browser_enabled or webView2OwnsActiveShell\(\)/);
  assert.match(resolve, /if \(url\.len > 0 and std\.mem\.indexOf\(u8, url, "ZSPANE"\) == null\) return url;/);
  assert.ok(resolve.indexOf('return url;') < resolve.indexOf('return app_state.g_last_browser_tab_url['));
  assert.match(resolve, /shells\[i\]\.last_active > app_state\.shells\[recent\.\?\]\.last_active/);
  assert.match(resolve, /return null;/);
  const remember = section(browser, 'pub fn rememberActiveBrowserTabUrl()', '\npub fn browserTabUrlForChat()');
  assert.match(remember, /!app_state\.shells\[idx\]\.browser_enabled and !webView2OwnsActiveShell\(\)/);
  assert.match(remember, /url\.len == 0 or std\.mem\.indexOf\(u8, url, "ZSPANE"\) != null/);
  assert.match(remember, /@memcpy\(app_state\.g_last_browser_tab_url\[0\.\.url\.len\], url\);/);
  const switching = section(read('src/console.zig'), 'pub fn switchToShell(idx:', '\n    app_state.active_shell = idx;');
  assert.match(switching, /@import\("browser_pane.zig"\)\.rememberActiveBrowserTabUrl\(\);/);
  assert.match(section(browser, 'pub fn updateBrowserVisibility()', '\n    if (webView2OwnsActiveShell())'), /rememberActiveBrowserTabUrl\(\);/);
  assert.match(section(main, 'WM_APP_BROWSER_URL_UPDATE => {', '\n        WM_APP_SHELL_EXITED'), /if \(ti == app_state\.active_shell\) \{\s*@import\("browser_pane.zig"\)\.rememberActiveBrowserTabUrl\(\);/);
});

test('ISSUE-493 URL insertion reuses the caret and menu-safe focus handoff without sending', () => {
  const insert = section(render, 'pub fn chatInsertBrowserTabUrl()', '\npub fn requestShotFocus(');
  assert.match(insert, /browserTabUrlForChat\(\) orelse \{\s*showHeaderNoticeAscii\("No browser tab URL available", 2000, false\);\s*return;/);
  assert.ok(insert.indexOf('browserTabUrlForChat()') < insert.indexOf('openChatView()'));
  assert.match(insert, /std\.unicode\.utf8ToUtf16Le\(&wide, url\) catch return/);
  assert.match(insert, /if \(!app_state\.g_chat_active\) @import\("chat_composer.zig"\)\.openChatView\(\);\s*if \(!app_state\.g_chat_active\) return;/);
  assert.match(insert, /if \(chatComposerInsertAtCaret\(wide\[0\.\.len\]\)\) \|caret\| requestShotFocus\(app_state\.active_shell, caret\);/);
  assert.doesNotMatch(insert, /chatSend|WM_APP_CHAT_SEND|pasteTextToShell|queueShotPaste|keybd_event|SetWindowTextW/);
  const caret = section(render, 'pub fn chatComposerInsertAtCaret(', '\npub fn chatInsertBrowserTabUrl(');
  assert.match(caret, /0x00B0[^]*?chat_image_insert\.plan\([^]*?0x00C2[^]*?0x00B1, insert\.caret, @intCast\(insert\.caret\)/);
  const plan = read('src/chat_image_insert.zig');
  assert.match(plan, /out\[len - 1\] = ' ';/);
  assert.match(plan, /\.caret = start \+ len/);
  const focus = section(render, 'pub fn shotFocusTick()', '\npub fn paintChatAttachButton(');
  assert.match(focus, /waiting for screenshot modifiers to release/);
  assert.deepEqual([...focus.matchAll(/keybd_event\(([^)]*)\);/g)].map(match => match[1]), [
    'VK_MENU, 0, 0, 0', '0xFF, 0, 0, 0', '0xFF, 0, KEYEVENTF_KEYUP, 0', 'VK_MENU, 0, KEYEVENTF_KEYUP, 0',
  ]);
  assert.match(focus, /SetFocus\(target\)/);
  assert.match(focus, /0x00B1, caret, @intCast\(caret\)/);
});

test('ISSUE-493 URL action has palette, tab context, shortcut documentation and CI wiring', () => {
  const palette = read('src/command_palette.zig');
  const sidebar = read('src/sidebar.zig');
  for (const id of ['SEARCH_CHAT_TAB_URL_OFFSET', 'SEARCH_TABCTX_CHAT_TAB_URL']) {
    assert.match(state, new RegExp(`pub const ${id}: usize = \\d+;`));
    assert.ok(palette.includes(`g_search_results[app_state.g_search_result_count] = ${id};`));
    assert.ok(sidebar.includes(`result_idx == ${id}`));
    assert.ok(main.includes(`target == ${id}`));
  }
  assert.match(main, /target == SEARCH_TABCTX_CHAT_TAB_URL\) findShellById\(app_state\.g_tabctx_sid\)/);
  assert.match(main, /if \(ti != app_state\.active_shell\) switchToShell\(ti\);\s*@import\("chat_render.zig"\)\.chatInsertBrowserTabUrl\(\);/);
  assert.match(sidebar, /const is_chat_action = is_chat_tab_url or/);
  assert.match(sidebar, /L\("Chat View: Insert browser tab URL"\)/);
  assert.match(sidebar, /L\("Ctrl\+Shift\+X"\)/);
  assert.match(shortcuts, /\.a = "Ctrl\+Shift\+X", \.b = "Insert current browser tab URL/);
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /\| Ctrl\+Shift\+X \| Insert current browser tab URL/);
  assert.match(read('build.zig'), /"node", "--test"[^\n]*"tools\/issue-493-tab-url-shortcut\.test\.js"/);
  const fragmentPath = path.join(__dirname, '..', 'changelog.d/IGSH-493-tab-url-shortcut.md');
  const changelog = fs.existsSync(fragmentPath) ? fs.readFileSync(fragmentPath, 'utf8') :
    (read('src/changelog.zig').match(/\.text = "([^"\n]+)", \.ticket = "IGSH-493"/)?.[1] || '') + '\n';
  assert.match(changelog, /^Ctrl\+Shift\+X inserts[^\n]+without sending\.\n$/);
});
