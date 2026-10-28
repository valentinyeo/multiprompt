const test = require('node:test');
const assert = require('node:assert/strict');
const { readControlSource } = require('./app-source');
assert.equal(typeof readControlSource, 'function', 'Control readers must follow physical feature files');
const fs = require('node:fs');
const path = require('node:path');

const read = file => (file.endsWith('control.ps1') ? readControlSource() : fs.readFileSync(path.join(__dirname, '..', file), 'utf8'));
const pane = read('src/browser_pane.zig');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, name);
  return source.slice(source.indexOf('{', start) + 1, end);
}

function translate(name, args) {
  const translated = body(pane, name)
    .replace(/@as\(i64, /g, '(')
    .replaceAll('@max', 'Math.max').replaceAll('@min', 'Math.min')
    .replaceAll('std.math.maxInt(i64)', 'Number.MAX_SAFE_INTEGER')
    .replaceAll('std.math.clamp', 'clamp')
    .replace(/var (\w+): (?:\?usize|i64) =/g, 'let $1 =')
    .replaceAll('var outside =', 'let outside =')
    .replaceAll('const xs = [_]i32{', 'const xs = [')
    .replaceAll('const ys = [_]i32{', 'const ys = [')
    .replace(/\n    };/g, '\n    ];')
    .replace(/RECT\{ ([^}]+) }/g, (_, fields) => `{ ${fields.replace(/\.(\w+) =/g, '$1:')} }`)
    .replace('for (monitors, 0..) |monitor, index| {', 'for (const [index, monitor] of monitors.entries()) {')
    .replace(/for \((\w+)\) \|(\w+)\| {/g, 'for (const $2 of $1) {')
    .replace('const nearest = nearestBrowserMonitor(rect, monitors) orelse continue;', 'const nearest = nearestBrowserMonitor(rect, monitors); if (nearest === null) continue;')
    .replace('std.meta.eql(monitors[nearest], owner)', 'equalRect(monitors[nearest], owner)')
    .replaceAll(' or ', ' || ').replaceAll(' and ', ' && ');
  return `function ${name}(${args}) { ${translated} }`;
}

const geometry = new Function(`
  const clamp = (value, low, high) => Math.max(low, Math.min(value, high));
  const equalRect = (a, b) => ['left', 'top', 'right', 'bottom'].every(key => a[key] === b[key]);
  ${translate('browserRectDistanceSquared', 'rect, monitor')}
  ${translate('browserRectIntersectionArea', 'rect, monitor')}
  ${translate('nearestBrowserMonitor', 'rect, monitors')}
  ${translate('browserParkRectPure', 'owner, monitors, width, height')}
  return { park: browserParkRectPure, nearest: nearestBrowserMonitor, area: browserRectIntersectionArea };
`)();

const owner = { left: 0, top: 0, right: 1920, bottom: 1080 };
const panel = { left: -2560, top: -493, right: 0, bottom: 1107 };
const oldPark = { left: -32000, top: -32000, right: -30854, bottom: -31007 };

function assertParked(rect, displays, ownerIndex, width = 1146, height = 993) {
  assert.ok(rect);
  assert.equal(geometry.nearest(rect, displays), ownerIndex);
  assert.equal(rect.right - rect.left, width);
  assert.equal(rect.bottom - rect.top, height);
  assert.ok(rect.left >= -32000 && rect.right <= 32000);
  assert.ok(rect.top >= -32000 && rect.bottom <= 32000);
  for (const monitor of displays) assert.equal(geometry.area(rect, monitor), 0);
}

test('production parking geometry keeps the reported 96-DPI owner; old -32000 parking selects the 120-DPI panel', () => {
  const displays = [owner, panel];
  assert.equal(geometry.nearest(oldPark, displays), 1);
  assert.throws(() => assertParked(oldPark, displays, 0), assert.AssertionError);
  assertParked(geometry.park(owner, displays, 1146, 993), displays, 0);
});

test('production parking geometry handles a single display and neighbors right, above and below either owner', () => {
  const layouts = [[owner], [owner, panel],
    [owner, { left: 1920, top: 0, right: 4480, bottom: 1600 }],
    [owner, { left: 0, top: -1600, right: 2560, bottom: 0 }],
    [owner, { left: 0, top: 1080, right: 2560, bottom: 2680 }]];
  for (const displays of layouts) {
    for (const [index, monitor] of displays.entries()) {
      assertParked(geometry.park(monitor, displays, 1146, 993), displays, index);
    }
  }
});

test('nearest-monitor ties use the largest intersection rather than enumeration order', () => {
  const displays = [{ left: 0, top: 0, right: 100, bottom: 100 }, { left: 100, top: 0, right: 300, bottom: 100 }];
  assert.equal(geometry.nearest({ left: 90, top: 0, right: 200, bottom: 100 }, displays), 1);
});

test('no candidate is returned for an owner surrounded by other displays instead of changing hide mechanisms', () => {
  const displays = [owner,
    { left: -1920, top: 0, right: 0, bottom: 1080 },
    { left: 1920, top: 0, right: 3840, bottom: 1080 },
    { left: -1920, top: -1080, right: 3840, bottom: 0 },
    { left: -1920, top: 1080, right: 3840, bottom: 2160 }];
  assert.equal(geometry.park(owner, displays, 1146, 993), null);
});

test('native parking enumerates monitors and validates offscreen geometry against MonitorFromRect before moving without resizing or hiding', () => {
  const native = body(pane, 'browserParkRect');
  assert.match(native, /MonitorFromWindow\(app_state.g_main_hwnd, win.MONITOR_DEFAULTTONEAREST\)/);
  assert.match(native, /EnumDisplayMonitors\(null, null, browserParkMonitorEnum,/);
  assert.match(native, /browserParkRectPure\(info.rcMonitor, monitors.items, current.right - current.left, current.bottom - current.top\)/);
  assert.match(native, /!browserRectIsParked\(rect\) or win.MonitorFromRect\(&rect, win.MONITOR_DEFAULTTONEAREST\) != owner/);
  const park = body(pane, 'parkBrowserWindow');
  assert.match(park, /GetWindowRect\(hwnd, &current\)/);
  assert.match(park, /browserParkRect\(current\) orelse/);
  assert.match(park, /setBrowserWindowPosAsync\(hwnd, null, target.left, target.top, 0, 0, SWP_NOSIZE \| SWP_NOZORDER \| SWP_NOACTIVATE\)/);
  assert.match(park, /showBrowserWindowAsync\(hwnd, SW_SHOWNOACTIVATE\)/);
  assert.doesNotMatch(park, /hideBrowserWindowHard|SW_HIDE|SWP_HIDEWINDOW/);
  assert.doesNotMatch(pane, /DWMWA_CLOAK|browserWindowCloaked|unparkBrowserWindow|BROWSER_PARK_[XY]/);
  assert.match(pane, /test "browser parking keeps the reported 96 DPI owner instead of the 120 DPI panel"/);
  assert.match(pane, /test "browser parking stays outside single right above and below monitor layouts"/);
});

test('parking falls back to the legacy offscreen point when monitor-aware geometry is unavailable', () => {
  const park = body(pane, 'parkBrowserWindow');
  const fallback = park.match(/browserParkRect\(current\) orelse fallback: \{([\s\S]*?)\n    };/);
  assert.ok(fallback, 'missing fallback instead of returning without parking');
  assert.match(fallback[1], /debugLog\("browser parking: no offscreen rectangle on owner monitor"\)/);
  assert.doesNotMatch(fallback[1], /\breturn\b/);
  const rect = fallback[1].match(/break :fallback RECT\{([\s\S]*?)\n        };/);
  assert.ok(rect, 'fallback must supply a rectangle');
  const current = { left: 100, top: 50, right: 1246, bottom: 1043 };
  const fields = rect[1].replace(/\.(\w+) =/g, '$1:');
  const target = new Function('current', `return { ${fields} };`)(current);
  assert.deepEqual(target, oldPark);
  for (const monitor of [owner, panel]) assert.equal(geometry.area(target, monitor), 0);
  assert.match(body(pane, 'browserRectIsParked'), /MonitorFromRect\(&rect, 0\) == null/);
});

test('browser shortcut hit testing is not restricted to the active shell', () => {
  assert.doesNotMatch(body(read('src/shortcuts.zig'), 'browserShellAtScreenPoint'), /if \(i != app_state.active_shell\) continue;/);
});

test('all parking recognition uses rectangle intersection with any monitor, including no-size moves', () => {
  assert.match(body(pane, 'browserRectIsParked'), /MonitorFromRect\(&rect, 0\) == null/);
  assert.match(body(pane, 'setBrowserWindowPosAsync'), /rect.right = x \+ current.right - current.left/);
  assert.match(body(pane, 'setBrowserWindowPosAsync'), /rect.bottom = y \+ current.bottom - current.top/);
  assert.match(body(pane, 'setBrowserWindowPosAsync'), /moveLeavesOnScreen\(browserRectIsParked\(rect\),/);
  assert.match(body(pane, 'browserDockGuardTarget'), /return browserParkRect\(current\)/);
  assert.match(body(pane, 'handleBrowserDockGuard'), /if \(browserRectIsParked\(target\)\)/);
  assert.match(body(pane, 'browserPaneCoversSlot'), /return !browserRectIsParked\(wr\)/);
  const source = read('src/browser_onscreen.zig');
  const rule = body(source, 'moveLeavesOnScreen');
  const move = new Function('parked', 'no_move', 'hide', rule);
  assert.equal(move(true, false, false), false);
  assert.equal(move(false, false, false), true);
  assert.equal(move(false, true, false), null);
  assert.equal(move(false, true, true), false);
});

test('adoption and tab switching still park by moving, and painted reveal retains its no-redraw move', () => {
  assert.match(body(pane, 'finishBrowserDock'), /parkBrowserWindow\(hwnd\);\s*positionActiveBrowser\(\)/);
  assert.match(body(pane, 'updateBrowserVisibility'), /if \(!browser_was_visible\) parkBrowserWindow\(bh\)/);
  assert.match(body(pane, 'parkStrayBrowserPanes'), /parkBrowserWindow\(/);
  assert.match(body(pane, 'hideAllBrowserChrome'), /parkBrowserWindow\(bh\)/);
  assert.match(body(pane, 'revealPaintedChatBrowser'), /setBrowserWindowPosAsync\([^;]+SWP_NOREDRAW\)/);
  assert.doesNotMatch(body(pane, 'shellExecuteEdgeUrl'), /force-device-scale-factor|high-dpi-support/);
  assert.match(body(pane, 'appendPaneLaunchFallbackBounds'), /paneLaunchFallbackBounds\(info.rcWork, &buf\)/);
});

test('Windows journey checks every parked pane monitor and every visible pane effective monitor DPI', () => {
  const driver = read('.claude/skills/verify-multiprompt/control.ps1');
  const proof = driver.slice(driver.indexOf('function Assert-BrowserPaneMonitors('), driver.indexOf('function Focus-LockedBrowser('));
  for (const marker of [
    'OwnedPaneWindows($script:window)', 'MonitorFromRect([ref]$rect, 0)',
    'MonitorFromWindow($paneHwnd, 2)', '$paneMonitor -ne $ownerMonitor',
    'GetDpiForWindow($paneHwnd)', 'GetDpiForMonitor($paneMonitor, 0,',
    '$paneDpi -ne $monitorDpiX', '$paneDpi -ne $monitorDpiY',
    'SetThreadDpiAwarenessContext([IntPtr](-4))',
    'finally { [void][VerifyNative]::SetThreadDpiAwarenessContext($previousDpiContext) }',
    'if ($RequireParked -and',
  ]) assert.ok(proof.includes(marker), marker);
  for (const step of ['initial', 'restored']) assert.ok(driver.includes(`Assert-BrowserLaunchOnOwnMonitor '${step}'`));
  assert.ok(driver.includes("Assert-BrowserPaneMonitors 'restored-overlay' -RequireParked"));
  assert.doesNotMatch(driver, /IsPaneCloaked|DwmGetWindowAttribute/);
  assert.ok(read('build.zig').includes('"tools/browser-onscreen.test.js", "tools/browser-pane-dpi.test.js"'));
});
