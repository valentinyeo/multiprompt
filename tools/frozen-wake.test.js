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
  assert.match(send, /buildBrowserCdpLifecycleCmd\(&job.cmd, window_id, if \(frozen\) "frozen" else "active"\)/);
  assert.match(worker, /zsbRunBridgeOnce\(job.cmd\[0..job.cmd_len\], &reply\)/);
  assert.match(worker, /browserLifecycleReplySucceeded\(run.proc_ok, run.timed_out, run.exit_code, reply\[0..run.out_len\]\)/);
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
  for (const before of ['sendBrowserLifecycle(idx, false)', 'browser wake sent:', 'std.Thread.spawn(.{}, browserLifecycleWorker, .{job})', 'run.exit_code', 'browser_window_id != job.window_id', 'if (job.confirmed) {', 'browser_wake_requested = true', 'wake_requested or idx == app_state.active_shell']) assert.throws(() => lifecycleContract(pane.replace(before, 'false')), `reject lifecycle regression: ${before}`);
  assert.throws(() => lifecycleContract(pane.replace('    if (!sendBrowserLifecycle(idx, false)) return;', '    Sleep(1);\n    if (!sendBrowserLifecycle(idx, false)) return;')));
});

test('pure lifecycle acknowledgment helper has Zig positive and negative unit cases without running Zig here', () => {
  const helper = body(pane, 'browserLifecycleReplySucceeded');
  assert.match(helper, /if \(!proc_ok or timed_out or exit_code != 0\) return false/);
  assert.match(helper, /json_reader.parse\(std.heap.page_allocator, reply\) catch return false/);
  assert.match(helper, /return json_reader.boolTrue\(parsed.value, "ok"\)/);
  const cases = pane.slice(pane.indexOf('test "IGSH-606 lifecycle confirmation'), pane.indexOf('fn browserLifecycleWorker'));
  for (const call of ['true, false, 0, ok', 'false, false, 0, ok', 'true, true, 0, ok', 'true, false, 1, ok', 'true, false, 0, reply']) assert.ok(cases.includes(`browserLifecycleReplySucceeded(${call})`));
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
  assert.match(bridge, /pub fn zsbRunBridgeOnce/);
  assert.match(body(bridge, 'zsbRunBridgeOnce'), /CreateProcessW/);
  assert.match(workflow, /node --test [^\n]*tools\/frozen-wake.test.js/);
  assert.deepEqual(readChangelogEntry('IGSH-606').trim().split('\n'), ['Browser session switching now has a dedicated speed check.', 'Switching back to a sleeping browser pane starts waking it immediately, before the session view is drawn.']);
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
