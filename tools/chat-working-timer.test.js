const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || path.resolve(__dirname, '..');
const layout = fs.readFileSync(path.join(root, 'src/window_layout.zig'), 'utf8');
const session = fs.readFileSync(path.join(root, 'src/chat_session.zig'), 'utf8');
const live = fs.readFileSync(path.join(root, 'src/chat_live.zig'), 'utf8');
const capture = fs.readFileSync(path.join(root, 'src/chat_capture.zig'), 'utf8');

function body(source, header) {
  const start = source.indexOf(header);
  assert.ok(start >= 0, header);
  const next = source.indexOf('\n}\n', start);
  return source.slice(start, next);
}

test('a busy chat keeps one working timer across a short idle gap', () => {
  const bar = body(layout, 'pub fn chatWorkingBarVisible() bool {');
  assert.match(bar, /g_chat_working_hold_until = now \+ 1000/);
  assert.match(bar, /g_chat_working_hold_shell == app_state\.active_shell and now < app_state\.g_chat_working_hold_until/);
  const poll = body(layout, 'pub fn chatWorkingTimesPoll() void {');
  assert.match(poll, /on_screen and chatWorkingBarVisible\(\)/);
  const sync = body(layout, 'pub fn chatWorkingIndicatorSync() void {');
  assert.match(sync, /if \(!visible and app_state\.active_shell < app_state\.shell_count\)/);
  assert.match(sync, /shell\.working_since_ms = 0/);
  const liveSync = body(session, 'fn chatLiveSyncWorking() void {');
  assert.match(liveSync, /const working = live\.busy\(shell\.shell_id\)/);
  assert.match(liveSync, /if \(working\) shell\.working_since_ms = @import\("chat_working\.zig"\)\.workingSince\(shell\.working_since_ms, true, GetTickCount64\(\)\)/);
  assert.equal(liveSync.includes('workingSince(shell.working_since_ms, working,'), false);
});

test('a live reply that is still on screen counts as working', () => {
  const busy = body(live, 'pub fn busy(');
  assert.match(busy, /live\.state == \.running or live\.held/);
  const status = body(capture, 'fn chatCaptureStatus(');
  assert.match(status, /chat_live\.zig"\)\.busy\(/);
  assert.equal(status.includes('chat_live.zig").running('), false);
});
