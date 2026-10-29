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
  assert.match(build, /browser_corner_source\.setEnvironmentVariable\("ZIG", b\.graph\.zig_exe\)/);
  assert.match(build, /b.path\("src\/browser_corners.zig"\)/);
  assert.match(build, /vps_test_step.dependOn\(&run_browser_corner_tests.step\)/);
  assert.match(build, /test_step.dependOn\(&run_browser_corner_tests.step\)/);
});

test('production corner geometry and alpha rasterizer execute at both scales', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-corners-'));
  try {
    fs.writeFileSync(path.join(dir, 'browser_corners.zig'), source('browser_corners.zig'));
    fs.writeFileSync(path.join(dir, 'win32.zig'), 'pub const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };');
    const radius = source('app_state.zig').match(/pub const CHAT_BUBBLE_RADIUS[^;]+;/);
    assert.ok(radius);
    assert.match(radius[0], /CHAT_BUBBLE_RADIUS = @import\("design_tokens.zig"\).bubble_radius;/);
    fs.writeFileSync(path.join(dir, 'app_state.zig'), radius[0]);
    fs.writeFileSync(path.join(dir, 'design_tokens.zig'), source('design_tokens.zig'));
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', path.join(dir, 'browser_corners.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    console.log(result.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});


test('IGSH-1057 activation never uncovers a visible browser frame', () => {
  const main = source('main.zig');
  const start = main.indexOf('        WM_ACTIVATEAPP => {');
  const end = main.indexOf('        WM_SETFOCUS => {', start);
  assert.doesNotMatch(main.slice(start, end), /hideBrowserEdgeMasks\(/);
  const foreground = body(source('focus.zig'), 'foregroundWinEventProc');
  assert.doesNotMatch(foreground, /hideBrowserEdgeMasks\(/);
});

test('IGSH-1057 background masks stay visible without raising above another app', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-background-'));
  try {
    const production = body(source('browser_pane.zig'), 'raiseBrowserEdgeMasksZOrderOnly').replace(/^fn /, 'pub fn ');
    fs.writeFileSync(path.join(dir, 'test.zig'), `
const std = @import("std");
const HANDLE = ?*anyopaque;
const BROWSER_EDGE_MASKS = true;
const BROWSER_EDGE_MASK_COUNT = 10;
const SWP_NOMOVE = 2;
const SWP_NOSIZE = 1;
const SWP_NOACTIVATE = 16;
const SWP_NOREDRAW = 8;
const app_state = struct {
    var g_main_hwnd: HANDLE = @ptrFromInt(1);
    var g_browser_edge_mask_shown = [_]bool{true} ** 10;
    var g_browser_edge_mask_hwnds = [_]HANDLE{@ptrFromInt(2)} ** 10;
};
var foreground = false;
var minimized = false;
var raised: usize = 0;
fn activeBrowserTransientPopupHasForegroundFocus() bool { return false; }
fn activeBrowserEdgeMasksAllowed() bool { return true; }
fn browserChromeCanStayVisible() bool { return !minimized; }
fn foregroundIsOurs() bool { return foreground; }
fn IsIconic(_: HANDLE) i32 { return if (minimized) 1 else 0; }
fn IsWindow(_: HANDLE) i32 { return 1; }
fn suspendBrowserEdgeMaskRaiseForPopup() void {}
fn hideBrowserEdgeMasks() void { app_state.g_browser_edge_mask_shown = [_]bool{false} ** 10; }
fn SetWindowPos(_: HANDLE, _: HANDLE, _: i32, _: i32, _: i32, _: i32, _: u32) i32 { raised += 1; return 1; }
${production}
test "background browser keeps every mask without covering foreign foreground" {
    raiseBrowserEdgeMasksZOrderOnly();
    for (app_state.g_browser_edge_mask_shown) |shown| try std.testing.expect(shown);
    try std.testing.expectEqual(@as(usize, 0), raised);
    foreground = true;
    raiseBrowserEdgeMasksZOrderOnly();
    try std.testing.expectEqual(@as(usize, 10), raised);
    minimized = true;
    raiseBrowserEdgeMasksZOrderOnly();
    for (app_state.g_browser_edge_mask_shown) |shown| try std.testing.expect(!shown);
}
`);
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All 1 tests passed/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('IGSH-1057 native original-source checkout pins a fetchable full commit', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/browser-corners.yml'), 'utf8');
  assert.match(workflow, /ref: [a-f0-9]{40}\s/);
  assert.match(workflow, /Get-Content evidence\/negative\/process-tree\.json/);
  assert.match(workflow, /\$cleanup\.activeAfterStop -ne 0/);
});
