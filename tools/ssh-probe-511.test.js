const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, 'src', file), 'utf8');
const send = read('chat_send.zig');
const reconnect = read('ssh_reconnect.zig');
const state = read('app_state.zig');
function body(name, source) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = source.indexOf('\n}', start);
  assert.ok(end > start, name);
  return source.slice(start, end + 2);
}

test('ISSUE-511 respawn preserves shell identity and allocates only a bounded console title', () => {
  for (const file of ['console.zig', 'main.zig', 'session.zig', 'account_desktop.zig']) {
    const source = read(file);
    assert.doesNotMatch(source, /next_shell_id/);
    assert.match(source, /app_state\.allocateShellId\(\) orelse/);
  }
  const respawn = body('respawnShellInPlace', read('console.zig'));
  assert.match(respawn, /const title_id = app_state\.allocateConsoleTitleId\(\) orelse return false/);
  assert.doesNotMatch(respawn, /allocateShellId\(|chatHistoryForget\(/);
  assert.match(respawn, /const shell_id = app_state\.shells\[idx\]\.shell_id/);
  assert.match(respawn, /\.shell_id = shell_id,\s*\.title_id = title_id/);
  assert.match(respawn, /makeCmdLine\([^\n]*null, shell_id, saved_ssh_reconnect\.create_session/);
  assert.match(respawn, /\.shell_id = shell_id, \.title_id = title_id, \.reconnect = true/);
  const worker = body('startupShellWorker', read('console.zig'));
  assert.match(worker, /si\.lpTitle = SPAWN_TITLES\[job\.title_id\]/);
  assert.match(worker, /FindWindowW\(null, SPAWN_TITLES\[job\.title_id\]\)/);
  assert.match(body('allocateConsoleTitleId', state), /&next_console_title_id, shells\[0\.\.shell_count\]/);
  assert.match(body('allocateShellId', state), /shells\[0\.\.shell_count\]/);
  const ids = body('allocateShellIdFrom', state);
  assert.match(ids, /while \(next\.\* != 0\)/);
  assert.match(ids, /next\.\* \+%= 1/);
  const allocator = body('allocateConsoleTitleIdFrom', state);
  assert.match(allocator, /next\.\* == 0 or next\.\* >= SPAWN_TITLE_CAP/);
  assert.match(allocator, /for \(1\.\.SPAWN_TITLE_CAP\)/);
  assert.match(allocator, /candidate \+ 1 == SPAWN_TITLE_CAP\) 1 else/);
  assert.match(allocator, /if \(!used\[id\]\)/);
  assert.match(allocator, /used\[shell\.title_id\] = true/);
  assert.match(state, /test "ISSUE-511 shell ids never recycle/);
  assert.match(state, /allocateConsoleTitleIdFrom\(&next, &full\)/);
  assert.doesNotMatch(body('chatBenchInit', read('chat_session.zig')), /next_shell_id/);
  assert.match(body('restore', read('launch_cache.zig')), /state\.next_shell_id != 0 and row\.id >= state\.next_shell_id\) state\.next_shell_id = row\.id \+% 1/);
});

test('ISSUE-511 one failed probe cannot disconnect a live transport', () => {
  const decision = body('probeUnreachable', reconnect);
  assert.match(decision, /return misses >= 3 and !process_alive;/);
  const finish = body('sshProbeFinish', send);
  assert.match(finish, /else if \(!job\.healthy\[item\.host\]\) \{\s*if \(@import\("ssh_reconnect\.zig"\)\.probeUnreachable\(ssh_probe_misses\[item\.host\], shellProcessAliveForRead\(idx\)\)\) \{\s*sshDisconnect\(idx, "probe-unreachable"\);\s*\}\s*\} else if \(!item\.attached\)/);
  assert.match(reconnect, /test "ISSUE-511 failed probes never override a live transport and require three misses"/);
  assert.match(reconnect, /for \(0\.\.256\)/);
});

test('ISSUE-511 consecutive probe misses reset saturate and count once per host', () => {
  assert.match(body('probeMisses', reconnect), /return if \(ok\) 0 else previous \+\| 1;/);
  const finish = body('sshProbeFinish', send);
  assert.match(finish, /if \(checked\[item\.host\]\) continue;\s*checked\[item\.host\] = true;\s*ssh_probe_misses\[item\.host\] = @import\("ssh_reconnect\.zig"\)\.probeMisses/);
  assert.equal((finish.match(/\.probeMisses\(/g) || []).length, 1);
  assert.match(reconnect, /test "ISSUE-511 probe misses count per result reset on success and saturate"/);
});

test('ISSUE-511 each host probe logs exit elapsed misses and sanitized output tail', () => {
  const finish = body('sshProbeFinish', send);
  assert.match(finish, /ssh-probe result host=\{d\} ok=\{d\} exit=\{d\} ms=\{d\} misses=\{d\} tail=\{s\}/);
  assert.match(finish, /probe\.exit_code, probe\.ms, ssh_probe_misses\[item\.host\], probe\.tail\[0\.\.probe\.len\]/);
  const worker = body('sshProbeThread', send);
  assert.match(worker, /probe\.exit_code = result\.exit_code/);
  assert.match(worker, /probe\.ms = GetTickCount64\(\) -\| started/);
  assert.match(worker, /output\[result\.len - probe\.len \.\. result\.len\]/);
  assert.match(worker, /if \(byte < 0x20 or byte == 0x7f\) ' ' else byte/);
  assert.match(send, /tail: \[60\]u8/);
  const capture = body('sshOneShotCaptureInput', read('vps.zig'));
  assert.match(capture, /exit_code: DWORD/);
  assert.match(capture, /\.len = total, \.success = exited, \.exit_code = exit_code/);
  assert.match(capture, /\.len = total, \.success = false, \.exit_code = 1/);
});

test('ISSUE-511 relaunch queues remote tabs and reconnect timer staggers host starts', () => {
  const restore = body('spawnSavedTab', read('session.zig'));
  assert.match(restore, /else if \(app_state\.g_restoring and isRemoteShellKind\(tabs\[t\]\.kind\)\)\s*preserveFailedRemoteSavedTab\(tab\) != null/);
  const account = body('applyServerLayout', read('account_desktop.zig'));
  assert.doesNotMatch(account, /spawnShellWithSession\(/);
  assert.match(account, /sshDisconnect\(app_state\.shell_count - 1, "account-restore-pending"\)/);
  const timer = body('armSshReconnectTimerIfNeeded', send).match(/if \(urgent\) (\d+) else if \(any\) 15_000/);
  assert.ok(timer);
  assert.ok(1000 / Number(timer[1]) <= 3);
  const tick = body('sshAutoReconnectTick', send);
  assert.match(tick, /var attempted = \[_\]bool\{false\} \*\* 256/);
  assert.match(tick, /if \(!attempted\[host\] and reconnecting\[host\] < 3 and shell\.ssh_reconnect\.due\(now\)\)/);
  assert.match(tick, /attempted\[host\] = true;\s*reconnecting\[host\] \+= 1;\s*sshReconnectAttempt/);
  assert.match(tick, /phase == \.reconnecting\) reconnecting\[shell\.tmux_host\] \+= 1/);
  assert.doesNotMatch(tick, /phase == \.reconnecting\) attempted/);
  assert.match(reconnect, /base \+ jitter % \(base \/ 4 \+ 1\)/);
});

test('ISSUE-511 reused ids cannot apply stale probes and stable outbox identities survive respawn', () => {
  const finish = body('sshProbeFinish', send);
  assert.match(finish, /shell\.spawn_tick != item\.spawn_tick/);
  assert.match(finish, /shell\.tmux_host != item\.host/);
  assert.match(finish, /std\.mem\.eql\(u8, shell\.tmux_session/);
  assert.match(body('sshProbeStart', send), /\.spawn_tick = shell\.spawn_tick/);
  const respawn = body('respawnShellInPlace', read('console.zig'));
  assert.match(respawn, /\.chat_id = saved_chat_id/);
  assert.match(respawn, /\.wake_id = saved_wake_id/);
  assert.doesNotMatch(body('chatOutboxKeyForShell', send), /shell_id/);
  assert.match(read('main.zig'), /if \(got_code and exit_code == @import\("win32\.zig"\)\.STILL_ACTIVE\) return 0/);
});

test('ISSUE-521 automatic reconnect paths never relayout the window or steal focus', () => {
  const console = read('console.zig');
  const forbidden = /repositionActive\(|invalidateSidebar\(|SetFocus\(|SetForegroundWindow\(|switchToShell\(|showActiveShellAfterOverlay\(|chatOutboxTick\(|showHeaderNoticeAscii\(/;
  assert.throws(() => assert.doesNotMatch('SetFocus(null);', forbidden), assert.AssertionError);
  for (const [name, source] of [['respawnShellInPlace', console], ['markSshTabDisconnected', console], ...['sshDisconnect', 'sshReconnectArm', 'sshReconnectAttempt', 'sshReconnectOk', 'sshAutoReconnectTick', 'sshProbeStart', 'sshProbeThread', 'sshProbeFinish', 'sshSessionEnded'].map(name => [name, send])]) {
    const fn = body(name, source);
    assert.doesNotMatch(fn, forbidden, name);
    assert.doesNotMatch(fn, /InvalidateRect\([^\n]*null/, name);
  }
  assert.match(body('resolveSshPath', console), /app_state\.g_ssh_reconnect_timer_ms == 0/);
  const invalidate = body('invalidateReconnectContent', read('drawing.zig'));
  assert.match(invalidate, /eventEffects\(reconnectTabVisible\(idx\)\)\.invalidate_content/);
  assert.equal((invalidate.match(/InvalidateRect\(/g) || []).length, 1);
  assert.match(invalidate, /&rc, 0/);
  assert.match(body('markSshTabDisconnected', console), /if \(state_changed\).*invalidateReconnectContent/);
  assert.match(body('sshReconnectOk', send), /if \(state_changed\).*invalidateReconnectContent/);
  assert.match(body('startupShellWorker', console), /SWP_NOACTIVATE \| SWP_NOREDRAW/);
  const show = body('showReconnectedConsole', console);
  assert.match(show, /eventEffects\(/);
  assert.match(show, /shellConsoleShouldBeVisible/);
  assert.doesNotMatch(show, /repositionActive\(|SetFocus\(|SetForegroundWindow\(/);
  assert.match(reconnect, /test "ISSUE-521 reconnect effects/);
});

test('ISSUE-521 healthy probes confirm missing sessions before ending and skip ended tabs', () => {
  const worker = body('sshProbeThread', send);
  assert.match(worker, /listing=\$\(tmux list-sessions -F '@@S #\{session_name\}' 2>&1\); if \[ \$\? -eq 0 \]/);
  assert.match(worker, /\.sessionGone\(/);
  const finish = body('sshProbeFinish', send);
  assert.match(finish, /if \(shell\.ssh_reconnect\.observeGone\(item\.session_gone, process_alive, GetTickCount64\(\)\)\) \{\s*sshSessionEnded\(idx\);\s*continue;/);
  assert.match(finish, /phase == \.ended/);
  assert.match(body('sshProbeStart', send), /phase == \.ended/);
  assert.match(body('sshAutoReconnectTick', send), /phase == \.ended/);
  assert.match(body('sshDisconnect', send), /phase == \.ended/);
  const ended = body('sshSessionEnded', send);
  assert.match(ended, /ssh-reconnect ended id=\{d\} reason=session-gone/);
  assert.match(ended, /\.end\(\)/);
  assert.doesNotMatch(ended, /repositionActive|invalidateSidebar|SetFocus|SetForegroundWindow/);
  assert.match(body('sessionGone', reconnect), /ssh_ok and exit_code == 0/);
  assert.match(reconnect, /test "ISSUE-521 session gone/);
  assert.match(reconnect, /test "ISSUE-521 ended tabs/);
  assert.match(body('due', reconnect), /!self\.awaiting_probe/);
  assert.match(body('sshDisconnect', send), /exit_code == 1.*3000/);
});

test('ISSUE-521 ended overlay and palette restart the same named host session explicitly', () => {
  const drawing = read('drawing.zig');
  assert.match(drawing, /"Session ended"/);
  assert.match(drawing, /L\("Start new session"\)/);
  const cmd = body('makeCmdLine', read('console.zig'));
  assert.match(cmd, /if \(new_session\) "tmux new-session -A -s " else "tmux attach -t "/);
  assert.match(cmd, /appendWideRemoteShellSingleQuoted\(buf, &pos, tmux_session\.\?\)/);
  assert.match(body('respawnShellInPlace', read('console.zig')), /saved_ssh_reconnect\.create_session/);
  assert.match(body('manual', reconnect), /self\.phase == \.ended/);
  const startId = state.match(/SEARCH_TABCTX_START_SESSION: usize = (\d+)/);
  assert.ok(startId);
  const urlId = state.match(/SEARCH_TABCTX_CHAT_TAB_URL: usize = (\d+)/);
  if (urlId) assert.notEqual(startId[1], urlId[1]);
  assert.match(read('command_palette.zig'), /phase == \.ended/);
  assert.match(read('command_palette.zig'), /g_search_results\[app_state.g_search_result_count\] = SEARCH_TABCTX_START_SESSION/);
  assert.match(read('sidebar.zig'), /result_idx == SEARCH_TABCTX_START_SESSION\) L\("Start new session"\)/);
  const main = read('main.zig');
  const start = main.indexOf('if (target == SEARCH_TABCTX_RECONNECT or target == SEARCH_TABCTX_START_SESSION)');
  assert.ok(start >= 0);
  const dispatch = main.slice(start, main.indexOf('} else if', start));
  assert.match(dispatch, /sshReconnectNow\(ti\)/);
  assert.match(read('shortcuts.zig'), /Start new session/);
  assert.match(fs.readFileSync(path.join(root, 'openwiki/operations/keyboard-shortcuts.md'), 'utf8'), /Start new session/);
});

test('ISSUE-521 user palette reconnect closes the palette and shows the requested tab', () => {
  const main = read('main.zig');
  const globalStart = main.indexOf('if (target == SEARCH_RECONNECT_OFFSET) {');
  assert.ok(globalStart >= 0);
  const global = main.slice(globalStart, main.indexOf('\n                }', globalStart));
  assert.match(global, /g_search_active = false;\s*app_state\.g_shell_focused = true;\s*clearSearchBackdrop\(\);\s*showActiveShellAfterOverlay\(\);\s*_ = PostMessageW\(app_state\.g_main_hwnd, WM_APP_RECONNECT, 0, 0\);\s*_ = InvalidateRect\(hwnd, null, 0\);/);
  const tabStart = main.indexOf('if (target == SEARCH_TABCTX_RECONNECT or target == SEARCH_TABCTX_START_SESSION) {');
  assert.ok(tabStart >= 0);
  const tab = main.slice(tabStart, main.indexOf('} else if', tabStart));
  assert.match(tab, /g_search_active = false;\s*app_state\.g_search_tabctx_mode = false;\s*app_state\.g_tabctx_sid = 0;\s*app_state\.g_shell_focused = true;\s*clearSearchBackdrop\(\);\s*app_state\.g_pending_new_tab_group = 0;\s*showActiveShellAfterOverlay\(\);\s*_ = InvalidateRect\(hwnd, null, 0\);\s*@import\("chat_send\.zig"\)\.sshReconnectNow\(ti\);\s*switchToShell\(ti\);/);
  assert.match(main, /const tc_sid = if \(target == SEARCH_TABCTX_START_SESSION and app_state\.g_tabctx_sid == 0 and app_state\.active_shell < app_state\.shell_count\) app_state\.shells\[app_state\.active_shell\]\.shell_id else app_state\.g_tabctx_sid;/);
});

test('ISSUE-521 visible-tab overlay restart does not request focus or switch tabs', () => {
  const main = read('main.zig');
  const clickStart = main.indexOf('if (@import("drawing.zig").reconnectButtonRect(client_rc.right)) |button| {');
  const clickEnd = main.indexOf('\n            if (chatViewOwnsInput()', clickStart);
  assert.ok(clickStart >= 0 && clickEnd > clickStart);
  const click = main.slice(clickStart, clickEnd);
  assert.match(click, /PostMessageW\(hwnd, WM_APP_RECONNECT, 0, 0\);\s*return 0;/);
  const handlerStart = main.indexOf('        WM_APP_RECONNECT => {');
  const handlerEnd = main.indexOf('\n        WM_APP_HIDE_TAB_UNTIL_ATTENTION => {', handlerStart);
  assert.ok(handlerStart >= 0 && handlerEnd > handlerStart);
  const handler = main.slice(handlerStart, handlerEnd);
  assert.match(handler, /sshReconnectNow\(app_state\.active_shell\)/);
  const forbidden = /SetFocus\(|SetForegroundWindow\(|switchToShell\(|showActiveShellAfterOverlay\(|repositionActive\(|TIMER_REFOCUS|g_shell_focused\s*=/;
  for (const source of [click, handler, body('sshReconnectNow', send), body('sshReconnectAttempt', send)]) {
    assert.doesNotMatch(source, forbidden);
  }
  const show = body('showReconnectedConsole', read('console.zig'));
  assert.match(body('positionReconnectedConsole', read('console.zig')), /SWP_NOACTIVATE \| SWP_NOREDRAW/);
  assert.match(show, /showShellConsole\(idx, SW_SHOWNOACTIVATE/);
});

test('ISSUE-513 synthetic tabs cannot start or apply probes or enter ended-session recovery', () => {
  for (const name of ['sshProbeStart', 'sshProbeFinish', 'sshSessionEnded', 'sshReconnectArm']) {
    assert.match(body(name, send), /\{\s*if \(chatBenchEnabled\(\)\) return;/, name);
  }
  for (const name of ['sshDisconnect', 'sshReconnectNow']) {
    assert.match(body(name, send), /\{\s*if \(chatBenchEnabled\(\) or idx >= app_state\.shell_count\) return;/, name);
  }
});

test('ISSUE-511 gone handling requires complete listing twice and defends live transports at the kill boundary', () => {
  assert.match(body('sessionGone', reconnect), /attached\(output, "@@LS_OK@@"\)/);
  assert.match(body('sshProbeThread', send), /job\.healthy\[item\.host\] = [^\n]*"@@LS_OK@@"/);
  const observe = body('observeGone', reconnect);
  assert.match(observe, /!self\.create_session and !self\.creating_session and \(self\.ever_healthy or self\.healthy_attach or self\.restored_session\)/);
  assert.match(observe, /gone and eligible and !process_alive/);
  assert.match(observe, /self\.gone_results >= 2/);
  const finish = body('sshProbeFinish', send);
  assert.match(finish, /const process_alive = shell\.process != null and shellProcessAliveForRead\(idx\)/);
  assert.match(finish, /if \(item\.session_gone and process_alive\) continue/);
  assert.match(finish, /gone_results > 0\) \{\s*sshRequestSessionProbe\(\);\s*continue/);
  assert.match(body('sshSessionEnded', send), /or \(shell\.process != null and shellProcessAliveForRead\(idx\)\)\) return/);
  assert.match(reconnect, /test "ISSUE-511 gone requires two consecutive results/);
  assert.match(reconnect, /test "ISSUE-511 creating reconnecting and never attached/);
  const respawn = body('respawnShellInPlace', read('console.zig'));
  assert.doesNotMatch(respawn, /ssh_reconnect\.(?:ever_healthy|restored_session|gone_results) =/);
  assert.match(body('start', reconnect), /self\.healthy_attach = false/);
  assert.match(body('preserveFailedRemoteSavedTab', read('session.zig')), /shell\.ssh_reconnect\.restored_session = tab\.kind == \.tmux/);
  assert.match(body('applyServerLayout', read('account_desktop.zig')), /shell\.ssh_reconnect\.restored_session = tab\.tmux_session\.len > 0/);
  assert.match(body('spawnShellWithSession', read('console.zig')), /const creating_session = kind == \.tmux and \(app_state\.g_pending_resurrect_len > 0 or app_state\.g_pending_tmux_cmd_len > 0\)/);
  assert.match(body('spawnShellWithSession', read('console.zig')), /\.creating_session = creating_session/);
  assert.match(body('sshAutoReconnectTick', send), /expireProbeWait\(now, shell\.spawn_tick\)/);
  assert.match(finish, /phase != \.reconnecting and !shell\.ssh_reconnect\.create_session and shell\.ssh_reconnect\.healthy_attach\) sshDisconnect/);
});

test('ISSUE-511 urgent probes bypass spawn grace and requests during a job survive completion', () => {
  assert.match(body('sshProbeStart', send), /!shell\.ssh_reconnect\.awaiting_probe and GetTickCount64\(\) -\| shell\.spawn_tick < 3000/);
  assert.match(body('sshRequestSessionProbe', send), /ssh_probe_pending_request = true;\s*ssh_probe_next_tick = 0/);
  assert.match(body('sshProbeStart', send), /ssh_probe_job = job;\s*ssh_probe_pending_request = false/);
  assert.match(body('sshProbeFinish', send), /ssh_probe_next_tick = if \(ssh_probe_pending_request\) 0 else GetTickCount64\(\) \+ 15_000/);
});

test('ISSUE-511 active respawn sizes its console before show without touching any other window', () => {
  const console = read('console.zig');
  const complete = body('finishStartupShell', console);
  assert.match(complete, /if \(job\.reconnect\) \{\s*if \(idx == app_state\.active_shell and @import\("drawing.zig"\)\.reconnectTabVisible\(idx\)\) \{\s*if \(positionReconnectedConsole\(idx\)\) showReconnectedConsole\(idx\)/);
  const reconnectComplete = complete.slice(complete.indexOf('    if (job.reconnect) {'), complete.indexOf('    if (idx == app_state.active_shell) {'));
  assert.doesNotMatch(reconnectComplete, /repositionActive|InvalidateRect|SetFocus|SetForegroundWindow/);
  assert.match(reconnectComplete, /sshRequestSessionProbe\(\)/);
  const position = body('positionReconnectedConsole', console);
  assert.match(position, /if \(!@import\("drawing.zig"\)\.reconnectTabVisible\(idx\)\) return false/);
  assert.match(position, /rc\.left = SIDEBAR_W\(\)/);
  assert.match(position, /pane\.calcBrowserLayout\(\)/);
  assert.match(position, /pane\.centeredConsoleColumn\(/);
  assert.match(position, /SetWindowPos\(shell\.hwnd,[^\n]*SWP_NOZORDER \| SWP_NOACTIVATE \| SWP_NOREDRAW/);
  assert.equal((position.match(/SetWindowPos\(/g) || []).length, 1);
  assert.doesNotMatch(position, /repositionActive|posBrowser|posMasks|SetFocus|SetForegroundWindow|ShowWindow/);
});

test('ISSUE-511 close forgets id-keyed history and browser files even without a bound window', () => {
  const close = body('closeShellRemember', read('console.zig'));
  assert.ok(close.indexOf('chatHistoryForget(') < close.indexOf('shell_count -= 1'));
  assert.ok(close.indexOf('closeBrowserForShell(idx)') < close.indexOf('shell_count -= 1'));
  const browser = body('closeBrowserForShell', read('browser_pane.zig'));
  assert.match(browser, /browser_window_id = 0;\s*removePaneSessionFilesForShell\(idx\);\s*\}\s*deleteBrowserWindowIdFile\(app_state\.shells\[idx\]\.shell_id\);\s*removePaneShellKeyFileForShell\(idx\)/);
  assert.match(browser, /removeWebView2SessionFile\(shellZsbSessionKey\(app_state\.shells\[idx\]\.shell_id, &key_buf\)\)/);
  assert.doesNotMatch(browser, /removeWebView2SessionFilesForShell\(/);
  assert.match(close, /if \(webView2OwnsShell\(idx\)\) closeWebView2\(\)/);
  assert.match(body('chatHistoryForget', read('chat_session.zig')), /entry\.retired = true/);
});
