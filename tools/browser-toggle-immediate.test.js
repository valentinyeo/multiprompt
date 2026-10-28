const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function fn(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('IGSH-1126 actual browser key policy accepts 20 open/close pairs within 300 ms', () => {
  const source = read('src/shortcuts.zig');
  const hook = source.slice(source.indexOf('if (wp == WM_SYSKEYDOWN and (kb.flags & 0x20) != 0 and !isCtrlDown() and (kb.vkCode == 0x41'));
  const press = hook.match(/if \(!([\w]+)\(true, ([^\n]+?)\)\) return 1;/);
  assert.ok(press, 'real Alt+A hook has a physical press policy');
  const timed = press[1] === 'claimBrowserTogglePress';
  assert.ok(timed || press[1] === 'claimBrowserFocusPress');
  const call = (down, tick) => timed
    ? `${press[1]}(${down}, ${tick}, &held, &last)`
    : `${press[1]}(${down}, &held)`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-toggle-'));
  try {
    fs.writeFileSync(path.join(dir, 'toggle.zig'), `const std = @import("std");
const BROWSER_TOGGLE_DEBOUNCE_MS: u32 = 1500;
${['claimBrowserToggleEvent', 'claimBrowserTogglePress', 'claimBrowserFocusPress'].map(name => fn(source, name)).join('\n')}
test "twenty immediate pairs reject held repeat, not a new press" {
    var held = false;
    ${timed ? 'var last: u32 = 0;' : ''}
    for (0..20) |i| {
        const tick: u32 = @intCast(10000 + i * 1000);
        try std.testing.expect(${call('true', 'tick')});
        try std.testing.expect(!${call('true', 'tick + 10')});
        try std.testing.expect(!${call('false', 'tick + 20')});
        try std.testing.expect(${call('true', 'tick + 100')});
        try std.testing.expect(!${call('false', 'tick + 120')});
        ${timed ? '' : '_ = tick;'}
    }
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'toggle.zig')], { cwd: dir, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-1126 pane loading never blocks a released shortcut', () => {
  const main = read('src/main.zig');
  const toggle = main.slice(main.indexOf('        WM_APP_BROWSER_TOGGLE => {'), main.indexOf('        WM_APP_BROWSER_MODE_TOGGLE => {'));
  assert.doesNotMatch(toggle, /physicalBrowserShortcutMayClose|open_guard|claimBrowserToggleEvent/);
  assert.match(toggle, /browser_enabled = !app_state\.shells\[target_idx\]\.browser_enabled/);
  assert.match(toggle, /closeBrowserForShell\(target_idx\)/);
  assert.match(read('src/shortcuts.zig'), /claimBrowserFocusPress\(false, &app_state\.g_browser_toggle_chord_held\)/);
});

test('IGSH-1126 GitHub journey measures actual keys and unfinished navigation', () => {
  const journey = read('.claude/skills/verify-multiprompt/control-feature-browser-pane-stuck.ps1');
  for (const token of ['$i -lt 20', 'ImmediateBrowserTogglePair()', "$before + 2", 'SLOW_LOADING', 'SLOW_FINISHED', "'toggle-keys.log'", 'immediate-toggle.mp4', "Assert-ImmediateBrowserPairs 'blank'", "Assert-ImmediateBrowserPairs 'slow'"]) assert.ok(journey.includes(token), token);
  assert.match(read('.github/workflows/verify.yml'), /name: Install browser toggle recorder\n\s+if: env\.FEATURE == 'browser-pane-stuck'[\s\S]*choco install ffmpeg --version=7\.1\.1/);
  assert.doesNotMatch(journey, /\$job\.Start\(/);
  for (const token of ['$serverJob = New-Object VerifyJob', '$recordJob = New-Object VerifyJob', '$helper.Stop()', '$helper.Dispose()', 'toggle-helper-process-tree.json']) assert.ok(journey.includes(token), token);
  const native = read('.claude/skills/verify-multiprompt/control-native.cs').split('public static double ImmediateBrowserTogglePair()')[1]?.split('public static void OpenAndCloseBrowserPane()')[0];
  assert.ok(native);
  assert.match(native, /chord\(\);[\s\S]*Thread\.Sleep\(100\);[\s\S]*chord\(\);/);
  assert.match(native, /gap > 300/);
});

test('IGSH-1126 a launch-owned browser belongs to the app before adoption', () => {
  const production = fn(read('src/focus.zig'), 'foregroundHwndIsOurs').replace('@import("settings_panel.zig").ownsWindow(fg)', 'settingsOwnsWindow(fg)');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-opening-owner-'));
  try {
    fs.writeFileSync(path.join(dir, 'owner.zig'), `const std = @import("std");
const HANDLE = ?*anyopaque;
const LONG_PTR = isize;
const GA_ROOTOWNER = 3;
const GWLP_HWNDPARENT = -8;
const app_state = @This();
var g_main_hwnd: HANDLE = @ptrFromInt(10);
var g_urlbar_hwnd: HANDLE = null;
const shell_count = 0;
const shells = [_]struct { hwnd: HANDLE, browser_hwnd: HANDLE }{};
fn GetAncestor(hwnd: HANDLE, _: u32) HANDLE { return if (hwnd == @as(HANDLE, @ptrFromInt(20))) @as(HANDLE, @ptrFromInt(10)) else hwnd; }
fn settingsOwnsWindow(_: HANDLE) bool { return false; }
fn IsWindow(_: HANDLE) i32 { return 1; }
fn GetWindowLongPtrW(_: HANDLE, _: i32) isize { return 0; }
fn GetParent(_: HANDLE) HANDLE { return null; }
fn browserPaneOwnsForegroundHwnd(_: HANDLE, _: HANDLE) bool { return false; }
${production}
test "opening pane owner is authoritative before shell browser_hwnd is populated" {
    try std.testing.expect(foregroundHwndIsOurs(@ptrFromInt(20)));
    try std.testing.expect(foregroundHwndIsOurs(@ptrFromInt(10)));
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(30)));
    try std.testing.expect(!foregroundHwndIsOurs(null));
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'owner.zig')], { cwd: dir, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
