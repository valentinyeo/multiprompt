const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
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
  const initialize = body(main, 'initializeDeferred');
  assert.match(initialize, /switch \(startup_phase\)/);
  assert.doesNotMatch(initialize, /Sleep\(|WaitFor|resolveSshPath\(|pollShellNames\(/);
  assert.match(initialize, /startupRestoreReady\(\)\) return false/);
  assert.ok(initialize.indexOf('startupRestoreReady()') < initialize.indexOf('launch_cache.deferred()'));
  const dispatch = body(main, 'wndProc');
  const posted = dispatch.slice(dispatch.indexOf('if (msg == launch_cache.WM_DEFERRED)'), dispatch.indexOf('if (msg == WM_TIMER and wp == launch_cache.TIMER_STARTUP)'));
  assert.match(posted, /SetTimer\(hwnd, launch_cache\.TIMER_STARTUP/);
  assert.doesNotMatch(posted, /initializeDeferred|launch_cache\.deferred/);
  const spawn = body(consoleSource, 'spawnShellWithSession');
  const asyncStart = spawn.indexOf('if (asynchronous) {');
  assert.notEqual(asyncStart, -1);
  const asyncPath = spawn.slice(asyncStart, spawn.indexOf('\n    }\n', asyncStart));
  assert.match(asyncPath, /Thread\.spawn\([\s\S]*startupShellWorker/);
  assert.match(asyncPath, /GetEnvironmentStringsW/);
  assert.doesNotMatch(asyncPath, /CreateProcessW|Sleep\(|WaitFor|FindWindowW/);
  assert.match(spawn, /if \(!asynchronous and CreateProcessW/);
  assert.match(spawn, /while \(!asynchronous and attempts < 50\)/);
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
  assert.match(initialize, /startup_inflight\.load\(\.acquire\) != 0\) return false/);
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

test('IGSH-522 phased startup persists the initial session after consoles finish and saving is unblocked', () => {
  const verify = (timer, initialize) => {
    assert.match(timer, /if \(app_state\.g_app_closing or initializeDeferred\(hwnd\)\) \{\s*_ = KillTimer\(hwnd, launch_cache\.TIMER_STARTUP\);\s*launch_cache\.pending = false;\s*saveSession\(\);\s*launch_cache\.changed\(\);/);
    assert.ok(initialize.indexOf('startup_inflight.load(.acquire) != 0) return false') < initialize.indexOf('.done => return true'));
    assert.match(initialize, /startup_inflight\.load\(\.acquire\) != 0\) return false/);
  };
  const main = read('src/main.zig');
  const dispatch = body(main, 'wndProc');
  const timer = dispatch.slice(dispatch.indexOf('if (msg == WM_TIMER and wp == launch_cache.TIMER_STARTUP)'), dispatch.indexOf('if (msg == WM_TIMER and wp == launch_cache.TIMER_SAVE)'));
  const initialize = body(main, 'initializeDeferred');
  verify(timer, initialize);
  for (const replacement of [
    'launch_cache.pending = false;',
    'saveSession();\n            launch_cache.pending = false;',
  ]) {
    const original = 'launch_cache.pending = false;\n            saveSession();';
    assert.ok(timer.includes(original));
    assert.throws(() => verify(timer.replace(original, replacement), initialize), assert.AssertionError);
  }
  assert.throws(() => verify(read('tools/fixtures/igsh-543/save-before/startup-timer.zig'), body(read('tools/fixtures/igsh-543/save-before/main.zig'), 'initializeDeferred')), { code: 'ERR_ASSERTION', operator: 'match' });
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
  assert.match(reply, /!reply\.unauthorized and !reply\.signed_out and !reply\.cancelled and \(reply\.job\.kind == \.startup/);
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
  assert.match(session, /const restored_active_tab = selectedSavedTab\(json, tabs\[0\.\.tab_count\], if \(@import\("launch_cache.zig"\)\.pending\) @import\("launch_cache.zig"\)\.selected_shell_id else 0\)/);
  const selected = body(read('src/session.zig'), 'selectedSavedTab');
  assert.match(selected, /for \(\[_\]u64\{ selected, json_reader\.uint\(json, "active_shell_id"\) \}\)/);
  assert.match(selected, /json_reader\.restoredSessionTab\(json, tabs, id\)/);
});

test('ISSUE-543 cached clicks survive restoration without consuming a new title range on every launch', () => {
  const cache = read('src/launch_cache.zig');
  const deferred = body(cache, 'deferred');
  assert.doesNotMatch(deferred, /selected_shell_id = state\.shells\[state\.active_shell\]\.shell_id/);
  assert.match(body(read('src/session.zig'), 'saveSession'), /if \(app_state.g_focus_user_action_tick != 0 and app_state.active_shell < app_state.shell_count\) \{\s*const shell_id = app_state.shells\[app_state.active_shell\].shell_id;\s*@import\("launch_cache.zig"\).selected_shell_id = shell_id/);
  assert.match(deferred, /closed_shells\[closed_count\] = id/);
  assert.doesNotMatch(deferred, /state\.next_shell_id = 1/);
  assert.match(body(read('src/console.zig'), 'spawnShellWithSession'), /allocateConsoleTitleId\(\)/);
  assert.match(deferred, /state\.shells\[kept\] = shell/);
  assert.match(deferred, /state\.shell_count = kept/);
  const restore = body(read('src/session.zig'), 'restoreSession');
  assert.match(restore, /closedDuringStartup\(tabs\[t\]\.shell_id\)/);
  assert.match(restore, /findShellById\(selected_live\)/);
  assert.ok(body(cache, 'bindRestoredChat').indexOf('entry.history.text.items.len != 0') < body(cache, 'bindRestoredChat').indexOf('appendSlice'));
});

test('ISSUE-543 startup retries contested registry ownership without waiting on the UI thread', () => {
  const registry = read('src/workspaces.zig');
  assert.match(body(registry, 'lockWorkspaceRegistry'), /lockWorkspaceRegistryWithTimeout\(if \(app_state\.g_main_hwnd != null and @import\("launch_cache.zig"\)\.pending and !app_state\.g_account_locked\) 0 else 5000\)/);
  assert.match(body(registry, 'reconcileWorkspaceRegistry'), /lockWorkspaceRegistry\(\) orelse return false/);
  const initialize = body(read('src/main.zig'), 'initializeDeferred');
  assert.match(initialize, /reconcileStartupWorkspaceRegistry\(true\)\) return false/);
  assert.match(initialize, /reconcileStartupWorkspaceRegistry\(false\)\) return false/);
});

const before = file => read(`tools/fixtures/igsh-543/startup-before/${path.basename(file)}`);
test('ISSUE-543 negative control: the real pre-fix UI startup fails the responsiveness oracle', () => {
  assert.throws(() => responsiveOrdering(before('src/main.zig'), before('src/console.zig'), before('src/session.zig')), { code: 'ERR_ASSERTION', operator: 'match' });
});
test('ISSUE-543 negative control: the real pre-fix visible browser launch fails the taskbar oracle', () => {
  assert.throws(() => taskbarOrdering(before('src/browser_pane.zig')), { code: 'ERR_ASSERTION', operator: 'match' });
});

const reviewBefore = file => read(`tools/fixtures/igsh-543/review-before/${path.basename(file)}`);
const reviewCases = [
  ['loading shells bypass reconnect until worker completion', read => {
    const consoleSource = read('src/console.zig');
    assert.match(body(consoleSource, 'spawnShellWithSession'), /\.console_inflight = asynchronous/);
    assert.match(body(read('src/launch_cache.zig'), 'restore'), /shell\.console_inflight = true/);
    const complete = body(consoleSource, 'finishStartupShell');
    assert.ok(complete.indexOf('console_inflight = false') < complete.indexOf('registerShellExitWait(idx)'));
    for (const name of ['sshAutoReconnectTick', 'sshDisconnect', 'sshReconnectNow', 'sshReconnectAttempt', 'sshReconnectArm', 'sshProbeStart']) {
      assert.match(body(read('src/chat_send.zig'), name), /shell\.console_inflight/);
    }
    assert.match(body(consoleSource, 'markSshTabDisconnected'), /shells\[idx\]\.console_inflight/);
    assert.match(body(read('src/main.zig'), 'wndProc'), /if \(app_state\.shells\[idx\]\.console_inflight\) return 0/);
  }],
  ['reconnect creates and retires consoles on workers without UI sleeps', read => {
    const source = read('src/console.zig');
    const respawn = body(source, 'respawnShellInPlace');
    assert.doesNotMatch(respawn, /Sleep\(|CreateProcessW\(|killProcessTree\(|WaitFor/);
    assert.match(respawn, /Thread\.spawn\([^;]*startupShellWorker/);
    assert.match(respawn, /\.console_inflight = true/);
    assert.match(respawn, /\.old_process = app_state\.shells\[idx\]\.process/);
    const worker = body(source, 'startupShellWorker');
    assert.ok(worker.indexOf('killProcessTree(job.old_pid)') < worker.indexOf('CreateProcessW('));
    assert.match(worker, /CloseHandle\(job\.old_process\)/);
  }, 'doesNotMatch'],
  ['cached zero-chat tab close and selection use saved shell identity', read => {
    const source = read('src/launch_cache.zig');
    const deferred = body(source, 'deferred');
    assert.match(deferred, /if \(!present\) \{\s*closed_shells\[closed_count\] = id/);
    assert.doesNotMatch(deferred, /selected_shell_id = state\.shells\[state\.active_shell\]\.shell_id/);
    assert.match(body(read('src/session.zig'), 'saveSession'), /if \(app_state.g_focus_user_action_tick != 0 and app_state.active_shell < app_state.shell_count\) \{\s*const shell_id = app_state.shells\[app_state.active_shell\].shell_id;\s*@import\("launch_cache.zig"\).selected_shell_id = shell_id/);
    assert.doesNotMatch(body(source, 'closedDuringStartup'), /chat/);
    const restore = body(read('src/session.zig'), 'restoreSession');
    assert.match(restore, /closedDuringStartup\(tabs\[t\]\.shell_id\)/);
    assert.match(restore, /const restored_active_tab = selectedSavedTab\(json, tabs\[0\.\.tab_count\], if \(@import\("launch_cache.zig"\)\.pending\) @import\("launch_cache.zig"\)\.selected_shell_id else 0\)/);
    assert.match(body(read('src/session.zig'), 'selectedSavedTab'), /json_reader\.restoredSessionTab\(json, tabs, id\)/);
    assert.match(restore, /restored_shell_ids\[tmux_identity\.restoreWinner\(tabs\[0\.\.tab_count\], t\)\]/);
    assert.match(restore, /findShellById\(restored_active_shell_id\)/);
  }],
  ['signed-out startup timer stops and sign-in resumes the saved phase', read => {
    const account = read('src/account_desktop.zig');
    assert.match(body(account, 'accountLock'), /KillTimer\([^;]*TIMER_STARTUP/);
    const main = body(read('src/main.zig'), 'wndProc');
    const timer = main.slice(main.indexOf('if (msg == WM_TIMER and wp == launch_cache.TIMER_STARTUP)'), main.indexOf('if (msg == WM_TIMER and wp == launch_cache.TIMER_SAVE)'));
    assert.match(timer, /if \(app_state\.g_account_locked\) \{\s*_ = KillTimer\(hwnd, launch_cache\.TIMER_STARTUP\);\s*return 0/);
    const reply = body(account, 'handleLayoutReply');
    assert.match(reply, /reply\.job\.kind == \.login and reply\.bytes != null/);
    assert.match(reply, /g_account_locked = false;\s*_ = PostMessageW\([^;]*WM_DEFERRED/);
    assert.ok(reply.indexOf('startup_reply = lp') < reply.indexOf('applyServerLayout'));
  }],
  ['registry retries are capped before a background five-second fallback', read => {
    const source = read('src/workspaces.zig');
    assert.match(body(source, 'lockWorkspaceRegistry'), /pending and !app_state\.g_account_locked\) 0 else 5000/);
    const reconcile = body(source, 'reconcileStartupWorkspaceRegistry');
    assert.match(reconcile, /startup_registry_retries < 100\) return false/);
    assert.match(reconcile, /Thread\.spawn\([^;]*startupRegistryWaitWorker/);
    assert.match(reconcile, /if \(!startup_registry_ready\.load\(\.acquire\)\) return false/);
    const finish = reconcile.slice(0, reconcile.indexOf('if (reconcileWorkspaceRegistry(force_scan))'));
    assert.match(finish, /_ = reconcileWorkspaceRegistry\(force_scan\);\s*return true/);
    assert.match(body(source, 'startupRegistryWaitWorker'), /lockWorkspaceRegistryWithTimeout\(5000\)/);
    assert.match(body(source, 'startupRegistryWaitWorker'), /unlockWorkspaceRegistry\(mutex\)/);
  }],
  ['account SSH discovery resolves before startup and cannot publish an unresolved empty list', read => {
    const source = read('src/account_desktop.zig');
    const worker = body(source, 'layoutSyncWorker');
    assert.ok(worker.indexOf('resolveSshPath(false)') >= 0 && worker.indexOf('resolveSshPath(false)') < worker.indexOf('accountResumeJob(.startup)'));
    const discovery = body(source, 'accountSyncHosts');
    assert.match(discovery, /appendSshExe\(&ssh_buf, &ssh_len\)\) return error\.SshUnavailable/);
    assert.match(discovery, /const output = try accountSshOutput/);
    const request = body(source, 'accountRequest');
    assert.ok(request.indexOf('const discovered: ?[]const account_hosts.Host = accountSyncHosts') < request.indexOf('g_account_hosts_cache ='));
    assert.ok(request.indexOf('const discovered: ?[]const account_hosts.Host = accountSyncHosts') < request.indexOf('rebased.hosts ='));
    assert.match(request, /hosts_ready = discovered != null/);
    assert.match(request, /if \(discovered\) \|found\| \{/);
    assert.match(request, /if \(hosts_ready\) synced_hosts else server\.value\.hosts/);
    const resolve = body(read('src/console.zig'), 'resolveSshPath');
    assert.match(resolve, /defer app_state\.g_ssh_resolved = true/);
  }, '=='],
  ['tabs await the published notification listener port', read => {
    const source = read('src/main.zig');
    const init = body(source, 'initializeDeferred');
    const tabs = init.slice(init.indexOf('        .tabs =>'), init.indexOf('        .chat =>'));
    assert.ok(tabs.indexOf('listener_status.load(.acquire)') >= 0 && tabs.indexOf('listener_status.load(.acquire)') < tabs.indexOf('launch_cache.deferred()'));
    assert.match(tabs, /\.pending => return false/);
    const failed = tabs.slice(tabs.indexOf('.failed => {'), tabs.indexOf('.ready =>'));
    assert.match(failed, /showHeaderNoticeAscii/);
    assert.doesNotMatch(failed, /return true/);
    const listener = body(read('src/notifications.zig'), 'notifyListenerThread');
    assert.ok(listener.indexOf('g_notify_bound_port = bound_port') < listener.indexOf('listener_status.store(.ready, .release)'));
  }, '=='],
  ['failed local workers retain a visible terminal error state', read => {
    const complete = body(read('src/console.zig'), 'finishStartupShell');
    assert.match(complete, /launch_failed = true/);
    assert.match(complete, /showHeaderNoticeAscii\("Could not start terminal/);
    const paint = body(read('src/drawing.zig'), 'paintDisconnectedShell');
    assert.match(paint, /if \(!launch_failed and reconnectButtonRect/);
    assert.match(paint, /if \(launch_failed\) L\("Terminal could not start/);
  }],
];
for (const [name, verify, operator = 'match'] of reviewCases) {
  test(`ISSUE-543 ${name}`, () => verify(read));
  test(`ISSUE-543 negative control: ${name}`, () => assert.throws(() => verify(reviewBefore), { code: 'ERR_ASSERTION', operator }));
}
