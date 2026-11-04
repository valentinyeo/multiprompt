const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');

const recorder = read('src/freeze_recorder.zig');
const main = read('src/main.zig');

test('responsive-loop paint starvation has an independent activation deadline', () => {
  assert.match(recorder, /pub fn activation\(active: bool\)/);
  assert.match(recorder, /if \(active == g_active\) return/);
  assert.match(recorder, /pub fn painted\(\)/);
  assert.match(recorder, /responsive and paint_detector\.probe\(demand, now\)/);
  assert.match(recorder, /record\(\.freeze, now -\| \(demand - 1\), \.paint\)/);
  assert.match(recorder, /test "paint demand threshold cancellation and recovery"/);
  assert.match(recorder, /test "activation demand is not extended/);
});

test('activation requests paint before foreground handlers and cancels on hide or minimize', () => {
  const start = main.indexOf('fn wndProc(');
  const lock = main.indexOf('if (app_state.g_account_locked)', start);
  const early = main.slice(start, lock);
  assert.match(early, /msg == WM_ACTIVATEAPP[\s\S]*freeze_recorder\.activation\(active\);[\s\S]*if \(active\) _ = InvalidateRect\(hwnd, null, 0\)/);
  assert.match(early, /msg == WM_SIZE and wp == 1[\s\S]*msg == 0x0018 and wp == 0[\s\S]*freeze_recorder\.activation\(false\)/);
  const paint = main.slice(main.indexOf('const _perf_start = GetTickCount64();', lock));
  assert.ok(paint.indexOf('defer freeze_recorder.painted();') > paint.indexOf('if (pw <= 0 or ph <= 0)'));
  assert.ok(paint.indexOf('defer freeze_recorder.painted();') < paint.indexOf('const mem_dc = ensurePaintBackbuffer'));
});

test('hosted-console foreground handoff remains an app activation', () => {
  const focus = read('src/focus.zig');
  const event = focus.slice(focus.indexOf('fn foregroundWinEventProc('), focus.indexOf('fn browserOrphanWinEventProc('));
  assert.match(event, /const ours = foregroundHwndIsOurs\(hwnd\)/);
  assert.match(event, /freeze_recorder.zig"\)\.activation\(ours and IsIconic\(app_state.g_main_hwnd\) == 0\)/);
  assert.match(event, /if \(ours or repaint_ring\) _ = InvalidateRect\(app_state.g_main_hwnd, null, 0\)/);
});

test('maximized clipping selects the proposed monitor and rejects minimized frames', () => {
  const frame = read('src/window_frame.zig');
  assert.match(frame, /IsZoomed\(hwnd\) != 0 and w\.IsIconic\(hwnd\) == 0/);
  assert.match(frame, /MonitorFromRect\(client, w\.MONITOR_DEFAULTTONEAREST\)/);
  assert.match(frame, /test "IGSH-1651 pending frame geometry cannot collapse/);
});

test('freeze evidence accepts bounded paint reasons and sizes, never arbitrary context', async () => {
  const { validateFreezeReport } = await import('./freeze-recorder-proof.mjs');
  const report = `multiprompt freeze report
version: 1.2.3
time_unix: 12345
unresponsive_ms: 5500
thread_context: captured
reason: 2
frame_size: 1920 1080
client_size: 8 1048
instruction: win32u.dll+0x123
stack_rvas:
  0x1234
app_events (uptime_ms message_id tab_index view):
  12000 0x1C 0 chat
`;
  validateFreezeReport(report);
  validateFreezeReport(report.replace('reason: 2', 'reason: 1'));
  assert.throws(() => validateFreezeReport(report.replace('reason: 2', 'reason: 3')));
  assert.throws(() => validateFreezeReport(report.replace('client_size: 8 1048', 'client_size: private-context')));
  assert.throws(() => validateFreezeReport(report + 'debug_log_tail: private-context\n'));
});
