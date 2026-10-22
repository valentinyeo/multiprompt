const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = process.env.IGSH_573_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const browser = read('src/browser_pane.zig');

function fn(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `Missing production function ${name}`);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, `Missing end of ${name}`);
  return source.slice(start, end + 2);
}

test('ISSUE-573 session link routing uses the Windows default browser only with the pane off and mode on', () => {
  const route = fn(browser, 'openSessionLink');
  assert.match(route, /if \(idx >= app_state\.shell_count\) return false;/);
  assert.match(route, /app_state\.g_external_browser_links and !app_state\.shells\[idx\]\.browser_enabled and !webView2OwnsShell\(idx\)/);
  assert.match(route, /std\.ascii\.startsWithIgnoreCase\(url, "http:\/\/"\) or std\.ascii\.startsWithIgnoreCase\(url, "https:\/\/"\)/);
  assert.match(route, /std\.unicode\.utf8ToUtf16LeAllocZ\(std\.heap\.page_allocator, url\)/);
  assert.match(route, /defer std\.heap\.page_allocator\.free\(wide\);/);
  assert.match(route, /ShellExecuteW\(null, L\("open"\), wide\.ptr, null, null, SW_SHOW\);\s*return false;/);
  assert.match(route, /navigateBrowserPaneWithActivation\(idx, url, true\);\s*return true;/);
  assert.match(browser, /const ShellExecuteW = @import\("win32.zig"\)\.ShellExecuteW;/);
  assert.doesNotMatch(route, /browser_enabled\s*=|launchBrowserForShell|normalizeBrowserUrl|SetTimer|Sleep/);
  assert.doesNotMatch(fn(browser, 'navigateBrowserPaneWithActivation'), /openSessionLink|g_external_browser_links|ShellExecuteW/);
});

test('ISSUE-573 terminal, Chat View, image, picker and dashboard links share the routing decision', () => {
  const chat = read('src/chat_render.zig');
  const clipboard = read('src/clipboard.zig');
  const main = read('src/main.zig');
  assert.match(fn(clipboard, 'openUrlAtScreenPoint'), /openClickedLink\(final_buf\[0\.\.m\]\);/);
  const handler = fn(chat, 'chatTranscriptWndProc');
  for (const message of ['WM_LBUTTONDOWN', 'WM_LBUTTONDBLCLK']) {
    const start = handler.indexOf(`${message} => {`);
    assert.ok(start >= 0);
    const click = handler.slice(start, handler.indexOf('\n        },', start));
    assert.match(click, /chatOpenUrlBytes\(image_url\)/);
    assert.match(click, /openClickedLink\(app_state\.g_chat_capture\[link\.start\.\.link\.end\]\)/);
  }
  for (const [source, name] of [[chat, 'openClickedLink'], [chat, 'chatOpenUrlBytes'], [clipboard, 'openUrlByIndex']]) {
    const click = fn(source, name);
    assert.match(click, /if \(!openSessionLink\(app_state\.active_shell, [^\n]+\)\) return;/);
    assert.ok(click.indexOf('openSessionLink(') < click.indexOf('requestWebView2Focus('));
    assert.match(click, /requestNativeBrowserFocus\(\)/);
    assert.doesNotMatch(click, /navigateBrowserPaneWithActivation|ShellExecuteW/);
  }
  assert.match(main, /_ = openSessionLink\(app_state\.active_shell, app_state\.g_ai_pace\.ladder_dashboard\[0\.\.app_state\.g_ai_pace\.ladder_dashboard_len\]\);/);
  for (const source of [chat, clipboard, main]) assert.doesNotMatch(source, /navigateBrowserPaneWithActivation\(/);
});

test('ISSUE-573 both terminal mouse hooks allow pane-off clicks only when the mode is on', () => {
  const shortcuts = read('src/shortcuts.zig');
  const focus = fn(read('src/focus.zig'), 'wantMouseHookForUrlClicks');
  assert.match(focus, /browser_enabled or webView2OwnsActiveShell\(\) or app_state\.g_external_browser_links/);
  assert.match(focus, /isCtrlDown\(\)/);
  for (const name of ['ctrlClickOverActiveShell', 'mouseHookProc']) {
    assert.match(fn(shortcuts, name), /!app_state\.shells\[app_state\.active_shell\]\.browser_enabled and !webView2OwnsActiveShell\(\) and !app_state\.g_external_browser_links/);
  }
  assert.match(fn(shortcuts, 'staleAltMouseHookProc'), /physical_ctrl_down and\s*ctrlClickOverActiveShell\(ms\.pt\)/);
});

test('ISSUE-573 default-on mode is persisted like neighbouring toggles and exposed on all required surfaces', () => {
  const state = read('src/app_state.zig');
  const session = read('src/session.zig');
  const main = read('src/main.zig');
  const palette = read('src/command_palette.zig');
  const sidebar = read('src/sidebar.zig');
  const offset = 'SEARCH_EXTERNAL_BROWSER_LINKS_OFFSET';
  const label = 'External Browser Links When Pane Off';
  assert.match(state, /pub var g_external_browser_links: bool = true;/);
  assert.match(session, /if \(!app_state\.g_external_browser_links and pos \+ 36 < json_buf\.len\) \{\s*const setting = ",\\"external_browser_links\\":false";\s*@memcpy\(json_buf\[pos \.\. pos \+ setting\.len\], setting\);\s*pos \+= setting\.len;/);
  assert.match(session, /app_state\.g_external_browser_links = !json_reader\.boolFalse\(json, "external_browser_links"\);/);
  const start = main.indexOf(`if (target == ${offset}) {`);
  assert.ok(start >= 0);
  const toggle = main.slice(start, main.indexOf('\n                }', start));
  assert.match(toggle, /app_state\.g_external_browser_links = !app_state\.g_external_browser_links;/);
  assert.match(toggle, /saveSession\(\)/);
  assert.match(toggle, /syncMouseHookForUrlClicks\(\)/);
  assert.ok(palette.includes(`= ${offset};`));
  assert.ok(palette.includes(`"${label}"`));
  assert.ok(palette.includes(`${offset} => "external browser links when pane off"`));
  assert.ok(sidebar.includes(`result_idx == ${offset}`));
  assert.match(sidebar, /else if \(is_external_browser_links\)/);
  assert.ok(sidebar.includes(`L("${label}")`));
  for (const name of ['is_newwin', 'is_new_shell', 'is_tmux_inactive']) {
    assert.ok(sidebar.match(new RegExp(`const ${name} = ([^;]+);`))[1].includes('!is_external_browser_links'));
  }
  assert.ok(read('src/shortcuts.zig').includes(`.{ .a = "Ctrl+K -> ${label}", .b = "Toggle desktop browser for HTTP(S) links when the session pane is off (default on)", .header = false }`));
  assert.ok(read('openwiki/operations/keyboard-shortcuts.md').includes(`Ctrl+K -&gt; ${label}`));
  for (const file of ['external-browser-links.test.js', 'external-browser-links-native.test.js']) {
    assert.ok(read('build.zig').includes(`"tools/${file}"`));
  }
});
