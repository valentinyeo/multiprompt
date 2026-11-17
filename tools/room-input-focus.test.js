const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

function enterRoom(state, calls) {
  const source = fs.readFileSync('src/room_frontend.zig', 'utf8');
  const start = source.indexOf('fn enter() bool {');
  const end = source.indexOf('\n}', start);
  assert.ok(start >= 0 && end > start);
  const production = source.slice(start + 'fn enter() bool {'.length, end)
    .replaceAll(' and ', ' && ').replaceAll(' or ', ' || ')
    .replaceAll('@import("focus.zig")', 'focus')
    .replaceAll('@import("chat_composer.zig")', 'chat')
    .replaceAll('@import("voice.zig")', 'voice')
    .replaceAll('@import("rename.zig")', 'rename')
    .replaceAll('_ = ', '');
  const app = { g_main_hwnd: 'frame', g_account_locked: false, g_focus_authorized_hwnd: null,
    g_focus_authorized_until: 0, g_chat_browser_swap: { cancel() {} } };
  const focus = {
    foregroundIsOurs: () => state.foreground !== 'foreign',
    cancelShellRefocus: () => calls.push('cancel'),
    unlockBrowserForeground() { calls.push('unlock'); },
    AttachThreadInput(from, to, attach) {
      assert.equal(from, 1);
      assert.equal(to, 2);
      calls.push(attach ? 'attach' : 'detach');
      return 1;
    },
    SetForegroundWindow() {
      assert.equal(app.g_focus_authorized_hwnd, 'frame');
      assert.equal(app.g_focus_authorized_until, 2500);
      calls.push('activate');
      if (state.activationFailed) return false;
      state.foreground = 'frame';
      return true;
    },
  };
  const rename = { hideShellsForOverlay() {
    calls.push('hide');
    assert.notEqual(state.foreground, 'console', 'park the owned console before hiding it');
    assert.equal(app.g_focus_authorized_hwnd, null);
    assert.equal(app.g_focus_authorized_until, 0);
  } };
  const run = new Function('enabled', 'created', 'scope_blocked', 'ui_ready', 'app_state', 'w', 'focus', 'chat', 'voice', 'rename', production);
  const result = run(true, true, state.blocked, true, app,
    { TIMER_CHAT_BROWSER_SWAP: 1, KillTimer() {}, GetTickCount64: () => 1000,
      GetCurrentThreadId: () => 1, GetWindowThreadProcessId: () => 2,
      GetForegroundWindow: () => state.foreground }, focus,
    { chatDraftFlush() {} }, { leavePrivateVoiceTarget() {} }, rename);
  assert.equal(app.g_focus_authorized_hwnd, null);
  assert.equal(app.g_focus_authorized_until, 0);
  return result;
}

test('Rooms parks the owned foreground console before hiding it', () => {
  const calls = [];
  const state = { foreground: 'console', blocked: false };
  assert.equal(enterRoom(state, calls), true);
  assert.equal(state.foreground, 'frame');
  assert.ok(calls.indexOf('activate') < calls.indexOf('hide'));
  assert.ok(calls.indexOf('cancel') < calls.indexOf('hide'));
});

test('Rooms never steals foreground from another app', () => {
  const calls = [];
  const state = { foreground: 'foreign', blocked: false };
  assert.equal(enterRoom(state, calls), true);
  assert.equal(state.foreground, 'foreign');
  assert.ok(!calls.includes('activate'));
});

test('failed foreground activation leaves the console visible and releases temporary focus authority', () => {
  const calls = [];
  const state = { foreground: 'console', blocked: false, activationFailed: true };
  assert.equal(enterRoom(state, calls), false);
  assert.equal(state.foreground, 'console');
  assert.ok(!calls.includes('hide'));
  assert.ok(calls.includes('detach'));
});

test('an already foreground frame does not need a foreground unlock', () => {
  const calls = [];
  assert.equal(enterRoom({ foreground: 'frame', blocked: false }, calls), true);
  assert.deepEqual(calls, ['cancel', 'hide']);
});

test('a blocked Room scope cannot change foreground or hide sessions', () => {
  const calls = [];
  assert.equal(enterRoom({ foreground: 'console', blocked: true }, calls), false);
  assert.deepEqual(calls, []);
});
