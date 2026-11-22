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
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'toggle.zig')], { cwd: dir, encoding: 'utf8' });
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
  for (const token of ['$i -lt 20', 'ImmediateBrowserTogglePair(50)', "$before + 2", 'SLOW_LOADING', 'SLOW_FINISHED', "'toggle-keys.log'", 'immediate-toggle.mp4', "Assert-ImmediateBrowserPairs 'blank'", "Assert-ImmediateBrowserPairs 'slow'"]) assert.ok(journey.includes(token), token);
  assert.match(read('.github/workflows/verify.yml'), /name: Install browser toggle recorder\n\s+if: env\.FEATURE == 'browser-pane-stuck'[\s\S]*choco install ffmpeg --version=7\.1\.1/);
  assert.doesNotMatch(journey, /\$job\.Start\(/);
  const recordingSeconds = Number(journey.match(/-t (\d+) -vf/)[1]);
  const settleMilliseconds = Number(journey.match(/\$recorder\.WaitForExit\((\d+)\)/)[1]);
  assert.ok(settleMilliseconds >= recordingSeconds * 1000, 'recorder settlement covers its entire recording duration');
  for (const token of ['$serverJob = New-Object VerifyJob', '$recordJob = New-Object VerifyJob', '$helper.Stop()', '$helper.Dispose()', 'toggle-helper-process-tree.json']) assert.ok(journey.includes(token), token);
  const native = read('.claude/skills/verify-multiprompt/control-native.cs').split('public static double ImmediateBrowserTogglePair(int delay)')[1]?.split('public static void OpenAndCloseBrowserPane()')[0];
  assert.ok(native);
  assert.match(native, /chord\(\);[\s\S]*remaining = delay - clock\.Elapsed\.TotalMilliseconds;[\s\S]*Thread\.Sleep\(\(int\)\(remaining\)\);[\s\S]*chord\(\);/);
  assert.doesNotMatch(native, /if \(gap > 300\) throw/);
  assert.match(journey, /\$speedWarning = \$gap -gt 300/);
  assert.match(journey, /if \(\$speedWarning\) \{ Record "WARNING:/);
  assert.match(journey, /inputGapMs = \$gap; verifiedClosedMs = \$verifiedClosedMs/);
  assert.match(native, /SendInput\(\(uint\)batch.Length, batch/);
  assert.doesNotMatch(native, /Key\(0x12/);
  assert.match(native, /key\(0x12, 0\); key\(0x41, 0\); key\(0x41, 2\); key\(0x12, 2\)/);
  assert.match(journey, /Press @\(0x11, 0x4C\) 'Ctrl\+L: navigate browser pane'/);
  assert.match(journey, /ClassName -eq 'OmniboxViewViews'/);
  assert.ok(journey.includes("(Read-Session).tabs[0].burl -eq $slowUrl"));
  assert.doesNotMatch(journey, /Alt\+L: navigate browser pane/);
  assert.match(journey, /Press @\(0x12, 0x41\) 'Alt\+A: open browser for slow navigation'/);
  assert.match(journey, /Record "IGSH-1126 \$Page immediate Alt\+A pair \$i"\s+\[VerifyNative\]::BringToForeground\(\$script:window\)\s+Wait-Foreground/);
});

test('IGSH-1126 a launch-owned browser belongs to the app before adoption', () => {
  const production = fn(read('src/focus.zig'), 'foregroundHwndIsOurs')
    .replace('@import("settings_panel.zig").ownsWindow(fg)', 'settingsOwnsWindow(fg)')
    .replace('@import("browser_pane.zig").pendingBrowserWindowOwnsForeground(fg)', 'pendingBrowserWindowOwnsForeground(fg)');
  const pending = fn(read('src/browser_pane.zig'), 'pendingBrowserWindowOwnsForeground');
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
var shell_count: u32 = 1;
var g_browser_adopt_target_idx: u32 = 0;
var g_cancelled_browser_launches = [_]struct { nonce: [40]u8 = @splat(0), nonce_len: usize = 0, deadline: u64 = 0 }{.{}};
fn GetTickCount64() u64 { return 100; }
fn InternalGetWindowText(hwnd: HANDLE, buffer: [*]u16, _: i32) i32 {
    const title = if (hwnd == @as(HANDLE, @ptrFromInt(80))) std.unicode.utf8ToUtf16LeStringLiteral("ZSPANE-test") else std.unicode.utf8ToUtf16LeStringLiteral("unrelated browser");
    @memcpy(buffer[0..title.len], title);
    return @intCast(title.len);
}
var shells = [_]struct { hwnd: HANDLE = null, browser_hwnd: HANDLE = null, browser_enabled: bool = true, browser_launch_tick: u64 = 1 }{.{}};
fn GetAncestor(hwnd: HANDLE, _: u32) HANDLE { return if (hwnd == @as(HANDLE, @ptrFromInt(20))) @as(HANDLE, @ptrFromInt(10)) else hwnd; }
fn settingsOwnsWindow(_: HANDLE) bool { return false; }
fn IsWindow(_: HANDLE) i32 { return 1; }
fn GetWindowLongPtrW(_: HANDLE, _: i32) isize { return 0; }
fn GetParent(_: HANDLE) HANDLE { return null; }
fn browserPaneOwnsForegroundHwnd(_: HANDLE, _: HANDLE) bool { return false; }
fn edgeWindowClassMatches(hwnd: HANDLE) bool { return hwnd != @as(HANDLE, @ptrFromInt(70)); }
fn browserSnapshotContains(hwnd: HANDLE) bool { return hwnd == @as(HANDLE, @ptrFromInt(60)); }
fn browserWindowProfileMatches(hwnd: HANDLE, _: u32) bool { return hwnd != @as(HANDLE, @ptrFromInt(50)); }
${pending}
${production}
test "opening pane owner is authoritative before shell browser_hwnd is populated" {
    try std.testing.expect(foregroundHwndIsOurs(@ptrFromInt(20)));
    try std.testing.expect(foregroundHwndIsOurs(@ptrFromInt(10)));
    try std.testing.expect(foregroundHwndIsOurs(@ptrFromInt(40)));
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(50)));
    try std.testing.expect(foregroundHwndIsOurs(@ptrFromInt(60)));
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(70)));
    shells[0].browser_enabled = false;
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(40)));
    shells[0].browser_enabled = true;
    shells[0].browser_launch_tick = 0;
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(40)));
    shells[0].browser_launch_tick = 1;
    g_browser_adopt_target_idx = 0xFFFFFFFF;
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(40)));
    try std.testing.expect(!foregroundHwndIsOurs(null));
    @memcpy(g_cancelled_browser_launches[0].nonce[0..11], "ZSPANE-test");
    g_cancelled_browser_launches[0].nonce_len = 11;
    g_cancelled_browser_launches[0].deadline = 200;
    try std.testing.expect(foregroundHwndIsOurs(@ptrFromInt(80)));
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(90)));
    g_cancelled_browser_launches[0].deadline = 100;
    try std.testing.expect(!foregroundHwndIsOurs(@ptrFromInt(80)));
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'owner.zig')], { cwd: dir, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('IGSH-1126 an enabled browser waiting to launch closes instead of recovering', () => {
  const source = read('src/shortcuts.zig');
  const policy = fn(source, 'physicalBrowserShortcutShouldRecover');
  const acceptsStarted = policy.slice(0, policy.indexOf(')')).includes('connection_started');
  const call = (live, tick, started) => `physicalBrowserShortcutShouldRecover(true, ${live}, ${tick}${acceptsStarted ? `, ${started}` : ''})`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'browser-pending-toggle-'));
  try {
    fs.writeFileSync(path.join(dir, 'pending.zig'), `const std = @import("std");
${policy}
test "pending open closes, crashed connection still recovers" {
    try std.testing.expect(!${call('false', 0, 'false')});
    try std.testing.expect(${call('false', 0, 'true')});
    try std.testing.expect(!${call('true', 0, 'true')});
    try std.testing.expect(!${call('false', 100, 'true')});
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'pending.zig')], { cwd: dir, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
