const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { readChangelogEntry } = require('./changelog-entry');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
const directory = '.claude/skills/verify-multiprompt';
const pane = read('src/browser_pane.zig');
const main = read('src/main.zig');
const win = read('src/win32.zig');
const driver = read(`${directory}/control.ps1`);
const workflow = read('.github/workflows/verify.yml');
const map = read(`${directory}/features/browser-pane-locked.md`);

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} exists`);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, `${name} has a body`);
  return source.slice(start, end + 2);
}

function guardContract(source) {
  const style = body(source, 'lockedBrowserStyle');
  for (const flag of ['WS_CAPTION', 'WS_THICKFRAME', 'WS_BORDER', 'WS_MAXIMIZEBOX', 'WS_MINIMIZEBOX']) assert.ok(style.includes(flag));
  assert.match(style, /style & ~@as\(isize,/);
  assert.match(body(source, 'browserDockWorker'), /lockedBrowserStyle\(GetWindowLongPtrW\(hwnd, GWL_STYLE\)\)/);
  const decision = body(source, 'browserDockGuardAction');
  assert.match(decision, /if \(!docked\) return \.none;\s*if \(zoomed\) return \.restore;/);
  assert.match(decision, /if \(!browserRectMatchesTarget\([^\n]+\)\) return \.reposition;\s*return \.none;/);
  const filter = body(source, 'dockedBrowserIndex');
  assert.match(filter, /GetPropW\(hwnd, L\("ZigShellPaneOwner"\)\) != app_state.g_main_hwnd/);
  assert.match(filter, /browser_hwnd == hwnd and !app_state.shells\[i\].browser_docking/);
  const callback = body(source, 'browserDockWinEvent');
  assert.match(callback, /EVENT_OBJECT_LOCATIONCHANGE and \(object != win.OBJID_WINDOW or child != 0\)/);
  assert.match(callback, /dockedBrowserIndex\(hwnd\) orelse return/);
  assert.match(callback, /EVENT_SYSTEM_MOVESIZESTART[\s\S]*PostMessageW\(hwnd, win.WM_CANCELMODE, 0, 0\)/);
  assert.match(callback, /PostMessageW\(hwnd, win.WM_KEYDOWN, win.VK_ESCAPE,/);
  assert.match(callback, /PostMessageW\(hwnd, win.WM_KEYUP, win.VK_ESCAPE,/);
  assert.match(callback, /EVENT_SYSTEM_MOVESIZEEND/);
  assert.match(callback, /if \(browser_dock_guard_pending\) return/);
  assert.match(callback, /GetWindowRect\(hwnd, &current\)/);
  assert.match(callback, /browserDockGuardAction\(true, win.IsZoomed\(hwnd\) != 0, current, target\) == \.none\) return/);
  assert.match(callback, /browser_dock_guard_pending = PostMessageW\(app_state.g_main_hwnd, win.WM_APP_BROWSER_DOCK_GUARD, 0, 0\) != 0/);
  assert.doesNotMatch(callback, /SetWindowPos|ReleaseCapture|SendMessageW/);
  const handler = body(source, 'handleBrowserDockGuard');
  assert.match(handler, /browser_dock_guard_pending = false/);
  assert.match(handler, /if \(action == \.none\) continue/);
  assert.match(handler, /if \(action == \.restore\) _ = ShowWindowAsync\(hwnd, win.SW_RESTORE\)/);
  assert.match(handler, /parkBrowserWindow\(hwnd\)/);
  assert.match(handler, /positionActiveBrowser\(\)/);
  assert.doesNotMatch(handler, /SetWindowPos|setBrowserWindowPosAsync/);
  assert.match(body(source, 'browserDockGuardTarget'), /g_monitor_transition.active or app_state.g_chat_browser_swap.shell_id != 0/);
  assert.match(body(source, 'browserDockGuardTarget'), /idx != app_state.active_shell[\s\S]*browserChromeHiddenForOverlay\(\)[\s\S]*foregroundIsOurs\(\)/);
  assert.match(body(source, 'browserDockGuardTarget'), /browserDockTarget\(calcBrowserLayout\(\)/);
  const positioning = body(source, 'positionActiveBrowser');
  assert.match(positioning, /browserDockTarget\(layout, native\)/);
  assert.equal((positioning.match(/browserWindowNeedsPosition\(/g) || []).length, 2);
  assert.match(positioning, /setBrowserWindowPosAsync\(/);
  const install = body(source, 'installBrowserDockHooks');
  assert.match(install, /SetWinEventHook\(win.EVENT_SYSTEM_MOVESIZESTART, win.EVENT_SYSTEM_MOVESIZEEND, null, browserDockWinEvent, 0, 0, win.WINEVENT_OUTOFCONTEXT\)/);
  assert.match(install, /SetWinEventHook\(win.EVENT_OBJECT_LOCATIONCHANGE, win.EVENT_OBJECT_LOCATIONCHANGE, null, browserDockWinEvent, 0, 0, win.WINEVENT_OUTOFCONTEXT\)/);
  const uninstall = body(source, 'uninstallBrowserDockHooks');
  for (const hook of ['browser_move_size_hook', 'browser_location_hook']) assert.ok(uninstall.includes(`win.UnhookWinEvent(${hook})`));
}

test('dock guard source contract reuses idempotent positioning and cancels on the browser thread', () => {
  guardContract(pane);
  for (const [before, after] of [
    ['fn lockedBrowserStyle(', 'fn oldBrowserStyle('],
    [' | win.WS_MAXIMIZEBOX', ''],
    ['if (!docked) return .none;', ''],
    ['if (zoomed) return .restore;', ''],
    ['!browserRectMatchesTarget(current,', 'browserRectMatchesTarget(current,'],
    ['object != win.OBJID_WINDOW', 'object == win.OBJID_WINDOW'],
    ['const idx = dockedBrowserIndex(hwnd) orelse return;', 'const idx: u32 = 0;'],
    ['PostMessageW(hwnd, win.WM_CANCELMODE, 0, 0)', 'ReleaseCapture()'],
    ['if (browser_dock_guard_pending) return;', ''],
    ['_ = ShowWindowAsync(hwnd, win.SW_RESTORE);', '{}'],
    ['win.WINEVENT_OUTOFCONTEXT', '1'],
  ]) {
    assert.ok(pane.includes(before), `negative control exists: ${before}`);
    assert.throws(() => guardContract(pane.replaceAll(before, after)), `reject ${before}`);
  }
});

test('dock guard is installed and removed with the app lifetime and dispatched on the main thread', () => {
  assert.match(main, /app_state.g_main_hwnd = hwnd;\s*@import\("browser_pane.zig"\).installBrowserDockHooks\(\);\s*defer @import\("browser_pane.zig"\).uninstallBrowserDockHooks\(\)/);
  assert.match(main, /if \(msg == @import\("win32.zig"\).WM_APP_BROWSER_DOCK_GUARD\) \{\s*@import\("browser_pane.zig"\).handleBrowserDockGuard\(\)/);
  assert.match(main, /uninstallForegroundHook\(\);\s*@import\("browser_pane.zig"\).uninstallBrowserDockHooks\(\)/);
  for (const [name, value] of [['EVENT_SYSTEM_MOVESIZESTART', '0x000A'], ['EVENT_SYSTEM_MOVESIZEEND', '0x000B'], ['EVENT_OBJECT_LOCATIONCHANGE', '0x800B'], ['WM_CANCELMODE', '0x001F']]) {
    assert.match(win, new RegExp(`pub const ${name}: \\w+ = ${value};`));
  }
  const messages = [...win.matchAll(/pub const (WM_APP_\w+): u32 = WM_APP \+ (\d+);/g)];
  const guard = messages.find(match => match[1] === 'WM_APP_BROWSER_DOCK_GUARD');
  assert.ok(guard);
  assert.equal(messages.filter(match => match[2] === guard[2]).length, 1);
});

test('browser-focused Aero Snap cannot maximize the owner frame while normal frame commands still work', () => {
  function contract(source) {
    assert.match(source, /WM_SYSCOMMAND => \{\s*if \(\(wp & 0xFFF0\) == @import\("win32.zig"\).SC_MAXIMIZE and activeBrowserHasForegroundFocus\(\)\) return 0;\s*return DefWindowProcW\(hwnd, msg, wp, lp\);\s*\}/);
  }
  contract(main);
  assert.match(win, /pub const SC_MAXIMIZE: usize = 0xF030;/);
  for (const before of ['(wp & 0xFFF0)', 'and activeBrowserHasForegroundFocus()', 'return DefWindowProcW(hwnd, msg, wp, lp);']) {
    assert.ok(main.includes(before));
    assert.throws(() => contract(main.replaceAll(before, '')));
  }
});

test('browser-focused Win+Up cannot maximize through the app snap command', () => {
  function contract(source) {
    const start = source.indexOf('        WM_APP_WIN_SNAP => {');
    assert.notEqual(start, -1);
    const handler = source.slice(start, source.indexOf('\n        WM_APP_', start + 1));
    assert.match(handler, /WM_APP_WIN_SNAP => \{\s*if \(wp == 2 and activeBrowserHasForegroundFocus\(\)\) return 0;\s*var mi: MONITORINFO/);
    assert.match(handler, /2 => _ = ShowWindow\(hwnd, SW_MAXIMIZE\)/);
  }
  contract(main);
  for (const [before, after] of [
    ['if (wp == 2 and activeBrowserHasForegroundFocus()) return 0;', ''],
    ['wp == 2 and activeBrowserHasForegroundFocus()', 'wp == 0 and activeBrowserHasForegroundFocus()'],
    ['wp == 2 and activeBrowserHasForegroundFocus()', 'wp == 2'],
    ['2 => _ = ShowWindow(hwnd, SW_MAXIMIZE)', '2 => {}'],
  ]) {
    assert.ok(main.includes(before), `negative control exists: ${before}`);
    assert.throws(() => contract(main.replaceAll(before, after)), `reject ${before}`);
  }
});

test('Windows Zig suite owns regression cases for styles, movement, zoom, no-op and non-docked windows', () => {
  assert.ok(main.includes('_ = @import("browser_pane.zig");'));
  for (const name of [
    'locked browser style removes maximize and minimize boxes',
    'docked browser moved rect triggers snap back',
    'docked browser zoomed pane triggers restore even at matching rect',
    'docked browser matching rect is an idempotent no-op',
    'non-docked browser window is ignored even when zoomed and moved',
  ]) assert.ok(pane.includes(`test "${name}"`), name);
});

function launchBoundsContract(source) {
  const formatter = body(source, 'paneLaunchFallbackBounds');
  assert.match(formatter, /std\.fmt\.bufPrint\(buf, " --window-position=\{d\},\{d\} --window-size=400,400", \.\{ work\.left, work\.top \}\)/);
  const fallback = body(source, 'appendPaneLaunchFallbackBounds');
  assert.match(fallback, /if \(app_state\.g_main_hwnd != null\)\s*win\.MonitorFromWindow\(app_state\.g_main_hwnd, win\.MONITOR_DEFAULTTOPRIMARY\)\s*else\s*win\.MonitorFromPoint\(\.\{ \.x = 0, \.y = 0 \}, win\.MONITOR_DEFAULTTOPRIMARY\)/);
  assert.match(fallback, /info\.cbSize = @sizeOf\(win\.MONITORINFO\)/);
  assert.match(fallback, /if \(win\.GetMonitorInfoW\(monitor, &info\) == 0\) return/);
  assert.match(fallback, /paneLaunchFallbackBounds\(info\.rcWork, &buf\)/);
  const launch = body(source, 'shellExecuteEdgeUrl');
  assert.equal((launch.match(/appendPaneLaunchFallbackBounds\(&params, &pos\)/g) || []).length, 2);
  assert.doesNotMatch(launch, /--window-position=-32000,-32000/);
  assert.match(source, /test "pane launch fallback bounds stay inside the owner monitor work area"/);
  assert.match(source, /x >= work\.left and y >= work\.top/);
  assert.match(source, /x \+ width <= work\.right and y \+ height <= work\.bottom/);
}

test('fresh launch fallbacks format the owner monitor work area and include Zig bounds regressions', () => {
  launchBoundsContract(pane);
  assert.match(win, /pub extern "user32" fn MonitorFromPoint\(POINT, DWORD\) callconv\(WINAPI\) HANDLE;/);
  assert.match(win, /pub const MONITOR_DEFAULTTOPRIMARY: DWORD = 1;/);
  for (const [before, after] of [
    ['.{ work.left, work.top }', '.{ -32000, -32000 }'],
    ['paneLaunchFallbackBounds(info.rcWork, &buf)', 'paneLaunchFallbackBounds(info.rcMonitor, &buf)'],
    ['win.MONITOR_DEFAULTTOPRIMARY', 'win.MONITOR_DEFAULTTONEAREST'],
    ['appendPaneLaunchFallbackBounds(&params, &pos);', 'appendBrowserWideAscii(&params, &pos, " --window-position=-32000,-32000 --window-size=400,400");'],
    ['x + width <= work.right and y + height <= work.bottom', 'true'],
  ]) {
    assert.ok(pane.includes(before), `negative control exists: ${before}`);
    assert.throws(() => launchBoundsContract(pane.replaceAll(before, after)), `reject ${before}`);
  }
});

function launchJourneyContract(source) {
  const proof = source.slice(source.indexOf('function Assert-BrowserLaunchOnOwnMonitor('), source.indexOf('function Focus-LockedBrowser('));
  for (const step of [
    'Doctor', "GetProp($browser, 'ZigShellPaneOwner') -ne $script:window",
    'MonitorFromWindow($script:window, 1)', 'GetMonitorInfoW($monitor, [ref]$info)',
    "'ZigShell/ChromeUserData'", '[regex]::Escape($profile)',
    `Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'"`,
    "$_.CommandLine -match $profileArgument -and $_.CommandLine.Contains('--window-position=')",
    '$x -ge $info.Monitor.Left -and $x -lt $info.Monitor.Right',
    '$y -ge $info.Monitor.Top -and $y -lt $info.Monitor.Bottom',
    'GetWindowThreadProcessId($browser, [ref]$browserPid)',
    'GetDpiForWindow($script:window)', 'GetDpiForWindow($browser)',
    '$launches.Count -eq 0', '$browserPid -notin', '-not $_.parsed -or -not $_.inside',
    '$mainDpi -eq 0 -or $paneDpi -ne $mainDpi',
    'commandLine = $_.CommandLine', 'monitor = $info.Monitor', 'mainDpi = $mainDpi; paneDpi = $paneDpi',
    'Save-Json $proof ("browser-pane-locked-launch-$Step.json")',
  ]) assert.ok(proof.includes(step), step);
  const journey = source.slice(source.indexOf("        'browser-pane-locked' {"), source.indexOf("        'browser-pane-stuck' {"));
  let offset = -1;
  for (const step of [
    "Open-BrowserPane 'locked-open'", "Assert-BrowserLaunchOnOwnMonitor 'initial'",
    '$process.CloseMainWindow()', '$process.WaitForExit(10000)', '$relaunchStopped = $job.Stop()',
    '$job.Dispose()', '$job = New-Object VerifyJob', '$process = $job.Start(',
    '$script:window = $process.MainWindowHandle', '[VerifyNative]::PaneVisible($script:window)',
    "'startup restored the owned browser pane without an open command' 60",
    "Assert-BrowserLaunchOnOwnMonitor 'restored'", '$_.pid -in @($initialLaunch.launches',
    "Write-Host 'browser-pane-locked launch-on-own-monitor PASS'",
  ]) {
    const next = journey.indexOf(step, offset + 1);
    assert.ok(next > offset, `missing or misordered ${step}`);
    offset = next;
  }
  assert.equal((journey.match(/Open-BrowserPane /g) || []).length, 1);
  assert.match(source, /\$warmup.CloseMainWindow\(\)/);
  assert.match(source, /\$warmup.WaitForExit\(10000\)/);
  assert.match(source, /\$chromeSetupStopped = \$warmupJob.Stop\(\)/);
  assert.match(source, /Palette 'browser engine'/);
  assert.match(source, /'dedicated Chrome selected'/);
  return proof;
}

test('journey proves first and restored Chrome launches use the owner monitor and matching DPI without vacuous success', () => {
  const proof = launchJourneyContract(driver);
  for (const before of [
    "Assert-BrowserLaunchOnOwnMonitor 'initial'", "Assert-BrowserLaunchOnOwnMonitor 'restored'",
    '$process.CloseMainWindow()', '$launches.Count -eq 0',
    '$x -ge $info.Monitor.Left', '$y -lt $info.Monitor.Bottom',
    '$paneDpi -ne $mainDpi', "Name = 'chrome.exe'",
    "Write-Host 'browser-pane-locked launch-on-own-monitor PASS'",
  ]) {
    assert.ok(driver.includes(before), `negative control exists: ${before}`);
    assert.throws(() => launchJourneyContract(driver.replaceAll(before, '')), `reject ${before}`);
  }
  const pattern = proof.match(/\$point = \[regex\]::Match\(\$_.CommandLine, '([^']+)'\)/)[1];
  const rect = { left: 0, top: 0, right: 1920, bottom: 1080 };
  for (const [argument, inside] of [
    ['0,40', true], ['1919,1079', true], ['-32000,-32000', false],
    ['-2560,-493', false], ['1920,0', false], ['0,1080', false], ['invalid', false],
  ]) {
    const match = new RegExp(pattern).exec(`chrome.exe --window-position=${argument} --window-size=400,400`);
    const actual = !!match && +match[1] >= rect.left && +match[1] < rect.right && +match[2] >= rect.top && +match[2] < rect.bottom;
    assert.equal(actual, inside, argument);
  }
});

function journeyContract(source) {
  const journey = source.slice(source.indexOf("        'browser-pane-locked' {"), source.indexOf("        'browser-pane-stuck' {"));
  assert.ok(journey.length > 0);
  for (const step of [
    'verified release tag=$env:RELEASE_TAG version=$ExpectedVersion',
    "Open-BrowserPane 'locked-open'", 'GetWindowRect($browser, [ref]$dockRect)',
    'Focus-LockedBrowser $browser', 'Get-LockedBrowserStrip $browser $dockRect',
    'DragBrowserStrip($browser, $script:window, $strip)',
    "Assert-LockedBrowserRect $browser $dockRect 'drag-blocked'",
    '[VerifyNative]::GetForegroundWindow() -ne $browser',
    '[VerifyNative]::Chord(@(0x5B, 0x26))',
    "Assert-LockedBrowserRect $browser $dockRect 'win-up-blocked'",
    'DoubleClickBrowserStrip($browser, $script:window, $strip)',
    "Assert-LockedBrowserRect $browser $dockRect 'maximize-blocked'",
    "Snapshot 'after'",
  ]) assert.ok(journey.includes(step), step);
  assert.doesNotMatch(journey, /Press @|MoveWindow|PostMessage|SendMessage/);
  const mouse = source.slice(source.indexOf('    static void MouseAt('), source.indexOf('    public static void ClickClient('));
  assert.match(mouse, /SendInput\(1,/);
  assert.match(mouse, /flags = flags \| 0xC001/);
  assert.match(mouse, /GetProp\(pane, "ZigShellPaneOwner"\) != owner/);
  assert.match(mouse, /GetForegroundWindow\(\) != pane/);
  assert.match(mouse, /GetAncestor\(WindowFromPoint\(point\), 2\) != pane/);
  assert.match(mouse, /MouseAt\(point.X, point.Y, 2\)/);
  assert.match(mouse, /step <= 20/);
  assert.match(mouse, /point.X - 300 \* step \/ 20, point.Y \+ 200 \* step \/ 20/);
  assert.match(mouse, /finally \{ MouseAt\(point.X - 300, point.Y \+ 200, 4\); \}/);
  assert.match(mouse, /new uint\[\] \{ 2, 4, 2, 4 \}/);
  const exact = source.slice(source.indexOf('function Assert-LockedBrowserRect('), source.indexOf('function Get-LockedBrowserStrip('));
  assert.match(exact, /ElapsedMilliseconds -ge 1000/);
  assert.equal((journey.match(/Assert-LockedBrowserRect \$browser \$dockRect '/g) || []).length, 3);
  assert.match(exact, /-not \[VerifyNative\]::IsZoomed\(\$Browser\)/);
  for (const edge of ['Left', 'Top', 'Right', 'Bottom']) assert.ok(exact.includes(`$current.${edge} -eq $DockRect.${edge}`));
  assert.match(exact, /exact dock rectangle and not zoomed" 5/);
  assert.match(exact, /Write-Host "browser-pane-locked \$Step PASS"/);
  const strip = source.slice(source.indexOf('function Get-LockedBrowserStrip('), source.indexOf('function Assert-ConnectedPaneStaysVisible('));
  assert.match(strip, /\$DockRect.Top \+ 8/);
  assert.match(strip, /ControlType.TabItem.*ControlType.Button.*ControlType.Edit/);
  assert.match(strip, /Strip UIA ancestry does not reach the owned browser/);
}

test('real-input journey requires exact dock geometry after drag and each maximize gesture', () => {
  journeyContract(driver);
  for (const [before, after] of [
    ['point.X - 300 * step / 20', 'point.X'],
    ['MouseAt(point.X, point.Y, 2)', 'MouseAt(point.X, point.Y, 0)'],
    ['$current.Right -eq $DockRect.Right', '$true'],
    ['-not [VerifyNative]::IsZoomed($Browser)', '$true'],
    ["Assert-LockedBrowserRect $browser $dockRect 'win-up-blocked'", ''],
    ['[VerifyNative]::Chord(@(0x5B, 0x26))', '[VerifyNative]::Chord(@(0x26))'],
    ['verified release tag=$env:RELEASE_TAG', 'verified release'],
  ]) {
    assert.ok(driver.includes(before), `negative control exists: ${before}`);
    assert.throws(() => journeyContract(driver.replaceAll(before, after)), `reject ${before}`);
  }
});

test('pane-lock journey is mapped, indexed, allowed and included in the pull-request matrix', () => {
  assert.match(driver, /ValidateSet\([^\n]*'browser-pane-locked'/);
  assert.match(driver, /if \(\$Feature -in @\('browser-pane-stuck', 'pane-layout', 'browser-pane-locked'\)\)/);
  const features = JSON.parse(workflow.match(/feature:.*github\.event_name == 'pull_request'.*fromJSON\('(\[[^']+\])'\)/)[1]);
  for (const feature of ['appearance', 'workspace-focus', 'favorites-groups', 'browser-pane-stuck', 'browser-pane-locked', 'pane-layout']) assert.ok(features.includes(feature));
  assert.match(workflow, /\$env:FEATURE -notin @\([^\n]*'browser-pane-locked'/);
  assert.ok(workflow.includes('tools/check-browser-pane-locked.test.js'));
  assert.match(workflow, /RELEASE_TAG: \$\{\{ inputs\.tag \|\| '' \}\}/);
  assert.match(workflow, /name: Build branch executable\s+if: env\.RELEASE_TAG == ''\s+run: zig build/);
  assert.match(workflow, /} else \{\s*Copy-Item zig-out\/bin\/multiprompt\.exe verify-bin\/multiprompt\.exe/);
  assert.ok(read(`${directory}/features/README.md`).includes('](browser-pane-locked.md)'));
  assert.ok(read(`${directory}/SKILL.md`).includes('`browser-pane-locked`'));
  for (const section of ['Sub-features', 'How to get to it (user POV)', 'Driving it with control.ps1', 'Gotchas']) assert.ok(map.includes(`## ${section}`));
  for (const marker of ['drag-blocked PASS', 'maximize-blocked PASS', 'launch-on-own-monitor PASS', 'tag=... version=...']) assert.ok(map.includes(marker));
});

test('existing browser recovery static contracts remain unchanged', async () => {
  await import('./check-browser-pane-stuck.mjs');
});


test('changed code is comment-free and the user-facing fragment follows the changelog format', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const [file, language] of [
    ['src/browser_pane.zig', 'zig'], ['src/main.zig', 'zig'], ['src/win32.zig', 'zig'],
    [`${directory}/control.ps1`, 'powershell'], ['.github/workflows/verify.yml', 'yaml'],
    ['tools/check-browser-pane-locked.test.js', 'javascript'], ['tools/verify-multiprompt.test.js', 'javascript'],
    ['tools/browser-overlay.test.js', 'javascript'],
  ]) assert.equal(strip(read(file), language).commentLines, 0, file);
  const fragment = readChangelogEntry('IGSH-566').trim();
  assert.equal(fragment.split('\n').length, 1);
  assert.equal(fragment, 'The browser pane stays in place: it can no longer be dragged away or maximized to full screen.');
  assert.match(read('openwiki/browser/routing-state-machine.md'), /cannot be dragged away or maximized to full screen/);
});

test('launch-scale feature map and changelog describe first launch and restored startup verification', () => {
  for (const marker of ['normal scale', 'first launch', 'relaunch', 'GetDpiForWindow', 'rcMonitor', 'browser-pane-locked-launch-initial.json', 'browser-pane-locked-launch-restored.json']) assert.ok(map.includes(marker), marker);
  const fragment = read('changelog.d/IGSH-601-browser-pane-scale.md').trim();
  assert.equal(fragment, 'The browser pane opens at its normal size after a relaunch on a two-monitor setup.');
  assert.equal(fragment.split('\n').length, 1);
});
