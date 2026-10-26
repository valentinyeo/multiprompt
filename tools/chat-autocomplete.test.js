const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const src = require('./app-source').readAppSource();
const docs = fs.readFileSync('openwiki/operations/keyboard-shortcuts.md', 'utf8');
test('command browse is reachable from keyboard, palette, and F1', () => {
  assert.match(src, /SEARCH_CHAT_AC_OFFSET: usize = 6356/);
  assert.match(src, /CHAT_AC_ENTER_SENDS = false/);
  assert.match(src, /0xBF => true/);
  assert.match(src, /chatAcOpenBrowse\(\)/);
  assert.match(src, /Chat View: Insert Command or Skill\.\.\./);
  assert.match(src, /\.a = "Ctrl\+\/ in Chat View"/);
  assert.match(docs, /Ctrl\+\/ in Chat View/);
});
test('popup is hidden on send, tab switch, close and overlay', () => {
  for (const fn of ['sendChatPrompt', 'switchToShell', 'closeChatView', 'hideShellsForOverlay']) {
    assert.match(src, new RegExp(`fn ${fn}\\([^]*?\\) void \\{\\s*chatAcClose\\(\\);`));
  }
  assert.match(src, /endsInTriggerToken\(send_text/);
  assert.match(src, /g_chat_ac_mru_count/);
  assert.match(src, /chat_ac_\{s\}_\{d\}/);
  assert.match(src, /WM_APP_CHAT_AC_READY: u32 = WM_APP \+ 143/);
});

test('IGSH-911 composer CR and Ctrl+Enter LF send once; Shift+Enter and autocomplete stay native', () => {
  const os = require('node:os');
  const path = require('node:path');
  const { spawnSync } = require('node:child_process');
  const composer = fs.readFileSync('src/chat_composer.zig', 'utf8');
  const start = composer.indexOf('    if (msg == 0x0102) {', composer.indexOf('fn chatComposerProc('));
  const end = composer.indexOf('\n    return CallWindowProcW', start);
  assert.ok(start >= 0 && end > start);
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'composer-enter-'));
  const program = `const std = @import("std");
const app_state = struct {
    var g_chat_ac_tab_accepted = false;
    var g_chat_ac = struct { open: bool = false }{};
    const g_main_hwnd = 1;
};
const VK_MENU = 0x12;
const WM_APP_CHAT_SEND = 123;
const CHAT_AC_ENTER_SENDS = false;
var ctrl = false;
var shift_down = false;
var sends: usize = 0;
var notes: usize = 0;
var accepts: usize = 0;
fn isCtrlDown() bool { return ctrl; }
fn GetAsyncKeyState(key: i32) i16 { return if (key == 0x10 and shift_down) -32768 else 0; }
fn chatAcAccept() bool { accepts += 1; return true; }
fn chatAcClose() void { app_state.g_chat_ac.open = false; }
fn chatShellDraftNoteSend() void { notes += 1; }
fn PostMessageW(_: usize, _: u32, _: usize, _: usize) i32 { sends += 1; return 1; }
fn character(wp: usize) i32 {
    const msg = 0x0102;
${composer.slice(start, end)}
    return 1;
}
test "composer submit and newline behavior" {
    ctrl = true;
    try std.testing.expectEqual(@as(i32, 0), character(0x0A));
    try std.testing.expectEqual(@as(usize, 1), sends);
    try std.testing.expectEqual(@as(usize, 1), notes);
    ctrl = false;
    try std.testing.expectEqual(@as(i32, 0), character(0x0D));
    try std.testing.expectEqual(@as(usize, 2), sends);
    shift_down = true;
    try std.testing.expectEqual(@as(i32, 1), character(0x0D));
    ctrl = true;
    try std.testing.expectEqual(@as(i32, 1), character(0x0A));
    try std.testing.expectEqual(@as(usize, 2), sends);
    shift_down = false;
    ctrl = false;
    app_state.g_chat_ac.open = true;
    try std.testing.expectEqual(@as(i32, 0), character(0x0D));
    try std.testing.expectEqual(@as(usize, 1), accepts);
    try std.testing.expectEqual(@as(usize, 2), sends);
    ctrl = true;
    try std.testing.expectEqual(@as(i32, 0), character(0x0A));
    try std.testing.expectEqual(@as(usize, 3), sends);
    try std.testing.expectEqual(@as(usize, 1), accepts);
    try std.testing.expectEqual(@as(usize, 3), notes);
}
`;
  try {
    const file = path.join(directory, 'enter.zig');
    fs.writeFileSync(file, program);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '-fno-llvm', '-fno-lld'], { encoding: 'utf8', timeout: 30000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
