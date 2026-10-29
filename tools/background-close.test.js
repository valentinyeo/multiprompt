const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('unattributed close requests cannot destroy an active or locked workspace', () => {
  const main = read('src/main.zig');
  const guard = main.indexOf('if (msg == WM_CLOSE) {');
  const lock = main.indexOf('if (app_state.g_account_locked) {\n        switch (msg)');
  assert.ok(guard >= 0 && guard < lock, 'Reject unsolicited close before every shutdown path, including sign-in');
  const body = main.slice(guard, lock);
  assert.match(body, /std\.enums\.fromInt\(app_state\.CloseReason, wp\)/);
  assert.match(body, /if \(!intentional\) return 0;/);
  assert.match(body, /foreground == hwnd or @import\("win32.zig"\)\.IsChild\(hwnd, foreground\) != 0/);
  assert.match(body, /sender=\{s\} declared_sender_pid=/);
  assert.match(body, /"declared" else "unavailable"/);
  assert.match(body, /InSendMessageEx\(null\)/);
});

test('deliberate window, restart and workspace closes carry explicit reasons', () => {
  const main = read('src/main.zig');
  assert.match(main, /msg == WM_SYSCOMMAND and \(wp & 0xFFF0\) == 0xF060[\s\S]*?requestAppClose\(hwnd, \.window_control\);/);
  for (const reason of ['quit_all', 'restart', 'workspace_close']) {
    assert.ok(main.includes(`, .${reason});`), `${reason} remains available`);
  }
  for (const file of ['src/main.zig', 'src/workspaces.zig', 'src/chat_session.zig']) {
    assert.doesNotMatch(read(file), /PostMessageW\([^;]*WM_CLOSE, 0, 0\)/, `${file} has no unexplained app close`);
  }
  const state = read('src/app_state.zig');
  assert.match(state, /pub const CloseReason = enum\(usize\)/);
  assert.match(state, /PostMessageW\(target, WM_CLOSE, @intFromEnum\(reason\), @intCast\(@import\("win32.zig"\)\.GetCurrentProcessId\(\)\)\)/);
});
