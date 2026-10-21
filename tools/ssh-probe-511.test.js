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

test('ISSUE-511 respawn and every shell creation use bounded reusable ids', () => {
  for (const file of ['console.zig', 'main.zig', 'session.zig', 'account_desktop.zig']) {
    const source = read(file);
    assert.doesNotMatch(source, /next_shell_id/);
    assert.match(source, /app_state\.allocateShellId\(\) orelse/);
  }
  assert.match(body('respawnShellInPlace', read('console.zig')), /const title_id = app_state\.allocateShellId\(\) orelse return false/);
  assert.match(body('allocateShellId', state), /shells\[0\.\.shell_count\]/);
  const allocator = body('allocateShellIdFrom', state);
  assert.match(allocator, /next\.\* == 0 or next\.\* >= SPAWN_TITLE_CAP/);
  assert.match(allocator, /for \(1\.\.SPAWN_TITLE_CAP\)/);
  assert.match(allocator, /candidate \+ 1 == SPAWN_TITLE_CAP\) 1 else/);
  assert.match(allocator, /if \(!used\[id\]\)/);
  assert.match(state, /test "ISSUE-511 shell ids wrap/);
  assert.match(state, /allocateShellIdFrom\(&next, &full\)/);
  assert.match(body('chatBenchInit', read('chat_session.zig')), /if \(app_state\.shell_count == 0\) app_state\.next_shell_id = 1/);
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
  const timer = body('armSshReconnectTimerIfNeeded', send).match(/SetTimer\([^\n]*TIMER_SSH_RECONNECT, (\d+), null\)/);
  assert.ok(timer);
  assert.ok(1000 / Number(timer[1]) <= 3);
  const tick = body('sshAutoReconnectTick', send);
  assert.match(tick, /var attempted = \[_\]bool\{false\} \*\* 256/);
  assert.match(tick, /if \(!attempted\[host\] and shell\.ssh_reconnect\.due\(now\)\)/);
  assert.match(tick, /attempted\[host\] = true;\s*sshReconnectAttempt/);
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

test('ISSUE-521 reconnect paths never relayout the window or steal focus', () => {
  const console = read('console.zig');
  for (const [name, source] of [['respawnShellInPlace', console], ['markSshTabDisconnected', console], ['sshDisconnect', send], ['sshReconnectOk', send], ['sshAutoReconnectTick', send]]) {
    const fn = body(name, source);
    assert.doesNotMatch(fn, /repositionActive\(|invalidateSidebar\(|SetFocus\(|SetForegroundWindow\(|switchToShell\(|chatOutboxTick\(|showHeaderNoticeAscii\(/, name);
    assert.doesNotMatch(fn, /InvalidateRect\([^\n]*null/, name);
  }
  assert.match(body('resolveSshPath', console), /!app_state\.g_ssh_reconnect_timer_on/);
  const invalidate = body('invalidateReconnectContent', read('drawing.zig'));
  assert.match(invalidate, /eventEffects\(reconnectTabVisible\(idx\)\)\.invalidate_content/);
  assert.equal((invalidate.match(/InvalidateRect\(/g) || []).length, 1);
  assert.match(invalidate, /&rc, 0/);
  assert.match(body('markSshTabDisconnected', console), /if \(state_changed\).*invalidateReconnectContent/);
  assert.match(body('sshReconnectOk', send), /if \(state_changed\).*invalidateReconnectContent/);
  assert.match(body('respawnShellInPlace', console), /SWP_NOACTIVATE \| SWP_NOREDRAW/);
  const show = body('showReconnectedConsole', console);
  assert.match(show, /eventEffects\(/);
  assert.match(show, /shellConsoleShouldBeVisible/);
  assert.doesNotMatch(show, /repositionActive\(|SetFocus\(|SetForegroundWindow\(/);
  assert.match(reconnect, /test "ISSUE-521 reconnect effects/);
});

test('ISSUE-521 healthy probes confirm missing sessions before ending and skip ended tabs', () => {
  const worker = body('sshProbeThread', send);
  assert.match(worker, /tmux list-sessions -F '@@S #\{session_name\}' 2>\/dev\/null;/);
  assert.match(worker, /\.sessionGone\(/);
  const finish = body('sshProbeFinish', send);
  assert.match(finish, /if \(item\.session_gone\) \{\s*sshSessionEnded\(idx\);\s*continue;/);
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
  assert.match(read('app_state.zig'), /SEARCH_TABCTX_START_SESSION: usize = 7183/);
  assert.match(read('command_palette.zig'), /phase == \.ended/);
  assert.match(read('command_palette.zig'), /g_search_results\[app_state.g_search_result_count\] = SEARCH_TABCTX_START_SESSION/);
  assert.match(read('sidebar.zig'), /result_idx == SEARCH_TABCTX_START_SESSION\) L\("Start new session"\)/);
  const main = read('main.zig');
  const start = main.indexOf('if (target == SEARCH_TABCTX_RECONNECT or target == SEARCH_TABCTX_START_SESSION)');
  assert.ok(start >= 0);
  const dispatch = main.slice(start, main.indexOf('} else if', start));
  assert.match(dispatch, /sshReconnectNow\(ti\)/);
  assert.doesNotMatch(dispatch, /switchToShell|showActiveShellAfterOverlay|SetFocus|SetForegroundWindow/);
  assert.match(read('shortcuts.zig'), /Start new session/);
  assert.match(fs.readFileSync(path.join(root, 'openwiki/operations/keyboard-shortcuts.md'), 'utf8'), /Start new session/);
});
