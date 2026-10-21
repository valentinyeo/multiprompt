const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `missing ${name}`);
  const open = source.indexOf('{', start);
  let depth = 1;
  for (let i = open + 1; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(open + 1, i);
  }
  assert.fail(`unclosed ${name}`);
}

function responsiveOrdering(main, consoleSource, session) {
  const dispatch = body(main, 'wndProc');
  const posted = dispatch.slice(dispatch.indexOf('if (msg == launch_cache.WM_DEFERRED)'), dispatch.indexOf('if (msg == WM_TIMER and wp == launch_cache.TIMER_STARTUP)'));
  assert.match(posted, /SetTimer\(hwnd, launch_cache\.TIMER_STARTUP/);
  assert.doesNotMatch(posted, /initializeDeferred|launch_cache\.deferred/);
  const initialize = body(main, 'initializeDeferred');
  assert.match(initialize, /switch \(startup_phase\)/);
  assert.doesNotMatch(initialize, /Sleep\(|WaitFor|resolveSshPath\(|pollShellNames\(/);
  assert.match(initialize, /startupRestoreReady\(\)\) return false/);
  assert.ok(initialize.indexOf('startupRestoreReady()') < initialize.indexOf('launch_cache.deferred()'));
  const spawn = body(consoleSource, 'spawnShellWithSession');
  const asyncStart = spawn.indexOf('if (asynchronous) {');
  assert.notEqual(asyncStart, -1);
  const asyncPath = spawn.slice(asyncStart, spawn.indexOf('\n    } else {', asyncStart));
  assert.match(asyncPath, /Thread\.spawn\([\s\S]*startupShellWorker/);
  assert.match(asyncPath, /GetEnvironmentStringsW/);
  assert.doesNotMatch(asyncPath, /CreateProcessW|Sleep\(|WaitFor|FindWindowW/);
  const worker = body(consoleSource, 'startupShellWorker');
  assert.match(worker, /CreateProcessW/);
  assert.match(worker, /WaitForSingleObject/);
  assert.match(worker, /PostMessageW\(job\.owner, WM_STARTUP_SHELL_READY/);
  const prepare = body(session, 'startupRestoreWorker');
  assert.match(prepare, /resolveSshPath\(false\)/);
  assert.match(prepare, /readSessionBytes/);
  assert.match(prepare, /json_reader\.parse/);
  assert.match(prepare, /startup_ready\.store\(true, \.release\)/);
  const postedShell = dispatch.slice(dispatch.indexOf('if (msg == @import("console.zig").WM_STARTUP_SHELL_READY)'), dispatch.indexOf('if (msg == WM_TIMER and wp == @import("console.zig").TIMER_STARTUP_SHELL)'));
  assert.match(postedShell, /queueStartupShell/);
  assert.doesNotMatch(postedShell, /finishStartupShell/);
  const tick = body(consoleSource, 'startupShellTick');
  assert.match(tick, /startup_completed = job\.next/);
  assert.doesNotMatch(tick, /while|for \(/);
  assert.match(tick, /finishStartupShell\(job\)/);
}

function taskbarOrdering(browser) {
  const launch = body(browser, 'browserLaunchWorker');
  assert.ok(launch.indexOf('SetWinEventHook') < launch.indexOf('ShellExecuteW'));
  assert.match(launch, /ShellExecuteW[^;]*SW_HIDE/);
  const guard = body(browser, 'browserLaunchEvent');
  assert.match(guard, /launch_guard_nonce/);
  assert.match(guard, /ZigShellPaneOwner/);
  assert.ok(guard.indexOf('ShowWindow(hwnd, SW_HIDE)') < guard.indexOf('suppressBrowserPaneAltTabEntry(hwnd)'));
  assert.match(guard, /GWLP_HWNDPARENT/);
  const dock = body(browser, 'browserDockWorker');
  assert.ok(dock.indexOf('ShowWindow(hwnd, SW_HIDE)') < dock.indexOf('suppressBrowserPaneAltTabEntry(hwnd)'));
  assert.doesNotMatch(body(browser, 'enumBrowserAdopt'), /IsWindowVisible\(hwnd\) == 0/);
  const style = body(browser, 'suppressBrowserPaneAltTabEntry');
  assert.match(style, /desired &= ~[^;]*WS_EX_APPWINDOW/);
  assert.match(style, /desired \|= [^;]*WS_EX_TOOLWINDOW/);
}

test('ISSUE-543 startup returns to input-priority timers before waiting on any console or SSH process', () => {
  responsiveOrdering(read('src/main.zig'), read('src/console.zig'), read('src/session.zig'));
});

test('ISSUE-543 hidden browser beacons get tool-window ownership before docking', () => {
  taskbarOrdering(read('src/browser_pane.zig'));
});

test('ISSUE-543 first-input timing is recorded after dispatch, once, including child-control input', () => {
  const main = body(read('src/main.zig'), 'main');
  assert.ok(main.indexOf('DispatchMessageW(&msg)') < main.indexOf('launch_cache.acceptedInput(msg.message)'));
  const input = body(read('src/launch_cache.zig'), 'acceptedInput');
  assert.match(input, /first_input or state\.g_account_locked or !plan\.isInput\(message\)/);
  assert.ok(input.indexOf('first_input = true') < input.indexOf('startup first-input ms='));
  assert.match(input, /elapsed\(\)/);
});

test('ISSUE-543 account validation stays optimistic and cannot reconcile over cached placeholder tabs', () => {
  const account = read('src/account_desktop.zig');
  const bootstrap = body(account, 'accountBootstrap');
  assert.match(bootstrap, /g_account_locked = false/);
  assert.match(bootstrap, /startAccountJob\(\.\{ \.kind = \.startup \}\)/);
  assert.doesNotMatch(bootstrap, /readDpapiFile|accountResumeJob|WaitFor|Sleep\(/);
  assert.match(body(account, 'layoutSyncWorker'), /accountResumeJob\(\.startup\)/);
  const reply = body(account, 'handleLayoutReply');
  assert.match(reply, /!reply\.unauthorized and !reply\.signed_out and reply\.job\.kind == \.startup/);
  assert.ok(reply.indexOf('startup_reply = lp') < reply.indexOf('applyServerLayout'));
  assert.match(body(account, 'resumeStartupReply'), /handleLayoutReply\(reply\)/);
});

test('ISSUE-543 late console completions bind by stable identity and discard closed or locked sessions', () => {
  const complete = body(read('src/console.zig'), 'finishStartupShell');
  assert.match(complete, /findShellById\(job\.shell_id\) orelse/);
  assert.match(complete, /g_app_closing or app_state\.g_account_locked/);
  assert.match(complete, /discardStartupShell\(job\)/);
  assert.match(complete, /idx == app_state\.active_shell/);
  const session = body(read('src/session.zig'), 'restoreSession');
  assert.match(session, /shell\.chat_id == selected_chat/);
});

test('ISSUE-543 startup retries contested registry ownership without waiting on the UI thread', () => {
  const registry = read('src/workspaces.zig');
  assert.match(body(registry, 'lockWorkspaceRegistry'), /WaitForSingleObject\(mutex, if \(app_state\.g_main_hwnd != null and @import\("launch_cache.zig"\)\.pending\) 0 else 5000\)/);
  assert.match(body(registry, 'reconcileWorkspaceRegistry'), /lockWorkspaceRegistry\(\) orelse return false/);
  const initialize = body(read('src/main.zig'), 'initializeDeferred');
  assert.match(initialize, /if \(!reconcileWorkspaceRegistry\(true\)\) return false/);
  assert.match(initialize, /if \(!reconcileWorkspaceRegistry\(false\)\) return false/);
});

if (process.env.STARTUP_BEFORE_REF) {
  const before = file => execFileSync('git', ['show', `${process.env.STARTUP_BEFORE_REF}:${file}`], { cwd: root, encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 });
  test('ISSUE-543 negative control: the real pre-fix UI startup fails the responsiveness oracle', () => {
    assert.throws(() => responsiveOrdering(before('src/main.zig'), before('src/console.zig'), before('src/session.zig')), assert.AssertionError);
  });
  test('ISSUE-543 negative control: the real pre-fix visible browser launch fails the taskbar oracle', () => {
    assert.throws(() => taskbarOrdering(before('src/browser_pane.zig')), assert.AssertionError);
  });
}
