const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const pane = read('src/browser_pane.zig');
const consoleSource = read('src/console.zig');
const bridge = read('src/browser_bridge.zig');
const state = read('src/app_state.zig');
const main = read('src/main.zig');
const win = read('src/win32.zig');
const workflow = read('.github/workflows/verify.yml');
const { readChangelogEntry } = require('./changelog-entry');
const body = (source, name) => {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\n}', start);
  assert.notEqual(end, -1, name);
  return source.slice(start, end + 2);
};

function earlyWake(source) {
  const switching = body(source, 'switchToShell');
  assert.match(switching, /defer switch_timing.finish\(&timing, timing_previous, idx\);\s+if \(idx < app_state.shell_count and app_state.shells\[idx\].browser_frozen\) wakeBrowserPaneFromFreeze\(idx\);/);
  assert.equal((switching.match(/wakeBrowserPaneFromFreeze\(idx\)/g) || []).length, 1);
  const wake = switching.indexOf('wakeBrowserPaneFromFreeze(idx)');
  for (const later of ['chatAcClose()', 'g_chat_browser_swap.request', 'TIMER_CHAT_BROWSER_SWAP', 'chatDraftBindToActive()', 'sessionFrontChanged()', 'active_shell = idx']) assert.ok(wake < switching.indexOf(later), later);
}

test('frozen target wake precedes all view preparation, chat paint and browser swap timer in both views', () => {
  earlyWake(consoleSource);
  for (const before of ['idx < app_state.shell_count and ', 'app_state.shells[idx].browser_frozen', 'wakeBrowserPaneFromFreeze(idx)']) assert.throws(() => earlyWake(consoleSource.replace(before, 'false')));
  assert.throws(() => earlyWake(consoleSource.replace('if (idx < app_state.shell_count and app_state.shells[idx].browser_frozen)', 'if (!defer_browser and idx < app_state.shell_count and app_state.shells[idx].browser_frozen)')));
});

function lifecycleContract(source) {
  const wake = body(source, 'wakeBrowserPaneFromFreeze');
  const send = body(source, 'sendBrowserLifecycle');
  const worker = body(source, 'browserLifecycleWorker');
  const done = body(source, 'handleBrowserLifecycleDone');
  assert.match(wake, /sendBrowserLifecycle\(idx, false\)/);
  assert.match(wake, /browser wake sent:/);
  assert.match(wake, /browser_lifecycle_pending\) \{\s+app_state.shells\[idx\].browser_wake_requested = true;\s+return;/);
  assert.match(send, /std.Thread.spawn\(.\{\}, browserLifecycleWorker, .\{job\}\)/);
  assert.match(send, /thread.detach\(\)/);
  assert.match(send, /if \(app_state.shells\[idx\].browser_lifecycle_pending\) return false/);
  assert.match(worker, /requestBrowserForWindow\(allocator, job.window_id, if \(own_token.len > 0\) own_token else profile\[0\.\.profile_len\], "cdp", fields, null\) catch break :lifecycle/);
  assert.match(worker, /const own_token = std.mem.sliceTo\(&job.profile, 0\);/);
  assert.match(worker, /GetEnvironmentVariableA\("MULTIPROMPT_BROWSER_PROFILE"/);
  assert.match(worker, /if \(job.frozen\) @as\(\[\]const u8, "frozen"\) else "active"/);
  assert.match(worker, /job.confirmed = browserLifecycleReplySucceeded\(reply\)/);
  assert.doesNotMatch(worker, /CreateProcessW|spawnBrowserCli|zsbRunBridgeOnce|buildBrowserCdpLifecycleCmd/);
  assert.match(worker, /PostMessageW\(job.owner, @import\("win32.zig"\).WM_APP_BROWSER_LIFECYCLE_DONE/);
  for (const direct of [wake, send]) assert.doesNotMatch(direct, /CreateProcessW|WaitFor|Sleep\(|ReadFile|zsbRunBridgeOnce|setBrowserFrozenMarkerForShell/);
  for (const check of ['findShellById(job.shell_id)', 'browserConnectionMatches(&app_state.shells[idx], job.connection_id)', 'browser_window_id != job.window_id', 'browser_frozen != job.frozen']) assert.ok(done.includes(check), check);
  assert.match(done, /if \(job.confirmed\) \{\s+setBrowserFrozenMarkerForShell\(idx, job.frozen\);\s+\} else \{\s+app_state.shells\[idx\].browser_frozen = !job.frozen;/);
  assert.match(done, /browser_lifecycle_pending = false/);
  assert.match(done, /if \(job.frozen and \(wake_requested or idx == app_state.active_shell or app_state.shells\[idx\].keep_awake\)\) wakeBrowserPaneFromFreeze\(idx\)/);
  assert.match(done, /if \(job.confirmed\) @as\(\[\]const u8, "confirmed"\) else "failed"/);
}

test('lifecycle dispatch is nonblocking, serializes an inflight freeze before wake and clears markers only on matching acknowledgment', () => {
  lifecycleContract(pane);
  for (const before of ['sendBrowserLifecycle(idx, false)', 'browser wake sent:', 'std.Thread.spawn(.{}, browserLifecycleWorker, .{job})', 'requestBrowserForWindow(allocator, job.window_id', 'browser_window_id != job.window_id', 'if (job.confirmed) {', 'browser_wake_requested = true', 'wake_requested or idx == app_state.active_shell']) assert.throws(() => lifecycleContract(pane.replace(before, 'false')), `reject lifecycle regression: ${before}`);
  assert.throws(() => lifecycleContract(pane.replace('    if (!sendBrowserLifecycle(idx, false)) return;', '    Sleep(1);\n    if (!sendBrowserLifecycle(idx, false)) return;')));
});

function overlappingWakePresentation(source) {
  const wake = body(source, 'wakeBrowserPaneFromFreeze');
  const sent = wake.indexOf('if (!sendBrowserLifecycle(idx, false)) return;');
  assert.ok(sent >= 0 && sent < wake.indexOf('app_state.shells[idx].browser_frozen = false;'));
  for (const name of ['revealPaintedChatBrowser', 'positionActiveBrowser']) {
    const present = body(source, name);
    const frozen = present.indexOf('browser_frozen');
    assert.ok(frozen >= 0 && frozen < present.indexOf('setBrowserWindowPosAsync('), name);
    assert.doesNotMatch(present, /browser_lifecycle_pending/, name);
    assert.doesNotMatch(present, /sendBrowserLifecycle|setBrowserFrozenMarkerForShell|SetTimer|Sleep|WaitFor|SetForegroundWindow|SetFocus/, name);
  }
  const reveal = body(source, 'revealPaintedChatBrowser');
  for (const guard of ['g_chat_browser_swap.shell_id != app_state.shells[app_state.active_shell].shell_id', 'sh.browser_docking', 'IsWindowVisible(bh) == 0', 'actual.right - actual.left != target.right - target.left', 'actual.bottom - actual.top != target.bottom - target.top']) {
    assert.ok(reveal.indexOf(guard) >= 0 && reveal.indexOf(guard) < reveal.indexOf('setBrowserWindowPosAsync('), guard);
  }
  assert.match(reveal, /SWP_NOSIZE \| SWP_NOZORDER \| SWP_NOACTIVATE \| SWP_NOREDRAW/);
}

test('IGSH-712: dispatched wake overlaps safe native presentation without waiting for acknowledgment', () => {
  overlappingWakePresentation(pane);
  for (const name of ['revealPaintedChatBrowser', 'positionActiveBrowser']) {
    const present = body(pane, name);
    const guarded = present.replace('browser_frozen', 'browser_frozen or app_state.shells[app_state.active_shell].browser_lifecycle_pending');
    assert.throws(() => overlappingWakePresentation(pane.replace(present, guarded)), assert.AssertionError);
  }
  for (const guard of ['sh.browser_frozen', 'IsWindowVisible(bh) == 0', 'actual.right - actual.left != target.right - target.left', 'actual.bottom - actual.top != target.bottom - target.top']) {
    assert.throws(() => overlappingWakePresentation(pane.replace(guard, 'false')), assert.AssertionError);
  }
  assert.throws(() => overlappingWakePresentation(pane.replace('    if (!sendBrowserLifecycle(idx, false)) return;\n', '')), assert.AssertionError);
});

test('pure lifecycle acknowledgment helper has Zig positive and negative unit cases without running Zig here', () => {
  const helper = body(pane, 'browserLifecycleReplySucceeded');
  assert.match(helper, /json_reader.parse\(std.heap.page_allocator, reply\) catch return false/);
  assert.match(helper, /return json_reader.boolTrue\(parsed.value, "ok"\)/);
  const cases = pane.slice(pane.indexOf('test "IGSH-606 lifecycle confirmation'), pane.indexOf('fn browserLifecycleWorker'));
  assert.ok(cases.includes('try std.testing.expect(browserLifecycleReplySucceeded("{\\"ok\\":true,\\"result\\":{}}"))'));
  assert.ok(cases.includes('try std.testing.expect(!browserLifecycleReplySucceeded(reply))'));
  for (const literal of ['"not json"', '"null"', '"{}"', '"{\\"ok\\":false}"', '"{\\"ok\\":\\"true\\"}"']) assert.ok(cases.includes(literal));
});

test('existing freeze deadlines, exemptions and UI-thread completion wiring remain intact', () => {
  assert.match(state, /BROWSER_FREEZE_PARK_MS_AC: u64 = 120_000/);
  assert.match(state, /BROWSER_FREEZE_PARK_MS_SAVING: u64 = 30_000/);
  for (const field of ['browser_lifecycle_pending', 'browser_wake_requested']) {
    assert.ok(state.includes(`${field}: bool = false`));
    assert.ok(body(pane, 'resetBrowserConnection').includes(`sh.${field} = false`));
  }
  const freeze = body(pane, 'freezeBrowserPaneForShell');
  assert.match(freeze, /sendBrowserLifecycle\(idx, true\)/);
  assert.doesNotMatch(freeze, /setBrowserFrozenMarkerForShell/);
  assert.match(main, /if \(msg == @import\("win32.zig"\).WM_APP_BROWSER_LIFECYCLE_DONE\) \{\s+@import\("browser_pane.zig"\).handleBrowserLifecycleDone\(@ptrFromInt/);
  const id = win.match(/WM_APP_BROWSER_LIFECYCLE_DONE: u32 = WM_APP \+ (\d+)/)[1];
  assert.equal([...win.matchAll(new RegExp(`= WM_APP \\+ ${id};`, 'g'))].length, 1);
  assert.match(bridge, /fn zsbRunBridgeOnce/);
  assert.match(body(bridge, 'zsbRunBridgeOnce'), /CreateProcessW/);
  assert.match(workflow, /node --test [^\n]*tools\/frozen-wake.test.js/);
  const release = read('src/changelog.zig').match(/\.ver = "0\.28\.836", \.items = &\.\{([^]*?)\n    \} \}/)[1];
  const released = [...release.matchAll(/\.\{\s*\.text = ("(?:\\.|[^"\\])*"),\s*\.ticket = "IGSH-606"\s*\}/g)].map(match => JSON.parse(match[1]));
  assert.deepEqual(released, ['Browser session switching now has a dedicated speed check.', 'Switching back to a sleeping browser pane starts waking it immediately, before the session view is drawn.']);
  assert.deepEqual(readChangelogEntry('IGSH-606').trim().split('\n').filter(line => !released.includes(line)), ['Switching chat sessions with the browser open now shows the browser page faster.']);
});

test('wake changes introduce no code comments', async () => {
  const { strip } = await import('./strip-comments.mjs');
  for (const file of ['src/browser_pane.zig', 'src/browser_bridge.zig', 'src/console.zig', 'src/main.zig', 'src/win32.zig', 'src/app_state.zig']) assert.equal(strip(read(file), 'zig').commentLines, 0, file);
  assert.equal(strip(read('tools/frozen-wake.test.js'), 'javascript').commentLines, 0);
});

function cornerCache(source) {
  const move = body(source, 'moveBrowserEdgeMask');
  assert.match(move, /const need_bitmap = cached == null or !std.meta.eql\(cached.\?, paint\) or prev.right != w or prev.bottom != h;/);
  assert.match(move, /if \(same_rect and !need_bitmap and app_state.g_browser_edge_mask_shown\[idx\]\) return;/);
  assert.match(move, /if \(need_bitmap\) \{\s+if \(!updateBrowserCorner/);
  assert.match(move, /if \(!app_state.g_browser_edge_mask_shown\[idx\]\) _ = ShowWindow\(hw, SW_SHOWNOACTIVATE\)/);
}

test('unchanged corner bitmaps survive session hides while changed paint and size invalidate them', () => {
  cornerCache(pane);
  for (const before of ['or prev.right != w', 'or prev.bottom != h', 'and app_state.g_browser_edge_mask_shown[idx]', 'if (need_bitmap) {']) assert.throws(() => cornerCache(pane.replace(before, '')));
});

test('mask placement validates focus and ownership once for the whole guarded batch, not ten times', () => {
  const place = body(pane, 'positionBrowserEdgeMasks');
  for (const guard of ['activeBrowserTransientPopupHasForegroundFocus()', 'activeBrowserEdgeMasksAllowed()', 'browserChromeForegroundAllowed()', 'browserChromeHiddenForOverlay()']) assert.ok(place.indexOf(guard) >= 0 && place.indexOf(guard) < place.indexOf('moveBrowserEdgeMask('), guard);
  const move = body(pane, 'moveBrowserEdgeMask');
  assert.doesNotMatch(move, /activeBrowserTransientPopupHasForegroundFocus|activeBrowserEdgeMasksAllowed|browserChromeForegroundAllowed/);
  const callers = pane.split('\n').filter(line => line.includes('moveBrowserEdgeMask(') && !line.startsWith('fn '));
  assert.ok(callers.length > 0);
  for (const call of callers) assert.ok(place.includes(call));
});

test('completed chat paint queues browser exchange immediately without a minimum-interval timer', () => {
  const painted = body(read('src/chat_session.zig'), 'chatSwitchDidPaint');
  assert.match(painted, /didPaint\(app_state.shells\[app_state.active_shell\].shell_id\)/);
  assert.match(painted, /PostMessageW\(app_state.g_main_hwnd, WM_TIMER, TIMER_CHAT_BROWSER_SWAP, 0\)/);
  assert.doesNotMatch(painted, /SetTimer|Sleep|WaitFor/);
});

test('post-paint dispatch reuses the existing guarded PostMessageW binding exactly once', () => {
  const chat = read('src/chat_session.zig');
  assert.equal((chat.match(/^const PostMessageW =/gm) || []).length, 1);
  assert.match(chat, /const PostMessageW = @import\("focus.zig"\).PostMessageW;/);
});

test('native console switches show and focus the console before queuing browser geometry through the existing settle handler', () => {
  const switching = body(consoleSource, 'switchToShell');
  assert.match(switching, /browser_enabled and app_state.shells\[idx\].browser_native/);
  assert.match(switching, /g_browser_switch_preparing = defer_native_browser/);
  assert.match(switching, /defer app_state.g_browser_switch_preparing = browser_preparing_previous/);
  const queued = switching.indexOf('PostMessageW(app_state.g_main_hwnd, @import("win32.zig").WM_TIMER');
  assert.ok(queued > switching.indexOf('showShellConsole(idx, SW_SHOW, "switchToShell")'));
  assert.ok(queued > switching.indexOf('focusActiveShell();'));
  assert.ok(switching.includes('@import("win32.zig").TIMER_BROWSER_SETTLE, 0)'));
  for (const name of ['positionActiveBrowser', 'updateBrowserVisibility']) assert.match(body(pane, name), /if \(app_state.g_browser_switch_preparing\) return/);
  assert.match(state, /g_browser_switch_preparing: bool = false/);
});

test('native console focus retains shared masks until queued geometry instead of hiding and repainting them synchronously', () => {
  const hide = body(pane, 'hideActiveBrowser');
  assert.match(hide, /if \(!app_state.g_browser_switch_preparing\) hideBrowserEdgeMasks\(\)/);
  assert.match(hide, /parkBrowserWindow\(bh\)/);
  const place = body(pane, 'positionBrowserEdgeMasks');
  const guard = place.indexOf('if (app_state.g_browser_switch_preparing) return;');
  assert.ok(guard >= 0 && guard < place.indexOf('ensureBrowserEdgeMaskWindows()'));
  assert.ok(guard < place.indexOf('moveBrowserEdgeMask('));
});


test('after-paint Chat switches retain native edge masks throughout the old-to-new browser handoff', () => {
  const switching = body(consoleSource, 'switchToShell');
  const native = switching.slice(switching.indexOf('const defer_native_browser'), switching.indexOf('const browser_preparing_previous'));
  assert.doesNotMatch(native, /!defer_browser/);
  assert.match(body(pane, 'hideBrowserFloatingChrome'), /if \(!app_state.g_browser_switch_preparing\) hideBrowserEdgeMasks\(\)/);
  assert.match(switching, /if \(!defer_browser and defer_native_browser\)/);
});


test('shared native pipe transport targets each lifecycle window and isolates concurrent reply pipes without changing its deadlines', () => {
  const native = read('src/bridge.zig');
  assert.match(body(native, 'requestBrowser'), /return requestBrowserForWindow\(allocator, g_window_id, g_profile_token, method, fields_json, deadline\)/);
  const request = body(native, 'requestBrowserForWindow');
  assert.match(request, /request_sequence.fetchAdd\(1, \.monotonic\)/);
  assert.match(request, /buildBrowserRequest\(allocator, id, method, reply_pipe_text, window_id, fields_json\)/);
  assert.match(request, /isolatedPipeName\(&pipe_name_buf, profile_token\)/);
  assert.match(request, /const until = deadline orelse \(GetTickCount64\(\) \+ 20_000\)/);
  assert.equal((request.match(/\.\{ pid, tick, sequence \}/g) || []).length, 2);
  const done = body(pane, 'handleBrowserLifecycleDone');
  assert.match(done, /if \(job.confirmed and !job.frozen and idx == app_state.active_shell\) updateBrowserVisibility\(\)/);
  const position = body(pane, 'positionActiveBrowser');
  const wake = position.indexOf('if (app_state.shells[app_state.active_shell].browser_frozen) return;');
  assert.ok(wake >= 0 && wake < position.indexOf('setBrowserWindowPosAsync('));
  assert.doesNotMatch(done, /showBrowserWindowAsync/);
  assert.doesNotMatch(done, /SetForegroundWindow|SetFocus|Sleep|WaitFor/);
  const build = read('build.zig');
  for (const target of ['exe', 'dev_exe', 'bridge_exe']) assert.ok(build.includes(`${target}.root_module.addOptions("bridge_config", bridge_opts)`));
});


test('Chat handoff preserves immediate stray parking and the post-paint inactive-pane safety pass', () => {
  assert.match(body(consoleSource, 'switchToShell'), /app_state.active_shell = idx;\s+parkStrayBrowserPanes\(/);
  const swap = body(read('src/chat_session.zig'), 'chatSwitchBrowserTick');
  assert.ok(swap.indexOf('parkInactiveBrowserPanes()') > swap.indexOf('g_chat_browser_swap.take('));
});


test('closing or replacing a browser connection clears frozen and pending lifecycle state before the new window can dock', () => {
  for (const name of ['beginBrowserOpening', 'resetBrowserConnection']) {
    const reset = body(pane, name);
    for (const field of ['browser_frozen', 'browser_lifecycle_pending', 'browser_wake_requested']) assert.ok(reset.includes(`sh.${field} = false`));
    assert.ok(reset.includes('sh.browser_parked_since = 0'));
  }
  const position = body(pane, 'positionActiveBrowser');
  assert.ok(position.indexOf('browserChromeHiddenForOverlay()') < position.indexOf('browser_frozen) return;'));
  assert.ok(position.indexOf('if (bh == null)') < position.indexOf('browser_frozen) return;'));
});
