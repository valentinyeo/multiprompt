const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = process.env.BROWSER_CORNERS_ROOT || path.resolve(__dirname, '..');
const source = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
function body(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  const end = text.indexOf('\n}', start);
  assert.ok(end > start, `${name} closing brace`);
  return text.slice(start, end + 2);
}

const corners = ['top_left', 'top_right', 'bottom_left', 'bottom_right'];

test('IGSH-496 four corner windows belong to the existing mask lifecycle', () => {
  const state = source('app_state.zig');
  for (const corner of corners) assert.match(state, new RegExp(`\\b${corner}\\b`), `${corner} mask must exist`);
  assert.match(state, /BROWSER_EDGE_MASK_COUNT: usize = 10;/);
  const pane = source('browser_pane.zig');
  for (const name of ['ensureBrowserEdgeMaskWindows', 'hideBrowserEdgeMasks', 'raiseBrowserEdgeMasksZOrderOnly']) {
    assert.match(body(pane, name), /for \(0\.\.BROWSER_EDGE_MASK_COUNT\)/, name);
  }
  assert.match(body(source('main.zig'), 'wndProc'), /DestroyWindow\(mh\)/);
  const position = body(pane, 'positionBrowserEdgeMasks');
  for (const corner of corners) assert.ok(position.includes(`.${corner}`), corner);
  assert.match(position, /browser_corners\.rect\(browser, corner, paint\)/);
  assert.match(position, /moveBrowserEdgeMask\(side, rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top\)/);
  for (const guard of ['g_monitor_transition.active', 'activeBrowserEdgeMasksAllowed()', 'browserChromeHiddenForOverlay()', 'browserChromeForegroundAllowed()']) assert.ok(position.includes(guard), guard);
  assert.match(body(pane, 'positionActiveBrowser'), /positionBrowserEdgeMasks\(layout\)/);
});

test('IGSH-496 corners use premultiplied per-pixel alpha without input, focus or foreign regions', () => {
  const pane = source('browser_pane.zig');
  const ensure = body(pane, 'ensureBrowserEdgeMaskWindows');
  assert.match(ensure, /WS_EX_TOOLWINDOW \| WS_EX_NOACTIVATE \| WS_EX_TRANSPARENT/);
  assert.match(ensure, /side == \.control_hit or browserMaskCorner\(side\) != null\) ex_style \|= WS_EX_LAYERED/);
  assert.match(ensure, /if \(side == \.control_hit\) _ = SetLayeredWindowAttributes/);
  const upload = body(pane, 'updateBrowserCorner');
  for (const symbol of ['CreateDIBSection', 'CreateCompatibleDC', 'browser_corners.render', 'UpdateLayeredWindow', 'ULW_ALPHA']) assert.ok(upload.includes(symbol), symbol);
  assert.match(upload, /\.height = -height/);
  for (const symbol of ['DeleteObject(bitmap)', 'SelectObject(dc, old)', 'DeleteDC(dc)', 'ReleaseDC(null, screen)']) assert.ok(upload.includes(symbol), symbol);
  assert.doesNotMatch(upload, /SetWindowRgn|SetFocus|SetForegroundWindow|SetLayeredWindowAttributes/);
  assert.match(body(pane, 'browserEdgeMaskWndProc'), /WM_NCHITTEST[\s\S]*?HTTRANSPARENT/);
  const move = body(pane, 'moveBrowserEdgeMask');
  assert.match(move, /!std.meta.eql\(cached\.\?, paint\)/);
  assert.ok(move.indexOf('updateBrowserCorner(') < move.indexOf('SW_SHOWNOACTIVATE'));
  assert.match(move, /SWP_NOACTIVATE \| SWP_NOREDRAW/);
  assert.match(source('win32.zig'), /source_constant_alpha: u8 = 255, alpha_format: u8 = 1/);
});

test('IGSH-496 Chat View and browser share the scaled radius, border width and theme colors', () => {
  const layout = source('window_layout.zig');
  assert.match(body(layout, 'chatSurfaceRadius'), /uiScaled\(CHAT_BUBBLE_RADIUS\)/);
  assert.match(body(layout, 'chatSurfaceBorderW'), /@max\(1, uiScaled\(1\)\)/);
  assert.match(body(layout, 'chatSurfaceBorderColor'), /customColorOr\("overlay_border"/);
  assert.match(body(layout, 'paintChatView'), /card_border, chatSurfaceRadius\(\)/);
  assert.match(body(layout, 'paintChatSurface'), /chatSurfaceBorderW\(\)/);
  const pane = source('browser_pane.zig');
  const move = body(pane, 'moveBrowserEdgeMask');
  for (const symbol of ['style.chatSurfaceRadius()', 'style.chatSurfaceBorderW()', 'style.chatSurfaceBorderColor()', 'browserEdgeMaskColor(side)', '.arc_background = browserEdgeMaskFrameColor()']) assert.ok(move.includes(symbol), symbol);
  const paint = body(pane, 'browserEdgeMaskWndProc');
  assert.match(paint, /style.chatSurfaceBorderColor\(\)/);
  assert.match(paint, /if \(side == \.controls\) \{[\s\S]*?for \(lines\) \|line\| _ = FillRect/);
  assert.match(body(pane, 'browserEdgeMaskFrameColor'), /g_amoled_theme/);
  assert.match(body(pane, 'browserEdgeMaskBottomColor'), /g_light_theme/);
  assert.match(body(pane, 'refreshBrowserEdgeMasks'), /positionBrowserEdgeMasks\(layout\)[\s\S]*InvalidateRect/);
  assert.match(source('themes.zig'), /refreshBrowserEdgeMasks\(\)/);
  const bitmap = source('browser_corners.zig');
  assert.match(bitmap, /@import\("app_state.zig"\).CHAT_BUBBLE_RADIUS \* scale/);
  assert.match(bitmap, /100, 150/);
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /b.path\("src\/browser_corners.zig"\)/);
  assert.match(build, /vps_test_step.dependOn\(&run_browser_corner_tests.step\)/);
  assert.match(build, /test_step.dependOn\(&run_browser_corner_tests.step\)/);
});
